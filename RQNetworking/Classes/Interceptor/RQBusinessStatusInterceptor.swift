//
//  RQBusinessStatusInterceptor.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//

/// 业务状态码拦截器
/// 根据业务返回的状态码进行统一处理
public final class RQBusinessStatusInterceptor: RQResponseInterceptor {
    
    // MARK: - 属性
    
    /// 状态码键路径
    /// 在JSON响应中状态码的字段路径，如 "code"、"status.code"
    private let statusCodeKeyPath: String?
    
    /// 成功状态码集合
    /// 表示请求成功的状态码
    private let successCodes: Set<Int>
    
    /// Token过期状态码集合
    /// 表示Token过期的状态码
    private let tokenExpiredCodes: Set<Int>
    
    /// Token过期处理器
    /// 当检测到Token过期时调用的处理方法
    private let tokenRefreshHandler: (@Sendable () async throws -> Void)?
    
    // MARK: - 初始化方法
    
    /// 初始化业务状态码拦截器
    /// - Parameters:
    ///   - statusCodeKeyPath: 状态码键路径，默认为 "code"
    ///   - successCodes: 成功状态码集合，默认为 [0, 200]
    ///   - tokenExpiredCodes: Token过期状态码集合，默认为 [401, 403, 1001]
    ///   - onTokenExpired: Token过期处理器
    public init(
        statusCodeKeyPath: String? = "code",
        successCodes: Set<Int> = [0, 200],
        tokenExpiredCodes: Set<Int> = [401, 403, 1001],
        tokenRefreshHandler: (@Sendable () async throws -> Void)? = nil
    ) {
        self.statusCodeKeyPath = statusCodeKeyPath
        self.successCodes = successCodes
        self.tokenExpiredCodes = tokenExpiredCodes
        self.tokenRefreshHandler = tokenRefreshHandler
    }
    
    // MARK: - 响应拦截器协议实现
    
    public func intercept(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        for request: RQNetworkRequest
    ) async -> RQInterceptResult {
        
        // 如果没有数据或数据为空，直接继续
        guard let data = data, !data.isEmpty else {
            return .proceed
        }
        
        do {
            // 解析业务状态码
            if let statusCode = try extractBusinessStatusCode(from: data) {
                if tokenExpiredCodes.contains(statusCode) {
                    print("🔐 [RQNetwork] 业务状态码指示Token过期: \(statusCode)")
                    return .retry(after: 0.1)
                }
                
                // 可以在这里添加其他业务状态码处理逻辑
                // 比如：显示错误提示、记录日志等
            }
        } catch {
            // 解析失败，继续处理
            return .proceed
        }
        
        return .proceed
    }
    
    public func handleRetry(
        _ request: RQNetworkRequest,
        originalData: Data?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task {
            do {
                try await tokenRefreshHandler?()
                print("🔐 [RQNetwork] 业务状态码触发的Token刷新成功")
                completion(.success(()))
            } catch {
                print("❌ [RQNetwork] 业务状态码触发的Token刷新失败: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 私有方法
    
    /// 从响应数据中提取业务状态码
    /// - Parameter data: 响应数据
    /// - Returns: 业务状态码，如果提取失败返回nil
    private func extractBusinessStatusCode(from data: Data) throws -> Int? {
        guard let keyPath = statusCodeKeyPath else { return nil }
        
        let json = try JSONSerialization.jsonObject(with: data)
        
        // 简单的keyPath解析（支持一级路径）
        if let dict = json as? [String: Any] {
            // 如果keyPath包含点号，支持多级路径解析
            if keyPath.contains(".") {
                let keys = keyPath.split(separator: ".").map(String.init)
                var current: Any? = dict
                for key in keys {
                    if let currentDict = current as? [String: Any] {
                        current = currentDict[key]
                    } else {
                        break
                    }
                }
                return current as? Int
            } else {
                // 单级路径
                return dict[keyPath] as? Int
            }
        }
        
        return nil
    }
}
