//
//  RQNetworkManager.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//


import Foundation
import Alamofire


/// 网络管理器
/// 基于Alamofire封装的现代化网络请求库，支持拦截器、重试、公共参数等高级功能
public final class RQNetworkManager: @unchecked Sendable {
    
    // MARK: - 单例管理
    
    /// 单例实例存储
    nonisolated(unsafe) private static var _shared: RQNetworkManager? 
    private static let lock = DispatchQueue(label: "com.rqnetwork.singleton", attributes: .concurrent)
    
    /// 获取共享网络管理器实例
    /// - Important: 在使用前必须先调用configure方法进行配置
    /// 获取共享网络管理器实例
        public static var shared: RQNetworkManager {
            lock.sync(flags: .barrier) {
                guard let instance = _shared else {
                    fatalError("""
                    RQNetworkManager必须在使用前进行配置。
                    请在App启动时调用 RQNetworkManager.configure(baseURL:) 方法。
                    """)
                }
                return instance
            }
        }
    
    /// 配置网络管理器单例
    /// - Parameter configuration: 网络配置对象
    public static func configure(_ configuration: RQNetworkConfiguration = .empty) {
        lock.sync(flags: .barrier) {
            _shared = RQNetworkManager(configuration: configuration)
        }
    }
    
    /// 重置单例实例
    /// 主要用于测试环境，可以重新配置网络管理器
    public static func reset() {
        lock.sync(flags: .barrier) {
            _shared = nil
        }
    }
    
    // MARK: - 实例属性
    
    /// Alamofire会话实例
    private let session: Session
    
    /// 域名管理器
    private let domainManager: RQDomainManager
    
    /// 复合请求拦截器，管理所有请求拦截器的执行
    private let compositeInterceptor: RQCompositeRequestInterceptor
    
    /// 请求拦截器数组
    private let requestInterceptors: [RequestInterceptor]
    
    
    /// 响应拦截器数组
    private let isolationQueue = DispatchQueue(
        label: "com.rqnetwork.manager.isolation",
        attributes: .concurrent
    )
    private var _responseInterceptors: [RQResponseInterceptor] = []
    private var responseInterceptors: [RQResponseInterceptor] {
        return isolationQueue.sync {
            return _responseInterceptors
        }
    }

    /// 请求级重试配置缓存
    private let retryConfigQueue = DispatchQueue(
        label: "com.rqnetwork.retryConfig",
        attributes: .concurrent
    )
    private var retryConfigByRequestID: [UUID: RQRetryConfiguration] = [:]
    
    /// 公共头提供者回调
    private let commonHeadersProvider: (@Sendable () -> HTTPHeaders)?
    
    /// 公共参数提供者回调
    private let commonParametersProvider: (@Sendable () -> (any Sendable & Codable)?)?
    
    /// 默认超时时间
    private let defaultTimeoutInterval: TimeInterval

    /// 默认JSON解码器
    private let jsonDecoder: JSONDecoder

    /// 默认JSON编码器
    private let jsonEncoder: JSONEncoder

    /// 内部公共头标记
    static let requiresCommonHeadersHeaderKey = "X-RQ-Requires-Common-Headers"

    private final class CancelRequestHolder: @unchecked Sendable {
        private let lock = NSLock()
        private var request: Request?

        func set(_ request: Request) {
            lock.lock()
            self.request = request
            lock.unlock()
        }

        func cancel() {
            lock.lock()
            let request = self.request
            lock.unlock()
            request?.cancel()
        }
    }
    
    // MARK: - 初始化方法
    
    /// 私有初始化方法
    /// - Parameter configuration: 网络配置对象
    private init(configuration: RQNetworkConfiguration) {
        self.domainManager = configuration.domainManager
        self.requestInterceptors = configuration.requestInterceptors
        self._responseInterceptors = configuration.responseInterceptors
        self.defaultTimeoutInterval = configuration.defaultTimeoutInterval
        self.commonHeadersProvider = configuration.commonHeadersProvider
        self.commonParametersProvider = configuration.commonParametersProvider
        self.jsonDecoder = configuration.jsonDecoder
        self.jsonEncoder = configuration.jsonEncoder
        
        // 创建复合拦截器来管理所有请求拦截器
        self.compositeInterceptor = RQCompositeRequestInterceptor(interceptors: requestInterceptors)
        
        // 配置Alamofire会话
        let sessionConfiguration = URLSessionConfiguration.af.default
        sessionConfiguration.timeoutIntervalForRequest = defaultTimeoutInterval
        
        self.session = Session(
            configuration: sessionConfiguration,
            interceptor: compositeInterceptor
        )
        
        // 设置认证拦截器的公共头提供者
        setupAuthInterceptor()

        // 设置重试拦截器的请求级配置读取
        setupRetryInterceptor()
        
        print("✅ [RQNetworkManager] 初始化完成")
    }
    
    /// 设置认证拦截器的公共头提供者
    private func setupAuthInterceptor() {
        // 查找认证拦截器并设置公共头提供者
        for case let interceptor as RQAuthInterceptor in requestInterceptors {
            interceptor.commonHeadersProvider = { [weak self] in
                return self?.commonHeadersProvider?() ?? HTTPHeaders()
            }
            break // 只设置第一个找到的认证拦截器
        }
    }

    /// 设置重试拦截器的请求级配置读取
    private func setupRetryInterceptor() {
        for case let interceptor as RQRetryInterceptor in requestInterceptors {
            interceptor.retryConfigurationProvider = { [weak self] request in
                return self?.retryConfiguration(for: request)
            }
            break
        }
    }

    private func registerRetryConfiguration(_ config: RQRetryConfiguration?, for request: Request) {
        guard let config else { return }
        _ = retryConfigQueue.sync(flags: .barrier) { [weak self] in
            self?.retryConfigByRequestID[request.id] = config
        }
    }

    private func retryConfiguration(for request: Request) -> RQRetryConfiguration? {
        return retryConfigQueue.sync {
            return retryConfigByRequestID[request.id]
        }
    }

    private func removeRetryConfiguration(for request: Request) {
        _ = retryConfigQueue.sync(flags: .barrier) { [weak self] in
            self?.retryConfigByRequestID.removeValue(forKey: request.id)
        }
    }
    
    // MARK: - 拦截器管理
    
    /// 添加请求拦截器
    /// - Parameter interceptor: 要添加的请求拦截器
    public func addRequestInterceptor(_ interceptor: RequestInterceptor) {
        compositeInterceptor.addInterceptor(interceptor)
        print("➕ [RQNetworkManager] 添加请求拦截器: \(type(of: interceptor))")
    }
    
    /// 添加响应拦截器
    /// - Parameter interceptor: 要添加的响应拦截器
    public func addResponseInterceptor(_ interceptor: RQResponseInterceptor) {
        isolationQueue.sync(flags: .barrier) { [weak self] in
            self?._responseInterceptors.append(interceptor)
            print("➕ [RQNetworkManager] 添加响应拦截器: \(type(of: interceptor))")
        }
    }
    
    /// 在指定位置插入请求拦截器
    /// - Parameters:
    ///   - interceptor: 要插入的请求拦截器
    ///   - index: 插入位置
    public func insertRequestInterceptor(_ interceptor: RequestInterceptor, at index: Int) {
        compositeInterceptor.insertInterceptor(interceptor, at: index)
        print("📋 [RQNetworkManager] 在位置 \(index) 插入请求拦截器: \(type(of: interceptor))")
        
    }
    
    /// 在指定位置插入响应拦截器
    /// - Parameters:
    ///   - interceptor: 要插入的响应拦截器
    ///   - index: 插入位置
    public func insertResponseInterceptor(_ interceptor: RQResponseInterceptor, at index: Int) {
        isolationQueue.sync(flags: .barrier) { [weak self] in
            self?._responseInterceptors.insert(interceptor, at: index)
            print("📋 [RQNetworkManager] 在位置 \(index) 插入响应拦截器: \(type(of: interceptor))")
        }
    }
    
    // MARK: - 网络请求接口
    
    /// 执行网络请求
    /// - Parameters:
    ///   - request: 网络请求对象
    /// - Returns: 解码后的响应数据
    /// - Throws: 网络错误或解码错误
    @discardableResult
    public func request<T: Decodable & Sendable>(
        _ request: RQNetworkRequest
    ) async throws -> RQResponse<T> {
        let urlRequest = try buildURLRequest(from: request)
        return try await performRequestWithInterceptors(urlRequest, for: request)
    }
    
    /// 执行网络请求（Completion回调）
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - callbackQueue: 回调队列，默认主队列
    ///   - completion: 完成回调
    /// - Returns: 可取消对象
    @discardableResult
    public func request<T: Decodable & Sendable>(
        _ request: RQNetworkRequest,
        callbackQueue: DispatchQueue = .main,
        completion: @escaping @Sendable (Result<RQResponse<T>, Error>) -> Void
    ) -> RQCancelable {
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let response: RQResponse<T> = try await self.request(request)
                callbackQueue.async { completion(.success(response)) }
            } catch {
                callbackQueue.async { completion(.failure(error)) }
            }
        }
        return RQTaskCancelable(task: task)
    }
    

    /// 使用构建器执行网络请求
    @discardableResult
    public func request<T: Decodable & Sendable>(
        _ builder: RQRequestBuilder
    ) async throws -> RQResponse<T> {
        return try await request(builder.build())
    }
    
    /// 使用构建器执行网络请求（Completion回调）
    @discardableResult
    public func request<T: Decodable & Sendable>(
        _ builder: RQRequestBuilder,
        callbackQueue: DispatchQueue = .main,
        completion: @escaping @Sendable (Result<RQResponse<T>, Error>) -> Void
    ) -> RQCancelable {
        return request(builder.build(), callbackQueue: callbackQueue, completion: completion)
    }
    
    
    /// 执行文件上传请求
    /// - Parameters:
    ///   - request: 文件上传请求对象
    ///   - progressHandler: 上传进度回调
    /// - Returns: 上传响应结果
    /// - Throws: 网络错误或解码错误
    @discardableResult
    public func upload<T: Decodable & Sendable>(
        _ request: RQUploadRequest,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> RQUploadResponse<T> {
        return try await performUpload(
            request,
            progressHandler: progressHandler,
            isRetry: false
        )
    }

    /// 执行文件上传请求（Completion回调）
    @discardableResult
    public func upload<T: Decodable & Sendable>(
        _ request: RQUploadRequest,
        progressHandler: (@Sendable (Progress) -> Void)? = nil,
        callbackQueue: DispatchQueue = .main,
        completion: @escaping @Sendable (Result<RQUploadResponse<T>, Error>) -> Void
    ) -> RQCancelable {
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let response: RQUploadResponse<T> = try await self.upload(
                    request,
                    progressHandler: progressHandler
                )
                callbackQueue.async { completion(.success(response)) }
            } catch {
                callbackQueue.async { completion(.failure(error)) }
            }
        }
        return RQTaskCancelable(task: task)
    }

    /// 使用构建器执行文件上传请求
    @discardableResult
    public func upload<T: Decodable & Sendable>(
        _ builder: RQUploadRequestBuilder,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> RQUploadResponse<T> {
        return try await upload(builder.build(), progressHandler: progressHandler)
    }

    /// 使用构建器执行文件上传请求（Completion回调）
    @discardableResult
    public func upload<T: Decodable & Sendable>(
        _ builder: RQUploadRequestBuilder,
        progressHandler: (@Sendable (Progress) -> Void)? = nil,
        callbackQueue: DispatchQueue = .main,
        completion: @escaping @Sendable (Result<RQUploadResponse<T>, Error>) -> Void
    ) -> RQCancelable {
        return upload(
            builder.build(),
            progressHandler: progressHandler,
            callbackQueue: callbackQueue,
            completion: completion
        )
    }

    private func performUpload<T: Decodable & Sendable>(
        _ request: RQUploadRequest,
        progressHandler: (@Sendable (Progress) -> Void)?,
        isRetry: Bool
    ) async throws -> RQUploadResponse<T> {
        let urlRequest = try buildURLRequest(from: request)
        let decoder = resolveJSONDecoder(for: request)
        let cancelHolder = CancelRequestHolder()
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let uploadRequest = session.upload(
                    multipartFormData: { formData in
                        // 添加表单字段
                        if let formFields = request.formFields {
                            for (key, value) in formFields {
                                if let data = value.data(using: .utf8) {
                                    formData.append(data, withName: key)
                                }
                            }
                        }
                        
                        // 添加上传数据
                        for uploadData in request.uploadData {
                            switch uploadData {
                            case .data(let data, let fileName, let mimeType):
                                formData.append(data, withName: uploadData.name, fileName: fileName, mimeType: mimeType)
                            case .file(let fileURL, let fileName, let mimeType):
                                formData.append(fileURL, withName: uploadData.name, fileName: fileName, mimeType: mimeType)
                            case .stream(let stream, let fileName, let mimeType):
                                // 使用 UInt64.max 作为安全的默认长度
                                formData.append(
                                    stream.createStream(),
                                    withLength: UInt64.max,
                                    name: uploadData.name,
                                    fileName: fileName,
                                    mimeType: mimeType
                                )
                            }
                        }
                    },
                    with: urlRequest
                )
                cancelHolder.set(uploadRequest)
                if Task.isCancelled {
                    uploadRequest.cancel()
                }
                
                registerRetryConfiguration(request.retryConfiguration, for: uploadRequest)
                uploadRequest
                    .uploadProgress { progress in
                        progressHandler?(progress)
                    }
                    .validate()
                    .responseDecodable(of: T.self, decoder: decoder) { [weak self] response in
                        guard let self = self else { return }
                        self.removeRetryConfiguration(for: uploadRequest)
                        
                        Task {
                            await self.handleUploadResponse(
                                response: response,
                                request: request,
                                progressHandler: progressHandler,
                                continuation: continuation,
                                isRetry: isRetry
                            )
                        }
                    }
            }
        } onCancel: {
            cancelHolder.cancel()
        }
    }
    
    /// 执行文件下载请求
    /// - Parameters:
    ///   - request: 文件下载请求对象
    ///   - progressHandler: 下载进度回调
    /// - Returns: 下载响应结果
    /// - Throws: 网络错误
    public func download(
        _ request: RQDownloadRequest,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> RQDownloadResponse {
        return try await performDownload(
            request,
            progressHandler: progressHandler,
            isRetry: false
        )
    }

    /// 执行文件下载请求（Completion回调）
    @discardableResult
    public func download(
        _ request: RQDownloadRequest,
        progressHandler: (@Sendable (Progress) -> Void)? = nil,
        callbackQueue: DispatchQueue = .main,
        completion: @escaping @Sendable (Result<RQDownloadResponse, Error>) -> Void
    ) -> RQCancelable {
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await self.download(
                    request,
                    progressHandler: progressHandler
                )
                callbackQueue.async { completion(.success(response)) }
            } catch {
                callbackQueue.async { completion(.failure(error)) }
            }
        }
        return RQTaskCancelable(task: task)
    }

    /// 使用构建器执行文件下载请求
    public func download(
        _ builder: RQDownloadRequestBuilder,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> RQDownloadResponse {
        return try await download(builder.build(), progressHandler: progressHandler)
    }

    /// 使用构建器执行文件下载请求（Completion回调）
    @discardableResult
    public func download(
        _ builder: RQDownloadRequestBuilder,
        progressHandler: (@Sendable (Progress) -> Void)? = nil,
        callbackQueue: DispatchQueue = .main,
        completion: @escaping @Sendable (Result<RQDownloadResponse, Error>) -> Void
    ) -> RQCancelable {
        return download(
            builder.build(),
            progressHandler: progressHandler,
            callbackQueue: callbackQueue,
            completion: completion
        )
    }

    private func performDownload(
        _ request: RQDownloadRequest,
        progressHandler: (@Sendable (Progress) -> Void)?,
        isRetry: Bool
    ) async throws -> RQDownloadResponse {
        let urlRequest = try buildURLRequest(from: request)
        let destinationURL = request.destination.makeURL()
        
        let destination: DownloadRequest.Destination = { _, _ in
            return (destinationURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        let cancelHolder = CancelRequestHolder()
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let downloadRequest = session.download(urlRequest, to: destination)
                cancelHolder.set(downloadRequest)
                if Task.isCancelled {
                    downloadRequest.cancel()
                }
                
                registerRetryConfiguration(request.retryConfiguration, for: downloadRequest)
                downloadRequest
                    .downloadProgress { progress in
                        progressHandler?(progress)
                    }
                    .validate()
                    .response { [weak self] response in
                        guard let self = self else { return }
                        self.removeRetryConfiguration(for: downloadRequest)
                        
                        Task {
                            await self.handleDownloadResponse(
                                response: response,
                                request: request,
                                destinationURL: destinationURL,
                                progressHandler: progressHandler,
                                continuation: continuation,
                                isRetry: isRetry
                            )
                        }
                    }
            }
        } onCancel: {
            cancelHolder.cancel()
        }
    }
    
    // MARK: - 私有实现方法
    
    /// 构建URLRequest对象
    /// - Parameter request: 网络请求协议对象
    /// - Returns: 构建好的URLRequest
    /// - Throws: URL构建错误或参数编码错误
    private func buildURLRequest(from request: RQNetworkRequest) throws -> URLRequest {
        // 构建完整URL
        guard let baseURL = domainManager.getDomain(request.domainKey) else {
            throw RQNetworkError.invalidURL
        }
        
        let urlString = baseURL + request.path
        guard let url = URL(string: urlString) else {
            throw RQNetworkError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeoutInterval ?? defaultTimeoutInterval
        
        // 设置请求头（配置中的公共头会在拦截器中添加）
        if let requestHeaders = request.headers {
            urlRequest.headers = requestHeaders
        }

        urlRequest.headers.update(
            name: RQNetworkManager.requiresCommonHeadersHeaderKey,
            value: request.requiresCommonHeaders ? "1" : "0"
        )
        
        // 合并请求参数和公共参数
        let encoder = resolveJSONEncoder(for: request)
        let mergedParameters = try mergeParameters(
            requestParameters: request.requestParameters,
            commonParameters: commonParametersProvider?(),
            encoder: encoder
        )
        
        // 使用请求的编码器编码合并后的参数
        if let parameters = mergedParameters {
            let parameterEncoder = resolveParameterEncoder(for: request, jsonEncoder: encoder)
            urlRequest = try parameterEncoder.encode(parameters, into: urlRequest)
        }
        
        return urlRequest
    }
    
    private func mergeParameters(
        requestParameters: (any Sendable & Codable)?,
        commonParameters: (any Codable)?,
        encoder: JSONEncoder
    ) throws -> (any Sendable & Codable)? {
        let commonValue = try commonParameters.map { try encodeToJSONValue($0, encoder: encoder) }
        let requestValue = try requestParameters.map { try encodeToJSONValue($0, encoder: encoder) }
        
        switch (commonValue, requestValue) {
        case (nil, nil):
            return nil
        case (nil, let request?):
            return unwrapJSONValue(request)
        case (let common?, nil):
            return unwrapJSONValue(common)
        case (let common?, let request?):
            if case .object(let commonObject) = common, case .object(let requestObject) = request {
                return mergeJSONObjects(commonObject, requestObject)
            }
            // 非对象类型无法合并时，请求参数优先
            return unwrapJSONValue(request)
        }
    }

    private func unwrapJSONValue(_ value: RQJSONValue) -> (any Sendable & Codable) {
        if case .object(let object) = value {
            return object
        }
        return value
    }

    private func mergeJSONObjects(
        _ base: [String: RQJSONValue],
        _ override: [String: RQJSONValue]
    ) -> [String: RQJSONValue] {
        var result = base
        for (key, value) in override {
            if case .object(let baseObject) = result[key],
               case .object(let overrideObject) = value {
                result[key] = .object(mergeJSONObjects(baseObject, overrideObject))
            } else {
                result[key] = value
            }
        }
        return result
    }

    private func encodeToJSONValue(_ encodable: Encodable, encoder: JSONEncoder) throws -> RQJSONValue {
        let data = try encoder.encode(encodable)
        return try JSONDecoder().decode(RQJSONValue.self, from: data)
    }

    private func resolveJSONDecoder(for request: RQNetworkRequest) -> JSONDecoder {
        return request.jsonDecoder ?? jsonDecoder
    }

    private func resolveJSONEncoder(for request: RQNetworkRequest) -> JSONEncoder {
        return request.jsonEncoder ?? jsonEncoder
    }

    private func resolveParameterEncoder(
        for request: RQNetworkRequest,
        jsonEncoder: JSONEncoder
    ) -> ParameterEncoder {
        if request.requestEncoder is JSONParameterEncoder {
            return JSONParameterEncoder(encoder: jsonEncoder)
        }
        return request.requestEncoder
    }
    
    /// 执行带拦截器的网络请求
    /// - Parameters:
    ///   - urlRequest: URL请求对象
    ///   - request: 网络请求协议对象
    ///   - isRetry: 是否是重试请求
    /// - Returns: 解码后的响应数据
    private func performRequestWithInterceptors<T: Decodable & Sendable>(
        _ urlRequest: URLRequest,
        for request: RQNetworkRequest,
        isRetry: Bool = false
    ) async throws -> RQResponse<T> {
        let cancelHolder = CancelRequestHolder()
        
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let dataRequest = session.request(urlRequest)
                cancelHolder.set(dataRequest)
                if Task.isCancelled {
                    dataRequest.cancel()
                }
                
                registerRetryConfiguration(request.retryConfiguration, for: dataRequest)
                dataRequest
                    .validate()
                    .responseData { [weak self] response in
                        guard let self = self else { return }
                        self.removeRetryConfiguration(for: dataRequest)
                        
                        Task {
                            await self.handleResponseWithInterceptors(
                                response: response,
                                request: request,
                                continuation: continuation,
                                isRetry: isRetry
                            )
                        }
                    }
            }
        } onCancel: {
            cancelHolder.cancel()
        }
    }
    
    /// 处理带拦截器的响应
    /// - Parameters:
    ///   - response: Alamofire响应对象
    ///   - request: 原始请求对象
    ///   - continuation: 异步续体
    ///   - isRetry: 是否是重试请求
    private func handleResponseWithInterceptors<T: Decodable & Sendable>(
        response: AFDataResponse<Data>,
        request: RQNetworkRequest,
        continuation: CheckedContinuation<RQResponse<T>, Error>,
        isRetry: Bool
    ) async {
        
        // 执行响应拦截器
        for interceptor in responseInterceptors {
            let result = await interceptor.intercept(
                data: response.data,
                response: response.response,
                error: response.error,
                for: request
            )
            
            switch result {
            case .proceed:
                continue
                
            case .retry(let delay):
                if !isRetry {
                    // 等待指定延迟后重试
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    
                    self.handleRetry(
                        request: request,
                        originalData: response.data,
                        originalResponse: response.response,
                        interceptor: interceptor,
                        continuation: continuation
                    )
                    return
                }
                
            case .fail(let error):
                continuation.resume(throwing: error)
                return
            }
        }
        
        // 正常处理响应
        await handleNormalResponse(
            response: response,
            request: request,
            continuation: continuation
        )
    }
    
    /// 处理正常响应（无拦截器干预）
    /// - Parameters:
    ///   - response: Alamofire响应对象
    ///   - request: 原始请求对象
    ///   - continuation: 异步续体
    private func handleNormalResponse<T: Decodable & Sendable>(
        response: AFDataResponse<Data>,
        request: RQNetworkRequest,
        continuation: CheckedContinuation<RQResponse<T>, Error>
    ) async {
        switch response.result {
        case .success(let data):
            do {
                let decoder = resolveJSONDecoder(for: request)
                let decoded = try decoder.decode(T.self, from: data)
                let rqResponse = RQResponse(
                    data: decoded,
                    statusCode: response.response?.statusCode ?? 0,
                    headers: mapHeaderFields(response.response?.allHeaderFields),
                    metrics: mapMetrics(response.metrics)
                )
                continuation.resume(returning: rqResponse)
            } catch {
                continuation.resume(throwing: RQNetworkError.decodingFailed(error))
            }
            
        case .failure(let error):
            continuation.resume(throwing: self.mapError(error))
        }
    }
    
    /// 处理上传响应
    /// - Parameters:
    ///   - response: Alamofire上传响应对象
    ///   - request: 上传请求对象
    ///   - continuation: 异步续体
    private func handleUploadResponse<T: Decodable & Sendable>(
        response: AFDataResponse<T>,
        request: RQUploadRequest,
        progressHandler: (@Sendable (Progress) -> Void)?,
        continuation: CheckedContinuation<RQUploadResponse<T>, Error>,
        isRetry: Bool
    ) async {
        
        // 执行响应拦截器
        for interceptor in responseInterceptors {
            let result = await interceptor.intercept(
                data: response.data,
                response: response.response,
                error: response.error,
                for: request
            )
            
            switch result {
            case .retry(let delay):
                if isRetry {
                    continue
                }
                // 等待指定延迟后重试
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
                self.handleUploadRetry(
                    request: request,
                    progressHandler: progressHandler,
                    originalData: response.data,
                    interceptor: interceptor,
                    continuation: continuation
                )
                return
                
            case .fail(let error):
                continuation.resume(throwing: error)
                return
                
            case .proceed:
                continue
            }
        }
        
        // 正常处理上传响应
        switch response.result {
        case .success(let data):
            let rqResponse = RQResponse(
                data: data,
                statusCode: response.response?.statusCode ?? 0,
                headers: mapHeaderFields(response.response?.allHeaderFields),
                metrics: mapMetrics(response.metrics)
            )
            
            let uploadResponse = RQUploadResponse(
                response: rqResponse
            )
            
            continuation.resume(returning: uploadResponse)
            
        case .failure(let error):
            continuation.resume(throwing: self.mapError(error))
        }
    }
    
    /// 处理下载响应
    /// - Parameters:
    ///   - response: Alamofire下载响应对象
    ///   - destinationURL: 目标文件URL
    ///   - continuation: 异步续体
    private func handleDownloadResponse(
        response: AFDownloadResponse<URL?>,
        request: RQDownloadRequest,
        destinationURL: URL,
        progressHandler: (@Sendable (Progress) -> Void)?,
        continuation: CheckedContinuation<RQDownloadResponse, Error>,
        isRetry: Bool
    ) async {

        for interceptor in responseInterceptors {
            let result = await interceptor.intercept(
                data: nil,
                response: response.response,
                error: response.error,
                for: request
            )

            switch result {
            case .retry(let delay):
                if isRetry {
                    continue
                }

                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                self.handleDownloadRetry(
                    request: request,
                    progressHandler: progressHandler,
                    originalData: nil,
                    interceptor: interceptor,
                    continuation: continuation
                )
                return

            case .fail(let error):
                continuation.resume(throwing: error)
                return

            case .proceed:
                continue
            }
        }

        switch response.result {
        case .success(let url):
            let fileURL = url ?? destinationURL
            let downloadResponse = RQDownloadResponse(
                localURL: fileURL,
                response: mapHTTPResponse(response.response)
            )
            continuation.resume(returning: downloadResponse)

        case .failure(let error):
            continuation.resume(throwing: self.mapError(error))
        }
    }
    
    /// 处理重试逻辑
    /// - Parameters:
    ///   - request: 原始请求对象
    ///   - originalData: 原始响应数据
    ///   - originalResponse: 原始响应对象
    ///   - interceptor: 触发重试的拦截器
    ///   - continuation: 异步续体
    private func handleRetry<T: Decodable & Sendable>(
        request: RQNetworkRequest,
        originalData: Data?,
        originalResponse: URLResponse?,
        interceptor: RQResponseInterceptor,
        continuation: CheckedContinuation<RQResponse<T>, Error>
    ) {
        interceptor.handleRetry(request, originalData: originalData) { result in
            switch result {
            case .success:
                // 重试原始请求
                Task {
                    do {
                        let urlRequest = try self.buildURLRequest(from: request)
                        let response: RQResponse<T> = try await self.performRequestWithInterceptors(
                            urlRequest,
                            for: request,
                            isRetry: true
                        )
                        continuation.resume(returning: response)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// 处理上传重试逻辑
    /// - Parameters:
    ///   - request: 上传请求对象
    ///   - originalData: 原始响应数据
    ///   - interceptor: 触发重试的拦截器
    ///   - continuation: 异步续体
    private func handleUploadRetry<T: Decodable & Sendable>(
        request: RQUploadRequest,
        progressHandler: (@Sendable (Progress) -> Void)?,
        originalData: Data?,
        interceptor: RQResponseInterceptor,
        continuation: CheckedContinuation<RQUploadResponse<T>, Error>
    ) {
        interceptor.handleRetry(request, originalData: originalData) { result in
            switch result {
            case .success:
                // 重试原始上传请求
                Task {
                    do {
                        let response: RQUploadResponse<T> = try await self.performUpload(
                            request,
                            progressHandler: progressHandler,
                            isRetry: true
                        )
                        continuation.resume(returning: response)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }

    /// 处理下载重试逻辑
    /// - Parameters:
    ///   - request: 下载请求对象
    ///   - originalData: 原始响应数据
    ///   - interceptor: 触发重试的拦截器
    ///   - continuation: 异步续体
    private func handleDownloadRetry(
        request: RQDownloadRequest,
        progressHandler: (@Sendable (Progress) -> Void)?,
        originalData: Data?,
        interceptor: RQResponseInterceptor,
        continuation: CheckedContinuation<RQDownloadResponse, Error>
    ) {
        interceptor.handleRetry(request, originalData: originalData) { result in
            switch result {
            case .success:
                Task {
                    do {
                        let response = try await self.performDownload(
                            request,
                            progressHandler: progressHandler,
                            isRetry: true
                        )
                        continuation.resume(returning: response)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }

            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// 映射Alamofire错误到RQNetworkError
    /// - Parameter error: Alamofire错误
    /// - Returns: RQNetworkError错误
    private func mapError(_ error: AFError) -> RQNetworkError {
        return RQNetworkError.from(error)
    }

    /// 将响应头转换为可Sendable的字典
    private func mapHeaderFields(_ headerFields: [AnyHashable: Any]?) -> [String: String] {
        guard let headerFields else { return [:] }
        var headers: [String: String] = [:]
        headers.reserveCapacity(headerFields.count)
        for (key, value) in headerFields {
            let name = String(describing: key)
            let stringValue = String(describing: value)
            headers[name] = stringValue
        }
        return headers
    }

    /// 将URLSessionTaskMetrics转换为可Sendable的快照
    private func mapMetrics(_ metrics: URLSessionTaskMetrics?) -> RQResponseMetrics? {
        guard let metrics else { return nil }
        return RQResponseMetrics(
            duration: metrics.taskInterval.duration,
            redirectCount: metrics.redirectCount,
            transactionCount: metrics.transactionMetrics.count
        )
    }

    /// 将HTTPURLResponse转换为可Sendable的快照
    private func mapHTTPResponse(_ response: HTTPURLResponse?) -> RQHTTPResponse? {
        guard let response else { return nil }
        return RQHTTPResponse(
            url: response.url,
            statusCode: response.statusCode,
            headers: mapHeaderFields(response.allHeaderFields)
        )
    }
}

// MARK: - 便捷方法扩展

extension RQNetworkManager {
    
    /// 快速执行GET请求
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - parameters: 查询参数
    /// - Returns: 解码后的响应数据
    @discardableResult
    public func get<T: Decodable & Sendable>(
        domainKey: RQDomainKey,
        path: String,
        parameters: (Codable & Sendable)? = nil
    ) async throws -> RQResponse<T> {
        let request = RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.get)
            .setRequestParameters(parameters)
            .build()
        
        return try await self.request(request)
    }

    /// 快速执行GET请求（Completion回调）
    @discardableResult
    public func get<T: Decodable & Sendable>(
        domainKey: RQDomainKey,
        path: String,
        parameters: (Codable & Sendable)? = nil,
        callbackQueue: DispatchQueue = .main,
        completion: @escaping @Sendable (Result<RQResponse<T>, Error>) -> Void
    ) -> RQCancelable {
        let builder = RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.get)
            .setRequestParameters(parameters)
        return request(builder, callbackQueue: callbackQueue, completion: completion)
    }
    
    /// 快速执行POST请求
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - parameters: 请求体参数
    /// - Returns: 解码后的响应数据
    @discardableResult
    public func post<T: Decodable & Sendable>(
        domainKey: RQDomainKey,
        path: String,
        parameters: (Codable & Sendable)? = nil
    ) async throws -> RQResponse<T> {
        let request = RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.post)
            .setRequestParameters(parameters)
            .build()
        
        return try await self.request(request)
    }

    /// 快速执行POST请求（Completion回调）
    @discardableResult
    public func post<T: Decodable & Sendable>(
        domainKey: RQDomainKey,
        path: String,
        parameters: (Codable & Sendable)? = nil,
        callbackQueue: DispatchQueue = .main,
        completion: @escaping @Sendable (Result<RQResponse<T>, Error>) -> Void
    ) -> RQCancelable {
        let builder = RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.post)
            .setRequestParameters(parameters)
        return request(builder, callbackQueue: callbackQueue, completion: completion)
    }
    
    /// 快速执行PUT请求
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - parameters: 请求体参数
    /// - Returns: 解码后的响应数据
    @discardableResult
    public func put<T: Decodable & Sendable>(
        domainKey: RQDomainKey,
        path: String,
        parameters: (Codable & Sendable)? = nil
    ) async throws -> RQResponse<T> {
        let request = RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.put)
            .setRequestParameters(parameters)
            .build()
        
        return try await self.request(request)
    }

    /// 快速执行PUT请求（Completion回调）
    @discardableResult
    public func put<T: Decodable & Sendable>(
        domainKey: RQDomainKey,
        path: String,
        parameters: (Codable & Sendable)? = nil,
        callbackQueue: DispatchQueue = .main,
        completion: @escaping @Sendable (Result<RQResponse<T>, Error>) -> Void
    ) -> RQCancelable {
        let builder = RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.put)
            .setRequestParameters(parameters)
        return request(builder, callbackQueue: callbackQueue, completion: completion)
    }
    
    /// 快速执行DELETE请求
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - parameters: 查询参数
    /// - Returns: 解码后的响应数据
    @discardableResult
    public func delete<T: Decodable & Sendable>(
        domainKey: RQDomainKey,
        path: String,
        parameters: (Codable & Sendable)? = nil
    ) async throws -> RQResponse<T> {
        let request = RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.delete)
            .setRequestParameters(parameters)
            .build()
        
        return try await self.request(request)
    }

    /// 快速执行DELETE请求（Completion回调）
    @discardableResult
    public func delete<T: Decodable & Sendable>(
        domainKey: RQDomainKey,
        path: String,
        parameters: (Codable & Sendable)? = nil,
        callbackQueue: DispatchQueue = .main,
        completion: @escaping @Sendable (Result<RQResponse<T>, Error>) -> Void
    ) -> RQCancelable {
        let builder = RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.delete)
            .setRequestParameters(parameters)
        return request(builder, callbackQueue: callbackQueue, completion: completion)
    }
}
