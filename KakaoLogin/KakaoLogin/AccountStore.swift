//
//  AccountStore.swift
//  KakaoLogin
//
//  Created by junyng on 2023/02/19.
//

import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser
import Foundation
import os

private extension Logger {
    static let accounts = Logger(subsystem: "KakaoLogin", category: "accounts")
}

final class AccountStore: NSObject, ObservableObject {
    @Published private(set) var currentUser: User?
    
    var isSignedIn: Bool {
        currentUser != nil
    }
    
    private let appKey: String
    private let client: UserApi
    
    init(
        appKey: String = ProcessInfo.processInfo.environment["NATIVE_APP_KEY"] ?? "",
        client: UserApi = .shared
    ) {
        self.appKey = appKey
        self.client = client
        KakaoSDK.initSDK(appKey: appKey)
    }
    
    @MainActor
    func signIn() async throws {
        let _: OAuthToken = try await withCheckedThrowingContinuation { continuation in
            client.loginWithKakaoAccount { token, error in
                if let error = error {
                    continuation.resume(throwing: error)
                }
                guard let token = token else {
                    Logger.accounts.error("SignIn failed: Token not founded")
                    return
                }
                continuation.resume(returning: token)
            }
        }
        let user = try await fetchUser()
        currentUser = .authenticated(user)
    }
    
    func signOut() {
        Task {
            let _: Void = try await withCheckedThrowingContinuation { continuation in
                client.logout { error in
                    if let error = error {
                        Logger.accounts.error("SignOut failed: \(error as NSError)")
                        continuation.resume(throwing: error)
                    }
                    continuation.resume(returning: ())
                }
            }
            currentUser = nil
        }
    }
    
    private func fetchUser() async throws -> KakaoSDKUser.User {
        return try await withCheckedThrowingContinuation { continuation in
            client.me { user, error in
                if let error = error {
                    continuation.resume(throwing: error)
                }
                guard let user = user else {
                    fatalError()
                }
                continuation.resume(returning: user)
            }
        }
    }
}

enum User {
    case `default`
    case authenticated(KakaoSDKUser.User)
}

// TODO: save oauth token
//private let decoder = JSONDecoder()
//private let encoder = JSONEncoder()
//
//private extension AccountStore {
//    enum Key {
//        static let oauthToken = "OAUTHTOKEN"
//    }
//}
