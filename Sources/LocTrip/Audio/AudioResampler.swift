import Foundation
import AVFoundation
import CoreMedia
import Accelerate

public final class AudioResampler {
    public static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    private var converter: AVAudioConverter?
    private var cachedInputFormat: AVAudioFormat?

    public init() {}

    /// Converts an incoming CMSampleBuffer to 16,000 Hz, 1-channel (mono), 32-bit Float array
    /// Returns both the raw [Float] array and the AVAudioPCMBuffer (useful for WAV export).
    public func resample(sampleBuffer: CMSampleBuffer) -> (samples: [Float], buffer: AVAudioPCMBuffer)? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }

        guard let inputFormat = AVAudioFormat(streamDescription: streamDesc) else {
            return nil
        }

        // Initialize or update converter if audio stream format changes (e.g. sample rate change)
        if converter == nil || cachedInputFormat != inputFormat {
            cachedInputFormat = inputFormat
            converter = AVAudioConverter(from: inputFormat, to: Self.targetFormat)
        }

        guard let converter = converter else { return nil }

        guard let sourceBuffer = extractPCMBuffer(from: sampleBuffer, format: inputFormat) else {
            return nil
        }

        let ratio = Self.targetFormat.sampleRate / inputFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio) + 128
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: Self.targetFormat, frameCapacity: outputFrameCapacity) else {
            return nil
        }

        var error: NSError?
        var isConsumed = false

        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if !isConsumed {
                isConsumed = true
                outStatus.pointee = .haveData
                return sourceBuffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        guard status != .error, error == nil, outputBuffer.frameLength > 0 else {
            return nil
        }

        guard let channelData = outputBuffer.floatChannelData?[0] else {
            return nil
        }

        let count = Int(outputBuffer.frameLength)
        let floatArray = Array(UnsafeBufferPointer(start: channelData, count: count))
        return (floatArray, outputBuffer)
    }

    /// Extracts PCM data from CMSampleBuffer into AVAudioPCMBuffer
    private func extractPCMBuffer(from sampleBuffer: CMSampleBuffer, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numSamples > 0 else { return nil }

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else {
            return nil
        }
        pcmBuffer.frameLength = AVAudioFrameCount(numSamples)

        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(numSamples),
            into: pcmBuffer.mutableAudioBufferList
        )
        guard status == noErr else { return nil }
        return pcmBuffer
    }

    /// Calculates Root Mean Square (RMS) power of samples normalized to 0.0 - 1.0
    public static func calculateRMSLevel(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        var sumSquares: Float = 0.0
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(samples.count))
        let meanSquare = sumSquares / Float(samples.count)
        let rms = sqrt(meanSquare)
        // Amplify visual response gently for human perception (VU meter style)
        return min(max(rms * 4.0, 0.0), 1.0)
    }
}
