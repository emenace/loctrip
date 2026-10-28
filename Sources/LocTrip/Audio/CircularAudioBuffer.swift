import Foundation

/// A thread-safe circular ring buffer for 16kHz Float32 audio samples
public final class CircularAudioBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: [Float]
    private let capacity: Int
    private var writeIndex: Int = 0
    private var availableCount: Int = 0
    private var unconsumedCount: Int = 0

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

    /// Number of unconsumed samples waiting to be processed
    public var unconsumedSampleCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return unconsumedCount
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
            if unconsumedCount < capacity {
                unconsumedCount += 1
            }
        }
    }

    /// Reads the next sequential audio chunk of `stepSamples` with `contextSamples` of preceding context.
    /// Returns nil if fewer than `stepSamples` are currently available.
    public func readChunk(
        stepSamples: Int,
        contextSamples: Int,
        maxBacklogSamples: Int = 16000 * 6
    ) -> (samples: [Float], step: Int)? {
        lock.lock()
        defer { lock.unlock() }

        // Cap backlog if system fell behind to prevent infinite catch-up delay
        if unconsumedCount > maxBacklogSamples {
            unconsumedCount = maxBacklogSamples
        }

        guard unconsumedCount >= stepSamples else {
            return nil
        }

        let step = stepSamples
        let context = min(contextSamples, availableCount - unconsumedCount)
        let totalCount = context + step

        var result = [Float](repeating: 0.0, count: totalCount)
        var readIndex = (writeIndex - unconsumedCount - context + capacity) % capacity

        for i in 0..<totalCount {
            result[i] = buffer[readIndex]
            readIndex = (readIndex + 1) % capacity
        }

        unconsumedCount -= step
        return (result, step)
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
        unconsumedCount = 0
    }
}
