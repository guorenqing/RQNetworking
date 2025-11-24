//
//  RQResponseModels.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//


import Foundation
import Alamofire

/// 网络响应包装结构体
/// 封装网络请求的响应数据，包含状态码、头信息等元数据
public struct RQResponse<T: Decodable> {
    
    // MARK: - 响应数据
    
    /// 解码后的业务数据
    public let data: T
    
    /// HTTP状态码
    public let statusCode: Int
    
    /// HTTP响应头信息
    public let headers: [AnyHashable: Any]
    
    /// 网络请求指标数据（如果可用）
    /// 包含请求时间、重定向等信息
    public let metrics: URLSessionTaskMetrics?
    
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
        headers: [AnyHashable: Any],
        metrics: URLSessionTaskMetrics? = nil
    ) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
        self.metrics = metrics
    }
}

/// 文件上传响应包装结构体
/// 封装文件上传请求的响应数据和上传进度信息
public struct RQUploadResponse<T: Decodable> {
    
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
public struct RQDownloadResponse {
    
    // MARK: - 响应数据
    
    /// 下载文件的本地URL
    public let localURL: URL
    
    /// HTTP响应信息
    public let response: HTTPURLResponse?
    
    
    // MARK: - 初始化方法
    
    /// 初始化下载响应
    /// - Parameters:
    ///   - localURL: 本地文件URL
    ///   - response: HTTP响应
    ///   - downloadProgress: 下载进度
    public init(localURL: URL, response: HTTPURLResponse?) {
        self.localURL = localURL
        self.response = response
    }
}
