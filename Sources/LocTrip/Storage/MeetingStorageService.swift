import Foundation

public final class MeetingStorageService: @unchecked Sendable {
    public static let shared = MeetingStorageService()

    private let fileManager = FileManager.default
    private let sessionsDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.sessionsDirectory = appSupport.appendingPathComponent("com.loctrip.app/sessions", isDirectory: true)

        try? fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    /// Saves a meeting session to disk
    public func saveSession(_ session: MeetingSession) throws {
        let fileURL = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        let data = try encoder.encode(session)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Loads all saved meeting sessions sorted by date descending (newest first)
    public func loadAllSessions() -> [MeetingSession] {
        guard let files = try? fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        var sessions: [MeetingSession] = []

        for fileURL in files where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let session = try? decoder.decode(MeetingSession.self, from: data) {
                sessions.append(session)
            }
        }

        return sessions.sorted { $0.date > $1.date }
    }

    /// Deletes a session by ID
    public func deleteSession(id: UUID) throws {
        let fileURL = sessionsDirectory.appendingPathComponent("\(id.uuidString).json")
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    /// Searches past sessions by title, app name, or spoken transcript text (case-insensitive)
    public func searchSessions(query: String) -> [MeetingSession] {
        let all = loadAllSessions()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }

        return all.filter { session in
            session.title.localizedCaseInsensitiveContains(trimmed) ||
            session.targetAppName.localizedCaseInsensitiveContains(trimmed) ||
            session.segments.contains(where: { $0.text.localizedCaseInsensitiveContains(trimmed) }) ||
            (session.summary?.executiveSummary.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }
}
