//
//  RQEnvironment.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//


import Foundation

/// 域名标识类型
/// 用于在业务侧定义可复用的域名Key，避免字符串拼写错误
public struct RQDomainKey: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ value: String) {
        self.rawValue = value
    }
    
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

/// 网络环境类型枚举
/// 用于管理不同部署环境（开发、测试、预生产、生产等）
public enum RQEnvironment: Equatable, Hashable {
    
    
    
    /// Mock环境
    /// 用于本地开发和测试，不发送真实网络请求
    case mock
    
    /// 开发环境
    /// - Parameter name: 环境名称，如"d1"、"d2"等，支持多个开发环境
    case develop(String)
    
    /// 测试环境
    /// - Parameter name: 环境名称，如"t1"、"t2"等，支持多个测试环境
    case test(String)
    
    /// 预生产环境
    /// 用于上线前的最后验证
    case preProduction
    
    /// 生产环境
    /// 线上正式环境
    case production
}

// MARK: - 环境描述扩展
extension RQEnvironment: CustomStringConvertible {
    public var description: String {
        switch self {
        case .mock:
            return "Mock环境"
        case .develop(let name):
            return "开发环境(\(name))"
        case .test(let name):
            return "测试环境(\(name))"
        case .preProduction:
            return "预生产环境"
        case .production:
            return "生产环境"
        }
    }
}
