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

            // Step size: 2.5 seconds (40,000 samples at 16kHz)
            let stepSamples = 16000 * 5 / 2
            // Preceding context: 1.0 second (16,000 samples)
            let contextSamples = 16000

            var streamElapsedSeconds: Double = 0.0

            while !Task.isCancelled {
                guard let chunk = await self.fetchNextChunk(stepSamples: stepSamples, contextSamples: contextSamples) else {
                    // Audio accumulating; sleep short 100ms tick to stay responsive
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    continue
                }

                guard !Task.isCancelled else { break }

                let chunkSamples = chunk.samples
                let stepDuration = Double(chunk.step) / 16000.0
                let segmentStart = streamElapsedSeconds
                let segmentEnd = streamElapsedSeconds + stepDuration
                streamElapsedSeconds += stepDuration

                // Voice Activity Detection: check if audio contains human speech
                let hasSpeech = await self.checkSpeech(samples: chunkSamples)
                await self.notifySpeechStatus(hasSpeech)

                // Skip inference if audio is silent
                guard hasSpeech else {
                    continue
                }

                // Perform Whisper on-device inference
                do {
                    let segments = try await self.transcriptionService.transcribe(
                        audioSamples: chunkSamples,
                        language: language
                    )

                    for segment in segments {
                        let cleaned = TranscriptCleaner.clean(segment.text)
                        if !cleaned.isEmpty {
                            let adjustedSegment = TranscriptSegment(
                                id: UUID(),
                                start: Float(segmentStart),
                                end: Float(segmentEnd),
                                text: cleaned,
                                language: segment.language
                            )
                            await self.notifyNewSegment(adjustedSegment)
                        }
                    }
                } catch {
                    if !Task.isCancelled {
                        await self.notifyError(error)
                    }
                }
            }
        }
    }

    private func fetchNextChunk(stepSamples: Int, contextSamples: Int) -> (samples: [Float], step: Int)? {
        return self.ringBuffer.readChunk(stepSamples: stepSamples, contextSamples: contextSamples)
    }

    private func checkSpeech(samples: [Float]) -> Bool {
        return self.vad.containsSpeech(in: samples)
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
