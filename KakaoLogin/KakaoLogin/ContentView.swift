//
//  ContentView.swift
//  KakaoLogin
//
//  Created by junyng on 2023/02/17.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var accountStore: AccountStore
    
    var body: some View {
        VStack {
            if accountStore.isSignedIn {
                Text("User Authenticated")
                Button("SignOut") {
                    accountStore.signOut()
                }
            } else {
                Button("SignIn") {
                    Task {
                        try await accountStore.signIn()
                    }
                }
            }
        }
    }
}
