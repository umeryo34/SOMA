//
//  TrainingBodyViewModel.swift
//  SOMA
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class TrainingBodyViewModel: ObservableObject {
    @Published var showingMuscleRecord = false
    @Published var selectedMuscleType: InteractiveBodyModelView.MuscleType?
    @Published var trainingTargets: [TrainingTarget] = []
    @Published var muscleVisualStates: [InteractiveBodyModelView.MuscleType: MuscleVisualState] = [:]
    @Published var isLoading = false

    private let trainingTargetManager = TrainingTargetManager()
    weak var authManager: AuthManager?

    func setAuthManager(_ authManager: AuthManager) {
        self.authManager = authManager
    }

    func fetchTrainingTargets() async {
        guard let userId = authManager?.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await trainingTargetManager.fetchTrainingTargets(userId: userId)
            trainingTargets = trainingTargetManager.trainingTargets
        } catch {
            print("筋トレ目標の取得に失敗: \(error)")
        }
    }

    func selectMuscle(_ muscleType: InteractiveBodyModelView.MuscleType) {
        selectedMuscleType = muscleType
        showingMuscleRecord = true
    }

    func getTrainingTargetManager() -> TrainingTargetManager {
        trainingTargetManager
    }

    private static func distinctExerciseCountByMuscle(records: [TrainingRecord]) -> [InteractiveBodyModelView.MuscleType: Int] {
        var namesByMuscle: [InteractiveBodyModelView.MuscleType: Set<String>] = [:]
        for record in records {
            guard let muscle = MuscleExerciseCatalog.muscleType(forExerciseType: record.exerciseType) else { continue }
            namesByMuscle[muscle, default: []].insert(record.exerciseType)
        }
        return namesByMuscle.mapValues { $0.count }
    }

    func refreshMuscleHighlightStates() async {
        guard let userId = authManager?.currentUser?.id else {
            muscleVisualStates = [:]
            return
        }
        let cal = Calendar.current
        let today = Date()
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today)) else {
            return
        }

        let todayRecords = SomaDataStore.shared.trainingRecords(onDate: today, userId: userId)
        let yesterdayRecords = SomaDataStore.shared.trainingRecords(onDate: yesterday, userId: userId)

        let todayDistinctCount = Self.distinctExerciseCountByMuscle(records: todayRecords)
        let yesterdayDistinctCount = Self.distinctExerciseCountByMuscle(records: yesterdayRecords)

        var next: [InteractiveBodyModelView.MuscleType: MuscleVisualState] = [:]
        for muscle in InteractiveBodyModelView.MuscleType.allCases {
            let todayN = todayDistinctCount[muscle] ?? 0
            let yesterdayN = yesterdayDistinctCount[muscle] ?? 0

            if todayN >= 3 {
                next[muscle] = .trainedToday
            } else if todayN >= 1 {
                next[muscle] = .fatigued
            } else if yesterdayN >= 3 {
                next[muscle] = .fatigued
            } else {
                next[muscle] = .unused
            }
        }
        muscleVisualStates = next
    }
}
