//
//  TrainingTargetManager.swift
//  SOMA
//

import Combine
import Foundation

@MainActor
final class TrainingTargetManager: ObservableObject {
    @Published var trainingTargets: [TrainingTarget] = []
    @Published var trainingTags: [TrainingTag] = []
    @Published var selectedDate: Date = Date()

    func fetchTrainingTargets(userId: UUID, date: Date = Date()) async throws {
        trainingTargets = SomaDataStore.shared.trainingTargets(userId: userId, date: date)
        selectedDate = date
    }

    func fetchTrainingTarget(userId: UUID, date: Date, exerciseType: String) async throws -> TrainingTarget? {
        SomaDataStore.shared.trainingTarget(userId: userId, date: date, exerciseType: exerciseType)
    }

    func createOrUpdateTrainingTarget(userId: UUID, exerciseType: String, target: Double, date: Date = Date()) async throws {
        _ = SomaDataStore.shared.upsertTrainingTarget(userId: userId, date: date, exerciseType: exerciseType, target: target, attempt: nil)
        try await fetchTrainingTargets(userId: userId, date: date)
    }

    func updateTrainingTarget(
        userId: UUID,
        exerciseType: String,
        target: Double? = nil,
        attempt: Double? = nil,
        date: Date? = nil
    ) async throws {
        let targetDate = date ?? selectedDate
        _ = SomaDataStore.shared.upsertTrainingTarget(userId: userId, date: targetDate, exerciseType: exerciseType, target: target, attempt: attempt)
        try await fetchTrainingTargets(userId: userId, date: targetDate)
    }

    func deleteTrainingTarget(userId: UUID, exerciseType: String, date: Date? = nil) async throws {
        let targetDate = date ?? selectedDate
        SomaDataStore.shared.deleteTrainingTarget(userId: userId, date: targetDate, exerciseType: exerciseType)
        trainingTargets.removeAll { $0.exerciseType == exerciseType }
    }

    func fetchTrainingTags(userId: UUID) async throws {
        trainingTags = SomaDataStore.shared.trainingTags(userId: userId)
    }

    func createTrainingTag(userId: UUID, tagName: String) async throws {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = SomaDataStore.shared.createTrainingTag(userId: userId, tagName: trimmed)
        try await fetchTrainingTags(userId: userId)
    }

    func deleteTrainingTag(userId: UUID, tagId: UUID) async throws {
        SomaDataStore.shared.deleteTrainingTag(userId: userId, tagId: tagId)
        trainingTags.removeAll { $0.id == tagId }
    }

    func fetchTrainingRecord(userId: UUID, date: Date, exerciseType: String) async throws -> TrainingRecord? {
        SomaDataStore.shared.trainingRecord(userId: userId, date: date, exerciseType: exerciseType)
    }

    func fetchTrainingRecords(userId: UUID, exerciseType: String) async throws -> [TrainingRecord] {
        SomaDataStore.shared.trainingRecords(userId: userId, exerciseType: exerciseType)
    }

    func upsertTrainingRecord(
        userId: UUID,
        date: Date,
        exerciseType: String,
        sets: [TrainingSetEntry]
    ) async throws {
        _ = SomaDataStore.shared.upsertTrainingRecord(userId: userId, date: date, exerciseType: exerciseType, sets: sets)
    }
}
