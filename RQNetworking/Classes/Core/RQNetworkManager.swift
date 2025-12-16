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
        _shared = nil
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
    
    /// 公共头提供者回调
    private let commonHeadersProvider: (@Sendable () -> HTTPHeaders)?
    
    /// 公共参数提供者回调
    private let commonParametersProvider: (@Sendable () -> (any Sendable & Codable)?)?
    
    /// 默认超时时间
    private let defaultTimeoutInterval: TimeInterval
    
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
    
    // MARK: - 拦截器管理
    
    /// 添加请求拦截器
    /// - Parameter interceptor: 要添加的请求拦截器
    public func addRequestInterceptor(_ interceptor: RequestInterceptor) {
        compositeInterceptor.interceptors.append(interceptor)
        print("➕ [RQNetworkManager] 添加请求拦截器: \(type(of: interceptor))")
    }
    
    /// 添加响应拦截器
    /// - Parameter interceptor: 要添加的响应拦截器
    public func addResponseInterceptor(_ interceptor: RQResponseInterceptor) {
        isolationQueue.async(flags: .barrier) { [weak self] in
            self?._responseInterceptors.append(interceptor)
            print("➕ [RQNetworkManager] 添加响应拦截器: \(type(of: interceptor))")
        }
    }
    
    /// 在指定位置插入请求拦截器
    /// - Parameters:
    ///   - interceptor: 要插入的请求拦截器
    ///   - index: 插入位置
    public func insertRequestInterceptor(_ interceptor: RequestInterceptor, at index: Int) {
        compositeInterceptor.interceptors.insert(interceptor, at: index)
        print("📋 [RQNetworkManager] 在位置 \(index) 插入请求拦截器: \(type(of: interceptor))")
        
    }
    
    /// 在指定位置插入响应拦截器
    /// - Parameters:
    ///   - interceptor: 要插入的响应拦截器
    ///   - index: 插入位置
    public func insertResponseInterceptor(_ interceptor: RQResponseInterceptor, at index: Int) {
        isolationQueue.async(flags: .barrier) { [weak self] in
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
    public func request<T: Decodable>(
        _ request: RQNetworkRequest
    ) async throws -> RQResponse<T> {
        let urlRequest = try buildURLRequest(from: request)
        return try await performRequestWithInterceptors(urlRequest, for: request)
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
        progressHandler: ((Progress) -> Void)? = nil
    ) async throws -> RQUploadResponse<T> {
        let urlRequest = try buildURLRequest(from: request)
        
        return try await withCheckedThrowingContinuation { continuation in
            session.upload(
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
            .uploadProgress { progress in
                progressHandler?(progress)
            }
            .validate()
            .responseDecodable(of: T.self) { [weak self] response in
                guard let self = self else { return }
                
                Task {
                    await self.handleUploadResponse(
                        response: response,
                        request: request,
                        continuation: continuation
                    )
                }
            }
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
        progressHandler: ((Progress) -> Void)? = nil
    ) async throws -> RQDownloadResponse {
        let urlRequest = try buildURLRequest(from: request)
        let destinationURL = request.destination.makeURL()
        
        let destination: DownloadRequest.Destination = { _, _ in
            return (destinationURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            session.download(urlRequest, to: destination)
                .downloadProgress { progress in
                    progressHandler?(progress)
                }
                .validate()
                .response { [weak self] response in
                    guard let self = self else { return }
                    
                    Task {
                        await self.handleDownloadResponse(
                            response: response,
                            destinationURL: destinationURL,
                            continuation: continuation
                        )
                    }
                }
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
        
        // 合并请求参数和公共参数
        let mergedParameters = try mergeParameters(
            requestParameters: request.requestParameters,
            commonParameters: commonParametersProvider?()
        )
        
        // 使用请求的编码器编码合并后的参数
        if let parameters = mergedParameters {
            urlRequest = try request.requestEncoder.encode(parameters, into: urlRequest)
        }
        
        return urlRequest
    }
    
    /// 合并请求参数和公共参数
    /// - Parameters:
    ///   - requestParameters: 请求特定参数
    ///   - commonParameters: 公共参数
    /// - Returns: 合并后的参数
    /// - Throws: 参数编码错误
    private func mergeParameters2222<T: Sendable & Codable>(
        requestParameters: T?,
        commonParameters: T?
    ) throws -> T? {
        // 如果都没有参数，返回nil
        guard let commonParams = commonParameters else {
            return requestParameters
        }
        
        guard let requestParams = requestParameters else {
            return commonParameters
        }
        
        // 将两个参数编码为字典
        let commonDict = try encodeToDictionary(commonParams)
        let requestDict = try encodeToDictionary(requestParams)
        
        // 合并字典（请求参数优先）
        let mergedDict = commonDict.merging(requestDict) { _, new in new }
        
        // 将合并后的字典解码回类型 T
        return try decodeFromDictionary(mergedDict, as: T.self)
    }
    
    // 辅助方法：将字典解码为指定类型
    private func decodeFromDictionary<T: Decodable>(_ dictionary: [String: Any], as type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
    
    /// 将Encodable对象编码为字典
    /// - Parameter encodable: 要编码的对象
    /// - Returns: 编码后的字典
    /// - Throws: JSON编码错误
    private func encodeToDictionary(_ encodable: Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(encodable)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RQNetworkError.encodingFailed(NSError(domain: "Encoding failed", code: -1))
        }
        return dictionary
    }
    
    private func mergeParameters(
        requestParameters: (any Sendable & Codable)?,
        commonParameters: (any Codable)?
    ) throws -> (any Sendable & Codable)? {
        // 编码为字典
        let commonDict = try commonParameters.flatMap(encodeToDictionary) ?? [:]
        let requestDict = try requestParameters.flatMap(encodeToDictionary) ?? [:]
        
        // 如果两个都为空，返回nil
        if commonDict.isEmpty && requestDict.isEmpty {
            return nil
        }
        
        // 合并字典（请求参数优先）
        let mergedDict = commonDict.merging(requestDict) { _, new in new }
        
        // 返回 [String: String]，它符合 Sendable & Codable
        let stringParameters = mergedDict.mapValues { value in
            switch value {
            case let string as String:
                return string
            case let int as Int:
                return "\(int)"
            case let double as Double:
                return "\(double)"
            case let bool as Bool:
                return "\(bool)"
            default:
                return "\(value)"
            }
        }
        
        return stringParameters
    }
    
    /// 执行带拦截器的网络请求
    /// - Parameters:
    ///   - urlRequest: URL请求对象
    ///   - request: 网络请求协议对象
    ///   - isRetry: 是否是重试请求
    /// - Returns: 解码后的响应数据
    private func performRequestWithInterceptors<T: Decodable>(
        _ urlRequest: URLRequest,
        for request: RQNetworkRequest,
        isRetry: Bool = false
    ) async throws -> RQResponse<T> {
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(urlRequest)
                .validate()
                .responseData { [weak self] response in
                    guard let self = self else { return }
                    
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
    }
    
    /// 处理带拦截器的响应
    /// - Parameters:
    ///   - response: Alamofire响应对象
    ///   - request: 原始请求对象
    ///   - continuation: 异步续体
    ///   - isRetry: 是否是重试请求
    private func handleResponseWithInterceptors<T: Decodable>(
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
            continuation: continuation
        )
    }
    
    /// 处理正常响应（无拦截器干预）
    /// - Parameters:
    ///   - response: Alamofire响应对象
    ///   - continuation: 异步续体
    private func handleNormalResponse<T: Decodable>(
        response: AFDataResponse<Data>,
        continuation: CheckedContinuation<RQResponse<T>, Error>
    ) async {
        switch response.result {
        case .success(let data):
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                let rqResponse = RQResponse(
                    data: decoded,
                    statusCode: response.response?.statusCode ?? 0,
                    headers: response.response?.allHeaderFields ?? [:],
                    metrics: response.metrics
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
        continuation: CheckedContinuation<RQUploadResponse<T>, Error>
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
                // 等待指定延迟后重试
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
                self.handleUploadRetry(
                    request: request,
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
                headers: response.response?.allHeaderFields ?? [:],
                metrics: response.metrics
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
        destinationURL: URL,
        continuation: CheckedContinuation<RQDownloadResponse, Error>
    ) async {
        
        switch response.result {
            case .success(let url):
                // 处理可选的 URL
                guard let fileURL = url else {
                    continuation.resume(throwing: RQNetworkError.invalidResponse("下载文件URL为空"))
                    return
                }
                
                let downloadResponse = RQDownloadResponse(
                    localURL: fileURL,  // 使用实际的下载文件URL
                    response: response.response
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
    private func handleRetry<T: Decodable>(
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
                        let response:RQUploadResponse<T> = try await self.upload(request)
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
        if let underlyingError = error.underlyingError {
            return .requestFailed(underlyingError)
        }
        
        if case .responseValidationFailed(let reason) = error {
            if case .unacceptableStatusCode(let code) = reason {
                return .statusCode(code)
            }
        }
        
        if error.isExplicitlyCancelledError {
            return .requestFailed(NSError(domain: "Cancelled", code: -999))
        }
        
        if error.isSessionTaskError {
            if let urlError = error.underlyingError as? URLError {
                switch urlError.code {
                case .timedOut:
                    return .timeout
                case .notConnectedToInternet:
                    return .requestFailed(urlError)
                case .networkConnectionLost:
                    return .requestFailed(urlError)
                case .cannotConnectToHost:
                    return .requestFailed(urlError)
                default:
                    break
                }
            }
        }
        
        return .requestFailed(error)
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
    public func get<T: Decodable>(
        domainKey: String,
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
    
    /// 快速执行POST请求
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - parameters: 请求体参数
    /// - Returns: 解码后的响应数据
    @discardableResult
    public func post<T: Decodable>(
        domainKey: String,
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
    
    /// 快速执行PUT请求
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - parameters: 请求体参数
    /// - Returns: 解码后的响应数据
    @discardableResult
    public func put<T: Decodable>(
        domainKey: String,
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
    
    /// 快速执行DELETE请求
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - parameters: 查询参数
    /// - Returns: 解码后的响应数据
    @discardableResult
    public func delete<T: Decodable>(
        domainKey: String,
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
}
