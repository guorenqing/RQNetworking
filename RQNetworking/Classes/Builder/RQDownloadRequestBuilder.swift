//
//  RQDownloadRequestBuilder.swift
//  RQNetworking
//
//  Created by edy on 2025/11/20.
//


import Foundation
import Alamofire

/// 文件下载请求构建器类
/// 专门用于构建文件下载请求，支持自定义下载目的地
public final class RQDownloadRequestBuilder {
    
    // MARK: - 构建器属性
    
    /// 域名标识
    private var domainKey: String = ""
    
    /// 请求路径
    private var path: String = ""
    
    /// HTTP方法（下载通常使用GET）
    private var method: HTTPMethod = .get
    
    /// 请求头信息
    private var headers: HTTPHeaders?
    
    /// 请求参数
    private var requestParameters: (Codable & Sendable)?
    
    /// 下载目的地
    private var destination: RQDownloadDestination = .temporary
    
    /// 超时时间
    private var timeoutInterval: TimeInterval?
    
    /// 是否需要认证
    private var requiresAuth: Bool = true
    
    /// 重试配置
    private var retryConfiguration: RQRetryConfiguration?
    
    // MARK: - 初始化方法
    
    /// 初始化空的下载请求构建器
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
    
    /// 设置请求参数
    /// - Parameter parameters: 请求参数
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setRequestParameters<T: Codable & Sendable>(_ parameters: T) -> Self {
        self.requestParameters = parameters
        return self
    }
    
    /// 设置下载目的地
    /// - Parameter destination: 下载目的地
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setDestination(_ destination: RQDownloadDestination) -> Self {
        self.destination = destination
        return self
    }
    
    /// 设置文档目录下载目的地
    /// - Parameter fileName: 文件名
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setDocumentDestination(fileName: String) -> Self {
        self.destination = .document(fileName)
        return self
    }
    
    /// 设置缓存目录下载目的地
    /// - Parameter fileName: 文件名
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setCachesDestination(fileName: String) -> Self {
        self.destination = .caches(fileName)
        return self
    }
    
    /// 设置自定义下载目的地
    /// - Parameter url: 自定义文件URL
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setCustomDestination(_ url: URL) -> Self {
        self.destination = .custom(url)
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
    
    /// 构建文件下载请求对象
    /// - Returns: 配置完成的RQDownloadRequest实例
    public func build() -> RQDownloadRequestImpl {
        return RQDownloadRequestImpl(
            domainKey: domainKey,
            path: path,
            method: method,
            headers: headers,
            requestParameters: requestParameters,
            destination: destination,
            timeoutInterval: timeoutInterval,
            requiresAuth: requiresAuth,
            retryConfiguration: retryConfiguration
        )
    }
}

/// 文件下载请求实现结构体
/// 实现RQDownloadRequest协议，用于构建具体的文件下载请求
public struct RQDownloadRequestImpl: RQDownloadRequest {
    
    // MARK: - RQNetworkRequest协议属性
    
    public let domainKey: String
    public let path: String
    public let method: HTTPMethod
    public let headers: HTTPHeaders?
    public let requestParameters: (any Sendable & Encodable)?
    public let requestEncoder: ParameterEncoder
    public let timeoutInterval: TimeInterval?
    public let requiresAuth: Bool
    public let retryConfiguration: RQRetryConfiguration?
    
    // MARK: - RQDownloadRequest协议属性
    
    public let destination: RQDownloadDestination
    
    // MARK: - 初始化方法
    
    /// 初始化文件下载请求
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - method: HTTP方法，默认为GET
    ///   - headers: 请求头，默认为nil
    ///   - requestParameters: 请求参数，默认为nil
    ///   - destination: 下载目的地
    ///   - timeoutInterval: 超时时间，默认为nil（使用全局配置）
    ///   - requiresAuth: 是否需要认证，默认为true
    ///   - retryConfiguration: 重试配置，默认为nil（使用全局配置）
    public init(
        domainKey: String,
        path: String,
        method: HTTPMethod = .get,
        headers: HTTPHeaders? = nil,
        requestParameters: (Codable & Sendable)? = nil,
        destination: RQDownloadDestination,
        timeoutInterval: TimeInterval? = nil,
        requiresAuth: Bool = true,
        retryConfiguration: RQRetryConfiguration? = nil
    ) {
        self.domainKey = domainKey
        self.path = path
        self.method = method
        self.headers = headers
        self.requestParameters = requestParameters
        self.requestEncoder = URLEncodedFormParameterEncoder.default
        self.destination = destination
        self.timeoutInterval = timeoutInterval
        self.requiresAuth = requiresAuth
        self.retryConfiguration = retryConfiguration
    }
}

// MARK: - 便捷下载请求构造扩展
extension RQDownloadRequestBuilder {
    
    /// 创建图片下载请求构建器
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - fileName: 保存的文件名
    /// - Returns: 配置完成的构建器
    public static func imageDownload(
        domainKey: String,
        path: String,
        fileName: String
    ) -> RQDownloadRequestBuilder {
        return RQDownloadRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.get)
            .setDocumentDestination(fileName: "images/\(fileName)")
            .setTimeoutInterval(300.0) // 图片下载需要较长超时时间
    }
    
    /// 创建大文件下载请求构建器
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - fileName: 保存的文件名
    /// - Returns: 配置完成的构建器
    public static func largeFileDownload(
        domainKey: String,
        path: String,
        fileName: String
    ) -> RQDownloadRequestBuilder {
        return RQDownloadRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.get)
            .setDocumentDestination(fileName: fileName)
            .setTimeoutInterval(1800.0) // 大文件下载需要很长超时时间
            .setRetryConfiguration(RQRetryConfiguration(
                maxRetryCount: 5,
                delayStrategy: .exponentialBackoff(base: 3.0)
            ))
    }
}
