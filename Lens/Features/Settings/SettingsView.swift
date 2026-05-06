import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    @AppStorage("ollamaURL") private var ollamaURL = "http://localhost:11434"
    @AppStorage("modelName") private var modelName = "llama3.2"
    @AppStorage("systemPrompt") private var systemPrompt = OllamaClient.defaultSystemPrompt

    var body: some View {
        Form {
            Section("Hotkey") {
                LabeledContent("Trigger") {
                    Text("⌥Space")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Section("Ollama") {
                LabeledContent("Server URL") {
                    TextField("", text: $ollamaURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 210)
                }

                LabeledContent("Model") {
                    TextField("", text: $modelName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 210)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Setup (run once in Terminal):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("brew install ollama\nollama serve\nollama pull \(modelName)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.top, 2)
            }

            Section("Summary Style") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("System Prompt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    Button("Reset to Default") {
                        systemPrompt = OllamaClient.defaultSystemPrompt
                    }
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 520)
    }
}
