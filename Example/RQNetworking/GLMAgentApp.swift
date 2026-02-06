//
//  GLMAgentApp.swift
//  GLMAgent
//
//  Created by edy on 2025/11/24.
//

import SwiftUI

@main
struct GLMAgentApp: App {
    init() {
        AppNetworkConfig.setupNetwork()
        print("app 初始化")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
