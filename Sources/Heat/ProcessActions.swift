import AppKit
import Foundation

enum ProcessActions {
    enum KillError: LocalizedError {
        case notFound
        case refused
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notFound: return "프로세스를 찾을 수 없습니다."
            case .refused: return "시스템 보호 프로세스라 종료할 수 없습니다."
            case .failed(let m): return m
            }
        }
    }

    private static let protected = Set([
        "kernel_task", "launchd", "WindowServer", "loginwindow",
        "Heat", "heat-sampler", "Finder", "Dock", "SystemUIServer",
    ])

    static func isProtected(name: String) -> Bool {
        protected.contains(name)
    }

    /// SIGTERM first via NSRunningApplication when possible.
    @discardableResult
    static func terminate(pid: Int, name: String) -> Result<Void, KillError> {
        if isProtected(name: name) { return .failure(.refused) }
        if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            if app.isTerminated { return .failure(.notFound) }
            if app.terminate() { return .success(()) }
            // Fall through to kill(2)
        }
        let result = kill(pid_t(pid), SIGTERM)
        if result == 0 { return .success(()) }
        if errno == ESRCH { return .failure(.notFound) }
        if errno == EPERM { return .failure(.refused) }
        return .failure(.failed(String(cString: strerror(errno))))
    }

    static func confirmAndTerminate(culprit: Culprit, onDone: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "“\(culprit.name)” 종료"
        alert.informativeText =
            "이 프로세스가 발열·팬의 원인일 수 있습니다. 저장하지 않은 작업이 있다면 먼저 저장하세요."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "종료")
        alert.addButton(withTitle: "취소")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            onDone(false)
            return
        }
        switch terminate(pid: culprit.pid, name: culprit.name) {
        case .success:
            onDone(true)
        case .failure(let err):
            let fail = NSAlert()
            fail.messageText = "종료하지 못했습니다"
            fail.informativeText = err.localizedDescription
            fail.alertStyle = .warning
            fail.addButton(withTitle: "확인")
            fail.runModal()
            onDone(false)
        }
    }
}
