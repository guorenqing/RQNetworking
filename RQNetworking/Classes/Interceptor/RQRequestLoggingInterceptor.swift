//
//  RQLoggingInterceptor.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//

import Foundation
import Alamofire

/// 日志拦截器
/// 记录网络请求的详细日志信息
public final class RQRequestLoggingInterceptor: RequestInterceptor {
    
    // MARK: - 初始化方法
    
    /// 初始化日志拦截器
    public init() {}
    
    // MARK: - RequestInterceptor协议实现
    
    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        logRequest(urlRequest)
        completion(.success(urlRequest))
    }
    
    public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        logRetry(request: request, error: error)
        // 日志拦截器不处理重试逻辑
        completion(.doNotRetry)
    }
    
    // MARK: - 私有方法
    
    /// 记录请求日志
    private func logRequest(_ request: URLRequest) {
        let method = request.httpMethod ?? "Unknown"
        let url = request.url?.absoluteString ?? "Unknown"
        let headers = request.headers.dictionary
        let body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "Empty"
        
        print("""
        🌐 [RQNetwork] 请求开始
          URL: \(url)
          方法: \(method)
          头信息: \(headers)
          请求体: \(body)
        """)
    }
    
    /// 记录重试日志
    private func logRetry(request: Request, error: Error) {
        let url = request.request?.url?.absoluteString ?? "Unknown"
        let retryCount = request.retryCount
        
        print("""
        🔄 [RQNetwork] 请求失败 (重试次数: \(retryCount))
          URL: \(url)
          错误: \(error.localizedDescription)
        """)
    }
}

