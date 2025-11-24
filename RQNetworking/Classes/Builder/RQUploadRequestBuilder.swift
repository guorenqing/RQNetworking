//
//  RQUploadRequestBuilder.swift
//  RQNetworking
//
//  Created by edy on 2025/11/20.
//


import Foundation
import Alamofire

/// 文件上传请求构建器类
/// 专门用于构建文件上传请求，支持多种上传数据类型
public final class RQUploadRequestBuilder {
    
    // MARK: - 构建器属性
    
    /// 域名标识
    private var domainKey: String = ""
    
    /// 请求路径
    private var path: String = ""
    
    /// HTTP方法（上传通常使用POST）
    private var method: HTTPMethod = .post
    
    /// 请求头信息
    private var headers: HTTPHeaders?
    
    /// 上传数据数组
    private var uploadData: [RQUploadData] = []
    
    /// 表单字段
    private var formFields: [String: String]?
    
    /// 超时时间
    private var timeoutInterval: TimeInterval?
    
    /// 是否需要认证
    private var requiresAuth: Bool = true
    
    /// 重试配置
    private var retryConfiguration: RQRetryConfiguration?
    
    // MARK: - 初始化方法
    
    /// 初始化空的上传请求构建器
    public init() {}
    
    // MARK: - 构建方法
    
    /// 设置域名标识
    /// - Parameter domainKey: 域名标识
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setDomainKey(_ domainKey: String) -> Self {
        self.domainKey = domainKey
        return self
    }
    
    /// 设置请求路径
    /// - Parameter path: 请求路径
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setPath(_ path: String) -> Self {
        self.path = path
        return self
    }
    
    /// 设置HTTP方法
    /// - Parameter method: HTTP方法
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setMethod(_ method: HTTPMethod) -> Self {
        self.method = method
        return self
    }
    
    /// 设置请求头信息
    /// - Parameter headers: 请求头字典
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setHeaders(_ headers: [String: String]) -> Self {
        self.headers = HTTPHeaders(headers)
        return self
    }
    
    /// 添加内存数据上传
    /// - Parameters:
    ///   - data: 文件数据
    ///   - fileName: 文件名
    ///   - mimeType: MIME类型
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func addDataUpload(
        _ data: Data,
        fileName: String,
        mimeType: String
    ) -> Self {
        let uploadData = RQUploadData.data(data, fileName: fileName, mimeType: mimeType)
        self.uploadData.append(uploadData)
        return self
    }
    
    /// 添加本地文件上传
    /// - Parameters:
    ///   - fileURL: 本地文件URL
    ///   - fileName: 文件名
    ///   - mimeType: MIME类型
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func addFileUpload(
        _ fileURL: URL,
        fileName: String,
        mimeType: String
    ) -> Self {
        let uploadData = RQUploadData.file(fileURL, fileName: fileName, mimeType: mimeType)
        self.uploadData.append(uploadData)
        return self
    }
    
    /// 添加上传数据对象
    /// - Parameter uploadData: 上传数据对象
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func addUploadData(_ uploadData: RQUploadData) -> Self {
        self.uploadData.append(uploadData)
        return self
    }
    
    /// 设置表单字段
    /// - Parameter formFields: 表单字段字典
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setFormFields(_ formFields: [String: String]) -> Self {
        self.formFields = formFields
        return self
    }
    
    /// 添加单个表单字段
    /// - Parameters:
    ///   - key: 字段名
    ///   - value: 字段值
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func addFormField(key: String, value: String) -> Self {
        if formFields == nil {
            formFields = [:]
        }
        formFields?[key] = value
        return self
    }
    
    /// 设置超时时间
    /// - Parameter interval: 超时时间（秒）
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setTimeoutInterval(_ interval: TimeInterval) -> Self {
        self.timeoutInterval = interval
        return self
    }
    
    /// 设置是否需要认证
    /// - Parameter requires: 是否需要认证
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setRequiresAuth(_ requires: Bool) -> Self {
        self.requiresAuth = requires
        return self
    }
    
    /// 设置重试配置
    /// - Parameter configuration: 重试配置
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setRetryConfiguration(_ configuration: RQRetryConfiguration) -> Self {
        self.retryConfiguration = configuration
        return self
    }
    
    /// 构建文件上传请求对象
    /// - Returns: 配置完成的RQUploadRequest实例
    public func build() -> RQUploadRequestImpl {
        return RQUploadRequestImpl(
            domainKey: domainKey,
            path: path,
            method: method,
            headers: headers,
            uploadData: uploadData,
            formFields: formFields,
            timeoutInterval: timeoutInterval,
            requiresAuth: requiresAuth,
            retryConfiguration: retryConfiguration
        )
    }
}

/// 文件上传请求实现结构体
/// 实现RQUploadRequest协议，用于构建具体的文件上传请求
public struct RQUploadRequestImpl: RQUploadRequest {
    
    // MARK: - RQNetworkRequest协议属性
    
    public let domainKey: String
    public let path: String
    public let method: HTTPMethod
    public let headers: HTTPHeaders?
    public let requestParameters: Encodable?
    public let requestEncoder: ParameterEncoder
    public let timeoutInterval: TimeInterval?
    public let requiresAuth: Bool
    public let retryConfiguration: RQRetryConfiguration?
    
    // MARK: - RQUploadRequest协议属性
    
    public let uploadData: [RQUploadData]
    public let formFields: [String: String]?
    
    // MARK: - 初始化方法
    
    /// 初始化文件上传请求
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - method: HTTP方法，默认为POST
    ///   - headers: 请求头，默认为nil
    ///   - uploadData: 上传数据数组
    ///   - formFields: 表单字段，默认为nil
    ///   - timeoutInterval: 超时时间，默认为nil（使用全局配置）
    ///   - requiresAuth: 是否需要认证，默认为true
    ///   - retryConfiguration: 重试配置，默认为nil（使用全局配置）
    public init(
        domainKey: String,
        path: String,
        method: HTTPMethod = .post,
        headers: HTTPHeaders? = nil,
        uploadData: [RQUploadData],
        formFields: [String: String]? = nil,
        timeoutInterval: TimeInterval? = nil,
        requiresAuth: Bool = true,
        retryConfiguration: RQRetryConfiguration? = nil
    ) {
        self.domainKey = domainKey
        self.path = path
        self.method = method
        self.headers = headers
        self.requestParameters = nil // 文件上传不使用普通参数
        self.requestEncoder = URLEncodedFormParameterEncoder.default
        self.uploadData = uploadData
        self.formFields = formFields
        self.timeoutInterval = timeoutInterval
        self.requiresAuth = requiresAuth
        self.retryConfiguration = retryConfiguration
    }
}

// MARK: - 便捷上传请求构造扩展
extension RQUploadRequestBuilder {
    
    /// 创建单图片上传请求构建器
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - imageData: 图片数据
    ///   - fileName: 文件名，默认为"image.jpg"
    /// - Returns: 配置完成的构建器
    public static func singleImage(
        domainKey: String,
        path: String,
        imageData: Data,
        fileName: String = "image.jpg"
    ) -> RQUploadRequestBuilder {
        return RQUploadRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.post)
            .addDataUpload(imageData, fileName: fileName, mimeType: "image/jpeg")
    }
    
    /// 创建多文件上传请求构建器
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - files: 文件数据数组
    /// - Returns: 配置完成的构建器
    public static func multipleFiles(
        domainKey: String,
        path: String,
        files: [(data: Data, fileName: String, mimeType: String)]
    ) -> RQUploadRequestBuilder {
        let builder = RQUploadRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.post)
        
        for file in files {
            builder.addDataUpload(file.data, fileName: file.fileName, mimeType: file.mimeType)
        }
        
        return builder
    }
}
