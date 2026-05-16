//
//  WeightSettingView.swift
//  Fiture
//
//  Created by 梅澤遼 on 2025/11/11.
//

import SwiftUI

struct WeightSettingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var weightTargetManager: WeightTargetManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var weightValue: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // ヘッダー
                VStack(spacing: 15) {
                    Image("weight")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    
                    Text("体重")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
                .padding(.top, 20)
                
                // 現在の体重表示
                if let weightEntry = weightTargetManager.weightEntry {
                    VStack(spacing: 10) {
                        Text("現在の体重")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("\(String(format: "%.1f", weightEntry.weight)) kg")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        
                        Text(formatDate(weightEntry.date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                }
                
                // 体重変化グラフ
                WeightChartView(weightEntries: weightTargetManager.weightEntries)
                    .padding(.vertical, 10)
                
                // 体重入力フォーム
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("体重 (kg)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("体重を入力", text: $weightValue)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                        
                        Text("小数第一位まで入力可能")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                
                // エラーメッセージ
                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // 保存ボタン
                Button(action: saveWeight) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text(weightTargetManager.weightEntry == nil ? "体重を記録" : "体重を更新")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(isFormValid ? Color.purple : Color.gray)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .disabled(!isFormValid || isLoading)
            }
            .navigationTitle("体重記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            // 既存の体重記録を取得（選択された日付で）
            if let userId = authManager.currentUser?.id {
                async let fetchEntry = weightTargetManager.fetchWeightEntry(userId: userId, date: weightTargetManager.selectedDate)
                async let fetchEntries = weightTargetManager.fetchWeightEntries(userId: userId, days: 30)
                try? await fetchEntry
                try? await fetchEntries
                // 既存の体重があれば値をセット
                if let weightEntry = weightTargetManager.weightEntry {
                    weightValue = String(format: "%.1f", weightEntry.weight)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !weightValue.isEmpty && Double(weightValue) != nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月dd日"
        dateFormatter.timeZone = TimeZone.current
        return dateFormatter.string(from: date)
    }
    
    private func saveWeight() {
        guard let weight = Double(weightValue),
              let userId = authManager.currentUser?.id else { return }
        
        isLoading = true
        showError = false
        
        Task {
            do {
                let currentDate = weightTargetManager.selectedDate
                
                // UPSERT: 既存レコードがあれば更新、なければ作成
                try await weightTargetManager.createOrUpdateWeightEntry(userId: userId, weight: weight, date: currentDate)
                
                // グラフデータも更新
                try await weightTargetManager.fetchWeightEntries(userId: userId, days: 30)
                
                // 体重データ更新を通知
                NotificationCenter.default.post(name: .init("WeightDataDidUpdate"), object: nil)
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError = true
                    errorMessage = "保存に失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    WeightSettingView()
        .environmentObject(AuthManager.shared)
        .environmentObject(WeightTargetManager())
}

