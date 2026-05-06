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
                LabeledContent("Model") {
                    TextField("", text: $modelName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 210)
                }

                OllamaStatusRow(modelName: modelName)
            }

            Section {
                DisclosureGroup("Advanced") {
                    LabeledContent("Server URL") {
                        TextField("", text: $ollamaURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 210)
                    }
                }
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

// MARK: - OllamaStatusRow

private struct OllamaStatusRow: View {
    let modelName: String
    private var manager: OllamaManager { OllamaManager.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Server") {
                HStack(spacing: 6) {
                    serverIndicator
                    Text(manager.serverStatus.label)
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Model") {
                HStack(spacing: 6) {
                    if case let .pulling(progress) = manager.modelStatus {
                        ProgressView(value: progress)
                            .frame(width: 80)
                        Text("\(Int(progress * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        modelIndicator
                        Text(manager.modelStatus.label)
                            .foregroundStyle(.secondary)
                        if manager.modelStatus == .unknown || {
                            if case .failed = manager.modelStatus { return true }
                            return false
                        }() {
                            Button("Pull") {
                                Task { await manager.pullModel(modelName) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(manager.serverStatus != .running)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var serverIndicator: some View {
        switch manager.serverStatus {
        case .running:
            Circle().fill(.green).frame(width: 8, height: 8)
        case .starting, .downloading:
            ProgressView().controlSize(.mini)
        case .failed:
            Circle().fill(.red).frame(width: 8, height: 8)
        case .idle:
            Circle().fill(.secondary).frame(width: 8, height: 8)
        }
    }

    @ViewBuilder
    private var modelIndicator: some View {
        switch manager.modelStatus {
        case .available:
            Circle().fill(.green).frame(width: 8, height: 8)
        case .checking, .pulling:
            ProgressView().controlSize(.mini)
        case .failed:
            Circle().fill(.red).frame(width: 8, height: 8)
        case .unknown:
            Circle().fill(.orange).frame(width: 8, height: 8)
        }
    }
}
