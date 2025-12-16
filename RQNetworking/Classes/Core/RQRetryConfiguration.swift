//
//  RQRetryConfiguration.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//


import Foundation

/// 重试配置结构体
/// 定义网络请求失败时的重试策略
public struct RQRetryConfiguration: Sendable {
    
    // MARK: - 配置属性
    
    /// 最大重试次数
    /// 包括首次请求，实际重试次数为 maxRetryCount
    public let maxRetryCount: Int
    
    /// 重试延迟策略
    /// 定义每次重试之间的延迟时间计算方式
    public let delayStrategy: RQRetryDelayStrategy
    
    /// 重试条件判断
    /// 定义在什么情况下应该进行重试
    public let retryCondition: RQRetryCondition
    
    // MARK: - 初始化方法
    
    /// 初始化重试配置
    /// - Parameters:
    ///   - maxRetryCount: 最大重试次数，默认为3次
    ///   - delayStrategy: 重试延迟策略，默认为指数退避
    ///   - retryCondition: 重试条件，默认为默认条件
    public init(
        maxRetryCount: Int = 3,
        delayStrategy: RQRetryDelayStrategy = .exponentialBackoff(base: 2.0),
        retryCondition: RQRetryCondition = .default
    ) {
        self.maxRetryCount = maxRetryCount
        self.delayStrategy = delayStrategy
        self.retryCondition = retryCondition
    }
    
    // MARK: - 预定义配置
    
    /// 默认重试配置
    /// 3次重试，指数退避延迟，默认重试条件
    public static let `default` = RQRetryConfiguration()
    
    /// 激进重试配置
    /// 5次重试，固定1秒延迟，对所有错误重试
    public static let aggressive = RQRetryConfiguration(
        maxRetryCount: 5,
        delayStrategy: .fixed(1.0),
        retryCondition: .always
    )
    
    /// 保守重试配置
    /// 2次重试，指数退避，只对服务器错误重试
    public static let conservative = RQRetryConfiguration(
        maxRetryCount: 2,
        delayStrategy: .exponentialBackoff(base: 3.0),
        retryCondition: .statusCodes(Set(500...599))
    )
}

/// 重试延迟策略枚举
/// 定义重试延迟时间的计算方式
public enum RQRetryDelayStrategy: Sendable {
    
    /// 固定延迟
    /// - Parameter interval: 固定的延迟时间（秒）
    case fixed(TimeInterval)
    
    /// 指数退避延迟
    /// - Parameters:
    ///   - base: 退避基数，延迟时间 = base^retryCount
    ///   - maxDelay: 最大延迟时间，避免延迟过长
    case exponentialBackoff(base: Double, maxDelay: TimeInterval = 60.0)
    
    /// 自定义延迟计算
    /// - Parameter calculator: 自定义延迟计算闭包，参数为重试次数
    case custom(@Sendable (Int) -> TimeInterval)
    
    /// 计算指定重试次数的延迟时间
    /// - Parameter retryCount: 当前重试次数（从0开始）
    /// - Returns: 延迟时间（秒）
    public func delay(for retryCount: Int) -> TimeInterval {
        switch self {
        case .fixed(let interval):
            return interval
            
        case .exponentialBackoff(let base, let maxDelay):
            let delay = pow(base, Double(retryCount))
            return min(delay, maxDelay)
            
        case .custom(let calculator):
            return calculator(retryCount)
        }
    }
}

/// 重试条件结构体
/// 定义在什么错误情况下应该进行重试
public struct RQRetryCondition: Sendable {
    
    /// 条件判断闭包
    private let condition: @Sendable (Error, URLRequest, HTTPURLResponse?) -> Bool
    
    /// 初始化重试条件
    /// - Parameter condition: 条件判断闭包
    public init(condition: @escaping @Sendable (Error, URLRequest, HTTPURLResponse?) -> Bool) {
        self.condition = condition
    }
    
    /// 判断是否应该重试
    /// - Parameters:
    ///   - error: 发生的错误
    ///   - request: 原始请求
    ///   - response: HTTP响应（如果有）
    /// - Returns: 是否应该重试
    public func shouldRetry(error: Error, request: URLRequest, response: HTTPURLResponse?) -> Bool {
        return condition(error, request, response)
    }
    
    // MARK: - 预定义条件
    
    /// 默认重试条件
    /// 对超时、服务器错误和网络连接问题进行重试
    public static let `default` = RQRetryCondition { error, request, response in
        // Token过期错误不应该重试，应该走Token刷新流程
        if case RQNetworkError.tokenExpired = error {
            return false
        }
        
        // 超时错误应该重试
        if case RQNetworkError.timeout = error {
            return true
        }
        
        // 5xx 服务器错误应该重试
        if case RQNetworkError.statusCode(let code) = error, (500...599).contains(code) {
            return true
        }
        
        // 特定的URL错误应该重试
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,                    // 超时
                 .cannotConnectToHost,         // 无法连接到主机
                 .networkConnectionLost,       // 网络连接丢失
                 .notConnectedToInternet,      // 未连接到互联网
                 .secureConnectionFailed:      // 安全连接失败
                return true
            default:
                break
            }
        }
        
        return false
    }
    
    /// 从不重试条件
    /// 对所有错误都不进行重试
    public static let never = RQRetryCondition { _, _, _ in false }
    
    /// 总是重试条件
    /// 对所有错误都进行重试（谨慎使用）
    public static let always = RQRetryCondition { _, _, _ in true }
    
    /// 自定义状态码重试条件
    /// - Parameter codes: 需要重试的状态码集合
    /// - Returns: 重试条件实例
    public static func statusCodes(_ codes: Set<Int>) -> RQRetryCondition {
        return RQRetryCondition { error, _, _ in
            if case RQNetworkError.statusCode(let code) = error {
                return codes.contains(code)
            }
            return false
        }
    }
    
    /// 网络错误重试条件
    /// 只对网络相关的错误进行重试
    public static let networkErrors = RQRetryCondition { error, _, _ in
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .dnsLookupFailed,
                 .cannotFindHost,
                 .secureConnectionFailed:
                return true
            default:
                return false
            }
        }
        return false
    }
}
