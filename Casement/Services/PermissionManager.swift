import AppKit
import Combine

@MainActor
final class PermissionManager: ObservableObject {
    enum State: Sendable {
        case unknown
        case granted
        case denied
    }

    @Published private(set) var state: State = .unknown
    private nonisolated(unsafe) var pollTimer: Timer?

    func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        state = trusted ? .granted : .denied
    }

    func requestAccessibilityIfNeeded() {
        let options = [
            "AXTrustedCheckOptionPrompt" as CFString: true
        ] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        state = trusted ? .granted : .denied

        if !trusted {
            startPolling()
        }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if AXIsProcessTrusted() {
                    self.state = .granted
                    self.pollTimer?.invalidate()
                    self.pollTimer = nil
                }
            }
        }
    }

    deinit {
        pollTimer?.invalidate()
    }
}
