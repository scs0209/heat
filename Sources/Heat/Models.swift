import Foundation

enum HeatLevel: String, Equatable {
    case calm
    case warm
    case hot
    case surge
}

struct Culprit: Identifiable, Equatable {
    var id: Int { pid }
    let pid: Int
    let name: String
    let cpuPercent: Double
    /// Resident set size in bytes.
    let memoryBytes: UInt64
    let reason: String

    var memoryLabel: String {
        Self.formatMemory(memoryBytes)
    }

    static func formatMemory(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        if mb >= 10 {
            return String(format: "%.0f MB", mb)
        }
        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
}

struct SensorSnapshot: Equatable {
    var thermalState: ProcessInfo.ThermalState
    var temperatureC: Double?
    var fanRPM: Int?
    var cpuCulprits: [Culprit]
    var memoryCulprits: [Culprit]
    var systemMemory: SystemMemory
    var detailedSensorsAvailable: Bool
    var updatedAt: Date

    /// Back-compat alias used by a few call sites.
    var culprits: [Culprit] {
        get { cpuCulprits }
        set { cpuCulprits = newValue }
    }

    static var empty: SensorSnapshot {
        SensorSnapshot(
            thermalState: .nominal,
            temperatureC: nil,
            fanRPM: nil,
            cpuCulprits: [],
            memoryCulprits: [],
            systemMemory: .empty,
            detailedSensorsAvailable: false,
            updatedAt: Date()
        )
    }

    var heatLevel: HeatLevel {
        if let t = temperatureC {
            if t >= 80 { return .hot }
            if t >= 65 { return .warm }
            return .calm
        }
        switch thermalState {
        case .nominal: return .calm
        case .fair: return .warm
        case .serious, .critical: return .hot
        @unknown default: return .warm
        }
    }

    /// Menubar title. Calm without °C → empty (SF Symbol only).
    var statusTitle: String {
        if let t = temperatureC {
            return String(format: "%.0f°", t)
        }
        switch thermalState {
        case .nominal: return ""
        case .fair: return "따뜻"
        case .serious: return "뜨거움"
        case .critical: return "위험"
        @unknown default: return ""
        }
    }

    var statusSymbolName: String {
        switch heatLevel {
        case .calm: return "thermometer.low"
        case .warm: return "thermometer.medium"
        case .hot, .surge: return "thermometer.high"
        }
    }

    var thermalLabel: String {
        switch thermalState {
        case .nominal: return "정상"
        case .fair: return "주의"
        case .serious: return "높음"
        case .critical: return "위험"
        @unknown default: return "알 수 없음"
        }
    }

    var thermalDetail: String {
        switch thermalState {
        case .nominal: return "열 부하가 낮습니다"
        case .fair: return "다소 따뜻합니다"
        case .serious: return "열이 높습니다"
        case .critical: return "열 제한이 걸릴 수 있습니다"
        @unknown default: return ""
        }
    }
}
