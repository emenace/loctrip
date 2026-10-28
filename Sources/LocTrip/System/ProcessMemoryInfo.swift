import Foundation
import Darwin

public final class ProcessMemoryInfo: @unchecked Sendable {
    public static let shared = ProcessMemoryInfo()

    private init() {}

    /// Returns the current resident memory (RAM) used by LocTrip process in Megabytes (MB)
    public func currentResidentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024.0 * 1024.0)
        } else {
            return 0.0
        }
    }

    /// Returns a user-friendly string of current memory footprint, e.g. "284 MB (ANE Active)"
    public var memoryFootprintString: String {
        let mb = currentResidentMemoryMB()
        return String(format: "%.1f MB", mb)
    }

    /// Checks if RAM is within the target 1.0 GB ceiling for Apple Silicon M2 16GB
    public var isWithinTargetBudget: Bool {
        return currentResidentMemoryMB() < 1024.0
    }
}
