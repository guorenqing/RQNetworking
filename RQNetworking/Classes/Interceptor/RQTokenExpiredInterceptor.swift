//
//  RQTokenExpiredInterceptor.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//

/// Token失效拦截器
/// 专门处理Token过期情况的响应拦截器
public final class RQTokenExpiredInterceptor: RQResponseInterceptor {
    
    // MARK: - 属性
    
    /// Token刷新处理器
    /// 当检测到Token过期时调用的异步刷新方法
    private let tokenRefreshHandler: (@Sendable () async throws -> Void)?
    
    /// Token过期检测器
    /// 自定义的Token过期检测逻辑
    private let tokenExpiredDetector: (@Sendable (Data?, URLResponse?) -> Bool)?
    
    // MARK: - 初始化方法
    
    /// 初始化Token失效拦截器
    /// - Parameters:
    ///   - tokenRefreshHandler: Token刷新处理器
    ///   - tokenExpiredDetector: Token过期检测器
    public init(
        tokenRefreshHandler: (@Sendable () async throws -> Void)? = nil,
        tokenExpiredDetector: (@Sendable (Data?, URLResponse?) -> Bool)? = nil
    ) {
        self.tokenRefreshHandler = tokenRefreshHandler
        self.tokenExpiredDetector = tokenExpiredDetector
    }
    
    // MARK: - 响应拦截器协议实现
    
    public func intercept(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        for request: RQNetworkRequest
    ) async -> RQInterceptResult {
        
        // 如果有网络错误，直接继续处理（让重试拦截器处理）
        if error != nil {
            return .proceed
        }
        
        // 检查是否是Token失效
        if let detector = tokenExpiredDetector, detector(data, response) {
            print("🔐 [RQNetwork] 检测到Token过期，准备刷新")
            return .retry(after: 0.1)
        }
        
        return .proceed
    }
    
    public func handleRetry(
        _ request: RQNetworkRequest,
        originalData: Data?,
        completion: @Sendable @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                // 调用Token刷新逻辑
                try await tokenRefreshHandler?()
                print("🔐 [RQNetwork] Token刷新成功")
                completion(.success(()))
            } catch {
                print("❌ [RQNetwork] Token刷新失败: \(error)")
                completion(.failure(error))
            }
        }
    }
}

