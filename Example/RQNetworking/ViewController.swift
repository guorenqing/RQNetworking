//
//  ViewController.swift
//  RQNetworking
//
//  Created by 郭仁庆 on 11/19/2025.
//  Copyright (c) 2025 郭仁庆. All rights reserved.
//

import UIKit
import Alamofire
import RQNetworking

/// 用户信息数据模型
public struct User: Codable, Sendable {
    public let id: Int
    public let name: String
    public let email: String
    public let avatar: String?
    
    public init(id: Int, name: String, email: String, avatar: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.avatar = avatar
    }
}

/// 用户列表响应模型
public struct UserListResponse: Codable, Sendable {
    public let users: [User]
    public let total: Int
    public let page: Int
    public let pageSize: Int
}

/// 登录请求参数模型
public struct LoginInput: Codable, Sendable {
    public let username: String
    public let password: String
}


/// httpbin /post 响应模型（用于演示）
public struct LoginResponse: Codable, Sendable {
    public let url: String
    public let json: LoginInput?
}

/// RQRequest 模板的登录示例
public struct DemoLoginRequest: RQRequest {

    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public var requestConfig: RQRequestConfig {
        RQRequestConfig(
            domainKey: .demo,
            path: "/post",
            method: .post,
            requestParameters: LoginInput(username: username, password: password)
        )
    }
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        Task {
            do {
                let response: RQResponse<LoginResponse> = try await RQNetworkManager.shared.request(
                    DemoLoginRequest(username: "demo", password: "123456")
                )
                print("✅ [Demo] 登录请求成功: \(response.data.url)")
            } catch {
                print("❌ [Demo] 登录请求失败: \(error)")
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
