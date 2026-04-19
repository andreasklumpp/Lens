import AppKit
import ApplicationServices
import Dependencies

// MARK: - Client

struct TextExtractorClient {
    var extractSelectedText: @Sendable () async throws -> String
}

// MARK: - TCA Dependency

extension TextExtractorClient: DependencyKey {
    static let liveValue = TextExtractorClient(
        extractSelectedText: {
            // Strategy 1: Accessibility API (preferred)
            if let text = try? axSelectedText(), !text.isEmpty {
                return text
            }
            // Strategy 2: Simulate ⌘C (fallback for Electron apps, browsers, etc.)
            return try await clipboardFallback()
        }
    )

    static let testValue = TextExtractorClient(
        extractSelectedText: { "This is test selected text for summarization purposes." }
    )
}

extension DependencyValues {
    var textExtractor: TextExtractorClient {
        get { self[TextExtractorClient.self] }
        set { self[TextExtractorClient.self] = newValue }
    }
}

// MARK: - AX Strategy

private func axSelectedText() throws -> String? {
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
        throw TextExtractorError.noFrontmostApp
    }

    let pid = frontmostApp.processIdentifier
    let appElement = AXUIElementCreateApplication(pid)

    var focusedElementRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef
    ) == .success, let focusedElement = focusedElementRef else {
        return nil
    }

    var selectedTextRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
        // swiftlint:disable:next force_cast
        focusedElement as! AXUIElement,
        kAXSelectedTextAttribute as CFString,
        &selectedTextRef
    ) == .success else {
        return nil
    }

    return selectedTextRef as? String
}

// MARK: - Clipboard Fallback

private func clipboardFallback() async throws -> String {
    let pasteboard = NSPasteboard.general
    let savedContents = pasteboard.string(forType: .string)
    let savedChangeCount = pasteboard.changeCount

    pasteboard.clearContents()

    // Simulate ⌘C (keyCode 8 = C)
    let source = CGEventSource(stateID: .hidSystemState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    keyDown?.post(tap: .cgAnnotatedSessionEventTap)
    keyUp?.post(tap: .cgAnnotatedSessionEventTap)

    try await Task.sleep(nanoseconds: 150_000_000) // 150 ms for clipboard to settle

    let copied = pasteboard.string(forType: .string) ?? ""

    // Restore previous clipboard contents if we changed it
    if pasteboard.changeCount != savedChangeCount {
        pasteboard.clearContents()
        if let saved = savedContents {
            pasteboard.setString(saved, forType: .string)
        }
    }

    if copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw TextExtractorError.noTextSelected
    }

    return copied
}

// MARK: - Errors

enum TextExtractorError: LocalizedError {
    case noFrontmostApp
    case noTextSelected

    var errorDescription: String? {
        switch self {
        case .noFrontmostApp: return "Could not determine the frontmost application."
        case .noTextSelected: return "Please select some text first."
        }
    }
}
