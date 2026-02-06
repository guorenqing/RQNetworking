//
//  RQNetworkError.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//

import Foundation
import Alamofire

/// 网络请求错误类型枚举
/// 统一管理所有网络相关的错误情况
public enum RQNetworkError: Error {
    
    /// URL无效错误
    /// 通常由于域名配置错误或路径格式不正确导致
    case invalidURL
    
    /// 请求失败错误
    /// 包含底层的错误信息，如网络连接问题
    case requestFailed(Error)
    
    /// 响应无效错误
    /// 服务器返回的响应格式不符合预期
    case invalidResponse(String)
    
    /// HTTP状态码错误
    /// 包含具体的HTTP状态码，如404、500等
    case statusCode(Int)
    
    /// JSON编码失败错误
    /// 包含底层的解码错误信息
    case encodingFailed(Error)
    
    /// JSON解析失败错误
    /// 包含底层的解码错误信息
    case decodingFailed(Error)
    
    /// Token过期错误
    /// 用于触发Token刷新流程
    case tokenExpired
    
    /// Mock数据未找到错误
    /// 在启用Mock但未提供Mock数据时抛出
    case mockDataNotFound
    
    /// 请求超时错误
    /// 请求在指定时间内未完成
    case timeout
    
    
}

// MARK: - 错误描述扩展
extension RQNetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "请求URL无效，请检查域名配置和路径格式"
        case .requestFailed(let error):
            return "网络请求失败: \(error.localizedDescription)"
        case .invalidResponse(let msg):
            return "服务器响应格式无效:\(msg)"
        case .statusCode(let code):
            return "HTTP状态码错误: \(code)"
        case .decodingFailed(let error):
            return "数据解析失败: \(error.localizedDescription)"
        case .tokenExpired:
            return "用户认证已过期，请重新登录"
        case .mockDataNotFound:
            return "Mock数据文件未找到"
        case .timeout:
            return "网络请求超时，请检查网络连接"
        case .encodingFailed(let error):
            return "数据编码失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Alamofire 错误映射
extension RQNetworkError {
    public static func from(_ error: AFError) -> RQNetworkError {
        if let underlyingError = error.underlyingError {
            return .requestFailed(underlyingError)
        }
        
        if case .responseValidationFailed(let reason) = error {
            if case .unacceptableStatusCode(let code) = reason {
                return .statusCode(code)
            }
        }
        
        if error.isExplicitlyCancelledError {
            return .requestFailed(NSError(domain: "Cancelled", code: -999))
        }
        
        if error.isSessionTaskError {
            if let urlError = error.underlyingError as? URLError {
                switch urlError.code {
                case .timedOut:
                    return .timeout
                case .notConnectedToInternet:
                    return .requestFailed(urlError)
                case .networkConnectionLost:
                    return .requestFailed(urlError)
                case .cannotConnectToHost:
                    return .requestFailed(urlError)
                default:
                    break
                }
            }
        }
        
        return .requestFailed(error)
    }
}
