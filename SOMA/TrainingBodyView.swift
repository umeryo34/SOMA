//
//  TrainingBodyView.swift
//  Fiture
//
//  Created by 梅澤遼 on 2025/02/02.
//

import SwiftUI
import SceneKit

struct TrainingBodyView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = TrainingBodyViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            InteractiveBodyModelView(
                muscleStates: viewModel.muscleVisualStates,
                onMuscleTapped: { muscleType in
                    viewModel.selectMuscle(muscleType)
                }
            )
            .padding(.horizontal, 8)
            .frame(minHeight: 420)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            viewModel.setAuthManager(authManager)
            await viewModel.refreshMuscleHighlightStates()
        }
        .onChange(of: viewModel.showingMuscleRecord) { _, isOpen in
            if !isOpen {
                Task { await viewModel.refreshMuscleHighlightStates() }
            }
        }
        .sheet(isPresented: $viewModel.showingMuscleRecord) {
            if let muscleType = viewModel.selectedMuscleType {
                MuscleRecordView(
                    muscleType: muscleType,
                    trainingTargetManager: viewModel.getTrainingTargetManager()
                )
                .environmentObject(authManager)
            }
        }
    }
}

struct HumanModelHeaderView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))

            if let scene = buildHumanScene() {
                SceneView(
                    scene: scene,
                    pointOfView: scene.rootNode.childNode(withName: "human_camera", recursively: false),
                    options: [.autoenablesDefaultLighting]
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
            } else {
                VStack(spacing: 8) {
                    Image("training")
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 28)
                    Text("\(HumanBodyUSDResource.primaryFilename) を読み込めません")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

struct HumanMuscleSceneView: View {
    var body: some View {
        ZStack {
            if let scene = buildHumanScene() {
                SceneView(
                    scene: scene,
                    pointOfView: scene.rootNode.childNode(withName: "human_camera", recursively: false),
                    options: [.autoenablesDefaultLighting]
                )
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(0)
            } else {
                VStack(spacing: 8) {
                    Image("training")
                        .resizable()
                        .scaledToFit()
                        .padding(40)
                    Text("\(HumanBodyUSDResource.primaryFilename) 読み込み失敗")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

// 体の模型ビュー（USDZ メッシュをタップして部位を選択）
struct InteractiveBodyModelView: View {
    @State private var bodyOrbitYaw: Double = HumanBodyUSDSceneKeys.defaultOrbitYawRadians
    let muscleStates: [MuscleType: MuscleVisualState]
    let onMuscleTapped: (MuscleType) -> Void
    
    enum MuscleType: String, CaseIterable {
        case chest = "胸"
        case biceps = "二頭"
        case shoulders = "肩"
        case arms = "腕"
        case triceps = "三頭"
        case back = "背中"
        case thighs = "太もも"
        case lowerLegs = "ふくらはぎ"
        case glutes = "尻"
        case abs = "腹"
    }
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 14) {
                legendChip(color: .red, text: "疲労度：高")
                legendChip(color: .yellow.opacity(0.85), text: "疲労度：中")
                legendChip(color: .gray.opacity(0.55), text: "なし")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 20)

            Text("横にドラッグでモデルを回転・タップで部位")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            
            GeometryReader { _ in
                ZStack {
                    Color(.systemGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    MuscleHitTestSceneView(
                        orbitYaw: $bodyOrbitYaw,
                        muscleStates: muscleStates,
                        onMuscleTapped: onMuscleTapped
                    )
                }
            }
        }
    }
    
    private func legendChip(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }
}

// 体の模型ビュー（よりリアルなシルエット - 前面）
struct BodyModelView: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let centerX = width / 2
            let scale = min(width / 200, height / 400)
            
            ZStack {
                // 背景
                Color(.systemGray6)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // 体のシルエット（Pathを使用）
                BodySilhouette(centerX: centerX, height: height, scale: scale)
                    .fill(Color.blue.opacity(0.2))
                    .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                
                // 筋肉部位のマーカー（オプション）
                MuscleMarkers(centerX: centerX, height: height, scale: scale)
            }
        }
    }
}

// 体のシルエット（Pathで描画）
struct BodySilhouette: Shape {
    let centerX: CGFloat
    let height: CGFloat
    let scale: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let h = height
        
        // 頭（楕円）
        let headWidth = 50 * scale
        let headHeight = 60 * scale
        path.addEllipse(in: CGRect(
            x: centerX - headWidth / 2,
            y: h * 0.05,
            width: headWidth,
            height: headHeight
        ))
        
        // 首
        let neckWidth = 25 * scale
        let neckHeight = 30 * scale
        path.addRect(CGRect(
            x: centerX - neckWidth / 2,
            y: h * 0.12,
            width: neckWidth,
            height: neckHeight
        ))
        
        // 肩と胴体（台形）
        let shoulderWidth = 120 * scale
        let waistWidth = 80 * scale
        let torsoHeight = 180 * scale
        
        path.move(to: CGPoint(x: centerX - shoulderWidth / 2, y: h * 0.18))
        path.addLine(to: CGPoint(x: centerX + shoulderWidth / 2, y: h * 0.18))
        path.addLine(to: CGPoint(x: centerX + waistWidth / 2, y: h * 0.18 + torsoHeight))
        path.addLine(to: CGPoint(x: centerX - waistWidth / 2, y: h * 0.18 + torsoHeight))
        path.closeSubpath()
        
        // 左腕（上腕）
        let upperArmWidth = 35 * scale
        let upperArmHeight = 80 * scale
        path.addRect(CGRect(
            x: centerX - shoulderWidth / 2 - upperArmWidth * 0.7,
            y: h * 0.2,
            width: upperArmWidth,
            height: upperArmHeight
        ))
        
        // 左腕（前腕）
        let forearmWidth = 30 * scale
        let forearmHeight = 70 * scale
        path.addRect(CGRect(
            x: centerX - shoulderWidth / 2 - forearmWidth * 0.8,
            y: h * 0.2 + upperArmHeight,
            width: forearmWidth,
            height: forearmHeight
        ))
        
        // 右腕（上腕）
        path.addRect(CGRect(
            x: centerX + shoulderWidth / 2 - upperArmWidth * 0.3,
            y: h * 0.2,
            width: upperArmWidth,
            height: upperArmHeight
        ))
        
        // 右腕（前腕）
        path.addRect(CGRect(
            x: centerX + shoulderWidth / 2 - forearmWidth * 0.2,
            y: h * 0.2 + upperArmHeight,
            width: forearmWidth,
            height: forearmHeight
        ))
        
        // 左足（太もも）
        let thighWidth = 40 * scale
        let thighHeight = 100 * scale
        path.addRect(CGRect(
            x: centerX - waistWidth / 2 - thighWidth * 0.2,
            y: h * 0.18 + torsoHeight,
            width: thighWidth,
            height: thighHeight
        ))
        
        // 左足（すね）
        let shinWidth = 30 * scale
        let shinHeight = 90 * scale
        path.addRect(CGRect(
            x: centerX - waistWidth / 2 - shinWidth * 0.2,
            y: h * 0.18 + torsoHeight + thighHeight,
            width: shinWidth,
            height: shinHeight
        ))
        
        // 右足（太もも）
        path.addRect(CGRect(
            x: centerX + waistWidth / 2 - thighWidth * 0.8,
            y: h * 0.18 + torsoHeight,
            width: thighWidth,
            height: thighHeight
        ))
        
        // 右足（すね）
        path.addRect(CGRect(
            x: centerX + waistWidth / 2 - shinWidth * 0.8,
            y: h * 0.18 + torsoHeight + thighHeight,
            width: shinWidth,
            height: shinHeight
        ))
        
        return path
    }
}

// 背面シルエット
struct BodySilhouetteBack: Shape {
    let centerX: CGFloat
    let height: CGFloat
    let scale: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let h = height
        
        // 頭（背面）
        let headWidth = 50 * scale
        let headHeight = 60 * scale
        path.addEllipse(in: CGRect(
            x: centerX - headWidth / 2,
            y: h * 0.05,
            width: headWidth,
            height: headHeight
        ))
        
        // 首
        let neckWidth = 25 * scale
        let neckHeight = 30 * scale
        path.addRect(CGRect(
            x: centerX - neckWidth / 2,
            y: h * 0.12,
            width: neckWidth,
            height: neckHeight
        ))
        
        // 肩と胴体（背面）
        let shoulderWidth = 120 * scale
        let waistWidth = 80 * scale
        let torsoHeight = 180 * scale
        
        path.move(to: CGPoint(x: centerX - shoulderWidth / 2, y: h * 0.18))
        path.addLine(to: CGPoint(x: centerX + shoulderWidth / 2, y: h * 0.18))
        path.addLine(to: CGPoint(x: centerX + waistWidth / 2, y: h * 0.18 + torsoHeight))
        path.addLine(to: CGPoint(x: centerX - waistWidth / 2, y: h * 0.18 + torsoHeight))
        path.closeSubpath()
        
        // 腕（背面）
        let upperArmWidth = 35 * scale
        let upperArmHeight = 80 * scale
        path.addRect(CGRect(
            x: centerX - shoulderWidth / 2 - upperArmWidth * 0.7,
            y: h * 0.2,
            width: upperArmWidth,
            height: upperArmHeight
        ))
        
        let forearmWidth = 30 * scale
        let forearmHeight = 70 * scale
        path.addRect(CGRect(
            x: centerX - shoulderWidth / 2 - forearmWidth * 0.8,
            y: h * 0.2 + upperArmHeight,
            width: forearmWidth,
            height: forearmHeight
        ))
        
        path.addRect(CGRect(
            x: centerX + shoulderWidth / 2 - upperArmWidth * 0.3,
            y: h * 0.2,
            width: upperArmWidth,
            height: upperArmHeight
        ))
        
        path.addRect(CGRect(
            x: centerX + shoulderWidth / 2 - forearmWidth * 0.2,
            y: h * 0.2 + upperArmHeight,
            width: forearmWidth,
            height: forearmHeight
        ))
        
        // 足（背面）
        let thighWidth = 40 * scale
        let thighHeight = 100 * scale
        path.addRect(CGRect(
            x: centerX - waistWidth / 2 - thighWidth * 0.2,
            y: h * 0.18 + torsoHeight,
            width: thighWidth,
            height: thighHeight
        ))
        
        let shinWidth = 30 * scale
        let shinHeight = 90 * scale
        path.addRect(CGRect(
            x: centerX - waistWidth / 2 - shinWidth * 0.2,
            y: h * 0.18 + torsoHeight + thighHeight,
            width: shinWidth,
            height: shinHeight
        ))
        
        path.addRect(CGRect(
            x: centerX + waistWidth / 2 - thighWidth * 0.8,
            y: h * 0.18 + torsoHeight,
            width: thighWidth,
            height: thighHeight
        ))
        
        path.addRect(CGRect(
            x: centerX + waistWidth / 2 - shinWidth * 0.8,
            y: h * 0.18 + torsoHeight + thighHeight,
            width: shinWidth,
            height: shinHeight
        ))
        
        return path
    }
}

// 前面の筋肉マーカー
struct MuscleMarkersFront: View {
    let centerX: CGFloat
    let height: CGFloat
    let scale: CGFloat
    
    var body: some View {
        ZStack {
            // 胸筋
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: 30 * scale, height: 30 * scale)
                .position(x: centerX, y: height * 0.25)
            
            // 腹筋
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.orange.opacity(0.3))
                .frame(width: 40 * scale, height: 50 * scale)
                .position(x: centerX, y: height * 0.35)
            
            // 上腕二頭筋（左）
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 20 * scale, height: 20 * scale)
                .position(x: centerX - 60 * scale, y: height * 0.3)
            
            // 上腕二頭筋（右）
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 20 * scale, height: 20 * scale)
                .position(x: centerX + 60 * scale, y: height * 0.3)
            
            // 太もも（左）
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.purple.opacity(0.3))
                .frame(width: 25 * scale, height: 40 * scale)
                .position(x: centerX - 20 * scale, y: height * 0.65)
            
            // 太もも（右）
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.purple.opacity(0.3))
                .frame(width: 25 * scale, height: 40 * scale)
                .position(x: centerX + 20 * scale, y: height * 0.65)
        }
    }
}

// 背面の筋肉マーカー
struct MuscleMarkersBack: View {
    let centerX: CGFloat
    let height: CGFloat
    let scale: CGFloat
    
    var body: some View {
        ZStack {
            // 広背筋
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.cyan.opacity(0.3))
                .frame(width: 60 * scale, height: 80 * scale)
                .position(x: centerX, y: height * 0.3)
            
            // 僧帽筋
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.yellow.opacity(0.3))
                .frame(width: 50 * scale, height: 30 * scale)
                .position(x: centerX, y: height * 0.22)
            
            // ハムストリング（左）
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.pink.opacity(0.3))
                .frame(width: 25 * scale, height: 50 * scale)
                .position(x: centerX - 20 * scale, y: height * 0.65)
            
            // ハムストリング（右）
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.pink.opacity(0.3))
                .frame(width: 25 * scale, height: 50 * scale)
                .position(x: centerX + 20 * scale, y: height * 0.65)
        }
    }
}

// 筋肉部位のマーカー（タップ可能にする場合）
struct MuscleMarkers: View {
    let centerX: CGFloat
    let height: CGFloat
    let scale: CGFloat
    
    var body: some View {
        MuscleMarkersFront(centerX: centerX, height: height, scale: scale)
    }
}

// セット情報
struct TrainingSet: Identifiable {
    let id = UUID()
    var weight: String = ""
    var reps: String = ""
}

// 部位別筋トレ記録画面
struct MuscleRecordView: View {
    let muscleType: InteractiveBodyModelView.MuscleType
    @ObservedObject var trainingTargetManager: TrainingTargetManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: MuscleRecordViewModel
    @State private var saveExerciseAsTag = false
    @State private var showingTagManagement = false
    
    init(muscleType: InteractiveBodyModelView.MuscleType, trainingTargetManager: TrainingTargetManager) {
        self.muscleType = muscleType
        self._trainingTargetManager = ObservedObject(wrappedValue: trainingTargetManager)
        _viewModel = StateObject(wrappedValue: MuscleRecordViewModel(muscleType: muscleType, trainingTargetManager: trainingTargetManager))
    }

    private var recordDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }

    private func recordDateString(_ date: Date) -> String {
        recordDateFormatter.string(from: date)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                VStack(spacing: 15) {
                    HumanModelHeaderView()
                    
                    Text("\(muscleType.rawValue)の筋トレ記録")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 種目名（タグ・入力・定番）
                        VStack(alignment: .leading, spacing: 12) {
                            Text("種目名")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if !trainingTargetManager.trainingTags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(trainingTargetManager.trainingTags) { tag in
                                            Button {
                                                let selectedExercise = tag.tagName
                                                viewModel.exerciseType = selectedExercise
                                                Task {
                                                    await viewModel.loadSavedSets(exerciseType: selectedExercise)
                                                    await viewModel.loadSavedRecords(exerciseType: selectedExercise)
                                                }
                                            } label: {
                                                Text(tag.tagName)
                                                    .font(.subheadline)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(Color(.systemGray5))
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            
                            TextField("種目名を入力", text: $viewModel.exerciseType)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Menu {
                                ForEach(viewModel.availableExercises, id: \.self) { exercise in
                                    Button(exercise) {
                                        viewModel.exerciseType = exercise
                                        Task {
                                            await viewModel.loadSavedSets(exerciseType: exercise)
                                            await viewModel.loadSavedRecords(exerciseType: exercise)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("定番種目から選ぶ")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            Toggle("この種目をタグとして保存", isOn: $saveExerciseAsTag)
                            
                            Button {
                                showingTagManagement = true
                            } label: {
                                HStack {
                                    Image(systemName: "tag")
                                    Text("タグ管理")
                                }
                                .font(.subheadline)
                                .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        
                        // 日付セレクタ（既存レコードの有無を切り替える）
                        DateSelectorBar(selectedDate: $trainingTargetManager.selectedDate) { _ in
                            let exercise = viewModel.exerciseType
                            let trimmed = exercise.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            Task {
                                await viewModel.loadSavedSets(exerciseType: trimmed)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 過去の記録（行ごとに「変更」）
                        if !viewModel.savedRecords.isEmpty,
                           !viewModel.exerciseType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("過去の記録")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(viewModel.savedRecords.prefix(10)) { record in
                                        HStack {
                                            Text(recordDateString(record.date))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            Spacer()
                                            
                                            Button("変更") {
                                                viewModel.applyRecord(record)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.red)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // セット一覧
                        VStack(alignment: .leading, spacing: 12) {
                            Text("セット")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                            
                            ForEach(viewModel.sets.indices, id: \.self) { index in
                                SetRowView(
                                    setNumber: index + 1,
                                    set: $viewModel.sets[index],
                                    onDelete: {
                                        viewModel.removeSet(at: index)
                                    },
                                    showWeight: viewModel.showWeightInput
                                )
                                .padding(.horizontal, 20)
                            }
                            
                            // セットを追加ボタン
                            Button(action: {
                                viewModel.addSet()
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18))
                                    Text("セットを追加")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red, lineWidth: 1.5)
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 10)
                }
                
                // エラーメッセージ
                if viewModel.showError {
                    Text(viewModel.errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                }
                
                // 保存ボタン
                Button(action: {
                    Task {
                        let ok = await viewModel.saveRecord()
                        if ok {
                            if saveExerciseAsTag,
                               let userId = authManager.currentUser?.id,
                               !viewModel.exerciseType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                try? await trainingTargetManager.createTrainingTag(
                                    userId: userId,
                                    tagName: viewModel.exerciseType
                                )
                            }
                            dismiss()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text(viewModel.isEditingExistingRecord ? "変更を保存" : "記録を保存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(viewModel.isFormValid ? Color.red : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .disabled(!viewModel.isFormValid || viewModel.isLoading)
            }
            .navigationTitle("筋トレ記録")
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
        .task(id: authManager.currentUser?.id) {
            guard let userId = authManager.currentUser?.id else { return }
            try? await trainingTargetManager.fetchTrainingTags(userId: userId)
        }
        .sheet(isPresented: $showingTagManagement) {
            TrainingTagManagementView(trainingTargetManager: trainingTargetManager)
                .environmentObject(authManager)
        }
        .onAppear {
            viewModel.setAuthManager(authManager)
        }
    }
}

// セット行ビュー
struct SetRowView: View {
    let setNumber: Int
    @Binding var set: TrainingSet
    let onDelete: () -> Void
    let showWeight: Bool
    
    init(setNumber: Int, set: Binding<TrainingSet>, onDelete: @escaping () -> Void, showWeight: Bool = true) {
        self.setNumber = setNumber
        self._set = set
        self.onDelete = onDelete
        self.showWeight = showWeight
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // セット番号
            Text("\(setNumber)")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 40)
            
            // 重量入力（腹の場合は非表示）
            if showWeight {
                VStack(alignment: .leading, spacing: 4) {
                    Text("kg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("0", text: $set.weight)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                }
            }
            
            // 回数入力
            VStack(alignment: .leading, spacing: 4) {
                Text("回数")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("0", text: $set.reps)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(width: 80)
            }
            
            Spacer()
            
            // 削除ボタン
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.system(size: 18))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    TrainingBodyView()
        .environmentObject(AuthManager.shared)
}
