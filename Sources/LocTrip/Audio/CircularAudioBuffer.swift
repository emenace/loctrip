import Foundation

/// A thread-safe circular ring buffer for 16kHz Float32 audio samples
public final class CircularAudioBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: [Float]
    private let capacity: Int
    private var writeIndex: Int = 0
    private var availableCount: Int = 0

    /// Initialize circular buffer with a given duration in seconds at 16,000 Hz
    public init(durationSeconds: Double = 30.0, sampleRate: Int = 16000) {
        self.capacity = Int(durationSeconds * Double(sampleRate))
        self.buffer = [Float](repeating: 0.0, count: capacity)
    }

    /// Number of available samples currently stored in the buffer
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return availableCount
    }

    /// Appends incoming audio samples to the ring buffer
    public func append(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }

        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
            if availableCount < capacity {
                availableCount += 1
            }
        }
    }

    /// Retrieves the most recent `count` samples without modifying the buffer state
    public func getLatest(count requestedCount: Int) -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        let n = min(requestedCount, availableCount)
        guard n > 0 else { return [] }

        var result = [Float](repeating: 0.0, count: n)
        var readIndex = (writeIndex - n + capacity) % capacity

        for i in 0..<n {
            result[i] = buffer[readIndex]
            readIndex = (readIndex + 1) % capacity
        }

        return result
    }

    /// Clears the ring buffer
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        writeIndex = 0
        availableCount = 0
    }
}
