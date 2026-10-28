import Foundation
import Accelerate

/// Voice Activity Detector (VAD) with energy thresholding and adaptive speech hangover
public final class VoiceActivityDetector: @unchecked Sendable {
    private let sampleRate: Int
    private let frameSize: Int
    public var energyThreshold: Float
    public var minSpeechRatio: Float

    private var speechHangoverSamplesRemaining: Int = 0
    private let hangoverSamples: Int

    public init(
        sampleRate: Int = 16000,
        frameDuration: Double = 0.05, // 50ms frames
        energyThreshold: Float = 0.012,
        hangoverSeconds: Double = 0.6, // 600ms hangover to prevent word chopping
        minSpeechRatio: Float = 0.15 // at least 15% of frames must contain speech
    ) {
        self.sampleRate = sampleRate
        self.frameSize = Int(Double(sampleRate) * frameDuration)
        self.energyThreshold = energyThreshold
        self.hangoverSamples = Int(Double(sampleRate) * hangoverSeconds)
        self.minSpeechRatio = minSpeechRatio
    }

    /// Evaluates whether an audio buffer contains active speech
    public func containsSpeech(in samples: [Float]) -> Bool {
        guard !samples.isEmpty else { return false }

        let frameCount = samples.count / frameSize
        guard frameCount > 0 else {
            return calculateRMS(samples) > energyThreshold
        }

        var speechFrames = 0

        for i in 0..<frameCount {
            let start = i * frameSize
            let end = min(start + frameSize, samples.count)
            let frameSlice = Array(samples[start..<end])
            let rms = calculateRMS(frameSlice)

            if rms > energyThreshold {
                speechFrames += 1
                speechHangoverSamplesRemaining = hangoverSamples
            } else if speechHangoverSamplesRemaining > 0 {
                speechFrames += 1
                speechHangoverSamplesRemaining = max(0, speechHangoverSamplesRemaining - frameSize)
            }
        }

        let ratio = Float(speechFrames) / Float(frameCount)
        return ratio >= minSpeechRatio
    }

    /// Calculates Root Mean Square energy of a frame
    private func calculateRMS(_ frame: [Float]) -> Float {
        guard !frame.isEmpty else { return 0.0 }
        var sumSquares: Float = 0.0
        vDSP_svesq(frame, 1, &sumSquares, vDSP_Length(frame.count))
        let meanSquare = sumSquares / Float(frame.count)
        return sqrt(meanSquare)
    }
}
