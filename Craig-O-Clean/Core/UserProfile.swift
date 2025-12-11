import Foundation

struct UserProfile: Codable, Equatable {
    var userId: String
    var displayName: String?
    var email: String?

    var createdAt: Date
    var lastSignInAt: Date
}

