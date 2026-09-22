import Foundation

enum ProcessSort {
    case cpu
    case memory
}

enum ProcessCulprits {
    /// Top processes via `ps` (no root). Sorted by CPU or RSS.
    static func top(limit: Int = 12, sort: ProcessSort = .cpu) -> [Culprit] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        // rss is kilobytes on macOS; -m sorts by memory, -r by CPU
        proc.arguments = [
            "-Aceo", "pid,pcpu,rss,comm",
            sort == .memory ? "-m" : "-r",
        ]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        var results: [Culprit] = []
        let skip = Set([
            "kernel_task", "WindowServer", "launchd", "ps", "Heat", "heat-sampler",
        ])
        for (index, line) in text.split(separator: "\n").enumerated() {
            if index == 0 { continue }
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 4,
                  let pid = Int(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = Double(parts[2])
            else { continue }
            let name = parts.dropFirst(3).joined(separator: " ")
            let base = URL(fileURLWithPath: name).lastPathComponent
            if skip.contains(base) { continue }
            let memoryBytes = UInt64(max(0, rssKB) * 1024)
            switch sort {
            case .cpu:
                if cpu < 0.5 { continue }
            case .memory:
                if memoryBytes < 20 * 1_048_576 { continue } // < 20 MB
            }
            results.append(
                Culprit(
                    pid: pid,
                    name: base,
                    cpuPercent: cpu,
                    memoryBytes: memoryBytes,
                    reason: reason(cpu: cpu, memoryBytes: memoryBytes, sort: sort)
                )
            )
            if results.count >= limit { break }
        }
        return results
    }

    private static func reason(cpu: Double, memoryBytes: UInt64, sort: ProcessSort) -> String {
        let mem = Culprit.formatMemory(memoryBytes)
        switch sort {
        case .memory:
            if memoryBytes >= 2_147_483_648 {
                return "\(mem) — 메모리 많이 사용"
            }
            return "\(mem) · CPU \(String(format: "%.0f", cpu))%"
        case .cpu:
            if cpu >= 100 {
                return "CPU \(Int(cpu))% · \(mem) — 팬이 돌 가능성 큼"
            }
            if cpu >= 40 {
                return "CPU \(Int(cpu))% · \(mem) — 부하 높음"
            }
            return "CPU \(String(format: "%.0f", cpu))% · \(mem)"
        }
    }

    static func remove(pid: Int) {
        _ = pid
    }
}
