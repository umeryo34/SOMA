//
//  TrainingRecord.swift
//  SOMA
//

import Foundation

struct TrainingRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let date: Date
    let exerciseType: String
    var sets: [TrainingSetEntry]
    let createdAt: Date
    var updatedAt: Date
}

struct TrainingSetEntry: Codable, Equatable {
    var weight: String
    var reps: String
}
