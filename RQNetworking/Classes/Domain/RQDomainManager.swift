//
//  RQDomainManager.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//

import Foundation

/// 域名管理器
/// 统一管理不同环境下的域名配置，支持动态切换环境
public final class RQDomainManager: @unchecked Sendable {
    
    // MARK: - 单例实例
    
    /// 共享域名管理器实例
    public static let shared = RQDomainManager()
    
    /// 私有初始化方法，确保单例模式
    private init() {
        print("🌍 [RQDomainManager] 初始化完成")
    }
    
    // MARK: - 属性
    
    /// 隔离队列，用于保护内部状态
    private let isolationQueue = DispatchQueue(
        label: "com.rqnetwork.domainmanager.isolation",
        attributes: .concurrent
    )
    
    /// 当前全局环境设置
    private var _currentEnvironment: RQEnvironment = .production
    
    /// 域名映射字典
    /// 结构: [域名标识: [环境: 基础URL]]
    private var _domainMapping: [String: [RQEnvironment: String]] = [:]
    
    // MARK: - 公共方法
    
    /// 设置当前全局环境
    /// - Parameter env: 要设置的环境
    public func setEnvironment(_ env: RQEnvironment) {
        isolationQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self._currentEnvironment = env
            print("🌍 [RQDomainManager] 环境已切换到: \(env.description)")
        }
    }
    
    /// 注册域名配置
    /// - Parameters:
    ///   - key: 域名标识，用于在请求中引用
    ///   - urls: 环境到URL的映射字典
    public func registerDomain(key: String, urls: [RQEnvironment: String]) {
        isolationQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self._domainMapping[key] = urls
            print("🌍 [RQDomainManager] 注册域名: \(key) - \(urls)")
        }
    }
    
    /// 注册单个环境的域名
    /// - Parameters:
    ///   - key: 域名标识
    ///   - url: 基础URL
    ///   - environment: 目标环境，默认为所有环境
    public func registerDomain(
        key: String,
        url: String,
        for environment: RQEnvironment
    ) {
        isolationQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if self._domainMapping[key] == nil {
                self._domainMapping[key] = [:]
            }
            self._domainMapping[key]?[environment] = url
            print("🌍 [RQDomainManager] 注册域名: \(key) -> \(url) (环境: \(environment.description))")
        }
    }
    
    /// 根据域名标识获取当前环境下的基础URL
    /// - Parameter key: 域名标识
    /// - Returns: 对应环境的基础URL，如果未找到返回nil
    public func getDomain(_ key: String) -> String? {
        return isolationQueue.sync {
            guard let environments = self._domainMapping[key] else {
                print("❌ [RQDomainManager] 未找到域名配置: \(key)")
                return nil
            }
            
            guard let url = environments[self._currentEnvironment] else {
                print("❌ [RQDomainManager] 域名 \(key) 在当前环境(\(self._currentEnvironment.description))下未配置")
                return nil
            }
            
            return url
        }
    }
    
    /// 获取指定环境下的域名
    /// - Parameters:
    ///   - key: 域名标识
    ///   - environment: 指定环境
    /// - Returns: 对应环境的基础URL
    public func getDomain(_ key: String, for environment: RQEnvironment) -> String? {
        return isolationQueue.sync {
            return self._domainMapping[key]?[environment]
        }
    }
    
    /// 获取当前环境设置
    /// - Returns: 当前环境枚举值
    public var currentEnvironment: RQEnvironment {
        return isolationQueue.sync {
            return self._currentEnvironment
        }
    }
    
    /// 检查域名是否已注册
    /// - Parameter key: 域名标识
    /// - Returns: 是否已注册
    public func isDomainRegistered(_ key: String) -> Bool {
        return isolationQueue.sync {
            return self._domainMapping[key] != nil
        }
    }
    
    /// 检查域名在特定环境下是否已配置
    /// - Parameters:
    ///   - key: 域名标识
    ///   - environment: 目标环境
    /// - Returns: 是否已配置
    public func isDomainConfigured(_ key: String, for environment: RQEnvironment) -> Bool {
        return isolationQueue.sync {
            return self._domainMapping[key]?[environment] != nil
        }
    }
    
    /// 获取所有已注册的域名标识
    /// - Returns: 域名标识数组
    public var allDomainKeys: [String] {
        return isolationQueue.sync {
            return Array(self._domainMapping.keys).sorted()
        }
    }
    
    /// 获取指定域名的所有环境配置
    /// - Parameter key: 域名标识
    /// - Returns: 环境到URL的映射字典
    public func getAllEnvironments(for key: String) -> [RQEnvironment: String]? {
        return isolationQueue.sync {
            return self._domainMapping[key]
        }
    }
    
    /// 移除域名配置
    /// - Parameter key: 要移除的域名标识
    public func removeDomain(_ key: String) {
        isolationQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self._domainMapping.removeValue(forKey: key)
            print("🗑️ [RQDomainManager] 已移除域名配置: \(key)")
        }
    }
    
    /// 清空所有域名配置
    public func clearAllDomains() {
        isolationQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let count = self._domainMapping.count
            self._domainMapping.removeAll()
            print("🗑️ [RQDomainManager] 已清空所有域名配置，共 \(count) 个")
        }
    }
    
    /// 批量获取多个域名
    /// - Parameter keys: 域名标识数组
    /// - Returns: 域名到URL的映射字典
    public func getMultipleDomains(_ keys: [String]) -> [String: String?] {
        return isolationQueue.sync {
            var result: [String: String?] = [:]
            for key in keys {
                result[key] = self._domainMapping[key]?[self._currentEnvironment]
            }
            return result
        }
    }
    
    /// 打印当前所有域名配置（调试用）
    public func printAllDomains() {
        isolationQueue.sync {
            print("=== 🌍 [RQDomainManager] 当前域名配置 ===")
            print("当前环境: \(self._currentEnvironment.description)")
            print("已注册域名:")
            
            if self._domainMapping.isEmpty {
                print("  无域名配置")
            } else {
                for (key, environments) in self._domainMapping.sorted(by: { $0.key < $1.key }) {
                    let currentURL = environments[self._currentEnvironment] ?? "未配置"
                    print("  📍 \(key): \(currentURL)")
                    
                    // 打印其他环境的配置
                    for (env, url) in environments where env != self._currentEnvironment {
                        print("      \(env.description): \(url)")
                    }
                }
            }
            print("=====================================")
        }
    }
}
