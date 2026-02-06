# RQNetworking

一个基于 **Alamofire** 的现代化 Swift 网络库，支持 `async/await`、类型安全、可扩展拦截器与多环境域名管理。

## ✨ 特性

- ✅ **Swift Concurrency**：原生 `async/await`
- ✅ **类型安全**：`RQRequest` + `RQRequestConfig` 模板化请求
- ✅ **强配置能力**：公共头 / 公共参数 / JSON 编解码 / 超时 / 重试策略
- ✅ **多环境域名**：开发 / 测试 / 预发 / 生产灵活切换
- ✅ **拦截器体系**：请求/响应拦截器链式扩展
- ✅ **文件上传/下载**：上传、下载 API 完备
- ✅ **可取消请求**：返回 `RQCancelable` 或取消 `Task`
- ✅ **日志清晰**：请求/响应日志拦截器（可格式化）

---

## 📦 安装

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/your-username/RQNetworking.git", from: "1.0.0")
]
```

### CocoaPods

```ruby
pod 'RQNetworking', '~> 1.0'
```

---

## 🚀 快速开始

### 1) 配置域名与网络管理器

```swift
import RQNetworking
import Alamofire

extension RQDomainKey {
    static let api: RQDomainKey = "api"
    static let upload: RQDomainKey = "upload"
}

public final class AppNetworkConfig {

    public static func setupNetwork() {
        setupDomains()

        let configuration = RQNetworkConfiguration.build { builder in
            // 请求拦截器（顺序决定执行顺序）
            builder.addRequestInterceptor(RQAuthInterceptor())
            builder.addRequestInterceptor(RQRequestLoggingInterceptor())
            builder.addRequestInterceptor(
                RQRetryInterceptor(
                    defaultRetryConfiguration: RQRetryConfiguration(
                        maxRetryCount: 3,
                        delayStrategy: .exponentialBackoff(base: 2.0),
                        retryCondition: .default
                    )
                )
            )

            // 响应拦截器（顺序决定执行顺序）
            builder.addResponseInterceptor(RQResponseLoggingInterceptor())
            builder.addResponseInterceptor(
                RQTokenExpiredInterceptor(
                    tokenRefreshHandler: {
                        try await RQTokenRefreshManager.shared.handleTokenExpired()
                    },
                    tokenExpiredDetector: { _, response in
                        guard let http = response as? HTTPURLResponse else { return false }
                        return http.statusCode == 401
                    }
                )
            )

            builder.addResponseInterceptor(
                RQBusinessStatusInterceptor(
                    statusCodeKeyPath: "code",
                    tokenExpiredCodes: [40001],
                    tokenRefreshHandler: {
                        try await RQTokenRefreshManager.shared.handleTokenExpired()
                    }
                )
            )

            // 动态公共头（Token 等动态信息在这里提供）
            builder.setCommonHeadersProvider {
                var headers: [String: String] = [
                    "User-Agent": "MyApp/1.0",
                    "Content-Type": "application/json",
                    "App-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                    "Platform": "iOS"
                ]

                // 例如追加认证 Token
                // if let token = TokenManager.shared.getAccessToken() {
                //     headers["Authorization"] = "Bearer \(token)"
                // }

                return HTTPHeaders(headers)
            }

            // 动态公共参数
            builder.setCommonParametersProvider {
                return ["platform": "iOS", "timestamp": Int(Date().timeIntervalSince1970)]
            }

            // 全局 JSON 编解码器（可按需配置策略）
            builder.setJSONDecoder(JSONDecoder())
            builder.setJSONEncoder(JSONEncoder())

            // 默认超时
            builder.setTimeoutInterval(30)
        }

        RQNetworkManager.configure(configuration)
    }

    private static func setupDomains() {
        let manager = RQDomainManager.shared

        manager.registerDomain(key: .api, urls: [
            .develop("d1"): "https://dev-api.example.com",
            .test("t1"): "https://test-api.example.com",
            .preProduction: "https://staging-api.example.com",
            .production: "https://api.example.com"
        ])

        manager.registerDomain(key: .upload, urls: [
            .develop("d1"): "https://dev-upload.example.com",
            .production: "https://upload.example.com"
        ])

        #if DEBUG
        manager.setEnvironment(.develop("d1"))
        #elseif STAGING
        manager.setEnvironment(.preProduction)
        #else
        manager.setEnvironment(.production)
        #endif
    }
}
```

SwiftUI 入口配置示例：

```swift
@main
struct MyApp: App {
    init() {
        AppNetworkConfig.setupNetwork()
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

---

## ✅ 请求与响应模型

### 响应模型必须满足
- `Decodable & Sendable`

### 响应结构体
- `RQResponse<T>`
  - `data: T`
  - `statusCode: Int`
  - `headers: [String: String]`
  - `metrics: RQResponseMetrics?`
- `RQUploadResponse<T>`
- `RQDownloadResponse`（含 `RQHTTPResponse` 快照）

---

## ✅ 使用方式

### 方式 A：RQRequest + RQRequestConfig（推荐）

```swift
struct LoginRequest: RQRequest {
    let username: String
    let password: String

    var requestConfig: RQRequestConfig {
        RQRequestConfig(
            domainKey: .api,
            path: "/login",
            method: .post,
            requestParameters: [
                "username": username,
                "password": password
            ]
        )
    }
}

let response: RQResponse<LoginResponse> = try await RQNetworkManager.shared.request(
    LoginRequest(username: "user", password: "pass")
)
```

### 方式 B：直接使用 Builder（无需 build）

```swift
let builder = RQRequestBuilder()
    .setDomainKey(.api)
    .setPath("/login")
    .setMethod(.post)
    .setRequestParameters(["username": "user", "password": "pass"])

let response: RQResponse<LoginResponse> = try await RQNetworkManager.shared.request(builder)
```

### 方式 C：自定义 RQNetworkRequest（全手写）

```swift
struct LoginRequest: RQNetworkRequest {
    var domainKey: RQDomainKey { .api }
    var path: String { "/login" }
    var method: HTTPMethod { .post }
    var requestParameters: (Codable & Sendable)? { ["username": "u", "password": "p"] }
}
```

---

## ✅ 回调方式调用（Completion）

```swift
let cancelable = RQNetworkManager.shared.request(LoginRequest(username: "u", password: "p")) {
    (result: Result<RQResponse<LoginResponse>, Error>) in
    switch result {
    case .success(let response):
        print(response.data)
    case .failure(let error):
        print(error)
    }
}

// 可取消
cancelable.cancel()
```

---

## ✅ 便捷方法（GET/POST/PUT/DELETE）

```swift
let users: RQResponse<UserList> = try await RQNetworkManager.shared.get(
    domainKey: .api,
    path: "/users"
)

let login: RQResponse<LoginResponse> = try await RQNetworkManager.shared.post(
    domainKey: .api,
    path: "/login",
    parameters: ["username": "u", "password": "p"]
)
```

---

## ✅ 上传 / 下载

```swift
let uploadReq = RQUploadRequestBuilder()
    .setDomainKey(.upload)
    .setPath("/upload")
    .addFile(fileURL)

let uploadResponse: RQUploadResponse<UploadResult> = try await RQNetworkManager.shared.upload(uploadReq)
```

```swift
let downloadReq = RQDownloadRequestBuilder()
    .setDomainKey(.api)
    .setPath("/file")
    .setDestinationURL(localURL)

let downloadResponse = try await RQNetworkManager.shared.download(downloadReq)
```

---

## ✅ 传参方式（字典 / 数组 / 混合类型）

- **简单字典（同类型）**：
```swift
.setRequestParameters(["ids": ["1", "2"]])
```

- **混合类型 / 嵌套结构**：使用 `RQJSONValue`
```swift
let params: [String: RQJSONValue] = [
    "username": .string("u"),
    "ids": .array([.int(1), .int(2)]),
    "meta": .object(["vip": .bool(true)])
]
```

---

## ✅ JSON 编解码策略

全局：
```swift
builder.setJSONDecoder(customDecoder)
builder.setJSONEncoder(customEncoder)
```

单请求级：
```swift
RQRequestConfig(
    domainKey: .api,
    path: "/login",
    jsonDecoder: customDecoder,
    jsonEncoder: customEncoder
)
```

---

## ✅ 重试策略

- 全局通过 `RQRetryInterceptor` 配置
- 单请求可覆盖 `retryConfiguration`

```swift
RQRequestConfig(
    domainKey: .api,
    path: "/login",
    retryConfiguration: .aggressive
)
```

---

## ✅ 日志

推荐启用：
- `RQRequestLoggingInterceptor`
- `RQResponseLoggingInterceptor`

注意：**拦截器顺序影响日志内容**  
公共头在 `RQAuthInterceptor` 中注入，日志拦截器建议放在它之后。

---

## ✅ 取消请求

### Completion 请求
```swift
let cancelable = RQNetworkManager.shared.request(builder) { _ in }
cancelable.cancel()
```

### async/await 请求
```swift
let task = Task {
    let response: RQResponse<LoginResponse> = try await RQNetworkManager.shared.request(builder)
    print(response.data)
}

// 取消 Task，会联动取消底层 Alamofire 请求
task.cancel()
```

---

## ✅ 常见问题

**Q: 为什么公共头没有进入请求？**  
A: 公共头在 `RQAuthInterceptor` 中注入，请确保它在请求拦截器链中，且日志拦截器放在其后。

**Q: `requestParameters` 能用字典吗？**  
A: 可以，但必须是 `Codable & Sendable`。混合类型推荐用 `RQJSONValue`。

