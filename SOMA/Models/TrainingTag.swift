//
//  TrainingTag.swift
//  SOMA
//

import Foundation

struct TrainingTag: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let tagName: String
    let createdAt: Date
    let updatedAt: Date

    init(id: UUID, userId: UUID, tagName: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.userId = userId
        self.tagName = tagName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
