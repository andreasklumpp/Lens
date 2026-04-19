import ComposableArchitecture
import Foundation

@Reducer
struct SummaryFeature {

    @ObservableState
    struct State: Equatable {
        var phase: Phase = .idle
        var selectedText: String = ""
        var summaryTokens: [String] = []
        var error: String? = nil

        enum Phase: Equatable {
            case idle, extracting, thinking, streaming, done, error
        }

        var summaryText: String { summaryTokens.joined() }
    }

    enum Action {
        case hotkeyPressed
        case textExtracted(String)
        case extractionFailed(String)
        case tokenReceived(String)
        case streamingComplete
        case streamingFailed(String)
        case dismiss
    }

    @Dependency(\.llmClient) var llmClient
    @Dependency(\.textExtractor) var textExtractor

    private enum CancelID { case streaming }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .hotkeyPressed:
                // Toggle: dismiss if already active
                if state.phase != .idle {
                    return .send(.dismiss)
                }
                state.phase = .extracting
                state.summaryTokens = []
                state.error = nil
                return .run { send in
                    do {
                        let text = try await textExtractor.extractSelectedText()
                        await send(.textExtracted(text))
                    } catch {
                        await send(.extractionFailed(error.localizedDescription))
                    }
                }

            case let .textExtracted(text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    state.phase = .error
                    state.error = "Please select some text first."
                    return .none
                }
                state.selectedText = trimmed
                state.phase = .thinking
                return .run { [llmClient, trimmed] send in
                    do {
                        for try await token in llmClient.summarize(trimmed) {
                            await send(.tokenReceived(token))
                        }
                        await send(.streamingComplete)
                    } catch {
                        await send(.streamingFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.streaming)

            case let .extractionFailed(message):
                state.phase = .error
                state.error = message
                return .none

            case let .tokenReceived(token):
                state.phase = .streaming
                state.summaryTokens.append(token)
                return .none

            case .streamingComplete:
                state.phase = .done
                return .none

            case let .streamingFailed(message):
                state.phase = .error
                state.error = message
                return .none

            case .dismiss:
                state.phase = .idle
                state.selectedText = ""
                state.summaryTokens = []
                state.error = nil
                return .cancel(id: CancelID.streaming)
            }
        }
    }
}
