
import AppKit
import SwiftUI
import Combine

@MainActor
final class IslandPresentationModel: ObservableObject {
    @Published var isExpanded = false
}

@MainActor
final class IslandWindowController: NSWindowController {
    let presentation = IslandPresentationModel()

    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    private let hostWidth: CGFloat = 320
    private let hostHeight: CGFloat = 200
    private let compactHeight: CGFloat = 40

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]

        super.init(window: panel)

        let islandView = FloatingIslandView(
            presentation: presentation,
            onSizeChange: { _ in
                // Keep the host window fixed so the top edge never moves.
            }
        )

        panel.contentView = NSHostingView(rootView: islandView)
        positionWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        positionWindow()
        window?.orderFrontRegardless()
        installOutsideClickMonitors()
    }

    private func positionWindow() {
        guard let window else { return }

        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let screenFrame = screen.frame

        let origin = NSPoint(
            x: screenFrame.midX - hostWidth / 2,
            y: screenFrame.maxY - hostHeight
        )

        window.setFrame(
            NSRect(
                origin: origin,
                size: NSSize(width: hostWidth, height: hostHeight)
            ),
            display: true
        )
    }

    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()

        // Handles clicks inside this app, including transparent parts
        // of the island's fixed hosting window.
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self,
                  let window = self.window else {
                return event
            }

            if event.window !== window {
                self.collapseIsland()
                return event
            }

            let point = event.locationInWindow

            if !self.visibleIslandRect.contains(point) {
                self.collapseIsland()
            }

            return event
        }

        // Handles clicks in other applications.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.collapseIsland()
            }
        }
    }

    private var visibleIslandRect: NSRect {
        let width: CGFloat = presentation.isExpanded ? 320 : 280
        let height: CGFloat = presentation.isExpanded ? 200 : 40

        // NSWindow coordinates use a bottom-left origin.
        return NSRect(
            x: (hostWidth - width) / 2,
            y: hostHeight - height,
            width: width,
            height: height
        )
    }

    func collapseIsland() {
        guard presentation.isExpanded else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            presentation.isExpanded = false
        }
    }

    private func removeOutsideClickMonitors() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }

        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
    }

    deinit {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
        }

        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
        }
    }
}
