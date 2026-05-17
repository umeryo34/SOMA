//
//  TrainingTarget.swift
//  SOMA
//

import Foundation

struct TrainingTarget: Codable, Identifiable {
    let userId: UUID
    let date: Date
    let exerciseType: String
    var target: Double
    var attempt: Double
    var isAchieved: Bool
    let createdAt: Date
    let updatedAt: Date

    var id: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        let dateString = dateFormatter.string(from: date)
        return "\(userId.uuidString)_\(dateString)_\(exerciseType)"
    }

    init(
        userId: UUID,
        date: Date,
        exerciseType: String,
        target: Double,
        attempt: Double,
        isAchieved: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.userId = userId
        self.date = date
        self.exerciseType = exerciseType
        self.target = target
        self.attempt = attempt
        self.isAchieved = isAchieved
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var progressPercentage: Double {
        guard target > 0 else { return 0 }
        return min(attempt / target * 100, 100)
    }
}
