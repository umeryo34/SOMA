//
//  TrainingTagManagementView.swift
//  Fiture
//
//  Created by 梅澤遼 on 2026/03/23.
//

import SwiftUI

struct TrainingTagManagementView: View {
    @ObservedObject var trainingTargetManager: TrainingTargetManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var newTagName: String = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("新しいタグ名", text: $newTagName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("追加") {
                        Task { await addTag() }
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding()
                
                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                
                List {
                    ForEach(trainingTargetManager.trainingTags) { tag in
                        Text(tag.tagName)
                    }
                    .onDelete(perform: deleteTags)
                }
                .listStyle(.plain)
            }
            .navigationTitle("タグ管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadTags()
            }
        }
    }
    
    private func loadTags() async {
        guard let userId = authManager.currentUser?.id else { return }
        do {
            try await trainingTargetManager.fetchTrainingTags(userId: userId)
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = "タグの読み込みに失敗しました"
            }
        }
    }
    
    private func addTag() async {
        guard let userId = authManager.currentUser?.id else { return }
        isLoading = true
        showError = false
        defer { isLoading = false }
        do {
            try await trainingTargetManager.createTrainingTag(userId: userId, tagName: newTagName)
            await MainActor.run { newTagName = "" }
        } catch {
            await MainActor.run {
                showError = true
                if error.localizedDescription.contains("duplicate") || error.localizedDescription.contains("unique") {
                    errorMessage = "同じ名前のタグが既にあります"
                } else {
                    errorMessage = "追加に失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteTags(at offsets: IndexSet) {
        guard let userId = authManager.currentUser?.id else { return }
        let tags = offsets.compactMap { trainingTargetManager.trainingTags.indices.contains($0) ? trainingTargetManager.trainingTags[$0] : nil }
        for tag in tags {
            Task {
                do {
                    try await trainingTargetManager.deleteTrainingTag(userId: userId, tagId: tag.id)
                } catch {
                    await MainActor.run {
                        showError = true
                        errorMessage = "削除に失敗しました"
                    }
                }
            }
        }
    }
}

#Preview {
    TrainingTagManagementView(trainingTargetManager: TrainingTargetManager())
        .environmentObject(AuthManager.shared)
}
