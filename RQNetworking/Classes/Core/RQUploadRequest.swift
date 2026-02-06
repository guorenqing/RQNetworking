//
//  RQUploadRequest.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//


import Foundation
import Alamofire

/// 文件上传请求协议
/// 继承自基础网络请求协议，专门用于处理文件上传场景
public protocol RQUploadRequest: RQNetworkRequest {
    
    // MARK: - 上传特定属性
    
    /// 上传数据数组
    /// 支持多种上传数据类型：内存数据、本地文件、输入流
    var uploadData: [RQUploadData] { get }
    
    /// 表单字段字典
    /// 除了文件外的其他表单字段，如描述信息、元数据等
    var formFields: [String: String]? { get }
}

// MARK: - 协议默认实现
public extension RQUploadRequest {
    
    /// 文件上传请求默认无普通请求参数
    /// 参数通过 multipart form data 方式传递
    var requestParameters: (Codable & Sendable)? { nil }
    
    /// 文件上传使用URL编码器作为默认编码器
    /// 实际参数会在 multipart form data 中处理
    var requestEncoder: ParameterEncoder {
        return URLEncodedFormParameterEncoder.default
    }
    
    /// 文件上传默认需要较长的超时时间
    var timeoutInterval: TimeInterval? { 300.0 } // 5分钟
    
    /// 文件上传默认需要公共头
    var requiresCommonHeaders: Bool { true }
}

public struct SafeInputStream: Sendable {
    private let _createStream: @Sendable () -> InputStream
    
    // 方式1：从 Data 创建
    public init(data: Data) {
        _createStream = { InputStream(data: data) }
    }
    
    // 方式2：从 URL 创建
    public init(url: URL) {
        _createStream = { InputStream(url: url) ?? InputStream(data: Data()) }
    }
    
    // 方式3：自定义创建逻辑
    public init(createStream: @escaping @Sendable () -> InputStream) {
        _createStream = createStream
    }
    
    // 创建新的 InputStream 实例
    public func createStream() -> InputStream {
        return _createStream()
    }
}


/// 上传数据类型枚举
/// 定义支持的各种文件上传方式
public enum RQUploadData: Sendable {
    
    /// 内存数据上传
    /// - Parameters:
    ///   - data: 文件数据
    ///   - fileName: 文件名
    ///   - mimeType: MIME类型，如 "image/jpeg"、"application/pdf"
    case data(Data, fileName: String, mimeType: String)
    
    /// 本地文件上传
    /// - Parameters:
    ///   - fileURL: 本地文件URL
    ///   - fileName: 文件名
    ///   - mimeType: MIME类型
    case file(URL, fileName: String, mimeType: String)
    
    /// 输入流上传
    /// - Parameters:
    ///   - stream: 输入流，用于大文件上传
    ///   - fileName: 文件名
    ///   - mimeType: MIME类型
    case stream(SafeInputStream, fileName: String, mimeType: String)
    
    /// 表单字段名称
    /// 在multipart form data中使用的字段名
    public var name: String {
        return "file"
    }
    
    /// 获取文件名
    public var fileName: String {
        switch self {
        case .data(_, let fileName, _),
             .file(_, let fileName, _),
             .stream(_, let fileName, _):
            return fileName
        }
    }
    
    /// 获取MIME类型
    public var mimeType: String {
        switch self {
        case .data(_, _, let mimeType),
             .file(_, _, let mimeType),
             .stream(_, _, let mimeType):
            return mimeType
        }
    }
}

// MARK: - 便捷上传数据构造方法
extension RQUploadData {
    
    /// 创建图片上传数据
    /// - Parameters:
    ///   - imageData: 图片数据
    ///   - fileName: 文件名，默认为 "image.jpg"
    ///   - mimeType: MIME类型，默认为 "image/jpeg"
    /// - Returns: 图片上传数据实例
    public static func image(
        _ imageData: Data,
        fileName: String = "image.jpg",
        mimeType: String = "image/jpeg"
    ) -> RQUploadData {
        return .data(imageData, fileName: fileName, mimeType: mimeType)
    }
    
    /// 创建JSON文件上传数据
    /// - Parameters:
    ///   - jsonData: JSON数据
    ///   - fileName: 文件名，默认为 "data.json"
    /// - Returns: JSON上传数据实例
    public static func json(
        _ jsonData: Data,
        fileName: String = "data.json"
    ) -> RQUploadData {
        return .data(jsonData, fileName: fileName, mimeType: "application/json")
    }
    
    /// 创建PDF文件上传数据
    /// - Parameters:
    ///   - pdfData: PDF数据
    ///   - fileName: 文件名，默认为 "document.pdf"
    /// - Returns: PDF上传数据实例
    public static func pdf(
        _ pdfData: Data,
        fileName: String = "document.pdf"
    ) -> RQUploadData {
        return .data(pdfData, fileName: fileName, mimeType: "application/pdf")
    }
}
