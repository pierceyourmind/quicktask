import Foundation

/// Task is the core value type for a single to-do item.
///
/// It is Codable for JSON serialization/deserialization (used by FileStore)
/// and Identifiable so SwiftUI ForEach can track items without explicit `.id` specifiers.
struct Task: Codable, Identifiable {

    /// Stable unique identifier — generated once at creation, never changes.
    let id: UUID

    /// The user-visible task text. Mutable so the user can edit it (Phase 3).
    var title: String

    /// Whether the task has been completed (tapped checkbox).
    var isCompleted: Bool

    /// Timestamp of when the task was created. Immutable after creation.
    let createdAt: Date

    /// Convenience initializer — creates a new, incomplete task with a generated UUID and current timestamp.
    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
    }
}
