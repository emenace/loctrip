import Foundation
import Combine

public struct LiveTranscriptUpdate: Sendable {
    public let text: String
    public let isSpeechActive: Bool
    public let timestampSeconds: Double
}

public actor StreamingAudioPipeline {
    public static let shared = StreamingAudioPipeline()

    private let screenService = ScreenAudioCaptureService.shared
    private let micService = MicrophoneCaptureService.shared
    private let ringBuffer = CircularAudioBuffer(durationSeconds: 30.0)
    private let vad = VoiceActivityDetector()
    private let transcriptionService = TranscriptionService.shared

    public private(set) var isStreaming: Bool = false
    public private(set) var isMicrophoneEnabled: Bool = false

    private var streamingTask: Task<Void, Never>?
    private var streamStartTime: Date = Date()

    public var onNewSegment: (@Sendable (TranscriptSegment) -> Void)?
    public var onSpeechStatusChange: (@Sendable (Bool) -> Void)?
    public var onError: (@Sendable (Error) -> Void)?

    private init() {}

    public func setOnNewSegment(_ callback: @escaping @Sendable (TranscriptSegment) -> Void) {
        self.onNewSegment = callback
    }

    public func setOnSpeechStatusChange(_ callback: @escaping @Sendable (Bool) -> Void) {
        self.onSpeechStatusChange = callback
    }

    /// Starts live streaming audio capture and continuous sliding-window transcription
    public func startStreaming(
        target: AudioTarget,
        includeMicrophone: Bool,
        language: String? = nil
    ) async throws {
        guard !isStreaming else { return }

        self.isStreaming = true
        self.isMicrophoneEnabled = includeMicrophone
        self.streamStartTime = Date()
        ringBuffer.clear()

        // 1. Hook ScreenCaptureKit output audio to ring buffer
        screenService.onResampledAudio = { [weak self] samples, _ in
            guard let self = self else { return }
            self.ringBuffer.append(samples)
        }

        try await screenService.startCapture(target: target)

        // 2. Hook Microphone audio if enabled
        if includeMicrophone {
            micService.onAudioChunk = { [weak self] micSamples in
                guard let self = self else { return }
                self.ringBuffer.append(micSamples)
            }
            try micService.startCapture()
        }

        // 3. Start background sliding-window transcription loop
        startSlidingWindowLoop(language: language)
    }

    /// Stops live streaming
    public func stopStreaming() async {
        guard isStreaming else { return }

        streamingTask?.cancel()
        streamingTask = nil

        try? await screenService.stopCapture()
        micService.stopCapture()

        self.isStreaming = false
        self.onSpeechStatusChange?(false)
    }

    private func startSlidingWindowLoop(language: String?) {
        streamingTask = Task { [weak self] in
            guard let self = self else { return }

            let streamStartTime = Date()
            // Sliding window: 4.0 seconds chunk (64,000 samples at 16kHz)
            let windowSamples = 16000 * 4
            // Check interval: every 3.0 seconds
            let intervalNanoseconds: UInt64 = 3_000_000_000

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled else { break }

                let samples = self.ringBuffer.getLatest(count: windowSamples)
                guard samples.count >= 16000 * 2 else {
                    continue
                }

                // Voice Activity Detection: check if audio contains human speech
                let hasSpeech = self.vad.containsSpeech(in: samples)
                await self.notifySpeechStatus(hasSpeech)

                // Skip inference if audio is silent
                guard hasSpeech else {
                    continue
                }

                // Perform Whisper on-device inference
                do {
                    let segments = try await self.transcriptionService.transcribe(
                        audioSamples: samples,
                        language: language
                    )

                    let elapsed = Float(Date().timeIntervalSince(streamStartTime))
                    let windowDuration: Float = 4.0

                    for segment in segments {
                        let cleaned = TranscriptCleaner.clean(segment.text)
                        if !cleaned.isEmpty {
                            // Compute realistic, continuous cumulative stream timestamps
                            let absStart = max(0.0, elapsed - windowDuration + segment.start)
                            let absEnd = max(absStart + 1.0, elapsed - windowDuration + segment.end)

                            let adjustedSegment = TranscriptSegment(
                                id: segment.id,
                                start: absStart,
                                end: absEnd,
                                text: cleaned,
                                language: segment.language
                            )
                            await self.notifyNewSegment(adjustedSegment)
                        }
                    }
                } catch {
                    await self.notifyError(error)
                }
            }
        }
    }

    private func notifySpeechStatus(_ isSpeech: Bool) {
        self.onSpeechStatusChange?(isSpeech)
    }

    private func notifyNewSegment(_ segment: TranscriptSegment) {
        self.onNewSegment?(segment)
    }

    private func notifyError(_ error: Error) {
        self.onError?(error)
    }
}
