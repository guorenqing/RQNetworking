//
//  RQNetworkConfiguration.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//

import Foundation
import Alamofire


/// 网络配置类
/// 用于配置网络管理器的所有参数，包括拦截器、公共头、公共参数等
public struct RQNetworkConfiguration {
    
    // MARK: - 配置属性
    
    /// 域名管理器，用于管理不同环境的域名
    public let domainManager: RQDomainManager
    
    /// 请求拦截器数组，按顺序执行
    /// 用于在请求发送前进行修改、添加认证头、日志记录等
    public let requestInterceptors: [RequestInterceptor]
    
    /// 响应拦截器数组，按顺序执行
    /// 用于在收到响应后进行统一处理、Token刷新、业务状态码检查等
    public let responseInterceptors: [RQResponseInterceptor]
    
    /// 默认超时时间（秒）
    public let defaultTimeoutInterval: TimeInterval
    
    /// 公共头提供者回调
    /// 使用回调而不是固定字典，因为头信息可能是动态的（如认证Token）
    public let commonHeadersProvider: (@Sendable () -> HTTPHeaders)?
    
    /// 公共参数提供者回调
    /// 使用回调而不是固定字典，因为参数可能是动态的（如时间戳、设备信息等）
    public let commonParametersProvider: (@Sendable () -> Encodable?)?
    
    // MARK: - 初始化方法
    
    /// 初始化网络配置
    /// - Parameters:
    ///   - domainManager: 域名管理器，默认使用共享实例
    ///   - requestInterceptors: 请求拦截器数组，默认为空
    ///   - responseInterceptors: 响应拦截器数组，默认为空
    ///   - defaultTimeoutInterval: 默认超时时间，默认为60秒
    ///   - commonHeadersProvider: 公共头提供者回调，默认为nil
    ///   - commonParametersProvider: 公共参数提供者回调，默认为nil
    public init(
        domainManager: RQDomainManager = .shared,
        requestInterceptors: [RequestInterceptor] = [],
        responseInterceptors: [RQResponseInterceptor] = [],
        defaultTimeoutInterval: TimeInterval = 60.0,
        commonHeadersProvider: (@Sendable () -> HTTPHeaders)? = nil,
        commonParametersProvider: (@Sendable () -> Encodable?)? = nil
    ) {
        self.domainManager = domainManager
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
        self.defaultTimeoutInterval = defaultTimeoutInterval
        self.commonHeadersProvider = commonHeadersProvider
        self.commonParametersProvider = commonParametersProvider
    }
}

// MARK: - 配置构建器
extension RQNetworkConfiguration {
    
    /// 网络配置构建器
    /// 提供链式API来构建配置，使配置代码更清晰易读
    public struct Builder {
        
        // MARK: - 构建器属性
        
        private var domainManager: RQDomainManager = .shared
        private var requestInterceptors: [RequestInterceptor] = []
        private var responseInterceptors: [RQResponseInterceptor] = []
        private var defaultTimeoutInterval: TimeInterval = 60.0
        private var commonHeadersProvider: (@Sendable () -> HTTPHeaders)?
        private var commonParametersProvider: (@Sendable () -> Encodable?)?
        
        /// 初始化空的构建器
        public init() {}
        
        // MARK: - 配置方法
        
        /// 设置域名管理器
        /// - Parameter manager: 域名管理器实例
        /// - Returns: 构建器自身，支持链式调用
        @discardableResult
        public mutating func setDomainManager(_ manager: RQDomainManager) -> Self {
            self.domainManager = manager
            return self
        }
        
        /// 添加请求拦截器
        /// - Parameter interceptor: 请求拦截器实例
        /// - Returns: 构建器自身，支持链式调用
        @discardableResult
        public mutating func addRequestInterceptor(_ interceptor: RequestInterceptor) -> Self {
            self.requestInterceptors.append(interceptor)
            return self
        }
        
        /// 添加响应拦截器
        /// - Parameter interceptor: 响应拦截器实例
        /// - Returns: 构建器自身，支持链式调用
        @discardableResult
        public mutating func addResponseInterceptor(_ interceptor: RQResponseInterceptor) -> Self {
            self.responseInterceptors.append(interceptor)
            return self
        }
        
        /// 设置默认超时时间
        /// - Parameter interval: 超时时间（秒）
        /// - Returns: 构建器自身，支持链式调用
        @discardableResult
        public mutating func setTimeoutInterval(_ interval: TimeInterval) -> Self {
            self.defaultTimeoutInterval = interval
            return self
        }
        
        /// 设置固定公共头
        /// - Parameter headers: 公共头字典
        /// - Returns: 构建器自身，支持链式调用
        @discardableResult
        public mutating func setCommonHeaders(_ headers: [String: String]) -> Self {
            self.commonHeadersProvider = { HTTPHeaders(headers) }
            return self
        }
        
        /// 设置动态公共头提供者
        /// - Parameter provider: 公共头提供者回调
        /// - Returns: 构建器自身，支持链式调用
        @discardableResult
        public mutating func setCommonHeadersProvider(_ provider: @escaping @Sendable () -> HTTPHeaders) -> Self {
            self.commonHeadersProvider = provider
            return self
        }
        
        /// 设置固定公共参数
        /// - Parameter parameters: 公共参数（必须实现Encodable协议）
        /// - Returns: 构建器自身，支持链式调用
        @discardableResult
        public mutating func setCommonParameters<T: Encodable>(_ parameters: T) -> Self {
            self.commonParametersProvider = { parameters }
            return self
        }
        
        /// 设置动态公共参数提供者
        /// - Parameter provider: 公共参数提供者回调
        /// - Returns: 构建器自身，支持链式调用
        @discardableResult
        public mutating func setCommonParametersProvider(_ provider: @escaping @Sendable () -> Encodable?) -> Self {
            self.commonParametersProvider = provider
            return self
        }
        
        /// 构建网络配置
        /// - Returns: 配置完成的RQNetworkConfiguration实例
        public func build() -> RQNetworkConfiguration {
            return RQNetworkConfiguration(
                domainManager: domainManager,
                requestInterceptors: requestInterceptors,
                responseInterceptors: responseInterceptors,
                defaultTimeoutInterval: defaultTimeoutInterval,
                commonHeadersProvider: commonHeadersProvider,
                commonParametersProvider: commonParametersProvider
            )
        }
    }
    
    // MARK: - 便捷创建方法
    
    /// 使用构建器模式创建配置
    /// - Parameter builder: 构建器闭包，用于配置各种参数
    /// - Returns: 配置完成的RQNetworkConfiguration实例
    public static func build(_ builder: (inout Builder) -> Void) -> RQNetworkConfiguration {
        var configBuilder = Builder()
        builder(&configBuilder)
        return configBuilder.build()
    }
    
    /// 创建空配置
    /// 不包含任何拦截器和公共配置，适合完全自定义的场景
    public static var empty: RQNetworkConfiguration {
        return RQNetworkConfiguration()
    }
}
