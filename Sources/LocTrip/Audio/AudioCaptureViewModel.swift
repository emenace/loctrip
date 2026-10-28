import Foundation
import Combine
import AppKit
import AVFoundation

@MainActor
public final class AudioCaptureViewModel: ObservableObject {
    public static let shared = AudioCaptureViewModel()

    private let captureService = ScreenAudioCaptureService.shared
    private var wavWriter: WAVFileWriter?
    private var timerCancellable: AnyCancellable?

    @Published public var availableTargets: [AudioTarget] = [.entireSystem]
    @Published public var selectedTarget: AudioTarget = .entireSystem
    @Published public var isRecording: Bool = false
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
                self?.errorMessage = error.localizedDescription
                self?.statusMessage = "Capture error occurred"
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

    /// Starts capturing output sound and writing to a test WAV file
    public func startTestRecording() async {
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

            // Start duration timer
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

    /// Reveals the saved .wav file in macOS Finder
    public func revealLastRecordingInFinder() {
        guard let url = lastSavedWavURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Plays the saved test recording using default macOS player
    public func playLastRecording() {
        guard let url = lastSavedWavURL else { return }
        NSWorkspace.shared.open(url)
    }
}
