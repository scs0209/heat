import AppKit
import Combine
import SwiftUI

enum ProcessTab: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "메모리"
    var id: String { rawValue }
}

final class PopoverModel: ObservableObject {
    @Published var snapshot: SensorSnapshot = .empty
    @Published var toast: String?
    @Published var tab: ProcessTab = .cpu
}

struct PopoverView: View {
    @ObservedObject var model: PopoverModel
    var onReenable: (() -> Void)?
    var onQuit: (() -> Void)?
    var onRefresh: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            memoryBanner
            Divider().opacity(0.4)
            processSection
            if let toast = model.toast {
                Text(toast)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            Divider().opacity(0.4)
            footer
        }
        .frame(width: 340, height: 380)
        .background(VisualEffectBackground())
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: model.snapshot.statusSymbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(levelColor)
                .symbolRenderingMode(.hierarchical)
            Text(headerTitle)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
            Text(model.snapshot.thermalLabel)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(levelColor.opacity(0.18)))
                .foregroundStyle(levelColor)
            Spacer(minLength: 4)
            Label(
                model.snapshot.temperatureC.map { String(format: "%.0f°", $0) } ?? "—",
                systemImage: "thermometer.medium"
            )
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            Label(
                model.snapshot.fanRPM.map { "\($0)" } ?? "—",
                systemImage: "fan"
            )
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var headerTitle: String {
        if let t = model.snapshot.temperatureC {
            return String(format: "%.0f°C", t)
        }
        return "heat"
    }

    private var levelColor: Color {
        switch model.snapshot.heatLevel {
        case .calm: return .secondary
        case .warm: return .orange
        case .hot, .surge: return .red
        }
    }

    private var memoryBanner: some View {
        let mem = model.snapshot.systemMemory
        let pressure = mem.usedFraction
        let barColor: Color = pressure >= 0.85 ? .red : (pressure >= 0.7 ? .orange : Color.accentColor)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("메모리")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(mem.usedLabel) / \(mem.totalLabel)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                Spacer(minLength: 0)
                Text("\(mem.usedPercent)%")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(barColor.opacity(0.85))
                        .frame(width: max(3, geo.size.width * pressure))
                }
            }
            .frame(height: 4)
            HStack(spacing: 10) {
                Text("앱 \(Culprit.formatMemory(mem.appBytes))")
                Text("와이어드 \(Culprit.formatMemory(mem.wiredBytes))")
                Text("압축 \(Culprit.formatMemory(mem.compressedBytes))")
            }
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var activeList: [Culprit] {
        switch model.tab {
        case .cpu: return model.snapshot.cpuCulprits
        case .memory: return model.snapshot.memoryCulprits
        }
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $model.tab) {
                ForEach(ProcessTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if activeList.isEmpty {
                columnHeader
                Text(model.tab == .cpu
                      ? "CPU를 많이 쓰는 앱이 없습니다."
                      : "메모리 사용이 큰 앱이 없습니다.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                Spacer(minLength: 0)
            } else {
                // Header + rows in ONE VStack(spacing:0) so nothing can sit between them.
                TopPinnedScroll(items: activeList, totalMemory: model.snapshot.systemMemory.totalBytes) { culprit, share in
                    ProcessRowView(
                        culprit: culprit,
                        share: share,
                        onQuit: { c in
                            ProcessActions.confirmAndTerminate(culprit: c) { ok in
                                if ok {
                                    ProcessCulprits.remove(pid: c.pid)
                                    model.toast = "“\(c.name)” 종료 요청함"
                                    model.snapshot.cpuCulprits.removeAll { $0.pid == c.pid }
                                    model.snapshot.memoryCulprits.removeAll { $0.pid == c.pid }
                                    onRefresh?()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                        model.toast = nil
                                    }
                                }
                            }
                        }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("이름").frame(maxWidth: .infinity, alignment: .leading)
            Text("CPU").frame(width: 36, alignment: .trailing)
            Text("메모리").frame(width: 52, alignment: .trailing)
            Text("점유").frame(width: 32, alignment: .trailing)
            Color.clear.frame(width: 36)
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 12)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if !model.snapshot.detailedSensorsAvailable {
                Button("센서 허용…") { onReenable?() }
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
            } else {
                Label("센서 연결됨", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("heat 종료") {
                if let onQuit { onQuit() } else { NSApp.terminate(nil) }
            }
            .font(.system(size: 11))
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Row

private struct ProcessRowView: View {
    let culprit: Culprit
    let share: Double
    var onQuit: (Culprit) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(culprit.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%.0f%%", culprit.cpuPercent))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(culprit.cpuPercent >= 40 ? Color.orange : Color.secondary)
                .frame(width: 36, alignment: .trailing)
            Text(culprit.memoryLabel)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(culprit.memoryBytes >= 1_073_741_824 ? Color.orange : Color.secondary)
                .frame(width: 52, alignment: .trailing)
            Text(String(format: "%.0f%%", share * 100))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(share >= 0.1 ? Color.orange : Color.secondary)
                .frame(width: 32, alignment: .trailing)
            Button(role: .destructive) { onQuit(culprit) } label: {
                Text("종료").font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .disabled(ProcessActions.isProtected(name: culprit.name))
            .frame(width: 36, alignment: .trailing)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 3)
        .frame(height: 24)
    }
}

private struct ProcessListContent: View {
    let items: [Culprit]
    let totalMemory: UInt64
    var row: (Culprit, Double) -> ProcessRowView

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text("이름").frame(maxWidth: .infinity, alignment: .leading)
                Text("CPU").frame(width: 36, alignment: .trailing)
                Text("메모리").frame(width: 52, alignment: .trailing)
                Text("점유").frame(width: 32, alignment: .trailing)
                // 종료 버튼(36) + 스크롤바 거터(15)
                Color.clear.frame(width: 51)
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(height: 18)

            ForEach(items) { c in
                let share = totalMemory > 0 ? Double(c.memoryBytes) / Double(totalMemory) : 0
                row(c, share)
            }
        }
        .padding(.trailing, 15) // vertical scroller gutter — keep 종료 visible
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - AppKit scroll, content glued to top

private final class FlippedClipView: NSClipView {
    override var isFlipped: Bool { true }
}

private struct TopPinnedScroll: NSViewRepresentable {
    let items: [Culprit]
    let totalMemory: UInt64
    var row: (Culprit, Double) -> ProcessRowView

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .legacy // reserve gutter so overlay scroller doesn't cover 종료
        scroll.borderType = .noBorder
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        scroll.scrollerInsets = .init(top: 0, left: 0, bottom: 0, right: 0)

        let clip = FlippedClipView()
        clip.drawsBackground = false
        clip.automaticallyAdjustsContentInsets = false
        clip.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        scroll.contentView = clip

        let hosting = context.coordinator.hosting
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = [.intrinsicContentSize]
        }
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width]
        scroll.documentView = hosting
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let root = ProcessListContent(items: items, totalMemory: totalMemory, row: row)
        context.coordinator.hosting.rootView = AnyView(root)

        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        scroll.scrollerStyle = .legacy
        scroll.contentView.automaticallyAdjustsContentInsets = false
        scroll.contentView.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 0)

        let width = max(scroll.bounds.width, 1)
        let hosting = context.coordinator.hosting
        hosting.setFrameSize(NSSize(width: width, height: 10_000)) // temp for measure
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        let height = max(ceil(fitting.height), 1)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        scroll.documentView = hosting
    }

    final class Coordinator {
        let hosting = NSHostingView(rootView: AnyView(EmptyView()))
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
