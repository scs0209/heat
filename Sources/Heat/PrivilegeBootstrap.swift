import AppKit
import Foundation

enum PrivilegeBootstrap {
    static let defaultsKeyPrompted = "heat.didPromptDetailedSensors"
    static let defaultsKeyEnabled = "heat.detailedSensorsEnabled"
    static let sharedDir = URL(fileURLWithPath: "/Users/Shared/heat", isDirectory: true)
    static let sensorsURL = sharedDir.appendingPathComponent("sensors.json")
    static let helperPath = "/usr/local/libexec/heat-sampler"
    static let plistPath = "/Library/LaunchDaemons/dev.heat.sampler.plist"

    static var isDetailedEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKeyEnabled)
            && FileManager.default.fileExists(atPath: helperPath)
    }

    static func promptIfNeeded(bundledHelper: URL) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: defaultsKeyPrompted) { return }
        defaults.set(true, forKey: defaultsKeyPrompted)

        let alert = NSAlert()
        alert.messageText = "Enable detailed temperature & fans?"
        alert.informativeText =
            "heat can show CPU temperature and fan speed. macOS requires administrator permission once to install a small local sampler. You can keep using heat without this — thermal state and top CPU processes still work."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Not Now")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            _ = installHelper(bundledHelper: bundledHelper)
        }
    }

    @discardableResult
    static func installHelper(bundledHelper: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: bundledHelper.path) else {
            presentError("Bundled heat-sampler is missing. Rebuild Heat.app with scripts/build-app.sh.")
            return false
        }

        let bundledPlist = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/dev.heat.sampler.plist")
        guard FileManager.default.fileExists(atPath: bundledPlist.path) else {
            presentError("Bundled LaunchDaemon plist is missing.")
            return false
        }

        let installScriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("heat-install-\(UUID().uuidString).sh")

        let helperSrc = bundledHelper.path
        let plistSrc = bundledPlist.path
        let script = """
        #!/bin/bash
        set -euo pipefail
        mkdir -p /usr/local/libexec /Users/Shared/heat
        cp "\(helperSrc)" /usr/local/libexec/heat-sampler
        chmod 755 /usr/local/libexec/heat-sampler
        chown root:wheel /usr/local/libexec/heat-sampler
        chmod 777 /Users/Shared/heat
        cp "\(plistSrc)" /Library/LaunchDaemons/dev.heat.sampler.plist
        /usr/bin/plutil -lint /Library/LaunchDaemons/dev.heat.sampler.plist
        chown root:wheel /Library/LaunchDaemons/dev.heat.sampler.plist
        chmod 644 /Library/LaunchDaemons/dev.heat.sampler.plist
        launchctl bootout system/dev.heat.sampler 2>/dev/null || true
        launchctl bootstrap system /Library/LaunchDaemons/dev.heat.sampler.plist
        launchctl enable system/dev.heat.sampler || true
        launchctl kickstart -k system/dev.heat.sampler
        """

        do {
            try script.write(to: installScriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: installScriptURL.path
            )
        } catch {
            presentError("Could not write install script: \(error.localizedDescription)")
            return false
        }

        let pathForAS = installScriptURL.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScript = "do shell script \"/bin/bash \\\"\(pathForAS)\\\"\" with administrator privileges"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", appleScript]
        let err = Pipe()
        proc.standardError = err
        proc.standardOutput = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            presentError("Could not start authorization: \(error.localizedDescription)")
            return false
        }
        defer { try? FileManager.default.removeItem(at: installScriptURL) }

        if proc.terminationStatus != 0 {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            presentError(msg.isEmpty ? "Administrator authorization was cancelled or failed." : msg)
            UserDefaults.standard.set(false, forKey: defaultsKeyEnabled)
            return false
        }
        UserDefaults.standard.set(true, forKey: defaultsKeyEnabled)
        return true
    }

    static func reenable(bundledHelper: URL) {
        UserDefaults.standard.set(false, forKey: defaultsKeyPrompted)
        _ = installHelper(bundledHelper: bundledHelper)
    }

    private static func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Could not enable detailed sensors"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
