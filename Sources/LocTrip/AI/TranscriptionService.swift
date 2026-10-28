import Foundation
import WhisperKit

public actor TranscriptionService {
    public static let shared = TranscriptionService()

    private var whisperKit: WhisperKit?
    public private(set) var currentModel: TranscriptionModel?

    // Common Indonesian & English meeting prompt for tokenizer biasing
    public static let defaultBilingualPrompt = "Percakapan meeting bilingual Bahasa Indonesia dan English. Topik: sprint planning, product roadmap, tech sync, deployment, backend, frontend, pull request, database, user experience, release timeline."

    public init() {}

    public var isLoaded: Bool {
        whisperKit != nil
    }

    /// Downloads and initializes the requested multilingual Whisper model
    public func loadModel(
        model: TranscriptionModel,
        progressCallback: (@Sendable (Double) -> Void)? = nil,
        stageCallback: (@Sendable (String) -> Void)? = nil
    ) async throws {
        // Download model weights with progress reporting
        let modelFolderURL = try await WhisperKit.download(
            variant: model.rawValue,
            progressCallback: { progress in
                progressCallback?(progress.fractionCompleted)
            }
        )

        // Compile and prewarm CoreML weights on ANE / Metal
        stageCallback?("Optimizing CoreML weights for Apple Neural Engine...")

        let computeOptions = ModelComputeOptions(
            audioEncoderCompute: .cpuAndNeuralEngine,
            textDecoderCompute: .cpuAndNeuralEngine
        )

        // Initialize WhisperKit pointing to the downloaded CoreML model with prewarming
        let pipe = try await WhisperKit(
            modelFolder: modelFolderURL.path,
            computeOptions: computeOptions,
            verbose: false,
            logLevel: .none,
            prewarm: true,
            load: true
        )

        self.whisperKit = pipe
        self.currentModel = model
    }

    /// Unloads the Whisper model from memory to free up RAM
    public func unloadModel() {
        self.whisperKit = nil
        self.currentModel = nil
    }

    /// Transcribes an audio file (e.g. the WAV captured from Part 2)
    public func transcribe(
        wavURL: URL,
        language: String? = nil,
        prompt: String? = defaultBilingualPrompt
    ) async throws -> [TranscriptSegment] {
        guard let whisperKit = whisperKit else {
            throw NSError(
                domain: "LocTrip.TranscriptionService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No Whisper model loaded. Please load a model first."]
            )
        }

        // Configure multilingual decoding options with strict token stripping
        let decodeOptions = DecodingOptions(
            task: .transcribe,
            language: language,
            temperature: 0.0,
            temperatureFallbackCount: 0,
            sampleLength: 64,
            usePrefillPrompt: prompt != nil,
            usePrefillCache: true,
            detectLanguage: language == nil,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )

        let results: [TranscriptionResult] = try await whisperKit.transcribe(
            audioPath: wavURL.path,
            decodeOptions: decodeOptions
        )

        return mapResults(results)
    }

    /// Transcribes raw in-memory 16kHz mono Float32 audio samples
    public func transcribe(
        audioSamples: [Float],
        language: String? = nil,
        prompt: String? = defaultBilingualPrompt
    ) async throws -> [TranscriptSegment] {
        guard let whisperKit = whisperKit else {
            throw NSError(
                domain: "LocTrip.TranscriptionService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No Whisper model loaded. Please load a model first."]
            )
        }

        // Configure multilingual decoding options with strict token stripping
        let decodeOptions = DecodingOptions(
            task: .transcribe,
            language: language,
            temperature: 0.0,
            temperatureFallbackCount: 0,
            sampleLength: 64,
            usePrefillPrompt: prompt != nil,
            usePrefillCache: true,
            detectLanguage: language == nil,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )

        let results: [TranscriptionResult] = try await whisperKit.transcribe(
            audioArray: audioSamples,
            decodeOptions: decodeOptions
        )

        return mapResults(results)
    }

    private func mapResults(_ results: [TranscriptionResult]) -> [TranscriptSegment] {
        var segments: [TranscriptSegment] = []

        for result in results {
            for segment in result.segments {
                let cleanedText = TranscriptCleaner.clean(segment.text)
                if !cleanedText.isEmpty {
                    segments.append(
                        TranscriptSegment(
                            start: segment.start,
                            end: segment.end,
                            text: cleanedText,
                            language: result.language
                        )
                    )
                }
            }
        }

        return segments
    }
}
