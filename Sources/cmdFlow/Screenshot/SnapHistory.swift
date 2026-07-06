import Foundation

/// One message in a screenshot conversation.
struct SnapTurn: Codable, Identifiable, Equatable {
    var id = UUID()
    var user: Bool
    var text: String
}

/// A screenshot chat session (the image plus the conversation).
struct SnapSession: Codable, Identifiable, Equatable {
    var id = UUID()
    var createdAt: Date
    var imageBase64: String        // downscaled PNG, used for display and vision
    var turns: [SnapTurn]

    var title: String {
        let firstQuestion = turns.first(where: { $0.user })?.text ?? ""
        return firstQuestion.isEmpty ? "Screenshot" : firstQuestion
    }
}

/// Persists screenshot chat sessions to Application Support.
@MainActor
final class SnapHistory: ObservableObject {
    @Published private(set) var sessions: [SnapSession] = []

    private let maxSessions = 50
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cmdFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("snap-history.json")
        load()
    }

    func upsert(_ session: SnapSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        if sessions.count > maxSessions {
            sessions = Array(sessions.prefix(maxSessions))
        }
        save()
    }

    func delete(_ session: SnapSession) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    func clear() {
        sessions = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([SnapSession].self, from: data)
        else { return }
        sessions = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
