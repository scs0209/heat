import Foundation

/// Privileged sampler: polls `powermetrics` and writes /Users/Shared/heat/sensors.json
@main
enum HeatSamplerMain {
    static func main() {
        let args = CommandLine.arguments
        let daemon = args.contains("--daemon")
        let outURL = URL(fileURLWithPath: "/Users/Shared/heat/sensors.json")

        if daemon {
            try? FileManager.default.createDirectory(
                at: URL(fileURLWithPath: "/Users/Shared/heat"),
                withIntermediateDirectories: true
            )
            while true {
                sampleOnce(to: outURL)
                Thread.sleep(forTimeInterval: 2.0)
            }
        } else {
            sampleOnce(to: outURL)
        }
    }

    private static func sampleOnce(to url: URL) {
        let result = runPowermetrics()
        var payload: [String: Any] = [
            "updatedAt": Date().timeIntervalSince1970,
            "source": "powermetrics",
        ]
        if let t = result.temperatureC { payload["temperatureC"] = t }
        if let f = result.fanRPM { payload["fanRPM"] = f }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    private struct Sample {
        var temperatureC: Double?
        var fanRPM: Int?
    }

    private static func runPowermetrics() -> Sample {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/powermetrics")
        // Single sample; SMC sampler covers die temp + fans on most Macs.
        proc.arguments = ["--samplers", "smc", "-n", "1", "-i", "500"]
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return Sample()
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        let text = (String(data: data, encoding: .utf8) ?? "")
            + "\n"
            + (String(data: errData, encoding: .utf8) ?? "")
        return parse(text)
    }

    /// Best-effort parser across macOS powermetrics SMC text formats.
    private static func parse(_ text: String) -> Sample {
        var temp: Double?
        var fan: Int?

        // Temperature patterns (Apple Silicon / Intel variants)
        let tempPatterns = [
            #"CPU die temperature:\s*([0-9]+(?:\.[0-9]+)?)\s*C"#,
            #"CPU Temperature:\s*([0-9]+(?:\.[0-9]+)?)\s*C"#,
            #"Die temperature:\s*([0-9]+(?:\.[0-9]+)?)\s*C"#,
            #"thermal pressure.*?([0-9]+(?:\.[0-9]+)?)\s*C"#,
            #"CPU die temp:\s*([0-9]+(?:\.[0-9]+)?)"#,
        ]
        for pattern in tempPatterns {
            if let v = firstDouble(in: text, pattern: pattern) {
                temp = v
                break
            }
        }

        // Fan patterns
        let fanPatterns = [
            #"Fan:\s*([0-9]+)\s*rpm"#,
            #"Fan\s+[0-9]+\s+([0-9]+)\s*rpm"#,
            #"([0-9]+)\s*rpm"#,
        ]
        for pattern in fanPatterns {
            if let v = firstInt(in: text, pattern: pattern) {
                fan = v
                break
            }
        }

        return Sample(temperatureC: temp, fanRPM: fan)
    }

    private static func firstDouble(in text: String, pattern: String) -> Double? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = re.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text)
        else { return nil }
        return Double(text[r])
    }

    private static func firstInt(in text: String, pattern: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = re.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text)
        else { return nil }
        return Int(text[r])
    }
}
