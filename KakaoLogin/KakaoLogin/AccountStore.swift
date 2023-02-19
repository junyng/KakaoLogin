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
    @Published private(set) var currentUser: User? = .default
    
    var isSignedIn: Bool {
        currentUser != nil
    }
    
    private let appKey: String
    private let client: UserApi
    private let keychainWrapper: KeychainWrapper
    
    init(
        appKey: String = ProcessInfo.processInfo.environment["NATIVE_APP_KEY"] ?? "",
        client: UserApi = .shared,
        keychainWrapper: KeychainWrapper = .init()
    ) {
        self.appKey = appKey
        self.client = client
        self.keychainWrapper = keychainWrapper
        KakaoSDK.initSDK(appKey: appKey)
        super.init()
        guard let token = keychainWrapper.retreive(OAuthToken.self, account: Key.oauthToken),
              .now < token.expiredAt else {
            return
        }
        guard let user = keychainWrapper.retreive(KakaoSDKUser.User.self, account: Key.user) else {
            return
        }
        currentUser = .authenticated(user)
    }
    
    @MainActor
    func signIn() async throws {
        let token: OAuthToken = try await withCheckedThrowingContinuation { continuation in
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
        keychainWrapper.set(item: token, account: Key.oauthToken)
        let user = try await fetchUser()
        currentUser = .authenticated(user)
        keychainWrapper.set(item: user, account: Key.user)
    }
    
    @MainActor
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
            keychainWrapper.delete(account: Key.oauthToken)
            keychainWrapper.delete(account: Key.user)
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

private extension AccountStore {
    enum Key {
        static let oauthToken = "OAUTHTOKEN"
        static let user = "USER"
    }
}

struct KeychainWrapper {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private var service: String {
        String(describing: type(of: self))
    }
    
    init(encoder: JSONEncoder = .init(), decoder: JSONDecoder = .init()) {
        self.encoder = encoder
        self.decoder = decoder
    }
    
    func set<T: Codable>(item: T, account: String) {
        guard let encoded = try? encoder.encode(item) else {
            return
        }
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecValueData: encoded,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ] as CFDictionary
        SecItemAdd(query, nil)
    }
    
    func retreive<T: Codable>(_ type: T.Type, account: String) -> T? {
        var item: CFTypeRef?
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true
        ] as CFDictionary
        SecItemCopyMatching(query, &item)
        guard let data = item as? Data else {
            return nil
        }
        guard let decoded = try? decoder.decode(type.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    func delete(account: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service
        ] as CFDictionary
        SecItemDelete(query)
    }
}
