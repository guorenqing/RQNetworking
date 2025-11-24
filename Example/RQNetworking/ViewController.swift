//
//  ViewController.swift
//  RQNetworking
//
//  Created by 郭仁庆 on 11/19/2025.
//  Copyright (c) 2025 郭仁庆. All rights reserved.
//

import UIKit

/// 用户信息数据模型
public struct User: Codable {
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
public struct UserListResponse: Codable {
    public let users: [User]
    public let total: Int
    public let page: Int
    public let pageSize: Int
}

/// 登录请求参数模型
public struct LoginRequest: Codable {
    public let username: String
    public let password: String
    
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// 登录响应模型
public struct LoginResponse: Codable {
    public let user: User
    public let token: String
    public let expiresIn: TimeInterval
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

