
import Foundation
import AppKit
import Combine

@MainActor
final class AppStoreDownloadService: ObservableObject {
    @Published private(set) var isRunning = false

    private var timer: Timer?

    func startPolling() {
        guard timer == nil else { return }
        refresh()

        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        isRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.AppStore")
            .isEmpty
    }

    func openAppStore() {
        NSWorkspace.shared.launchApplication("App Store")
    }
}
