import Foundation
import Combine
import AppKit
import AVFoundation

@MainActor
public final class AudioCaptureViewModel: ObservableObject {
    public static let shared = AudioCaptureViewModel()

    private let captureService = ScreenAudioCaptureService.shared
    private let streamingPipeline = StreamingAudioPipeline.shared
    private var wavWriter: WAVFileWriter?
    private var timerCancellable: AnyCancellable?

    @Published public var availableTargets: [AudioTarget] = [.entireSystem]
    @Published public var selectedTarget: AudioTarget = .entireSystem
    @Published public var isRecording: Bool = false
    @Published public var isLiveStreaming: Bool = false
    @Published public var includeMicrophone: Bool = false
    @Published public var isSpeechDetected: Bool = false
    @Published public var recordingDuration: TimeInterval = 0.0
    @Published public var audioLevel: Float = 0.0
    @Published public var lastSavedWavURL: URL?
    @Published public var lastSavedDuration: Double = 0.0
    @Published public var statusMessage: String = "Ready to capture"
    @Published public var errorMessage: String?

    public init() {
        setupCallbacks()
    }

    private func setupCallbacks() {
        captureService.onAudioLevel = { [weak self] level in
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }

        captureService.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.isRecording = false
                self?.isLiveStreaming = false
                self?.errorMessage = error.localizedDescription
                self?.statusMessage = "Capture error occurred"
            }
        }

        Task {
            await streamingPipeline.setOnNewSegment { segment in
                Task { @MainActor in
                    TranscriptionViewModel.shared.appendLiveSegment(segment)
                }
            }

            await streamingPipeline.setOnSpeechStatusChange { isSpeech in
                Task { @MainActor in
                    AudioCaptureViewModel.shared.isSpeechDetected = isSpeech
                }
            }
        }
    }

    /// Discovers active applications and audio targets
    public func loadTargets() async {
        do {
            let targets = try await captureService.discoverAudioTargets()
            self.availableTargets = targets
            if !targets.contains(where: { $0.id == self.selectedTarget.id }) {
                self.selectedTarget = .entireSystem
            }
        } catch {
            self.errorMessage = "Failed to list audio targets: \(error.localizedDescription)"
        }
    }

    /// Starts continuous live streaming & transcription
    public func startLiveStreaming(languageCode: String) async {
        guard !isLiveStreaming && !isRecording else { return }
        errorMessage = nil

        let lang: String? = (languageCode == "auto") ? nil : languageCode

        do {
            try await streamingPipeline.startStreaming(
                target: selectedTarget,
                includeMicrophone: includeMicrophone,
                language: lang
            )
            self.isLiveStreaming = true
            self.recordingDuration = 0.0
            self.statusMessage = "Live Transcribing: \(selectedTarget.name)"

            timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.recordingDuration += 0.1
                }
        } catch {
            self.isLiveStreaming = false
            self.errorMessage = "Could not start live stream: \(error.localizedDescription)"
        }
    }

    /// Stops live streaming
    public func stopLiveStreaming() async {
        guard isLiveStreaming else { return }
        timerCancellable?.cancel()
        timerCancellable = nil

        await streamingPipeline.stopStreaming()
        self.isLiveStreaming = false
        self.isSpeechDetected = false
        self.audioLevel = 0.0
        self.statusMessage = "Live streaming stopped"

        let currentSegments = TranscriptionViewModel.shared.segments
        if !currentSegments.isEmpty {
            _ = MeetingHistoryViewModel.shared.saveSession(
                title: nil,
                duration: recordingDuration,
                appName: selectedTarget.name,
                language: AppViewModel.shared.selectedLanguage,
                segments: currentSegments
            )
        }
    }

    /// Starts capturing output sound and writing to a test WAV file
    public func startTestRecording() async {
        guard !isLiveStreaming else { return }
        errorMessage = nil
        do {
            let writer = WAVFileWriter()
            _ = try writer.startRecording(filenamePrefix: "LocTrip_OutputAudio")
            self.wavWriter = writer

            captureService.onResampledAudio = { [weak writer] _, pcmBuffer in
                try? writer?.write(buffer: pcmBuffer)
            }

            try await captureService.startCapture(target: selectedTarget)
            self.isRecording = true
            self.recordingDuration = 0.0
            self.statusMessage = "Capturing: \(selectedTarget.name)"

            timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.recordingDuration += 0.1
                }
        } catch {
            self.isRecording = false
            self.errorMessage = "Could not start capture: \(error.localizedDescription)"
            self.statusMessage = "Capture failed"
        }
    }

    /// Stops audio capture and finalizes the test WAV file
    public func stopTestRecording() async {
        timerCancellable?.cancel()
        timerCancellable = nil

        do {
            try await captureService.stopCapture()
        } catch {
            self.errorMessage = "Error stopping capture: \(error.localizedDescription)"
        }

        if let writer = wavWriter {
            let result = writer.stopRecording()
            self.lastSavedWavURL = result.url
            self.lastSavedDuration = result.durationSeconds
            self.wavWriter = nil
        }

        self.isRecording = false
        self.audioLevel = 0.0
        self.statusMessage = "Captured \(String(format: "%.1f", recordingDuration))s of audio"
    }

    public func revealLastRecordingInFinder() {
        guard let url = lastSavedWavURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func playLastRecording() {
        guard let url = lastSavedWavURL else { return }
        NSWorkspace.shared.open(url)
    }
}
