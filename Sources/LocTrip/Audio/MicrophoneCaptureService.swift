import Foundation
import AVFoundation

public final class MicrophoneCaptureService: @unchecked Sendable {
    public static let shared = MicrophoneCaptureService()

    private var audioEngine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var configChangeObserver: NSObjectProtocol?
    public private(set) var isRunning: Bool = false

    public var onAudioChunk: (([Float]) -> Void)?
    public var onDeviceReconnected: ((String) -> Void)?
    public var onError: ((Error) -> Void)?

    private init() {}

    /// Starts capturing microphone input and converts to 16kHz mono Float32
    public func startCapture() throws {
        guard !isRunning else { return }

        let engine = AVAudioEngine()
        try setupTapAndStart(engine: engine)

        // Observe hardware route/device changes (AirPods disconnect, headphones unplugged)
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }

        self.audioEngine = engine
        self.isRunning = true
    }

    private func setupTapAndStart(engine: AVAudioEngine) throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw NSError(
                domain: "LocTrip.MicrophoneCapture",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid microphone format or input device not found."]
            )
        }

        let targetFormat = AudioResampler.targetFormat
        let audioConverter = AVAudioConverter(from: inputFormat, to: targetFormat)
        self.converter = audioConverter

        let bufferSize: AVAudioFrameCount = 2048
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, let converter = self.converter else { return }

            let ratio = targetFormat.sampleRate / inputFormat.sampleRate
            let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64

            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
                return
            }

            var error: NSError?
            var isConsumed = false
            let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                if !isConsumed {
                    isConsumed = true
                    outStatus.pointee = .haveData
                    return buffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }

            guard status != .error, error == nil, outputBuffer.frameLength > 0 else { return }
            guard let channelData = outputBuffer.floatChannelData?[0] else { return }

            let count = Int(outputBuffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData, count: count))
            self.onAudioChunk?(samples)
        }

        try engine.start()
    }

    /// Gracefully handles mid-meeting audio device disconnection / route change
    private func handleConfigurationChange() {
        guard isRunning, let engine = audioEngine else { return }
        print("[MicrophoneCaptureService] Audio engine route change detected (AirPods/Headphones changed). Reconnecting...")

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        do {
            try setupTapAndStart(engine: engine)
            onDeviceReconnected?("Audio input device reconnected successfully")
        } catch {
            print("[MicrophoneCaptureService] Reconnect error: \(error)")
            onError?(error)
        }
    }

    /// Stops microphone capture
    public func stopCapture() {
        guard isRunning, let engine = audioEngine else { return }

        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configChangeObserver = nil
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.audioEngine = nil
        self.converter = nil
        self.isRunning = false
    }
}
