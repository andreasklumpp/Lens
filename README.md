# Lens

A lightweight macOS menubar app that summarizes any selected text using a local LLM — no cloud, no clipboard paste, no context switching.

Select text anywhere, press **⌥Space**, and a floating summary appears next to your cursor.

![Lens panel showing a German summary](docs/screenshot.png)

---

## Features

- **Global hotkey** — ⌥Space works in any app, any window
- **Floating panel** — appears near your selection, never steals focus
- **Local LLM via Ollama** — fully on-device, works offline, GPU-accelerated on Apple Silicon
- **Zero-setup Ollama** — Lens starts Ollama automatically on launch; downloads it if not installed
- **Language-aware** — summaries are always in the same language as the selected text
- **Customizable system prompt** — tune the summary style directly from Settings
- **Minimal footprint** — lives in the menubar, no Dock icon

---

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel Mac
- Xcode 15+ (to build from source)

> Ollama is managed automatically by Lens. No manual installation required.

---

## Setup

### 1. Clone and open in Xcode

```bash
git clone https://github.com/andreasklumpp/Lens.git
cd Lens
open Lens.xcodeproj
```

Xcode will resolve the [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) dependency automatically on first open.

### 2. Build and run

Select the **Lens** scheme and press **⌘R**. On first launch, macOS will ask for Accessibility permission — this is required to read selected text system-wide.

> **System Settings → Privacy & Security → Accessibility → Lens ✓**

Once granted, the hotkey activates automatically (no restart needed).

### 3. That's it

Lens starts Ollama automatically in the background. If Ollama isn't installed, it downloads the binary on first launch. The default model (`llama3.2`) is pulled automatically if not already available — or you can pull any model from **Settings**.

---

## Usage

| Action | Result |
|---|---|
| Select text → press **⌥Space** | Opens summary panel |
| Press **⌥Space** again | Dismisses panel |
| Press **Esc** | Dismisses panel |
| Click **✕** in panel | Dismisses panel |
| Nothing selected → press **⌥Space** | Shows "Please select some text first" |

---

## Settings

Open via the menubar icon → **Settings…**

| Setting | Description |
|---|---|
| Model | Any model pulled via `ollama pull` or the Pull button — default: `llama3.2` |
| Server status | Live indicator showing whether Ollama is running |
| Model status | Shows if the selected model is available; includes a **Pull** button to download it |
| System Prompt | Controls how the LLM summarizes text; editable with a Reset to Default button |
| Server URL *(Advanced)* | Default: `http://localhost:11434` |

Changes take effect immediately on the next summary request.

**Recommended models:**

| Model | Size | Notes |
|---|---|---|
| `llama3.2` | 2 GB | Good default, fast |
| `qwen2.5:7b` | 4.7 GB | Higher quality |
| `phi4` | 9.1 GB | Excellent for summarization |

---

## Architecture

Lens is built with [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture) and follows a strict unidirectional data flow.

```
Lens/
├── App/
│   ├── LensApp.swift           # @main entry point, no Dock icon (LSUIElement)
│   └── AppDelegate.swift       # Menubar, hotkey wiring, store lifecycle
├── Features/
│   ├── Summary/
│   │   ├── SummaryFeature.swift  # TCA Reducer — state machine for the summary flow
│   │   └── SummaryView.swift     # Floating panel UI, all phases
│   └── Settings/
│       ├── SettingsFeature.swift # TCA Reducer — settings state
│       └── SettingsView.swift    # Settings window with live Ollama status
└── Core/
    ├── LLMClient.swift         # Protocol + OllamaClient (reads model/URL/prompt from UserDefaults)
    ├── OllamaManager.swift     # Auto-starts Ollama, downloads binary if needed, pulls models
    ├── TextExtractor.swift     # AXUIElement selected-text extraction (+ ⌘C fallback)
    ├── HotkeyManager.swift     # Global CGEventTap for ⌥Space and Esc
    └── PanelManager.swift      # Borderless, non-activating NSPanel lifecycle
```

### State machine

```
idle → extracting → thinking → streaming → done
                ↘                        ↗
                        error
```

Any state → `dismiss` → `idle`

### Adding a different LLM backend

Only `LLMClient.swift` needs to change. Implement the protocol:

```swift
protocol LLMClientProtocol: Sendable {
    func summarize(_ text: String) -> AsyncThrowingStream<String, Error>
}
```

Then swap the `liveValue` in `LLMClientKey`. The reducer, view, and panel are unaffected.

---

## Dependencies

| Package | Purpose |
|---|---|
| [swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture) | State management |

No other third-party dependencies. Text extraction uses `AXUIElement` (Accessibility framework). The hotkey uses `CGEventTap` (CoreGraphics). Ollama is managed as a subprocess via `Foundation.Process`.

---

## Privacy

- No data leaves your machine
- No analytics, no telemetry
- Selected text is sent only to the local Ollama process
- Accessibility permission is used exclusively to read selected text

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Acknowledgements

Inspired by [Hex](https://github.com/kitlangton/Hex) by Kit Langton — same architectural pattern, different superpower.
