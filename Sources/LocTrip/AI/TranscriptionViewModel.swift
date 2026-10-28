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
            try await service.loadModel(
                model: selectedModel,
                progressCallback: { [weak self] fraction in
                    Task { @MainActor [weak self] in
                        self?.modelStatus = .downloading(fraction)
                        self?.statusMessage = "Downloading \(self?.selectedModel.displayName ?? ""): \(Int(fraction * 100))%"
                    }
                },
                stageCallback: { [weak self] stage in
                    Task { @MainActor [weak self] in
                        self?.modelStatus = .loading
                        self?.statusMessage = stage
                    }
                }
            )

            self.modelStatus = .ready(selectedModel)
            self.statusMessage = "Model Ready: \(selectedModel.displayName)"
        } catch {
            print("[TranscriptionViewModel] Model load error: \(error)")
            self.modelStatus = .error(error.localizedDescription)
            self.errorMessage = "Failed to load \(selectedModel.displayName): \(error.localizedDescription)"
            self.statusMessage = "Download failed"
        }
    }

    /// Unloads model from memory to free up RAM
    public func unloadModel() async {
        await service.unloadModel()
        self.modelStatus = .idle
        self.statusMessage = "Model unloaded. RAM cleared."
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

    /// Appends real-time streaming segments with smart-merging and sliding window deduplication
    public func appendLiveSegment(_ segment: TranscriptSegment) {
        TranscriptCleaner.appendOrMerge(newSegment: segment, into: &self.segments)
    }

    /// Clears the active transcript list
    public func clearTranscript() {
        self.segments.removeAll()
    }
}

