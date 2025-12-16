//
//  RQNetworkRequest.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//


import Foundation
import Alamofire

/// 网络请求协议
/// 定义网络请求的基本结构和行为，所有具体请求都应遵循此协议
public protocol RQNetworkRequest: Sendable {
    
    // MARK: - 必需属性
    
    /// 域名标识
    /// 用于从域名管理器中获取对应的基础URL
    var domainKey: String { get }
    
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
    
    /// 是否需要认证
    /// 如果为true，会自动添加认证头信息
    var requiresAuth: Bool { get }
    
    /// 重试配置
    /// 特定于此请求的重试策略，如果为nil则使用全局配置
    var retryConfiguration: RQRetryConfiguration? { get }
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
    
    /// 默认需要认证
    var requiresAuth: Bool { true }
    
    /// 默认使用全局重试配置
    var retryConfiguration: RQRetryConfiguration? { nil }
}
