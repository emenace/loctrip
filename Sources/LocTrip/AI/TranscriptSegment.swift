import Foundation

public struct TranscriptSegment: Identifiable, Sendable {
    public let id: UUID
    public let start: Float
    public let end: Float
    public let text: String
    public let language: String?

    public init(id: UUID = UUID(), start: Float, end: Float, text: String, language: String? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
        self.language = language
    }

    public var timestampFormatted: String {
        let startMinutes = Int(start) / 60
        let startSeconds = Int(start) % 60
        let endMinutes = Int(end) / 60
        let endSeconds = Int(end) % 60
        return String(format: "[%02d:%02d - %02d:%02d]", startMinutes, startSeconds, endMinutes, endSeconds)
    }
}
