//
//  RQNetworkRequest.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//


import Foundation
import Alamofire

/// 可取消任务协议
public protocol RQCancelable {
    func cancel()
}

/// 基于Task的取消实现
public final class RQTaskCancelable: RQCancelable {
    
    private let task: Task<Void, Never>
    
    public init(task: Task<Void, Never>) {
        self.task = task
    }
    
    public func cancel() {
        task.cancel()
    }
}

/// 请求配置描述，减少请求模板样板代码
public struct RQRequestConfig: @unchecked Sendable {
    
    public let domainKey: RQDomainKey
    public let path: String
    public let method: HTTPMethod
    public let requestParameters: (Codable & Sendable)?
    public let headers: HTTPHeaders?
    public let requestEncoder: ParameterEncoder
    public let timeoutInterval: TimeInterval?
    public let requiresCommonHeaders: Bool
    public let retryConfiguration: RQRetryConfiguration?
    public let jsonDecoder: JSONDecoder?
    public let jsonEncoder: JSONEncoder?

    public init(
        domainKey: RQDomainKey,
        path: String,
        method: HTTPMethod = .get,
        requestParameters: (Codable & Sendable)? = nil,
        headers: HTTPHeaders? = nil,
        requestEncoder: ParameterEncoder? = nil,
        timeoutInterval: TimeInterval? = nil,
        requiresCommonHeaders: Bool = true,
        retryConfiguration: RQRetryConfiguration? = nil,
        jsonDecoder: JSONDecoder? = nil,
        jsonEncoder: JSONEncoder? = nil
    ) {
        self.domainKey = domainKey
        self.path = path
        self.method = method
        self.requestParameters = requestParameters
        self.headers = headers
        if let requestEncoder {
            self.requestEncoder = requestEncoder
        } else {
            switch method {
            case .get, .delete:
                self.requestEncoder = URLEncodedFormParameterEncoder.default
            default:
                self.requestEncoder = JSONParameterEncoder.default
            }
        }
        self.timeoutInterval = timeoutInterval
        self.requiresCommonHeaders = requiresCommonHeaders
        self.retryConfiguration = retryConfiguration
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
    }
}

/// 请求模板协议：只需提供requestConfig即可
public protocol RQRequest: RQNetworkRequest {
    var requestConfig: RQRequestConfig { get }
}

public extension RQRequest {
    var domainKey: RQDomainKey { requestConfig.domainKey }
    var path: String { requestConfig.path }
    var method: HTTPMethod { requestConfig.method }
    var headers: HTTPHeaders? { requestConfig.headers }
    var requestParameters: (Codable & Sendable)? { requestConfig.requestParameters }
    var requestEncoder: ParameterEncoder { requestConfig.requestEncoder }
    var timeoutInterval: TimeInterval? { requestConfig.timeoutInterval }
    var requiresCommonHeaders: Bool { requestConfig.requiresCommonHeaders }
    var retryConfiguration: RQRetryConfiguration? { requestConfig.retryConfiguration }
    var jsonDecoder: JSONDecoder? { requestConfig.jsonDecoder }
    var jsonEncoder: JSONEncoder? { requestConfig.jsonEncoder }
}

/// 网络请求协议
/// 定义网络请求的基本结构和行为，所有具体请求都应遵循此协议
public protocol RQNetworkRequest: Sendable {
    
    // MARK: - 必需属性
    
    /// 域名标识
    /// 用于从域名管理器中获取对应的基础URL
    var domainKey: RQDomainKey { get }
    
    /// 请求路径
    /// 相对于基础URL的路径，如 "/users"、"/api/v1/login"
    var path: String { get }
    
    /// HTTP请求方法
    /// 如 GET、POST、PUT、DELETE 等
    var method: HTTPMethod { get }
    
    // MARK: - 可选属性
    
    /// 请求头信息
    /// 特定于此请求的头部信息，会与公共头合并
    var headers: HTTPHeaders? { get }
    
    /// 请求参数
    /// 支持任何遵循Encodable协议的类型，提供类型安全的参数传递
    var requestParameters: (Codable & Sendable)? { get }
    
    /// 请求参数编码器
    /// 定义如何将参数编码到请求中（URL查询参数或JSON Body）
    var requestEncoder: ParameterEncoder { get }
    
    /// 请求超时时间
    /// 如果为nil，则使用网络管理器的默认超时时间
    var timeoutInterval: TimeInterval? { get }
    
    /// 是否需要公共头
    /// 如果为true，会自动添加公共头信息
    var requiresCommonHeaders: Bool { get }
    
    /// 重试配置
    /// 特定于此请求的重试策略，如果为nil则使用全局配置
    var retryConfiguration: RQRetryConfiguration? { get }

    /// 请求级JSON解码器
    /// 如果为nil，则使用全局默认解码器
    var jsonDecoder: JSONDecoder? { get }

    /// 请求级JSON编码器
    /// 如果为nil，则使用全局默认编码器
    var jsonEncoder: JSONEncoder? { get }
}

// MARK: - 协议默认实现
public extension RQNetworkRequest {
    
    /// 默认HTTP方法为GET
    var method: HTTPMethod { .get }
    
    /// 默认无自定义请求头
    var headers: HTTPHeaders? { nil }
    
    /// 默认无请求参数
    var requestParameters: (Codable & Sendable)? { nil }
    
    /// 默认参数编码器
    /// 根据HTTP方法智能选择：GET/DELETE使用URL编码，其他使用JSON编码
    var requestEncoder: ParameterEncoder {
        switch method {
        case .get, .delete:
            return URLEncodedFormParameterEncoder.default
        default:
            return JSONParameterEncoder.default
        }
    }
    
    /// 默认使用全局超时配置
    var timeoutInterval: TimeInterval? { nil }
    
    /// 默认需要公共头
    var requiresCommonHeaders: Bool { true }
    
    /// 默认使用全局重试配置
    var retryConfiguration: RQRetryConfiguration? { nil }

    /// 默认使用全局JSON解码器
    var jsonDecoder: JSONDecoder? { nil }

    /// 默认使用全局JSON编码器
    var jsonEncoder: JSONEncoder? { nil }
}
