# RQNetworking

一个基于 **Alamofire** 封装的现代化、类型安全的 Swift 网络库，采用 Swift 并发编程模式，提供简洁的 API 和强大的扩展能力。

## 🌟 特性

- 🚀 **完全基于 Swift Concurrency** - 原生 `async/await` 支持
- 🛡️ **类型安全** - 泛型 + 协议导向设计
- 🔧 **高度可配置** - 丰富的配置选项和拦截器
- 🌍 **多环境管理** - 灵活的环境切换和域名管理
- 🔄 **智能重试** - 可配置的重试策略和延迟机制
- 🔐 **自动 Token 刷新** - 防止重复刷新的智能 Token 管理
- 📁 **文件传输** - 完整的文件上传下载支持
- 📊 **全面监控** - 详细的日志和性能指标
- 🧩 **模块化设计** - 易于扩展和维护

## 📦 安装

### Swift Package Manager

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/your-username/RQNetworking.git", from: "1.0.0")
]
```

### CocoaPods

在 `Podfile` 中添加：

```ruby
pod 'RQNetworking', '~> 1.0'
```

## 🚀 快速开始

### 1. 应用启动配置

创建一个配置类来集中管理网络设置：

```swift
import RQNetworking
import Alamofire

/// 应用网络配置
public final class AppNetworkConfig {
    
    /// 配置网络管理器单例
    public static func setupNetwork() {
        
        // 1. 配置域名
        setupDomains()
        
        // 2. 创建网络配置
        let configuration = RQNetworkConfiguration.build { builder in
            
            // 添加请求拦截器
            builder.addRequestInterceptor(RQRequestLoggingInterceptor()) // 请求日志
            builder.addRequestInterceptor(RQAuthInterceptor()) // 认证处理
            builder.addRequestInterceptor(RQRetryInterceptor( // 重试逻辑
                defaultRetryConfiguration: RQRetryConfiguration(
                    maxRetryCount: 3,
                    delayStrategy: .exponentialBackoff(base: 2.0),
                    retryCondition: .default
                )
            ))
            
            // 添加响应拦截器
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
            
            // 业务状态码拦截器
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
                
                // 动态添加认证Token
                if let token = TokenManager.shared.getAccessToken() {
                    headers["Authorization"] = "Bearer \(token)"
                }
                
                return HTTPHeaders(headers)
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
        domainManager.registerDomain(key: "api", urls: [
            .develop("d1"): "https://dev-api.example.com",
            .develop("d2"): "https://dev-api-2.example.com",
            .test("t1"): "https://test-api.example.com",
            .preProduction: "https://staging-api.example.com",
            .production: "https://api.example.com"
        ])
        
        // 注册上传域名
        domainManager.registerDomain(key: "upload", urls: [
            .develop("d1"): "https://dev-upload.example.com",
            .test("t1"): "https://test-upload.example.com",
            .production: "https://upload.example.com"
        ])
        
        // 设置当前环境（根据编译配置）
        #if DEBUG
        domainManager.setEnvironment(.develop("d1"))
        #elseif STAGING
        domainManager.setEnvironment(.preProduction)
        #else
        domainManager.setEnvironment(.production)
        #endif
        
        print("🌍 [AppNetworkConfig] 域名配置完成")
    }
}
```

### 2. 在 AppDelegate 中初始化

```swift
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 配置网络
        AppNetworkConfig.setupNetwork()
        
        // 配置 Token 刷新处理器
        RQTokenRefreshManager.shared.refreshTokenHandler = {
            try await AuthService.refreshToken()
        }
        
        return true
    }
}
```

### 3. 执行网络请求

```swift
// 使用构建器创建请求
let request = RQRequestBuilder()
    .setDomainKey("api")
    .setPath("/users")
    .setMethod(.get)
    .build()

do {
    let response: RQResponse<UserList> = try await RQNetworkManager.shared.request(request)
    print("获取用户成功: \(response.data)")
} catch {
    print("请求失败: \(error)")
}
```

### 4. 便捷方法

```swift
// 快速 GET 请求
let users: RQResponse<UserList> = try await RQNetworkManager.shared.get(
    domainKey: "api", 
    path: "/users"
)

// 快速 POST 请求
let response: RQResponse<LoginResponse> = try await RQNetworkManager.shared.post(
    domainKey: "api",
    path: "/login",
    parameters: LoginRequest(username: "user", password: "pass")
)
```

## 📁 核心功能

### 请求构建器

#### 普通请求
```swift
let request = RQRequestBuilder()
    .setDomainKey("api")
    .setPath("/users")
    .setMethod(.post)
    .setRequestParameters(userParams)
    .setHeaders(["Custom-Header": "value"])
    .setTimeoutInterval(30)
    .build()
```

#### 文件上传
```swift
let uploadRequest = RQUploadRequestBuilder()
    .setDomainKey("upload")
    .setPath("/images")
    .addDataUpload(imageData, fileName: "photo.jpg", mimeType: "image/jpeg")
    .addFormField(key: "description", value: "用户头像")
    .build()
```

#### 文件下载
```swift
let downloadRequest = RQDownloadRequestBuilder()
    .setDomainKey("cdn")
    .setPath("/files/document.pdf")
    .setDocumentDestination(fileName: "important.pdf")
    .setTimeoutInterval(300)
    .build()
```

### 预定义便捷方法

```swift
// JSON POST 请求
let request = RQRequestBuilder.postJSON(
    domainKey: "api",
    path: "/users",
    parameters: userData
)

// 带查询参数的 GET 请求
let request = RQRequestBuilder.getWithQuery(
    domainKey: "api", 
    path: "/search",
    parameters: searchParams
)

// 图片下载
let request = RQDownloadRequestBuilder.imageDownload(
    domainKey: "cdn",
    path: "/images/avatar.jpg",
    fileName: "user_avatar.jpg"
)
```

## 🔧 高级配置

### 拦截器系统

#### Token 过期处理（双重保障）
```swift
// HTTP 状态码检测 (401)
builder.addResponseInterceptor(RQTokenExpiredInterceptor(
    tokenRefreshHandler: {
        try await RQTokenRefreshManager.shared.handleTokenExpired()
    },
    tokenExpiredDetector: { data, response in
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return httpResponse.statusCode == 401
    }
))

// 业务状态码检测 (40001)
builder.addResponseInterceptor(RQBusinessStatusInterceptor(
    statusCodeKeyPath: "code",
    tokenExpiredCodes: [40001],
    tokenRefreshHandler: {
        try await RQTokenRefreshManager.shared.handleTokenExpired()
    }
))
```

#### 智能重试配置
```swift
builder.addRequestInterceptor(RQRetryInterceptor(
    defaultRetryConfiguration: RQRetryConfiguration(
        maxRetryCount: 3,
        delayStrategy: .exponentialBackoff(base: 2.0), // 指数退避
        retryCondition: .default // 默认重试条件
    )
))
```

### 动态公共头
```swift
builder.setCommonHeadersProvider {
    var headers: [String: String] = [
        "User-Agent": "MyApp/1.0",
        "Content-Type": "application/json",
        "App-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
        "Platform": "iOS"
    ]
    
    // 动态添加认证Token
    if let token = TokenManager.shared.getAccessToken() {
        headers["Authorization"] = "Bearer \(token)"
    }
    
    return HTTPHeaders(headers)
}
```

### 多环境域名管理
```swift
// 注册多环境域名
domainManager.registerDomain(key: "api", urls: [
    .develop("d1"): "https://dev-api.example.com",
    .develop("d2"): "https://dev-api-2.example.com",
    .test("t1"): "https://test-api.example.com",
    .preProduction: "https://staging-api.example.com",
    .production: "https://api.example.com"
])

// 根据编译配置自动设置环境
#if DEBUG
domainManager.setEnvironment(.develop("d1"))
#elseif STAGING
domainManager.setEnvironment(.preProduction)
#else
domainManager.setEnvironment(.production)
#endif
```

## 🎯 最佳实践

### 服务层封装

```swift
class UserService {
    static func fetchUsers() async throws -> [User] {
        let request = RQRequestBuilder.get(domainKey: "api", path: "/users")
        let response: RQResponse<UserListResponse> = try await RQNetworkManager.shared.request(request)
        return response.data.users
    }
    
    static func uploadAvatar(_ imageData: Data) async throws -> String {
        let request = RQUploadRequestBuilder()
            .setDomainKey("upload")
            .setPath("/users/avatar")
            .addDataUpload(imageData, fileName: "avatar.jpg", mimeType: "image/jpeg")
            .build()
            
        let response: RQUploadResponse<UploadResponse> = try await RQNetworkManager.shared.upload(request)
        return response.response.data.url
    }
    
    static func downloadUserManual() async throws -> URL {
        let request = RQDownloadRequestBuilder()
            .setDomainKey("api")
            .setPath("/documents/manual.pdf")
            .setDocumentDestination(fileName: "user_manual.pdf")
            .build()
            
        let response = try await RQNetworkManager.shared.download(request)
        return response.localURL
    }
}
```

### Token 刷新管理

```swift
// 配置 Token 刷新处理器
RQTokenRefreshManager.shared.refreshTokenHandler = {
    let refreshToken = TokenManager.shared.getRefreshToken()
    let newTokens = try await AuthAPI.refreshToken(refreshToken)
    
    // 保存新的 tokens
    TokenManager.shared.saveTokens(newTokens)
    
    print("✅ Token 刷新成功")
}

// 在需要的地方触发刷新
do {
    try await RQTokenRefreshManager.shared.handleTokenExpired()
} catch {
    print("Token 刷新失败: \(error)")
    // 跳转到登录页面
    navigateToLogin()
}
```

### 错误处理

```swift
do {
    let users = try await UserService.fetchUsers()
    // 处理数据
} catch RQNetworkError.tokenExpired {
    // Token 过期，尝试自动刷新
    try await RQTokenRefreshManager.shared.handleTokenExpired()
    // 重试原始请求
    let users = try await UserService.fetchUsers()
} catch RQNetworkError.statusCode(let code) where (500...599).contains(code) {
    // 服务器错误，显示重试提示
    showRetryAlert()
} catch {
    // 其他错误
    showErrorAlert(error.localizedDescription)
}
```

## 🔍 调试和监控

### 查看当前配置
```swift
// 打印所有域名配置
RQDomainManager.shared.printAllDomains()

// 输出示例：
// === 🌍 [RQDomainManager] 当前域名配置 ===
// 当前环境: 开发环境(d1)
// 已注册域名:
//   📍 api: https://dev-api.example.com
//   📍 upload: https://dev-upload.example.com
```

### 请求日志
拦截器会自动输出详细的请求和响应日志：
```
🌐 [RQNetwork] 请求开始
  URL: https://dev-api.example.com/users
  方法: GET
  头信息: ["Authorization": "Bearer xxx", "Content-Type": "application/json"]
```

## 🐛 故障排除

### 常见问题

1. **URL 构建失败**
   - 检查域名是否正确注册：`RQDomainManager.shared.printAllDomains()`
   - 验证路径格式（以 `/` 开头）

2. **Token 刷新循环**
   - 确保 Token 刷新逻辑正确实现
   - 检查刷新失败次数限制

3. **环境切换不生效**
   - 确认在 `setupDomains()` 之后设置环境
   - 检查编译配置标志

### 调试技巧

```swift
// 检查域名配置
if let apiURL = RQDomainManager.shared.getDomain("api") {
    print("API 域名: \(apiURL)")
} else {
    print("❌ API 域名未配置")
}

// 手动触发环境切换（调试用）
RQDomainManager.shared.setEnvironment(.test("t1"))
```

## 📚 API 参考

### 核心协议
- `RQNetworkRequest` - 基础网络请求协议
- `RQUploadRequest` - 文件上传请求协议  
- `RQDownloadRequest` - 文件下载请求协议

### 主要类
- `RQNetworkManager` - 网络管理器主类
- `RQDomainManager` - 域名管理器
- `RQTokenRefreshManager` - Token 刷新管理器
- `RQCompositeRequestInterceptor` - 复合拦截器管理器

### 配置类
- `RQNetworkConfiguration` - 网络配置
- `RQRetryConfiguration` - 重试配置
- `RQEnvironment` - 环境枚举

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

---

更多详细用法请查看源代码注释和示例项目。
