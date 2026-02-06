//
//  RQResponseLoggingInterceptor.swift
//  RQNetworking
//
//  Created by edy on 2025/11/19.
//

import Foundation

/// 响应日志拦截器
/// 输出网络响应日志（格式化、可读性更好）
public final class RQResponseLoggingInterceptor: RQResponseInterceptor {
    
    private let maxBodyLength: Int
    private let prettyPrintedJSON: Bool
    private let includeHeaders: Bool
    private let maxValueWidth: Int
    
    /// 初始化日志拦截器
    /// - Parameters:
    ///   - maxBodyLength: 响应体最大输出长度，超出则截断
    ///   - prettyPrintedJSON: 是否对JSON进行格式化输出
    ///   - includeHeaders: 是否输出响应头
    ///   - maxValueWidth: 表格值列最大宽度
    public init(
        maxBodyLength: Int = 2048,
        prettyPrintedJSON: Bool = true,
        includeHeaders: Bool = true,
        maxValueWidth: Int = 60
    ) {
        self.maxBodyLength = maxBodyLength
        self.prettyPrintedJSON = prettyPrintedJSON
        self.includeHeaders = includeHeaders
        self.maxValueWidth = maxValueWidth
    }
    
    public func intercept(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        for request: RQNetworkRequest
    ) async -> RQInterceptResult {
        logResponse(
            data: data,
            response: response,
            error: error,
            request: request
        )
        return .proceed
    }
    
    // MARK: - 私有方法
    
    private func logResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        request: RQNetworkRequest
    ) {
        let url = response?.url?.absoluteString
            ?? "\(request.domainKey.rawValue)\(request.path)"
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        let headers = (response as? HTTPURLResponse)?.allHeaderFields
        let headerText = includeHeaders ? formatHeaders(headers) : "Hidden"
        let bodyText = formatBody(data)
        let errorText = error?.localizedDescription ?? "None"
        let rows: [(String, String)] = [
            ("URL", url),
            ("Method", request.method.rawValue),
            ("DomainKey", request.domainKey.rawValue),
            ("Path", request.path),
            ("StatusCode", statusCode.map(String.init) ?? "N/A"),
            ("Error", errorText),
            ("Headers", headerText),
            ("Body", bodyText)
        ]
        
        print(makeTable(title: "📥 [RQNetwork] 响应结束", rows: rows))
    }
    
    private func formatHeaders(_ headers: [AnyHashable: Any]?) -> String {
        guard let headers, !headers.isEmpty else { return "Empty" }
        let lines = headers.map { key, value in
            "\(String(describing: key)): \(String(describing: value))"
        }.sorted()
        return lines.joined(separator: "\n")
    }
    
    private func formatBody(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "Empty" }
        
        if prettyPrintedJSON,
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           JSONSerialization.isValidJSONObject(jsonObject),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return wrapAndTruncate(prettyString)
        }
        
        if let text = String(data: data, encoding: .utf8) {
            return wrapAndTruncate(text)
        }
        
        return "Binary (\(data.count) bytes)"
    }
    
    private func wrapAndTruncate(_ text: String) -> String {
        var output = text
        if output.count > maxBodyLength {
            let prefix = output.prefix(maxBodyLength)
            output = "\(prefix)…(truncated)"
        }
        return output
    }
    
    private func makeTable(title: String, rows: [(String, String)]) -> String {
        let keyWidth = max(rows.map { displayWidth($0.0) }.max() ?? 0, 8)
        let valueWidth = maxValueWidth
        let border = "+\(String(repeating: "-", count: keyWidth + 2))+\(String(repeating: "-", count: valueWidth + 2))+"
        let contentWidth = border.count - 4
        
        var lines: [String] = []
        lines.append(border)
        lines.append("| \(center(title, width: contentWidth)) |")
        lines.append(border)
        
        for (key, value) in rows {
            let keyLines = wrapText(key, width: keyWidth)
            let valueLines = wrapText(value, width: valueWidth)
            let count = max(keyLines.count, valueLines.count)
            for index in 0..<count {
                let keyPart = index < keyLines.count ? keyLines[index] : ""
                let valuePart = index < valueLines.count ? valueLines[index] : ""
                lines.append("| \(pad(keyPart, keyWidth)) | \(pad(valuePart, valueWidth)) |")
            }
            lines.append(border)
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func wrapText(_ text: String, width: Int) -> [String] {
        guard width > 0 else { return [text] }
        var result: [String] = []
        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for rawLine in rawLines {
            if rawLine.isEmpty {
                result.append("")
                continue
            }
            var current = ""
            var currentWidth = 0
            for scalar in rawLine.unicodeScalars {
                let scalarWidth = isWideScalar(scalar) ? 2 : 1
                if currentWidth + scalarWidth > width {
                    result.append(current)
                    current = ""
                    currentWidth = 0
                }
                current.unicodeScalars.append(scalar)
                currentWidth += scalarWidth
            }
            result.append(current)
        }
        return result
    }
    
    private func pad(_ text: String, _ width: Int) -> String {
        let textWidth = displayWidth(text)
        if textWidth >= width { return text }
        return text + String(repeating: " ", count: width - textWidth)
    }

    private func center(_ text: String, width: Int) -> String {
        let fitted = truncateToWidth(text, width: width)
        let textWidth = displayWidth(fitted)
        if textWidth >= width { return fitted }
        let padding = width - textWidth
        let left = padding / 2
        let right = padding - left
        return String(repeating: " ", count: left) + fitted + String(repeating: " ", count: right)
    }

    private func truncateToWidth(_ text: String, width: Int) -> String {
        guard width > 0 else { return "" }
        var output = ""
        var currentWidth = 0
        for scalar in text.unicodeScalars {
            let scalarWidth = isWideScalar(scalar) ? 2 : 1
            if currentWidth + scalarWidth > width {
                return output
            }
            output.unicodeScalars.append(scalar)
            currentWidth += scalarWidth
        }
        return output
    }
    
    private func displayWidth(_ text: String) -> Int {
        var width = 0
        for scalar in text.unicodeScalars {
            width += isWideScalar(scalar) ? 2 : 1
        }
        return width
    }
    
    private func isWideScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x1100...0x115F,
             0x2329...0x232A,
             0x2E80...0xA4CF,
             0xAC00...0xD7A3,
             0xF900...0xFAFF,
             0xFE10...0xFE19,
             0xFE30...0xFE6F,
             0xFF00...0xFF60,
             0xFFE0...0xFFE6,
             0x20000...0x2FFFD,
             0x30000...0x3FFFD:
            return true
        default:
            return false
        }
    }
}
