//
//  UserView.swift
//  Fiture
//
//  Created by 梅澤遼 on 2025/10/27.
//

import SwiftUI
import PhotosUI

struct UserView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingEditProfile = false
    @State private var showingThemeSetting = false
    @State private var showingFitnessProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    VStack(spacing: 0) {
                        SettingRow(icon: "person.circle", title: "プロフィール編集", color: .blue) {
                            showingEditProfile = true
                        }
                        
                        SettingRow(icon: "target", title: "目標を変更", color: .red) {
                            showingFitnessProfile = true
                        }
                        
                        SettingRow(icon: "bell.fill", title: "通知設定", color: .orange) {
                        }
                        
                        SettingRow(icon: "lock.fill", title: "プライバシー", color: .green) {
                        }
                        
                        SettingRow(icon: "paintbrush.fill", title: "テーマ", color: .purple) {
                            showingThemeSetting = true
                        }
                        
                        SettingRow(icon: "info.circle", title: "アプリ情報", color: .gray) {
                        }
                        
                        SettingRow(icon: "questionmark.circle", title: "ヘルプ", color: .cyan) {
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal, 20)
                    
                    // ログアウトボタン
                    Button(action: {
                        AuthManager.shared.signOut()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18))
                            Text("ログアウト")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingThemeSetting) {
            ThemeSettingView()
        }
        .sheet(isPresented: $showingFitnessProfile) {
            FitnessProfileGoalSettingView()
                .environmentObject(authManager)
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        
        if title != "ヘルプ" {
            Divider()
                .padding(.leading, 65)
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var userName: String = ""
    @State private var userEmail: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        // プロフィール画像
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else if let profileImageUrl = authManager.currentUser?.profileImageUrl, !profileImageUrl.isEmpty {
                            AsyncImage(url: URL(string: profileImageUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 100))
                                    .foregroundColor(.purple)
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.purple)
                        }
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("写真を変更")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .onChange(of: selectedPhoto) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    await MainActor.run {
                                        selectedImage = image
                                    }
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("名前")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("名前を入力", text: $userName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                
                    VStack(alignment: .leading, spacing: 8) {
                        Text("メールアドレス")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("メールアドレスを入力", text: $userEmail)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
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
                
                Button(action: {
                    saveProfile()
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("保存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .disabled(isLoading)
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // 現在のユーザー情報を初期値として設定
            userName = authManager.currentUser?.name ?? ""
            userEmail = authManager.currentUser?.email ?? ""
        }
    }
    
    private func saveProfile() {
        isLoading = true
        showError = false
        
        Task {
            do {
                guard let userId = authManager.currentUser?.id else {
                    await MainActor.run {
                        isLoading = false
                        showError = true
                        errorMessage = "ユーザーIDが取得できません"
                    }
                    return
                }
                
                var profileImageUrl: String? = authManager.currentUser?.profileImageUrl
                
                // 画像が選択されている場合、ローカルへ保存
                if let selectedImage = selectedImage,
                   let imageData = selectedImage.jpegData(compressionQuality: 0.8) {
                    let fileName = "\(userId.uuidString)_\(UUID().uuidString).jpg"
                    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                    if let documents {
                        let fileURL = documents.appendingPathComponent(fileName)
                        try imageData.write(to: fileURL, options: .atomic)
                        profileImageUrl = fileURL.absoluteString
                    }
                }
                
                let updatedUser = try LocalDataStore.shared.updateUser(
                    userId: userId,
                    name: userName,
                    email: userEmail,
                    profileImageUrl: profileImageUrl
                )
                
                await MainActor.run {
                    authManager.currentUser = updatedUser
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
    UserView()
        .environmentObject(AuthManager.shared)
}
