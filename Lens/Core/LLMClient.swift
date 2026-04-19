import Dependencies
import Foundation

// MARK: - Protocol

protocol LLMClientProtocol: Sendable {
    func summarize(_ text: String) -> AsyncThrowingStream<String, Error>
}

// MARK: - Ollama (on-device via Metal)

struct OllamaClient: LLMClientProtocol {

    private static let systemPrompt = """
        Summarize the following text concisely in 2–3 sentences.
        Focus on the key points. Do not add commentary or preamble.
        Always respond in the same language as the input text.
        """

    func summarize(_ text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let baseURL = UserDefaults.standard.string(forKey: "ollamaURL")
                        ?? "http://localhost:11434"
                    let model = UserDefaults.standard.string(forKey: "modelName")
                        ?? "llama3.2"

                    guard let url = URL(string: "\(baseURL)/api/generate") else {
                        throw OllamaError.invalidURL(baseURL)
                    }

                    var request = URLRequest(url: url, timeoutInterval: 60)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body = OllamaRequest(
                        model: model,
                        prompt: "\(Self.systemPrompt)\n\nText:\n\(text)\n\nSummary:",
                        stream: true
                    )
                    request.httpBody = try JSONEncoder().encode(body)

                    let (asyncBytes, urlResponse) = try await URLSession.shared.bytes(for: request)

                    guard let http = urlResponse as? HTTPURLResponse else {
                        throw OllamaError.invalidResponse
                    }
                    guard (200...299).contains(http.statusCode) else {
                        throw OllamaError.httpError(http.statusCode)
                    }

                    for try await line in asyncBytes.lines {
                        guard !line.isEmpty,
                              let data = line.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(OllamaChunk.self, from: data)
                        else { continue }

                        if !chunk.response.isEmpty {
                            continuation.yield(chunk.response)
                        }
                        if chunk.done { break }
                    }

                    continuation.finish()
                } catch let error as OllamaError {
                    continuation.finish(throwing: error)
                } catch let urlError as URLError
                    where urlError.code == .cannotConnectToHost
                       || urlError.code == .networkConnectionLost {
                    continuation.finish(throwing: OllamaError.notRunning)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Ollama wire types

private struct OllamaRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
}

private struct OllamaChunk: Decodable {
    let response: String
    let done: Bool
}

// MARK: - Errors

enum OllamaError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)
    case notRunning

    var errorDescription: String? {
        switch self {
        case let .invalidURL(u):  return "Invalid Ollama URL: \(u)"
        case .invalidResponse:    return "Unexpected response from Ollama."
        case let .httpError(c):   return "Ollama returned HTTP \(c)."
        case .notRunning:
            return "Ollama isn't running. Install with: brew install ollama\nThen start: ollama serve"
        }
    }
}

// MARK: - TCA Dependency

private enum LLMClientKey: DependencyKey {
    static let liveValue: any LLMClientProtocol = OllamaClient()
    static let testValue: any LLMClientProtocol = OllamaClient()
}

extension DependencyValues {
    var llmClient: any LLMClientProtocol {
        get { self[LLMClientKey.self] }
        set { self[LLMClientKey.self] = newValue }
    }
}
