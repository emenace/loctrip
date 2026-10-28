import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit

public final class ScreenAudioCaptureService: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    public static let shared = ScreenAudioCaptureService()

    private var stream: SCStream?
    private let resampler = AudioResampler()
    private let audioQueue = DispatchQueue(label: "com.loctrip.audio.capture", qos: .userInitiated)

    public private(set) var isCapturing: Bool = false
    public private(set) var currentTarget: AudioTarget = .entireSystem

    // Callbacks
    public var onResampledAudio: (([Float], AVAudioPCMBuffer) -> Void)?
    public var onAudioLevel: ((Float) -> Void)?
    public var onError: ((Error) -> Void)?

    private override init() {
        super.init()
    }

    /// Fetches available audio targets (Entire system + active applications)
    public func discoverAudioTargets() async throws -> [AudioTarget] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)

        var targets: [AudioTarget] = [.entireSystem]

        let currentPID = ProcessInfo.processInfo.processIdentifier

        // Filter valid user-facing applications (exclude LocTrip itself and headless background helpers)
        let apps = content.applications
            .filter { app in
                app.processID != currentPID &&
                !app.applicationName.isEmpty &&
                app.bundleIdentifier != "com.apple.dock" &&
                app.bundleIdentifier != "com.apple.finder" &&
                app.bundleIdentifier != "com.apple.controlcenter"
            }
            .sorted { $0.applicationName.localizedCaseInsensitiveCompare($1.applicationName) == .orderedAscending }

        for app in apps {
            let target = AudioTarget(
                id: "app.\(app.bundleIdentifier).\(app.processID)",
                name: app.applicationName,
                type: .application(bundleID: app.bundleIdentifier, name: app.applicationName, processID: app.processID),
                iconName: "app.fill",
                runningApplication: app
            )
            targets.append(target)
        }

        return targets
    }

    /// Starts capturing output audio from the specified AudioTarget
    public func startCapture(target: AudioTarget) async throws {
        guard !isCapturing else { return }

        let shareableContent = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        guard let display = shareableContent.displays.first else {
            throw NSError(domain: "LocTrip.AudioCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active display found for ScreenCaptureKit"])
        }

        let filter: SCContentFilter
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let ownApps = shareableContent.applications.filter { $0.processID == currentPID }

        switch target.type {
        case .entireSystem:
            // Capture all system audio except LocTrip's own output
            filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])

        case .application(_, _, let targetPID):
            if let targetApp = shareableContent.applications.first(where: { $0.processID == targetPID }) {
                filter = SCContentFilter(display: display, including: [targetApp], exceptingWindows: [])
            } else {
                filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
            }
        }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.channelCount = 2
        config.sampleRate = 48000
        config.queueDepth = 5

        // Minimize video pipeline completely to preserve CPU & M2 GPU battery
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)

        try await newStream.startCapture()

        self.stream = newStream
        self.currentTarget = target
        self.isCapturing = true
    }

    /// Stops audio capture and frees the stream
    public func stopCapture() async throws {
        guard isCapturing, let stream = stream else { return }
        try await stream.stopCapture()
        self.stream = nil
        self.isCapturing = false
    }

    // MARK: - SCStreamOutput

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        // Downmix & resample to 16kHz mono Float32
        guard let (samples, pcmBuffer) = resampler.resample(sampleBuffer: sampleBuffer) else {
            return
        }

        // Calculate RMS power for audio visualizer
        let rms = AudioResampler.calculateRMSLevel(samples: samples)
        onAudioLevel?(rms)

        // Pass 16kHz buffer for saving to WAV and (in Part 3) feeding to Whisper
        onResampledAudio?(samples, pcmBuffer)
    }

    // MARK: - SCStreamDelegate

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        self.isCapturing = false
        self.stream = nil
        self.onError?(error)
    }
}
