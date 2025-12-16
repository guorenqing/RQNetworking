//
//  RQCompositeRequestInterceptor.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//

import Foundation
import Alamofire

/// 复合请求拦截器
/// 管理多个请求拦截器的执行顺序，保证线程安全和高性能
public final class RQCompositeRequestInterceptor:  RequestInterceptor, @unchecked Sendable {
    
    // MARK: - 属性
    
    /// 底层拦截器数组存储
    private var _interceptors: [RequestInterceptor]
    
    /// 用于保护拦截器数组的锁
    /// 使用 NSLock 而不是串行队列，因为性能更高（快 2-5 倍）
    private let lock = NSLock()
    
    // MARK: - 公开接口
    
    /// 线程安全的拦截器数组访问
    public var interceptors: [RequestInterceptor] {
        get {
            return getInterceptorsSnapshot()
        }
        set {
            updateInterceptors(newValue)
        }
    }
    
    // MARK: - 初始化方法
    
    /// 初始化复合拦截器
    /// - Parameter interceptors: 拦截器数组
    public init(interceptors: [RequestInterceptor] = []) {
        self._interceptors = interceptors
    }
    
    // MARK: - RequestInterceptor 协议实现
    
    public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @Sendable @escaping (Result<URLRequest, Error>) -> Void
    ) {
        // 获取拦截器快照，确保在递归执行期间不受外部修改影响
        let currentInterceptors = getInterceptorsSnapshot()
        
        // 递归执行所有拦截器的 adapt 方法
        adaptRecursively(
            urlRequest: urlRequest,
            interceptors: currentInterceptors,
            session: session,
            completion: completion
        )
    }
    
    public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @Sendable @escaping (RetryResult) -> Void
    ) {
        // 获取拦截器快照，确保在递归执行期间不受外部修改影响
        let currentInterceptors = getInterceptorsSnapshot()
        
        // 递归执行所有拦截器的 retry 方法
        retryRecursively(
            request: request,
            interceptors: currentInterceptors,
            session: session,
            dueTo: error,
            completion: completion
        )
    }
    
    // MARK: - 拦截器管理方法（线程安全）
    
    /// 添加拦截器到末尾
    /// - Parameter interceptor: 要添加的拦截器
    public func addInterceptor(_ interceptor: RequestInterceptor) {
        executeWithLock {
            _interceptors.append(interceptor)
        }
    }
    
    /// 批量添加拦截器
    /// - Parameter interceptors: 要添加的拦截器数组
    public func addInterceptors(_ interceptors: [RequestInterceptor]) {
        executeWithLock {
            _interceptors.append(contentsOf: interceptors)
        }
    }
    
    /// 在指定位置插入拦截器
    /// - Parameters:
    ///   - interceptor: 要插入的拦截器
    ///   - index: 插入位置
    public func insertInterceptor(_ interceptor: RequestInterceptor, at index: Int) {
        executeWithLock {
            guard index >= 0 && index <= _interceptors.count else {
                print("⚠️ [RQCompositeRequestInterceptor] 插入位置 \(index) 无效，当前拦截器数量: \(_interceptors.count)")
                return
            }
            _interceptors.insert(interceptor, at: index)
        }
    }
    
    /// 移除指定拦截器
    /// - Parameter interceptor: 要移除的拦截器
    public func removeInterceptor(_ interceptor: RequestInterceptor) {
        executeWithLock {
            _interceptors.removeAll { $0 as AnyObject === interceptor as AnyObject}
        }
    }
    
    /// 移除指定类型的拦截器
    /// - Parameter type: 要移除的拦截器类型
    public func removeInterceptors<T: RequestInterceptor>(ofType type: T.Type) {
        executeWithLock {
            _interceptors.removeAll { $0 is T }
        }
    }
    
    /// 移除指定位置的拦截器
    /// - Parameter index: 要移除的拦截器位置
    public func removeInterceptor(at index: Int) {
        executeWithLock {
            guard index >= 0 && index < _interceptors.count else {
                print("⚠️ [RQCompositeRequestInterceptor] 移除位置 \(index) 无效，当前拦截器数量: \(_interceptors.count)")
                return
            }
            _interceptors.remove(at: index)
        }
    }
    
    /// 清空所有拦截器
    public func removeAllInterceptors() {
        executeWithLock {
            _interceptors.removeAll()
        }
    }
    
    /// 获取拦截器数量
    public var count: Int {
        return executeWithLock { _interceptors.count }
    }
    
    /// 检查是否包含指定拦截器
    /// - Parameter interceptor: 要检查的拦截器
    /// - Returns: 是否包含
    public func contains(_ interceptor: RequestInterceptor) -> Bool {
        return executeWithLock {
            _interceptors.contains { $0 as AnyObject === interceptor as AnyObject }
        }
    }
    
    /// 检查是否包含指定类型的拦截器
    /// - Parameter type: 要检查的拦截器类型
    /// - Returns: 是否包含
    public func contains<T: RequestInterceptor>(interceptorOfType type: T.Type) -> Bool {
        return executeWithLock {
            _interceptors.contains { $0 is T }
        }
    }
    
    // MARK: - 私有方法
    
    /// 获取拦截器数组的快照
    /// - Returns: 当前拦截器数组的副本
    private func getInterceptorsSnapshot() -> [RequestInterceptor] {
        lock.lock()
        defer { lock.unlock() }
        return _interceptors
    }
    
    /// 更新拦截器数组
    /// - Parameter newValue: 新的拦截器数组
    private func updateInterceptors(_ newValue: [RequestInterceptor]) {
        lock.lock()
        defer { lock.unlock() }
        _interceptors = newValue
    }
    
    /// 在锁保护下执行代码块
    /// - Parameter block: 要执行的代码块
    /// - Returns: 代码块的返回值
    private func executeWithLock<T>(_ block: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return block()
    }
    
    /// 在锁保护下执行代码块（无返回值）
    /// - Parameter block: 要执行的代码块
    private func executeWithLock(_ block: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        block()
    }
    
    // MARK: - 递归执行方法
    
    /// 递归执行拦截器的 adapt 方法
    /// - Parameters:
    ///   - urlRequest: 当前 URL 请求
    ///   - interceptors: 要执行的拦截器数组
    ///   - session: Session 对象
    ///   - completion: 完成回调
    private func adaptRecursively(
        urlRequest: URLRequest,
        interceptors: [RequestInterceptor],
        session: Session,
        completion: @Sendable @escaping (Result<URLRequest, Error>) -> Void
    ) {
        // 基础情况：没有更多拦截器需要执行
        guard let firstInterceptor = interceptors.first else {
            completion(.success(urlRequest))
            return
        }
        
        let remainingInterceptors = Array(interceptors.dropFirst())
        
        // 执行当前拦截器的 adapt 方法
        firstInterceptor.adapt(urlRequest, for: session) { [weak self] result in
            guard let self = self else {
                completion(.failure(NSError(domain: "RQCompositeRequestInterceptor", code: -1, userInfo: [NSLocalizedDescriptionKey: "拦截器已释放"])))
                return
            }
            
            switch result {
            case .success(let adaptedRequest):
                if remainingInterceptors.isEmpty {
                    // 所有拦截器执行完毕，返回最终结果
                    completion(.success(adaptedRequest))
                } else {
                    // 继续执行下一个拦截器
                    self.adaptRecursively(
                        urlRequest: adaptedRequest,
                        interceptors: remainingInterceptors,
                        session: session,
                        completion: completion
                    )
                }
                
            case .failure(let error):
                // 任何一个拦截器失败，立即返回错误
                completion(.failure(error))
            }
        }
    }
    
    /// 递归执行拦截器的 retry 方法
    /// - Parameters:
    ///   - request: 当前请求
    ///   - interceptors: 要执行的拦截器数组
    ///   - session: Session 对象
    ///   - dueTo: 错误原因
    ///   - completion: 完成回调
    private func retryRecursively(
        request: Request,
        interceptors: [RequestInterceptor],
        session: Session,
        dueTo error: Error,
        completion: @Sendable @escaping (RetryResult) -> Void
    ) {
        // 基础情况：没有更多拦截器需要执行
        guard let firstInterceptor = interceptors.first else {
            completion(.doNotRetry)
            return
        }
        
        let remainingInterceptors = Array(interceptors.dropFirst())
        
        // 执行当前拦截器的 retry 方法
        firstInterceptor.retry(request, for: session, dueTo: error) { [weak self] result in
            guard let self = self else {
                completion(.doNotRetry)
                return
            }
            
            switch result {
            case .retry, .retryWithDelay:
                // 当前拦截器决定重试，立即返回结果（不询问后续拦截器）
                completion(result)
                
            case .doNotRetry, .doNotRetryWithError:
                if remainingInterceptors.isEmpty {
                    // 所有拦截器都不重试
                    completion(result)
                } else {
                    // 继续询问下一个拦截器
                    self.retryRecursively(
                        request: request,
                        interceptors: remainingInterceptors,
                        session: session,
                        dueTo: error,
                        completion: completion
                    )
                }
            }
        }
    }
    
    // MARK: - 调试支持
    
    /// 打印拦截器信息（用于调试）
    public func printInterceptors() {
        let snapshot = getInterceptorsSnapshot()
        print("🔍 [RQCompositeRequestInterceptor] 当前拦截器 (\(snapshot.count) 个):")
        for (index, interceptor) in snapshot.enumerated() {
            print("  \(index + 1). \(type(of: interceptor))")
        }
    }
}

// MARK: - 便捷扩展

extension RQCompositeRequestInterceptor {
    
    /// 获取第一个指定类型的拦截器
    /// - Parameter type: 拦截器类型
    /// - Returns: 找到的拦截器，如果不存在返回 nil
    public func firstInterceptor<T: RequestInterceptor>(ofType type: T.Type) -> T? {
        return executeWithLock {
            _interceptors.first { $0 is T } as? T
        }
    }
    
    /// 获取所有指定类型的拦截器
    /// - Parameter type: 拦截器类型
    /// - Returns: 找到的拦截器数组
    public func interceptors<T: RequestInterceptor>(ofType type: T.Type) -> [T] {
        return executeWithLock {
            _interceptors.compactMap { $0 as? T }
        }
    }
    
    /// 替换指定类型的拦截器
    /// - Parameters:
    ///   - type: 要替换的拦截器类型
    ///   - newInterceptor: 新的拦截器
    public func replaceInterceptor<T: RequestInterceptor>(ofType type: T.Type, with newInterceptor: RequestInterceptor) {
        executeWithLock {
            if let index = _interceptors.firstIndex(where: { $0 is T }) {
                _interceptors[index] = newInterceptor
            }
        }
    }
}
