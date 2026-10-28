import Foundation
import AVFoundation

public final class WAVFileWriter {
    private var audioFile: AVAudioFile?
    public private(set) var fileURL: URL?
    public private(set) var totalFramesWritten: AVAudioFramePosition = 0

    public init() {}

    /// Starts writing a new WAV file to the user's Downloads or temporary directory
    public func startRecording(filenamePrefix: String = "LocTrip_TestCapture") throws -> URL {
        let fileManager = FileManager.default
        let downloadsDir = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let destinationURL = downloadsDir.appendingPathComponent("\(filenamePrefix)_\(timestamp).wav")

        let settings = AudioResampler.targetFormat.settings
        self.audioFile = try AVAudioFile(
            forWriting: destinationURL,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        self.fileURL = destinationURL
        self.totalFramesWritten = 0
        return destinationURL
    }

    /// Appends resampled 16kHz audio buffer
    public func write(buffer: AVAudioPCMBuffer) throws {
        guard let audioFile = audioFile else { return }
        try audioFile.write(from: buffer)
        totalFramesWritten += Int64(buffer.frameLength)
    }

    /// Closes the WAV file and returns the final file URL and duration in seconds
    public func stopRecording() -> (url: URL?, durationSeconds: Double) {
        let duration = Double(totalFramesWritten) / AudioResampler.targetFormat.sampleRate
        let savedURL = self.fileURL
        self.audioFile = nil
        return (savedURL, duration)
    }
}
