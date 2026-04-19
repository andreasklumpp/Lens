import AppKit
import SwiftUI
import ComposableArchitecture

final class PanelManager {
    static let shared = PanelManager()

    private var panel: NSPanel?
    private weak var store: StoreOf<SummaryFeature>?

    private init() {}

    func setup(store: StoreOf<SummaryFeature>) {
        self.store = store
        buildPanel(store: store)
    }

    func show(near selectionBounds: CGRect? = nil) {
        guard let panel else { return }
        positionPanel(near: selectionBounds)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - Private

    private func buildPanel(store: StoreOf<SummaryFeature>) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        let hostingController = NSHostingController(rootView: SummaryView(store: store))
        // Let SwiftUI drive the panel size — panel grows/shrinks as content changes
        hostingController.sizingOptions = [.preferredContentSize]

        panel.contentViewController = hostingController
        self.panel = panel
    }

    private func positionPanel(near bounds: CGRect?) {
        guard let panel, let screen = NSScreen.main else { return }

        let panelSize = panel.frame.size
        var origin: CGPoint

        if let bounds {
            // Place just below the selected text on screen coordinates
            origin = CGPoint(
                x: bounds.midX - panelSize.width / 2,
                y: bounds.minY - panelSize.height - 12
            )
        } else {
            // Fallback: horizontal center, slightly above vertical center
            origin = CGPoint(
                x: screen.frame.midX - panelSize.width / 2,
                y: screen.frame.midY
            )
        }

        // Clamp to visible screen area
        let visible = screen.visibleFrame
        origin.x = max(visible.minX + 8, min(origin.x, visible.maxX - panelSize.width - 8))
        origin.y = max(visible.minY + 8, min(origin.y, visible.maxY - panelSize.height - 8))

        panel.setFrameOrigin(origin)
    }
}
