//
//  User.swift
//  SOMA
//

import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let name: String
    let email: String?
    let profileImageUrl: String?
    let createdAt: Date
    let updatedAt: Date
}
