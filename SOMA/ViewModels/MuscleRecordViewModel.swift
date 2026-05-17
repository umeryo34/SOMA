//
//  MuscleRecordViewModel.swift
//  SOMA
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class MuscleRecordViewModel: ObservableObject {
    @Published var exerciseType: String = ""
    @Published var sets: [TrainingSet] = [TrainingSet()]
    @Published var savedRecords: [TrainingRecord] = []
    @Published var isEditingExistingRecord: Bool = false
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    let muscleType: InteractiveBodyModelView.MuscleType
    private let trainingTargetManager: TrainingTargetManager
    weak var authManager: AuthManager?

    var availableExercises: [String] {
        MuscleExerciseCatalog.exercises(for: muscleType)
    }

    var showWeightInput: Bool {
        muscleType != .abs
    }

    var isFormValid: Bool {
        guard !exerciseType.isEmpty else { return false }
        if muscleType == .abs {
            return sets.contains { !$0.reps.isEmpty }
        }
        return sets.contains { !$0.weight.isEmpty && !$0.reps.isEmpty }
    }

    init(muscleType: InteractiveBodyModelView.MuscleType, trainingTargetManager: TrainingTargetManager) {
        self.muscleType = muscleType
        self.trainingTargetManager = trainingTargetManager
    }

    func setAuthManager(_ authManager: AuthManager) {
        self.authManager = authManager
    }

    func addSet() {
        sets.append(TrainingSet())
    }

    func removeSet(at index: Int) {
        if sets.count > 1 {
            sets.remove(at: index)
        }
    }

    func loadSavedSets(exerciseType: String) async {
        guard let userId = authManager?.currentUser?.id else { return }
        let currentDate = trainingTargetManager.selectedDate

        do {
            if let record = try await trainingTargetManager.fetchTrainingRecord(
                userId: userId,
                date: currentDate,
                exerciseType: exerciseType
            ) {
                let loadedSets = record.sets.map { TrainingSet(weight: $0.weight, reps: $0.reps) }
                sets = loadedSets.isEmpty ? [TrainingSet()] : loadedSets
                isEditingExistingRecord = true
            } else {
                sets = [TrainingSet()]
                isEditingExistingRecord = false
            }
        } catch {
            // 読み込み失敗時はフォームをそのままにする
        }
    }

    func loadSavedRecords(exerciseType: String) async {
        guard let userId = authManager?.currentUser?.id else { return }

        do {
            savedRecords = try await trainingTargetManager.fetchTrainingRecords(
                userId: userId,
                exerciseType: exerciseType
            )
        } catch {
            savedRecords = []
        }
    }

    func applyRecord(_ record: TrainingRecord) {
        trainingTargetManager.selectedDate = record.date
        exerciseType = record.exerciseType
        sets = record.sets.map { TrainingSet(weight: $0.weight, reps: $0.reps) }
        isEditingExistingRecord = true
    }

    @discardableResult
    func saveRecord() async -> Bool {
        guard let userId = authManager?.currentUser?.id else {
            errorMessage = "ユーザー情報が取得できません"
            showError = true
            return false
        }

        let validSets: [TrainingSet]
        if muscleType == .abs {
            validSets = sets.filter { !$0.reps.isEmpty }
        } else {
            validSets = sets.filter { !$0.weight.isEmpty && !$0.reps.isEmpty }
        }

        guard !validSets.isEmpty else {
            errorMessage = "少なくとも1セットの記録が必要です"
            showError = true
            return false
        }

        isLoading = true
        showError = false

        do {
            let currentDate = trainingTargetManager.selectedDate
            let targetSets = Double(validSets.count)

            let existing = try await trainingTargetManager.fetchTrainingTarget(
                userId: userId,
                date: currentDate,
                exerciseType: exerciseType
            )

            if existing != nil {
                try await trainingTargetManager.updateTrainingTarget(
                    userId: userId,
                    exerciseType: exerciseType,
                    target: targetSets,
                    attempt: targetSets,
                    date: currentDate
                )
            } else {
                try await trainingTargetManager.createOrUpdateTrainingTarget(
                    userId: userId,
                    exerciseType: exerciseType,
                    target: targetSets,
                    date: currentDate
                )
                try await trainingTargetManager.updateTrainingTarget(
                    userId: userId,
                    exerciseType: exerciseType,
                    attempt: targetSets,
                    date: currentDate
                )
            }

            let setEntries = validSets.map { TrainingSetEntry(weight: $0.weight, reps: $0.reps) }
            try await trainingTargetManager.upsertTrainingRecord(
                userId: userId,
                date: currentDate,
                exerciseType: exerciseType,
                sets: setEntries
            )

            await loadSavedRecords(exerciseType: exerciseType)
            isLoading = false
            return true
        } catch {
            isLoading = false
            showError = true
            errorMessage = "記録の保存に失敗しました: \(error.localizedDescription)"
            return false
        }
    }
}
