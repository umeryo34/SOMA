//
//  AuthManager.swift
//  SOMA
//

import Combine
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true

    static let shared = AuthManager()

    private init() {
        checkAuthStatus()
    }

    func checkAuthStatus() {
        Task {
            isLoading = true
            await fetchCurrentUser()
            isLoading = false
        }
    }

    func fetchCurrentUser() async {
        let user = SomaDataStore.shared.currentUser() ?? SomaDataStore.shared.ensureGuestSession()
        currentUser = user
        isAuthenticated = true
    }

    func signOut() {
        SomaDataStore.shared.signOut()
        Task {
            let guest = SomaDataStore.shared.ensureGuestSession()
            currentUser = guest
            isAuthenticated = true
        }
    }
}
