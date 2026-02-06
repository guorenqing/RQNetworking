//
//  RQAuthInterceptor.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//

import Foundation
import Alamofire

/// 认证拦截器
/// 处理请求的认证信息，如添加Token等
public final class RQAuthInterceptor: @unchecked Sendable, RequestInterceptor {
    
    // MARK: - 属性
    
    /// 公共头提供者
    public var commonHeadersProvider: (@Sendable () -> HTTPHeaders)?
    
    // MARK: - 初始化方法
    
    /// 初始化认证拦截器
    /// - Parameter commonHeadersProvider: 公共头提供者
    public init() {
        
    }
    
    // MARK: - RequestInterceptor协议实现
    
    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        var adaptedRequest = urlRequest

        let requiresCommonHeadersValue = adaptedRequest.headers.value(
            for: RQNetworkManager.requiresCommonHeadersHeaderKey
        )
        adaptedRequest.headers.remove(name: RQNetworkManager.requiresCommonHeadersHeaderKey)

        let requiresCommonHeaders: Bool
        if let value = requiresCommonHeadersValue?.lowercased() {
            requiresCommonHeaders = !(value == "0" || value == "false")
        } else {
            requiresCommonHeaders = true
        }

        guard requiresCommonHeaders else {
            completion(.success(adaptedRequest))
            return
        }
        
        // 添加公共头
        var headers = adaptedRequest.headers
        
        if let commonHeadersProvider = commonHeadersProvider {
            for header in commonHeadersProvider() {
                headers.update(header)
            }
            adaptedRequest.headers = headers
        }
        
        
        completion(.success(adaptedRequest))
    }
    
    public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        // 认证拦截器不处理重试逻辑
        completion(.doNotRetry)
    }
}
