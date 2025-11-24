//
//  RQResponseInterceptor.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//

import Foundation

/// 响应拦截结果枚举
/// 定义响应拦截器的处理结果
public enum RQInterceptResult {
    
    /// 继续处理
    /// 不进行特殊处理，继续后续拦截器或正常响应流程
    case proceed
    
    /// 重试请求
    /// - Parameter after: 重试前的延迟时间（秒）
    case retry(after: TimeInterval = 0)
    
    /// 失败处理
    /// - Parameter error: 失败错误
    case fail(Error)
}

/// 响应拦截器协议
/// 用于在收到网络响应后进行统一处理，如Token刷新、业务状态码检查等
public protocol RQResponseInterceptor: Sendable {
    
    /// 拦截响应
    /// - Parameters:
    ///   - data: 响应数据，可能为nil
    ///   - response: URL响应对象，可能为nil
    ///   - error: 发生的错误，可能为nil
    ///   - request: 原始请求对象
    /// - Returns: 拦截处理结果
    func intercept(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        for request: RQNetworkRequest
    ) async -> RQInterceptResult
    
    /// 处理需要重试的请求
    /// - Parameters:
    ///   - request: 需要重试的请求
    ///   - originalData: 原始响应数据
    ///   - completion: 重试完成回调，返回成功或失败
    func handleRetry(
        _ request: RQNetworkRequest,
        originalData: Data?,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

// MARK: - 协议默认实现
public extension RQResponseInterceptor {
    
    /// 默认的重试处理方法
    /// 直接调用完成回调，子类可以重写此方法实现自定义重试逻辑
    func handleRetry(
        _ request: RQNetworkRequest,
        originalData: Data?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // 默认实现，子类应该重写此方法
        completion(.success(()))
    }
}
