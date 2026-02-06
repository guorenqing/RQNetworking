//
//  RQTokenRefreshManager.swift
//  RQNetworking
//
//  Created by edy on 2025/11/20.
//


import Foundation

/// Token 刷新管理器
/// 统一管理 Token 刷新流程，防止重复刷新，支持并发请求等待
public final class RQTokenRefreshManager: @unchecked Sendable {
    
    // MARK: - 单例实例
    
    /// 共享 Token 刷新管理器实例
    public static let shared = RQTokenRefreshManager()
    
    /// 私有初始化方法，确保单例模式
    private init() {
        tokenRefreshQueue.setSpecific(key: queueKey, value: ())
    }
    
    // MARK: - 属性
    
    /// Token 刷新处理器
    /// 实际执行 Token 刷新逻辑的异步方法
    public var refreshTokenHandler: (@Sendable () async throws -> Void)?
    
    /// Token 刷新状态队列
    /// 用于同步访问刷新状态和等待队列
    private let tokenRefreshQueue = DispatchQueue(label: "com.rqnetwork.tokenRefreshQueue")
    private let queueKey = DispatchSpecificKey<Void>()
    
    /// Token 刷新状态标志
    /// 表示当前是否正在刷新 Token
    private var _isRefreshingToken = false
    
    /// 等待 Token 刷新的续体数组
    /// 当多个请求同时遇到 Token 过期时，其他请求会等待当前刷新完成
    private var refreshContinuations: [CheckedContinuation<Bool, Error>] = []
    
    /// 最后一次刷新成功的时间
    private var lastRefreshTime: Date?
    
    /// 刷新失败次数（用于限制频繁刷新）
    private var refreshFailureCount = 0
    
    /// 最大刷新失败次数
    private let maxRefreshFailureCount = 3
    
    // MARK: - 公共方法
    
    /// 处理认证失败，统一进行 Token 刷新
    /// - Returns: 刷新成功返回 true，失败抛出错误
    /// - Throws: 如果没有设置刷新处理器或刷新失败会抛出错误
    @discardableResult
    public func handleTokenExpired() async throws -> Bool {
        // 检查是否设置了刷新处理器
        guard refreshTokenHandler != nil else {
            throw TokenRefreshError.noRefreshHandlerSet
        }
        return try await enqueueTokenRefresh()
    }
    
    /// 手动触发 Token 刷新
    /// - Returns: 刷新成功返回 true，失败抛出错误
    /// - Note: 如果已有刷新任务在执行，会复用当前刷新结果
    @discardableResult
    public func refreshToken() async throws -> Bool {
        guard refreshTokenHandler != nil else {
            throw TokenRefreshError.noRefreshHandlerSet
        }
        
        print("🔐 [TokenRefreshManager] 手动触发 Token 刷新...")
        return try await enqueueTokenRefresh()
    }
    
    /// 检查 Token 是否需要刷新（基于时间）
    /// - Parameter maxAge: Token 最大有效期（秒），默认 30 分钟
    /// - Returns: 如果需要刷新返回 true
    public func shouldRefreshToken(maxAge: TimeInterval = 30 * 60) -> Bool {
        return withQueueSync {
            guard let lastRefresh = lastRefreshTime else {
                return true // 从未刷新过，需要刷新
            }
            
            let timeSinceLastRefresh = Date().timeIntervalSince(lastRefresh)
            return timeSinceLastRefresh > maxAge
        }
    }
    
    
    
    /// 重置刷新状态
    /// 用于用户登出或清除认证状态时调用
    public func reset() {
        tokenRefreshQueue.sync { [weak self] in
            guard let self = self else { return }
            
            self._isRefreshingToken = false
            self.refreshFailureCount = 0
            self.lastRefreshTime = nil
            
            // 取消所有等待的请求
            for continuation in self.refreshContinuations {
                continuation.resume(throwing: TokenRefreshError.refreshCancelled)
            }
            self.refreshContinuations.removeAll()
            
            print("🔐 [TokenRefreshManager] 刷新状态已重置")
        }
    }
    
    
    // MARK: - 私有方法
    
    /// 等待或发起 Token 刷新
    private func enqueueTokenRefresh() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            tokenRefreshQueue.async { [weak self] in
                guard let self = self else { return }
                
                // 检查是否达到最大失败次数
                if self.refreshFailureCount >= self.maxRefreshFailureCount {
                    continuation.resume(throwing: TokenRefreshError.maxRetryExceeded)
                    return
                }
                
                // 如果已在刷新中，加入等待队列
                if self._isRefreshingToken {
                    print("🔐 [TokenRefreshManager] Token 正在刷新中，等待完成...")
                    self.refreshContinuations.append(continuation)
                    return
                }
                
                // 启动新的刷新流程
                self._isRefreshingToken = true
                self.refreshContinuations.append(continuation)
                
                Task { [weak self] in
                    await self?.performTokenRefreshAndNotify()
                }
            }
        }
    }
    
    /// 执行 Token 刷新并通知等待者
    private func performTokenRefreshAndNotify() async {
        do {
            print("🔄 [TokenRefreshManager] 执行 Token 刷新...")
            try await refreshTokenHandler?()
            let continuations = withQueueSync {
                self.lastRefreshTime = Date()
                self.refreshFailureCount = 0
                self._isRefreshingToken = false
                let continuations = self.refreshContinuations
                self.refreshContinuations.removeAll()
                return continuations
            }
            for continuation in continuations {
                continuation.resume(returning: true)
            }
            print("✅ [TokenRefreshManager] Token 刷新成功")
        } catch {
            let continuations = withQueueSync {
                self.refreshFailureCount += 1
                self._isRefreshingToken = false
                let continuations = self.refreshContinuations
                self.refreshContinuations.removeAll()
                return continuations
            }
            for continuation in continuations {
                continuation.resume(throwing: error)
            }
            print("❌ [TokenRefreshManager] Token 刷新失败: \(error)")
        }
    }
    
    private func withQueueSync<T>(_ block: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return block()
        }
        return tokenRefreshQueue.sync(execute: block)
    }
}

// MARK: - 错误类型

/// Token 刷新错误类型
public enum TokenRefreshError: Error, LocalizedError {
    case noRefreshHandlerSet
    case maxRetryExceeded
    case refreshCancelled
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .noRefreshHandlerSet:
            return "未设置 Token 刷新处理器"
        case .maxRetryExceeded:
            return "Token 刷新失败次数过多，请重新登录"
        case .refreshCancelled:
            return "Token 刷新已取消"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}
