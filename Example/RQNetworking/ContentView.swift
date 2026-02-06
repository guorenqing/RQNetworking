//
//  ContentView.swift
//  GLMAgent
//
//  Created by edy on 2025/11/24.
//

import SwiftUI
import RQNetworking

struct ContentView: View {
    @State private var isLoading = false
    @State private var statusText = "点击按钮发起登录请求"
    @State private var urlText = "-"
    @State private var jsonText = "-"

    var body: some View {
        VStack {
            Text("RQNetworking Demo")
                .font(.title2)
                .bold()
            
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("响应 URL: \(urlText)")
                Text("响应 JSON: \(jsonText)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            
            Button(isLoading ? "请求中..." : "发送登录请求") {
                Task {
                    await runDemo()
                }
            }
            .disabled(isLoading)
            .padding(.top, 12)
        }
        .padding()
    }

    @MainActor
    private func runDemo() async {
        isLoading = true
        statusText = "请求中..."
        urlText = "-"
        jsonText = "-"
        do {
            let response: RQResponse<LoginResponse> = try await RQNetworkManager.shared.request(
                DemoLoginRequest(username: "demo", password: "123456")
            )
            statusText = "请求成功"
            urlText = response.data.url
            if let json = response.data.json {
                jsonText = "\(json.username) / \(json.password)"
            } else {
                jsonText = "nil"
            }
        } catch {
            statusText = "请求失败: \(error)"
        }
        isLoading = false
    }
}

#Preview {
    ContentView()
}
