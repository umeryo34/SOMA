//
//  SomaDataStore.swift
//  SOMA
//
//  筋トレ用のローカル永続化（Fiture の LocalDataStore から分割）
//

import Foundation

final class SomaDataStore {
    static let shared = SomaDataStore()

    private let stateKey = "soma_local_state_v1"
    private let sessionUserIdKey = "soma_session_user_id"
    private let guestUserIdKey = "soma_guest_user_id"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    // MARK: - Session

    func currentUser() -> User? {
        guard let session = UserDefaults.standard.string(forKey: sessionUserIdKey),
              let userId = UUID(uuidString: session) else {
            return nil
        }
        return loadState().users.first(where: { $0.id == userId })?.toDomain()
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: sessionUserIdKey)
    }

    func ensureGuestSession() -> User {
        var state = loadState()
        let guestId: UUID
        if let raw = UserDefaults.standard.string(forKey: guestUserIdKey),
           let parsed = UUID(uuidString: raw) {
            guestId = parsed
        } else {
            guestId = UUID()
            UserDefaults.standard.set(guestId.uuidString, forKey: guestUserIdKey)
        }

        let now = Date()
        if let index = state.users.firstIndex(where: { $0.id == guestId }) {
            state.users[index].updatedAt = now
            state.users[index].name = "ゲストユーザー"
        } else {
            state.users.append(
                LocalUser(
                    id: guestId,
                    name: "ゲストユーザー",
                    email: "guest@local",
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        saveState(state)
        UserDefaults.standard.set(guestId.uuidString, forKey: sessionUserIdKey)
        return state.users.first(where: { $0.id == guestId })!.toDomain()
    }

    // MARK: - Training Targets

    func trainingTargets(userId: UUID, date: Date) -> [TrainingTarget] {
        let targetDate = startOfDay(date)
        return loadState().trainingTargets
            .filter { $0.userId == userId && Calendar.current.isDate($0.date, inSameDayAs: targetDate) }
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.toDomain() }
    }

    func trainingTarget(userId: UUID, date: Date, exerciseType: String) -> TrainingTarget? {
        let targetDate = startOfDay(date)
        return loadState().trainingTargets
            .first { $0.userId == userId && Calendar.current.isDate($0.date, inSameDayAs: targetDate) && $0.exerciseType == exerciseType }?
            .toDomain()
    }

    func upsertTrainingTarget(
        userId: UUID,
        date: Date,
        exerciseType: String,
        target: Double? = nil,
        attempt: Double? = nil
    ) -> TrainingTarget {
        var state = loadState()
        let targetDate = startOfDay(date)
        let now = Date()
        if let index = state.trainingTargets.firstIndex(where: {
            $0.userId == userId && Calendar.current.isDate($0.date, inSameDayAs: targetDate) && $0.exerciseType == exerciseType
        }) {
            if let target { state.trainingTargets[index].target = target }
            if let attempt { state.trainingTargets[index].attempt = attempt }
            state.trainingTargets[index].isAchieved = state.trainingTargets[index].attempt >= state.trainingTargets[index].target
            state.trainingTargets[index].updatedAt = now
            let value = state.trainingTargets[index]
            saveState(state)
            return value.toDomain()
        }

        let value = LocalTrainingTarget(
            userId: userId,
            date: targetDate,
            exerciseType: exerciseType,
            target: target ?? 0,
            attempt: attempt ?? 0,
            isAchieved: (attempt ?? 0) >= (target ?? 0),
            createdAt: now,
            updatedAt: now
        )
        state.trainingTargets.append(value)
        saveState(state)
        return value.toDomain()
    }

    func deleteTrainingTarget(userId: UUID, date: Date, exerciseType: String) {
        var state = loadState()
        let targetDate = startOfDay(date)
        state.trainingTargets.removeAll {
            $0.userId == userId && Calendar.current.isDate($0.date, inSameDayAs: targetDate) && $0.exerciseType == exerciseType
        }
        saveState(state)
    }

    // MARK: - Training Tags

    func trainingTags(userId: UUID) -> [TrainingTag] {
        loadState().trainingTags
            .filter { $0.userId == userId }
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.toDomain() }
    }

    func createTrainingTag(userId: UUID, tagName: String) -> TrainingTag {
        var state = loadState()
        let now = Date()
        let value = LocalTrainingTag(id: UUID(), userId: userId, tagName: tagName, createdAt: now, updatedAt: now)
        state.trainingTags.append(value)
        saveState(state)
        return value.toDomain()
    }

    func deleteTrainingTag(userId: UUID, tagId: UUID) {
        var state = loadState()
        state.trainingTags.removeAll { $0.userId == userId && $0.id == tagId }
        saveState(state)
    }

    // MARK: - Training Records

    func trainingRecord(userId: UUID, date: Date, exerciseType: String) -> TrainingRecord? {
        let targetDate = startOfDay(date)
        return loadState().trainingRecords
            .first { $0.userId == userId && Calendar.current.isDate($0.date, inSameDayAs: targetDate) && $0.exerciseType == exerciseType }?
            .toDomain()
    }

    func trainingRecords(userId: UUID, exerciseType: String) -> [TrainingRecord] {
        loadState().trainingRecords
            .filter { $0.userId == userId && $0.exerciseType == exerciseType }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date > rhs.date }
                return lhs.updatedAt > rhs.updatedAt
            }
            .map { $0.toDomain() }
    }

    func trainingRecords(onDate date: Date, userId: UUID) -> [TrainingRecord] {
        let targetDate = startOfDay(date)
        return loadState().trainingRecords
            .filter { $0.userId == userId && Calendar.current.isDate($0.date, inSameDayAs: targetDate) }
            .map { $0.toDomain() }
    }

    func upsertTrainingRecord(
        userId: UUID,
        date: Date,
        exerciseType: String,
        sets: [TrainingSetEntry]
    ) -> TrainingRecord {
        var state = loadState()
        let targetDate = startOfDay(date)
        let now = Date()
        let localSets = sets.map { LocalTrainingSet(weight: $0.weight, reps: $0.reps) }

        if let index = state.trainingRecords.firstIndex(where: {
            $0.userId == userId &&
            Calendar.current.isDate($0.date, inSameDayAs: targetDate) &&
            $0.exerciseType == exerciseType
        }) {
            state.trainingRecords[index].sets = localSets
            state.trainingRecords[index].updatedAt = now
            let value = state.trainingRecords[index]
            saveState(state)
            return value.toDomain()
        }

        let newRecord = LocalTrainingRecord(
            id: UUID(),
            userId: userId,
            date: targetDate,
            exerciseType: exerciseType,
            sets: localSets,
            createdAt: now,
            updatedAt: now
        )
        state.trainingRecords.append(newRecord)
        saveState(state)
        return newRecord.toDomain()
    }

    // MARK: - Private

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func loadState() -> LocalAppState {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let decoded = try? decoder.decode(LocalAppState.self, from: data) else {
            return LocalAppState()
        }
        return decoded
    }

    private func saveState(_ state: LocalAppState) {
        guard let data = try? encoder.encode(state) else { return }
        UserDefaults.standard.set(data, forKey: stateKey)
    }
}

// MARK: - Local persistence types

private struct LocalAppState: Codable {
    var users: [LocalUser] = []
    var trainingTargets: [LocalTrainingTarget] = []
    var trainingTags: [LocalTrainingTag] = []
    var trainingRecords: [LocalTrainingRecord] = []
}

private struct LocalUser: Codable {
    let id: UUID
    var name: String
    var email: String
    let createdAt: Date
    var updatedAt: Date

    func toDomain() -> User {
        User(id: id, name: name, email: email, profileImageUrl: nil, createdAt: createdAt, updatedAt: updatedAt)
    }
}

private struct LocalTrainingTarget: Codable {
    let userId: UUID
    let date: Date
    let exerciseType: String
    var target: Double
    var attempt: Double
    var isAchieved: Bool
    let createdAt: Date
    var updatedAt: Date

    func toDomain() -> TrainingTarget {
        TrainingTarget(
            userId: userId,
            date: date,
            exerciseType: exerciseType,
            target: target,
            attempt: attempt,
            isAchieved: isAchieved,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct LocalTrainingRecord: Codable {
    let id: UUID
    let userId: UUID
    let date: Date
    let exerciseType: String
    var sets: [LocalTrainingSet]
    let createdAt: Date
    var updatedAt: Date

    func toDomain() -> TrainingRecord {
        TrainingRecord(
            id: id,
            userId: userId,
            date: date,
            exerciseType: exerciseType,
            sets: sets.map { $0.toDomain() },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct LocalTrainingSet: Codable {
    var weight: String
    var reps: String

    func toDomain() -> TrainingSetEntry {
        TrainingSetEntry(weight: weight, reps: reps)
    }
}

private struct LocalTrainingTag: Codable {
    let id: UUID
    let userId: UUID
    let tagName: String
    let createdAt: Date
    var updatedAt: Date

    func toDomain() -> TrainingTag {
        TrainingTag(id: id, userId: userId, tagName: tagName, createdAt: createdAt, updatedAt: updatedAt)
    }
}
