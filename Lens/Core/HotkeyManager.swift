import AppKit
import ApplicationServices

final class HotkeyManager {
    static let shared = HotkeyManager()

    var onHotkey: (() -> Void)?
    /// Set while the panel is visible; cleared when it hides. Escape is consumed only when non-nil.
    var onEscape: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?

    private init() {}

    func start() {
        if AXIsProcessTrusted() {
            registerEventTap()
        } else {
            promptForAccessibility()
            // Poll until the user grants permission, then auto-register without needing a restart
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self.permissionTimer = nil
                    self.registerEventTap()
                    print("[Lens] Accessibility granted — event tap registered.")
                }
            }
        }
    }

    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
    }

    // MARK: - Private

    private func registerEventTap() {
        guard eventTap == nil else { return } // Already registered

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[Lens] CGEvent.tapCreate failed — check Accessibility permission in System Settings.")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[Lens] Hotkey (⌥Space) registered.")
    }

    private func promptForAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    fileprivate func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Escape (keyCode 53) — only intercept when the panel is open
        if keyCode == 53, let handler = onEscape {
            DispatchQueue.main.async { handler() }
            return nil // Consume
        }

        // ⌥Space: keyCode 49 with only Option modifier active
        let isOption = flags.contains(.maskAlternate)
        let isCmd    = flags.contains(.maskCommand)
        let isCtrl   = flags.contains(.maskControl)

        if keyCode == 49 && isOption && !isCmd && !isCtrl {
            DispatchQueue.main.async { [weak self] in
                self?.onHotkey?()
            }
            return nil // Consume — prevent ⌥Space from reaching other apps
        }

        return Unmanaged.passRetained(event)
    }
}

// MARK: - C Callback (must not capture Swift values)

private let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard type == .keyDown, let refcon else {
        return Unmanaged.passRetained(event)
    }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handleKeyDown(event)
}
