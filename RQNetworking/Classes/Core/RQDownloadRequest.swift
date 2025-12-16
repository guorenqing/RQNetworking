//
//  RQDownloadRequest.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//

import Foundation
import Alamofire

/// 文件下载请求协议
/// 继承自基础网络请求协议，专门用于处理文件下载场景
public protocol RQDownloadRequest: RQNetworkRequest {
    
    // MARK: - 下载特定属性
    
    /// 下载目标路径
    /// 定义下载文件的保存位置
    var destination: RQDownloadDestination { get }
}

// MARK: - 协议默认实现
public extension RQDownloadRequest {
    
    /// 文件下载请求默认无请求参数
    var requestParameters: Encodable? { nil }
    
    /// 文件下载使用URL编码器
    var requestEncoder: ParameterEncoder {
        return URLEncodedFormParameterEncoder.default
    }
    
    /// 文件下载默认需要较长的超时时间
    var timeoutInterval: TimeInterval? { 600.0 } // 10分钟
    
    /// 文件下载默认需要认证
    var requiresAuth: Bool { true }
}

/// 下载目的地枚举
/// 定义文件下载后的保存位置
public enum RQDownloadDestination: Sendable {
    
    /// 临时目录
    /// 文件保存在系统临时目录，文件名自动生成UUID
    case temporary
    
    /// 文档目录
    /// - Parameter fileName: 文件名，如 "document.pdf"
    case document(String)
    
    /// 缓存目录
    /// - Parameter fileName: 文件名，如 "cache.file"
    case caches(String)
    
    /// 自定义目录
    /// - Parameter url: 自定义文件URL
    case custom(URL)
    
    /// 生成目标文件URL
    /// - Returns: 完整的文件URL路径
    public func makeURL() -> URL {
        switch self {
        case .temporary:
            // 临时目录，使用UUID作为文件名避免冲突
            return FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            
        case .document(let fileName):
            // 文档目录，用户数据应该保存在这里
            let documentsURL = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!
            return documentsURL.appendingPathComponent(fileName)
            
        case .caches(let fileName):
            // 缓存目录，可被系统清理的临时数据
            let cachesURL = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first!
            return cachesURL.appendingPathComponent(fileName)
            
        case .custom(let url):
            // 自定义URL
            return url
        }
    }
}

// MARK: - 便捷下载目的地构造方法
extension RQDownloadDestination {
    
    /// 创建文档目录下载目的地
    /// - Parameter fileName: 文件名
    /// - Returns: 文档目录目的地实例
    public static func document(fileName: String) -> RQDownloadDestination {
        return .document(fileName)
    }
    
    /// 创建缓存目录下载目的地
    /// - Parameter fileName: 文件名
    /// - Returns: 缓存目录目的地实例
    public static func caches(fileName: String) -> RQDownloadDestination {
        return .caches(fileName)
    }
    
    /// 创建图片下载目的地
    /// - Parameter fileName: 图片文件名
    /// - Returns: 文档目录中的图片文件目的地
    public static func image(fileName: String) -> RQDownloadDestination {
        return .document("images/\(fileName)")
    }
    
    /// 创建视频下载目的地
    /// - Parameter fileName: 视频文件名
    /// - Returns: 文档目录中的视频文件目的地
    public static func video(fileName: String) -> RQDownloadDestination {
        return .document("videos/\(fileName)")
    }
    
    /// 创建音频下载目的地
    /// - Parameter fileName: 音频文件名
    /// - Returns: 文档目录中的音频文件目的地
    public static func audio(fileName: String) -> RQDownloadDestination {
        return .document("audios/\(fileName)")
    }
}
