import Darwin
import Foundation

struct SystemMemory: Equatable {
    var totalBytes: UInt64
    var usedBytes: UInt64
    var freeBytes: UInt64
    var compressedBytes: UInt64
    var wiredBytes: UInt64
    var appBytes: UInt64

    var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(usedBytes) / Double(totalBytes))
    }

    var usedPercent: Int {
        Int((usedFraction * 100).rounded())
    }

    var usedLabel: String { Culprit.formatMemory(usedBytes) }
    var totalLabel: String { Culprit.formatMemory(totalBytes) }

    static var empty: SystemMemory {
        SystemMemory(
            totalBytes: ProcessInfo.processInfo.physicalMemory,
            usedBytes: 0,
            freeBytes: 0,
            compressedBytes: 0,
            wiredBytes: 0,
            appBytes: 0
        )
    }

    /// Aligns with Activity Monitor’s “Memory Used” ≈ App + Wired + Compressed.
    /// File cache (inactive/external) is reclaimable and is NOT counted as used.
    static func sample() -> SystemMemory {
        let total = ProcessInfo.processInfo.physicalMemory
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            return .empty
        }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return .empty }

        let ps = UInt64(pageSize)
        let wired = UInt64(stats.wire_count) * ps
        let compressed = UInt64(stats.compressor_page_count) * ps
        let free = UInt64(stats.free_count) * ps
        let internalPages = UInt64(stats.internal_page_count) * ps
        let purgeable = UInt64(stats.purgeable_count) * ps
        // App Memory (AM): anonymous app pages minus purgeable
        let app = internalPages > purgeable ? internalPages - purgeable : 0
        let used = min(app + wired + compressed, total)

        return SystemMemory(
            totalBytes: total,
            usedBytes: used,
            freeBytes: free,
            compressedBytes: compressed,
            wiredBytes: wired,
            appBytes: app
        )
    }
}
