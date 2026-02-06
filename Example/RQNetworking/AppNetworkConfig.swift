//
//  AppNetworkConfig.swift
//  RQNetworking_Example
//
//  Created by edy on 2025/11/20.
//  Copyright © 2025 CocoaPods. All rights reserved.
//

import RQNetworking
import Alamofire

extension RQDomainKey {
    static let api: RQDomainKey = "api"
    static let upload: RQDomainKey = "upload"
    static let demo: RQDomainKey = "demo"
}

/// 应用网络配置
public final class AppNetworkConfig {
    
    /// 配置网络管理器单例
    public static func setupNetwork() {
        
        // 1. 配置域名
        setupDomains()
        
        // 2. 创建网络配置
        let configuration = RQNetworkConfiguration.build { builder in
            
            // 添加请求拦截器
            // 认证相关拦截器
            builder.addRequestInterceptor(RQAuthInterceptor())
            // 请求日志拦截器
            builder.addRequestInterceptor(RQRequestLoggingInterceptor())
            
            // 重试逻辑拦截器
            builder.addRequestInterceptor(RQRetryInterceptor(
                defaultRetryConfiguration: RQRetryConfiguration(
                    maxRetryCount: 3,
                    delayStrategy: .exponentialBackoff(base: 2.0),
                    retryCondition: .default
                )
            ))
            
            // 添加响应拦截器（token过期状态码定义在状态码里）
            builder.addResponseInterceptor(RQResponseLoggingInterceptor())
            builder.addResponseInterceptor(RQTokenExpiredInterceptor(
                tokenRefreshHandler: {
                    try await RQTokenRefreshManager.shared.handleTokenExpired()
                },
                tokenExpiredDetector: { data, response in
                    // 检测HTTP 401状态码表示Token过期
                    guard let httpResponse = response as? HTTPURLResponse else { return false }
                    return httpResponse.statusCode == 401
                }
            ))
            
            // token过期状态码定义在业务层
            builder.addResponseInterceptor(RQBusinessStatusInterceptor(
                statusCodeKeyPath: "code",
                tokenExpiredCodes: [40001], // 业务定义的Token过期码
                tokenRefreshHandler: {
                    try await RQTokenRefreshManager.shared.handleTokenExpired()
                }
            ))
            
            // 设置动态公共头
            builder.setCommonHeadersProvider {
                var headers: [String: String] = [
                    "User-Agent": "MyApp/1.0",
                    "Content-Type": "application/json",
                    "App-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                    "Platform": "iOS"
                ]
                
//                // 动态添加认证Token
//                if let token = TokenManager.shared.getAccessToken() {
//                    headers["Authorization"] = "Bearer \(token)"
//                }
                
                return HTTPHeaders(headers)
            }
            
            // 设置动态公共参数
            builder.setCommonParametersProvider {
                let params: [String: String]? = nil
                return params
            }
            
            // 设置自定义超时时间
            builder.setTimeoutInterval(30.0)
        }
        
        // 3. 配置网络管理器
        RQNetworkManager.configure(configuration)
        
        print("✅ [AppNetworkConfig] 网络配置完成")
    }
    

    
    /// 配置域名
    private static func setupDomains() {
        let domainManager = RQDomainManager.shared
        
        // 注册API域名
        domainManager.registerDomain(key: .api, urls: [
            .develop("d1"): "https://dev-api.example.com",
            .develop("d2"): "https://dev-api-2.example.com",
            .test("t1"): "https://test-api.example.com",
            .preProduction: "https://staging-api.example.com",
            .production: "https://api.example.com"
        ])
        
        // 注册上传域名
        domainManager.registerDomain(key: .upload, urls: [
            .develop("d1"): "https://dev-upload.example.com",
            .test("t1"): "https://test-upload.example.com",
            .production: "https://upload.example.com"
        ])
        
        // 注册演示域名（真实可访问）
        domainManager.registerDomain(key: .demo, urls: [
            .develop("d1"): "https://httpbin.org",
            .develop("d2"): "https://httpbin.org",
            .test("t1"): "https://httpbin.org",
            .preProduction: "https://httpbin.org",
            .production: "https://httpbin.org"
        ])
        
        // 设置当前环境（根据编译配置或用户设置）
        #if DEBUG
        domainManager.setEnvironment(.develop("d1"))
        #elseif STAGING
        domainManager.setEnvironment(.preProduction)
        #else
        domainManager.setEnvironment(.production)
        #endif
        
        print("🌍 [AppNetworkConfig] 域名配置完成，当前环境: \(domainManager.currentEnvironment.description)")
    }
}
