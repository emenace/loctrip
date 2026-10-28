import Foundation

public struct MeetingSummary: Codable, Sendable, Equatable {
    public var executiveSummary: String
    public var keyPoints: [String]
    public var actionItems: [String]

    public init(executiveSummary: String, keyPoints: [String], actionItems: [String]) {
        self.executiveSummary = executiveSummary
        self.keyPoints = keyPoints
        self.actionItems = actionItems
    }
}

public struct MeetingSession: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public let date: Date
    public var durationSeconds: Double
    public var targetAppName: String
    public var languageMode: String
    public var segments: [TranscriptSegment]
    public var summary: MeetingSummary?

    public init(
        id: UUID = UUID(),
        title: String? = nil,
        date: Date = Date(),
        durationSeconds: Double = 0.0,
        targetAppName: String = "Entire System",
        languageMode: String = "auto",
        segments: [TranscriptSegment] = [],
        summary: MeetingSummary? = nil
    ) {
        self.id = id
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        self.title = title ?? "Meeting \(formatter.string(from: date))"
        self.date = date
        self.durationSeconds = durationSeconds
        self.targetAppName = targetAppName
        self.languageMode = languageMode
        self.segments = segments
        self.summary = summary
    }

    public var totalWordCount: Int {
        segments.reduce(0) { total, segment in
            total + segment.text.split(separator: " ").count
        }
    }

    public var formattedDuration: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
