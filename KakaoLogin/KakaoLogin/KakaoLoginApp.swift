//
//  KakaoLoginApp.swift
//  KakaoLogin
//
//  Created by junyng on 2023/02/17.
//

import SwiftUI

@main
struct KakaoLoginApp: App {
    @StateObject private var accountStore = AccountStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView(accountStore: accountStore)
        }
    }
}
