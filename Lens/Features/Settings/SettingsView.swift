import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    @AppStorage("ollamaURL") private var ollamaURL = "http://localhost:11434"
    @AppStorage("modelName") private var modelName = "llama3.2"

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
                    TextField("http://localhost:11434", text: $ollamaURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 210)
                }

                LabeledContent("Model") {
                    TextField("llama3.2", text: $modelName)
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
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 280)
    }
}
