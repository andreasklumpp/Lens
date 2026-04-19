import AppKit
import ApplicationServices
import ComposableArchitecture
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Stores

    private(set) var summaryStore: StoreOf<SummaryFeature>!
    private(set) var settingsStore: StoreOf<SettingsFeature>!

    // MARK: - UI

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var phaseObservationTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        summaryStore = Store(initialState: SummaryFeature.State()) { SummaryFeature() }
        settingsStore = Store(initialState: SettingsFeature.State()) { SettingsFeature() }

        PanelManager.shared.setup(store: summaryStore)

        setupMenubar()
        setupHotkey()
        requestAccessibilityIfNeeded()
        startPhaseObservation()
    }

    func applicationWillTerminate(_ notification: Notification) {
        phaseObservationTask?.cancel()
        HotkeyManager.shared.stop()
    }

    // MARK: - Menubar

    private func setupMenubar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Lens")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        // Useful during development — remove once everything works
        menu.addItem(withTitle: "Test Panel", action: #selector(testPanel), keyEquivalent: "t")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Lens", action: #selector(quitApp), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        HotkeyManager.shared.onHotkey = { [weak self] in
            guard let self else { return }
            self.summaryStore.send(.hotkeyPressed)

            // The reducer transitions phase synchronously; show panel unless we just dismissed
            if self.summaryStore.phase != .idle {
                PanelManager.shared.show()
            }
        }
        HotkeyManager.shared.start()
    }

    // MARK: - Phase Observation
    //
    // Watches summaryStore.phase via lightweight polling so the panel hides
    // when the store goes back to .idle (e.g. after dismiss action from the view).
    // We avoid store.publisher because it was removed in TCA 1.15+.

    private func startPhaseObservation() {
        phaseObservationTask = Task { @MainActor [weak self] in
            var lastPhase: SummaryFeature.State.Phase = .idle
            while !Task.isCancelled {
                guard let self else { return }
                let currentPhase = self.summaryStore.phase
                if currentPhase != lastPhase {
                    lastPhase = currentPhase
                    if currentPhase == .idle {
                        PanelManager.shared.hide()
                        HotkeyManager.shared.onEscape = nil
                    } else {
                        HotkeyManager.shared.onEscape = { [weak self] in
                            self?.summaryStore.send(.dismiss)
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
            }
        }
    }

    // MARK: - Accessibility

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        // HotkeyManager.start() will also prompt; this is an early nudge on first launch
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Actions

    @objc private func testPanel() {
        summaryStore.send(.textExtracted("This is a test. The panel should appear with a streaming summary below."))
        PanelManager.shared.show()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Lens Settings"
            window.contentViewController = NSHostingController(rootView: SettingsView(store: settingsStore))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
