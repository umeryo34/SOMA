//
//  FitnessProfileGoalSettingView.swift
//  Fiture
//
//  設定から開く「目標を変更」用。シート内は単一の NavigationStack に載せ、
//  ウィザード本体は二重ナビを避けるため外部ナビモードで表示する。
//

import SwiftUI

struct FitnessProfileGoalSettingView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TargetSettingView(
                allowsManualDismiss: false,
                usesExternalNavigationStack: true,
                onCompleted: {
                    dismiss()
                }
            )
            .environmentObject(authManager)
            .navigationTitle("目標を変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FitnessProfileGoalSettingView()
        .environmentObject(AuthManager.shared)
}
