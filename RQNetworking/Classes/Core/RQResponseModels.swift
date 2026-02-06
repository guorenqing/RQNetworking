//
//  RQResponseModels.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//


import Foundation

/// Sendable 响应指标快照（精简、可跨并发边界传递）
public struct RQResponseMetrics: Sendable {
    
    /// 请求总耗时（秒）
    public let duration: TimeInterval
    
    /// 重定向次数
    public let redirectCount: Int
    
    /// 事务数
    public let transactionCount: Int
    
    public init(
        duration: TimeInterval,
        redirectCount: Int,
        transactionCount: Int
    ) {
        self.duration = duration
        self.redirectCount = redirectCount
        self.transactionCount = transactionCount
    }
}

/// Sendable 的 HTTP 响应快照
public struct RQHTTPResponse: Sendable {
    
    public let url: URL?
    public let statusCode: Int
    public let headers: [String: String]
    
    public init(
        url: URL?,
        statusCode: Int,
        headers: [String: String]
    ) {
        self.url = url
        self.statusCode = statusCode
        self.headers = headers
    }
}

/// 网络响应包装结构体
/// 封装网络请求的响应数据，包含状态码、头信息等元数据
public struct RQResponse<T: Decodable & Sendable>: Sendable {
    
    // MARK: - 响应数据
    
    /// 解码后的业务数据
    public let data: T
    
    /// HTTP状态码
    public let statusCode: Int
    
    /// HTTP响应头信息
    public let headers: [String: String]
    
    /// 网络请求指标数据（如果可用）
    /// 包含请求时间、重定向等信息
    public let metrics: RQResponseMetrics?
    
    // MARK: - 初始化方法
    
    /// 初始化网络响应
    /// - Parameters:
    ///   - data: 业务数据
    ///   - statusCode: HTTP状态码
    ///   - headers: 响应头信息
    ///   - metrics: 请求指标数据
    public init(
        data: T,
        statusCode: Int,
        headers: [String: String],
        metrics: RQResponseMetrics? = nil
    ) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
        self.metrics = metrics
    }
}

/// 文件上传响应包装结构体
/// 封装文件上传请求的响应数据和上传进度信息
public struct RQUploadResponse<T: Decodable & Sendable>: Sendable {
    
    // MARK: - 响应数据
    
    /// 上传请求的响应数据
    public let response: RQResponse<T>
    
    // MARK: - 初始化方法
    
    /// 初始化上传响应
    /// - Parameters:
    ///   - response: 响应数据
    ///   - uploadProgress: 上传进度
    public init(response: RQResponse<T>) {
        self.response = response
    }
}

/// 文件下载响应包装结构体
/// 封装文件下载请求的响应数据和下载进度信息
public struct RQDownloadResponse: Sendable {
    
    // MARK: - 响应数据
    
    /// 下载文件的本地URL
    public let localURL: URL
    
    /// HTTP响应信息（Sendable快照）
    public let response: RQHTTPResponse?
    
    
    // MARK: - 初始化方法
    
    /// 初始化下载响应
    /// - Parameters:
    ///   - localURL: 本地文件URL
    ///   - response: HTTP响应
    ///   - downloadProgress: 下载进度
    public init(localURL: URL, response: RQHTTPResponse?) {
        self.localURL = localURL
        self.response = response
    }
}
