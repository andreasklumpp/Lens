# Lens

A lightweight macOS menubar app that summarizes any selected text using a local LLM — no cloud, no clipboard paste, no context switching.

Select text anywhere, press **⌥Space**, and a floating summary appears next to your cursor.

![Lens panel showing a German summary](docs/screenshot.png)

---

## Features

- **Global hotkey** — ⌥Space works in any app, any window
- **Floating panel** — appears near your selection, never steals focus
- **Local LLM via Ollama** — fully on-device, works offline, GPU-accelerated on Apple Silicon
- **Language-aware** — summaries are always in the same language as the selected text
- **Minimal footprint** — lives in the menubar, no Dock icon

---

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel Mac
- [Ollama](https://ollama.com) (for real summaries — see setup below)
- Xcode 15+ (to build from source)

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

### 3. Install Ollama (for real summaries)

```bash
brew install ollama
ollama serve          # starts the local inference server
ollama pull llama3.2  # downloads the default model (~2 GB)
```

Then open **Lens → Settings**, uncheck **Use Mock LLM**, and you're live.

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
| Ollama URL | Default: `http://localhost:11434` |
| Model | Any model pulled via `ollama pull` — default: `llama3.2` |

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
│       └── SettingsView.swift    # Settings window
└── Core/
    ├── LLMClient.swift         # Protocol + OllamaClient + MockLLMClient
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

No other third-party dependencies. Text extraction uses `AXUIElement` (Accessibility framework). The hotkey uses `CGEventTap` (CoreGraphics). Ollama is an optional external process.

---

## Privacy

- No data leaves your machine
- No analytics, no telemetry
- Selected text is sent only to the local Ollama process (or discarded in mock mode)
- Accessibility permission is used exclusively to read selected text

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Acknowledgements

Inspired by [Hex](https://github.com/kitlangton/Hex) by Kit Langton — same architectural pattern, different superpower.
