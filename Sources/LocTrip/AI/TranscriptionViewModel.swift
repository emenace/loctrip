import Foundation
import Combine
import AppKit

public enum ModelStatus: Equatable {
    case idle
    case downloading(Double)
    case loading
    case ready(TranscriptionModel)
    case error(String)
}

@MainActor
public final class TranscriptionViewModel: ObservableObject {
    public static let shared = TranscriptionViewModel()

    private let service = TranscriptionService.shared

    @Published public var selectedModel: TranscriptionModel = .base
    @Published public var modelStatus: ModelStatus = .idle
    @Published public var isTranscribing: Bool = false
    @Published public var statusMessage: String = "Select model to begin"
    @Published public var segments: [TranscriptSegment] = []
    @Published public var lastInferenceTime: Double = 0.0
    @Published public var copiedToClipboard: Bool = false
    @Published public var errorMessage: String?

    public init() {}

    public var isModelReady: Bool {
        if case .ready = modelStatus {
            return true
        }
        return false
    }

    /// Loads the currently selected model into memory
    public func loadModel() async {
        errorMessage = nil
        modelStatus = .downloading(0.0)
        statusMessage = "Downloading \(selectedModel.displayName)..."

        do {
            try await service.loadModel(model: selectedModel) { [weak self] fraction in
                Task { @MainActor [weak self] in
                    self?.modelStatus = .downloading(fraction)
                    self?.statusMessage = "Downloading: \(Int(fraction * 100))%"
                }
            }

            self.modelStatus = .ready(selectedModel)
            self.statusMessage = "Model Ready: \(selectedModel.displayName)"
        } catch {
            self.modelStatus = .error(error.localizedDescription)
            self.errorMessage = "Failed to load model: \(error.localizedDescription)"
            self.statusMessage = "Model loading failed"
        }
    }

    /// Transcribes a specific WAV file
    public func transcribeAudioFile(at url: URL, languageCode: String) async {
        guard isModelReady else {
            errorMessage = "Please load a Whisper model before transcribing."
            return
        }

        errorMessage = nil
        isTranscribing = true
        statusMessage = "Transcribing audio..."
        let startTime = Date()

        let languageParam: String?
        if languageCode == "auto" {
            languageParam = nil
        } else {
            languageParam = languageCode
        }

        do {
            let resultSegments = try await service.transcribe(
                wavURL: url,
                language: languageParam
            )
            self.segments = resultSegments
            self.lastInferenceTime = Date().timeIntervalSince(startTime)
            self.isTranscribing = false
            self.statusMessage = "Transcription finished in \(String(format: "%.2f", lastInferenceTime))s"
        } catch {
            self.isTranscribing = false
            self.errorMessage = "Transcription failed: \(error.localizedDescription)"
            self.statusMessage = "Transcription error"
        }
    }

    /// Copies full transcript text with timestamps to system clipboard
    public func copyTranscriptToClipboard() {
        guard !segments.isEmpty else { return }

        let formatted = segments.map { "\($0.timestampFormatted) \($0.text)" }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(formatted, forType: .string)

        self.copiedToClipboard = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.copiedToClipboard = false
        }
    }

    /// Appends real-time streaming segments, avoiding duplicate adjacent lines
    public func appendLiveSegment(_ segment: TranscriptSegment) {
        if let last = segments.last, last.text == segment.text {
            return
        }
        self.segments.append(segment)
    }

    /// Clears the active transcript list
    public func clearTranscript() {
        self.segments.removeAll()
    }
}

