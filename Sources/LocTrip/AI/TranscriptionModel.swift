import Foundation

public enum TranscriptionModel: String, CaseIterable, Identifiable, Sendable {
    case base = "openai_whisper-base"
    case small = "openai_whisper-small"
    case largeV3Turbo = "openai_whisper-large-v3_turbo"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .base:
            return "Whisper Base (Multilingual)"
        case .small:
            return "Whisper Small (Recommended for ID)"
        case .largeV3Turbo:
            return "Whisper Large-v3-Turbo (Highest Accuracy)"
        }
    }

    public var downloadSizeDescription: String {
        switch self {
        case .base:
            return "~140 MB"
        case .small:
            return "~460 MB"
        case .largeV3Turbo:
            return "~950 MB"
        }
    }

    public var description: String {
        switch self {
        case .base:
            return "Fastest download & inference. Ideal for quick testing and lightweight meetings."
        case .small:
            return "Strong Bahasa Indonesia accuracy and code-switching. Very low latency on M2."
        case .largeV3Turbo:
            return "State-of-the-art multilingual accuracy for technical vocabulary and mixed language."
        }
    }
}
