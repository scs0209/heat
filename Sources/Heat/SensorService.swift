import Foundation

final class SensorService {
    private(set) var snapshot: SensorSnapshot = .empty
    private var timer: Timer?
    private var previousCPUTotal: Double = 0
    private(set) var lastSurge: Bool = false
    var onUpdate: ((SensorSnapshot) -> Void)?

    func start() {
        tick()
        let t = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func tickNow() {
        tick()
    }

    private func tick() {
        let thermal = ProcessInfo.processInfo.thermalState
        let cpuList = ProcessCulprits.top(limit: 15, sort: .cpu)
        let memList = ProcessCulprits.top(limit: 15, sort: .memory)
        let memory = SystemMemory.sample()
        let detailed = readDetailedSensors()
        let cpuTotal = cpuList.reduce(0.0) { $0 + $1.cpuPercent }
        lastSurge = previousCPUTotal > 0 && (cpuTotal - previousCPUTotal) >= 60
        previousCPUTotal = cpuTotal

        let snap = SensorSnapshot(
            thermalState: thermal,
            temperatureC: detailed?.temperatureC,
            fanRPM: detailed?.fanRPM,
            cpuCulprits: cpuList,
            memoryCulprits: memList,
            systemMemory: memory,
            detailedSensorsAvailable: PrivilegeBootstrap.isDetailedEnabled && detailed != nil,
            updatedAt: Date()
        )
        snapshot = snap
        onUpdate?(snap)
    }

    private struct Detailed: Decodable {
        var temperatureC: Double?
        var fanRPM: Int?
        var updatedAt: Double?
    }

    private func readDetailedSensors() -> Detailed? {
        let url = PrivilegeBootstrap.sensorsURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let decoded = try? JSONDecoder().decode(Detailed.self, from: data) else { return nil }
        if let ts = decoded.updatedAt, Date().timeIntervalSince1970 - ts > 15 {
            return nil
        }
        return decoded
    }

    func isSurging(snapshot: SensorSnapshot) -> Bool {
        if lastSurge { return true }
        let total = snapshot.cpuCulprits.reduce(0.0) { $0 + $1.cpuPercent }
        return total >= 120
    }
}
