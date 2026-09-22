import AppKit
import SwiftUI

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let sensors = SensorService()
    private let model = PopoverModel()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover.contentSize = NSSize(width: 340, height: 380)
        popover.behavior = .transient
        popover.animates = true

        let root = PopoverView(
            model: model,
            onReenable: { [weak self] in
                self?.reenableDetailedSensors()
            },
            onQuit: {
                NSApp.terminate(nil)
            },
            onRefresh: { [weak self] in
                self?.sensors.tickNow()
            }
        )
        popover.contentViewController = NSHostingController(rootView: root)

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.setAccessibilityTitle("heat")
            button.imagePosition = .imageLeading
            applySymbol(named: "thermometer.low", title: "")
        }

        sensors.onUpdate = { [weak self] snap in
            Task { @MainActor in
                self?.apply(snapshot: snap)
            }
        }
        sensors.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.promptDetailedSensorsIfNeeded()
        }
    }

    private func bundledHelperURL() -> URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/heat-sampler")
    }

    private func promptDetailedSensorsIfNeeded() {
        PrivilegeBootstrap.promptIfNeeded(bundledHelper: bundledHelperURL())
    }

    private func apply(snapshot: SensorSnapshot) {
        model.snapshot = snapshot
        guard let button = statusItem.button else { return }
        let surge = sensors.isSurging(snapshot: snapshot)
        let title: String
        if surge && snapshot.heatLevel != .calm {
            title = "↑\(snapshot.statusTitle.isEmpty ? snapshot.thermalLabel : snapshot.statusTitle)"
        } else {
            title = snapshot.statusTitle
        }
        applySymbol(named: snapshot.statusSymbolName, title: title)

        switch snapshot.heatLevel {
        case .calm:
            button.contentTintColor = nil
        case .warm:
            button.contentTintColor = .systemOrange
        case .hot, .surge:
            button.contentTintColor = .systemRed
        }
    }

    private func applySymbol(named: String, title: String) {
        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let image = NSImage(systemSymbolName: named, accessibilityDescription: "heat")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
        button.title = title.isEmpty ? "" : " \(title)"
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func reenableDetailedSensors() {
        PrivilegeBootstrap.reenable(bundledHelper: bundledHelperURL())
    }
}
