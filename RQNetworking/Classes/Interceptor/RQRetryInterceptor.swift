//
//  RQRetryInterceptor.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//

import Foundation
import Alamofire

/// 重试拦截器
/// 处理网络请求的重试逻辑
public final class RQRetryInterceptor: RequestInterceptor {
    
    // MARK: - 属性
    
    /// 默认重试配置
    public let defaultRetryConfiguration: RQRetryConfiguration
    
    
    // MARK: - 初始化方法
    
    /// 初始化重试拦截器
    /// - Parameter defaultRetryConfiguration: 默认重试配置
    public init(defaultRetryConfiguration: RQRetryConfiguration = .default) {
        self.defaultRetryConfiguration = defaultRetryConfiguration
    }
    
    // MARK: - RequestInterceptor协议实现
    
    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        // 重试拦截器不修改请求
        completion(.success(urlRequest))
    }
    
    public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        guard let originalRequest = request.request else {
            completion(.doNotRetry)
            return
        }
        
        // 获取重试配置
        let retryConfig = defaultRetryConfiguration
        
        // 检查当前重试次数
        let retryCount = request.retryCount
        guard retryCount < retryConfig.maxRetryCount else {
            print("🔄 [RQNetwork] 达到最大重试次数: \(retryConfig.maxRetryCount)")
            completion(.doNotRetry)
            return
        }
        
        // 检查是否应该重试
        guard shouldRetry(
            error: error,
            request: originalRequest,
            retryCount: retryCount,
            configuration: retryConfig
        ) else {
            completion(.doNotRetry)
            return
        }
        
        // 计算延迟
        let delay = retryConfig.delayStrategy.delay(for: retryCount)
        
        print("🔄 [RQNetwork] 第\(retryCount + 1)次重试，延迟\(delay)秒")
        
        completion(.retryWithDelay(delay))
    }
    
    // MARK: - 私有方法
    
    /// 判断是否应该重试
    private func shouldRetry(
        error: Error,
        request: URLRequest,
        retryCount: Int,
        configuration: RQRetryConfiguration
    ) -> Bool {
        return configuration.retryCondition.shouldRetry(
            error: error,
            request: request,
            response: nil
        )
    }
}
