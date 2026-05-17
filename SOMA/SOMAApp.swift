//
//  SOMAApp.swift
//  SOMA
//

import Combine
import SwiftUI

@main
struct SOMAApp: App {
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            TrainingBodyView()
                .environmentObject(authManager)
        }
    }
}
