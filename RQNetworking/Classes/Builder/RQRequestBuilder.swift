//
//  RQRequestBuilder.swift
//  RQNetworking
//
//  Created by edy on 2025/11/20.
//


import Foundation
import Alamofire

/// 请求构建器类
/// 提供链式API来构建网络请求，使请求创建更加清晰和类型安全
public final class RQRequestBuilder {
    
    // MARK: - 构建器属性
    
    /// 域名标识
    private var domainKey: String = ""
    
    /// 请求路径
    private var path: String = ""
    
    /// HTTP方法
    private var method: HTTPMethod = .get
    
    /// 请求头信息
    private var headers: HTTPHeaders?
    
    /// 请求参数
    private var requestParameters: Encodable?
    
    /// 请求参数编码器
    private var requestEncoder: ParameterEncoder?
    
    /// 超时时间
    private var timeoutInterval: TimeInterval?
    
    /// 是否需要认证
    private var requiresAuth: Bool = true
    
    /// 重试配置
    private var retryConfiguration: RQRetryConfiguration?
    
    // MARK: - 初始化方法
    
    /// 初始化空的请求构建器
    public init() {}
    
    // MARK: - 构建方法
    
    /// 设置域名标识
    /// - Parameter domainKey: 域名标识，必须在域名管理器中注册
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setDomainKey(_ domainKey: String) -> Self {
        self.domainKey = domainKey
        return self
    }
    
    /// 设置请求路径
    /// - Parameter path: 请求路径，如 "/users"、"/api/v1/login"
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setPath(_ path: String) -> Self {
        self.path = path
        return self
    }
    
    /// 设置HTTP方法
    /// - Parameter method: HTTP方法，如 .get、.post、.put、.delete
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
    
    /// 设置Alamofire请求头
    /// - Parameter headers: Alamofire HTTPHeaders对象
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setHeaders(_ headers: HTTPHeaders) -> Self {
        self.headers = headers
        return self
    }
    
    /// 设置请求参数
    /// - Parameter parameters: 遵循Encodable协议的参数对象
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setRequestParameters(_ parameters: Encodable?) -> Self {
        self.requestParameters = parameters
        return self
    }
    
    /// 设置请求参数编码器
    /// - Parameter encoder: 参数编码器
    /// - Returns: 构建器自身，支持链式调用
    @discardableResult
    public func setRequestEncoder(_ encoder: ParameterEncoder) -> Self {
        self.requestEncoder = encoder
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
    
    /// 构建基础请求对象
    /// - Returns: 配置完成的RQBasicRequest实例
    public func build() -> RQBasicRequest {
        return RQBasicRequest(
            domainKey: domainKey,
            path: path,
            method: method,
            headers: headers,
            requestParameters: requestParameters,
            requestEncoder: requestEncoder,
            timeoutInterval: timeoutInterval,
            requiresAuth: requiresAuth,
            retryConfiguration: retryConfiguration
        )
    }
}

/// 基础请求实现结构体
/// 实现RQNetworkRequest协议，用于构建具体的网络请求
public struct RQBasicRequest: RQNetworkRequest {
    
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
    
    // MARK: - 初始化方法
    
    /// 初始化基础请求
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - method: HTTP方法，默认为GET
    ///   - headers: 请求头，默认为nil
    ///   - requestParameters: 请求参数，默认为nil
    ///   - requestEncoder: 参数编码器，默认为根据方法自动选择
    ///   - timeoutInterval: 超时时间，默认为nil（使用全局配置）
    ///   - requiresAuth: 是否需要认证，默认为true
    ///   - retryConfiguration: 重试配置，默认为nil（使用全局配置）
    public init(
        domainKey: String,
        path: String,
        method: HTTPMethod = .get,
        headers: HTTPHeaders? = nil,
        requestParameters: Encodable? = nil,
        requestEncoder: ParameterEncoder? = nil,
        timeoutInterval: TimeInterval? = nil,
        requiresAuth: Bool = true,
        retryConfiguration: RQRetryConfiguration? = nil
    ) {
        self.domainKey = domainKey
        self.path = path
        self.method = method
        self.headers = headers
        self.requestParameters = requestParameters
        // 使用自定义编码器或根据HTTP方法自动选择默认编码器
        self.requestEncoder = requestEncoder ?? {
            switch method {
            case .get, .delete:
                return URLEncodedFormParameterEncoder.default
            default:
                return JSONParameterEncoder.default
            }
        }()
        self.timeoutInterval = timeoutInterval
        self.requiresAuth = requiresAuth
        self.retryConfiguration = retryConfiguration
    }
}

// MARK: - 便捷请求构造扩展
extension RQRequestBuilder {
    
    /// 创建GET请求构建器
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    /// - Returns: 配置了GET方法的构建器
    public static func get(domainKey: String, path: String) -> RQRequestBuilder {
        return RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.get)
    }
    
    /// 创建POST请求构建器
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    /// - Returns: 配置了POST方法的构建器
    public static func post(domainKey: String, path: String) -> RQRequestBuilder {
        return RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.post)
    }
    
    /// 创建PUT请求构建器
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    /// - Returns: 配置了PUT方法的构建器
    public static func put(domainKey: String, path: String) -> RQRequestBuilder {
        return RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.put)
    }
    
    /// 创建DELETE请求构建器
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    /// - Returns: 配置了DELETE方法的构建器
    public static func delete(domainKey: String, path: String) -> RQRequestBuilder {
        return RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.delete)
    }
    
    /// 创建带JSON参数的POST请求构建器
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - parameters: JSON参数
    /// - Returns: 配置完成的构建器
    public static func postJSON<T: Encodable>(
        domainKey: String,
        path: String,
        parameters: T
    ) -> RQRequestBuilder {
        return RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.post)
            .setRequestParameters(parameters)
            .setRequestEncoder(JSONParameterEncoder.default)
    }
    
    /// 创建带查询参数的GET请求构建器
    /// - Parameters:
    ///   - domainKey: 域名标识
    ///   - path: 请求路径
    ///   - parameters: 查询参数
    /// - Returns: 配置完成的构建器
    public static func getWithQuery<T: Encodable>(
        domainKey: String,
        path: String,
        parameters: T
    ) -> RQRequestBuilder {
        return RQRequestBuilder()
            .setDomainKey(domainKey)
            .setPath(path)
            .setMethod(.get)
            .setRequestParameters(parameters)
            .setRequestEncoder(URLEncodedFormParameterEncoder.default)
    }
}
