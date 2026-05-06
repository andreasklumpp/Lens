import Foundation
import Observation

// MARK: - Status Types

enum OllamaServerStatus: Equatable {
    case idle
    case starting
    case downloading
    case running
    case failed(String)

    var label: String {
        switch self {
        case .idle:            return "Not started"
        case .starting:        return "Starting…"
        case .downloading:     return "Downloading Ollama…"
        case .running:         return "Running"
        case let .failed(msg): return "Failed: \(msg)"
        }
    }
}

enum OllamaModelStatus: Equatable {
    case unknown
    case checking
    case available
    case pulling(Double)    // 0–1 progress
    case failed(String)

    var label: String {
        switch self {
        case .unknown:            return "Not pulled"
        case .checking:           return "Checking…"
        case .available:          return "Available"
        case let .pulling(p):     return "Pulling \(Int(p * 100))%"
        case let .failed(msg):    return "Failed: \(msg)"
        }
    }
}

// MARK: - OllamaManager

@MainActor
@Observable
final class OllamaManager {

    static let shared = OllamaManager()
    private init() {}

    private(set) var serverStatus: OllamaServerStatus = .idle
    private(set) var modelStatus: OllamaModelStatus = .unknown

    private var process: Process?
    private var ownedProcess = false

    private let port = 11434
    private var localBaseURL: String { "http://127.0.0.1:\(port)" }

    // MARK: - Public API

    /// Start ollama (if needed) and verify the given model is pulled.
    func start(model: String) async {
        // Already running externally or by us?
        if await checkHealth() {
            serverStatus = .running
            await verifyModel(model)
            return
        }

        serverStatus = .starting

        do {
            let binary = try await ensureBinary()
            try launchProcess(binary: binary)
            try await waitUntilReady()
            ownedProcess = true
            serverStatus = .running
            await verifyModel(model)
        } catch {
            serverStatus = .failed(error.localizedDescription)
        }
    }

    /// Stop the managed subprocess (no-op if we didn't start it).
    func stop() {
        guard ownedProcess else { return }
        process?.terminate()
        process = nil
        ownedProcess = false
    }

    /// Pull the given model, updating modelStatus with progress.
    func pullModel(_ model: String) async {
        guard serverStatus == .running else { return }
        modelStatus = .pulling(0)
        do {
            try await streamPull(model: model)
            modelStatus = .available
        } catch {
            modelStatus = .failed(error.localizedDescription)
        }
    }

    // MARK: - Model Verification

    private func verifyModel(_ model: String) async {
        modelStatus = .checking
        do {
            if try await isModelAvailable(model) {
                modelStatus = .available
            } else {
                modelStatus = .unknown
            }
        } catch {
            modelStatus = .unknown
        }
    }

    private func isModelAvailable(_ model: String) async throws -> Bool {
        let url = URL(string: "\(localBaseURL)/api/tags")!
        let (data, _) = try await URLSession.shared.data(from: url)

        struct TagsResponse: Decodable {
            struct ModelInfo: Decodable { let name: String }
            let models: [ModelInfo]
        }

        let response = try JSONDecoder().decode(TagsResponse.self, from: data)
        let baseName = model.components(separatedBy: ":")[0]
        return response.models.contains { $0.name.hasPrefix(baseName) }
    }

    private func streamPull(model: String) async throws {
        let url = URL(string: "\(localBaseURL)/api/pull")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["name": model, "stream": "true"])

        struct PullChunk: Decodable {
            let status: String
            let total: Int64?
            let completed: Int64?
        }

        let (bytes, _) = try await URLSession.shared.bytes(for: request)
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(PullChunk.self, from: data)
            else { continue }

            if let total = chunk.total, let completed = chunk.completed, total > 0 {
                modelStatus = .pulling(Double(completed) / Double(total))
            }
            if chunk.status == "success" { break }
        }
    }

    // MARK: - Binary Management

    private var downloadedBinaryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Lens/bin/ollama")
    }

    private func ensureBinary() async throws -> URL {
        // 1. Binary bundled inside the app (optional — developer can add it)
        if let bundled = Bundle.main.url(forResource: "ollama", withExtension: nil) {
            return bundled
        }

        // 2. System installations
        let systemPaths = [
            "/usr/local/bin/ollama",
            "/opt/homebrew/bin/ollama",
            "\(NSHomeDirectory())/.ollama/bin/ollama",
        ]
        for path in systemPaths where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        // 3. Previously downloaded binary
        if FileManager.default.isExecutableFile(atPath: downloadedBinaryURL.path) {
            return downloadedBinaryURL
        }

        // 4. Download from GitHub releases
        serverStatus = .downloading
        return try await downloadOllama()
    }

    private func downloadOllama() async throws -> URL {
        guard let downloadURL = URL(string: "https://github.com/ollama/ollama/releases/latest/download/ollama-darwin") else {
            throw OllamaManagerError.downloadFailed
        }

        let destDir = downloadedBinaryURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)

        if FileManager.default.fileExists(atPath: downloadedBinaryURL.path) {
            try FileManager.default.removeItem(at: downloadedBinaryURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: downloadedBinaryURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: downloadedBinaryURL.path)

        return downloadedBinaryURL
    }

    // MARK: - Process Lifecycle

    private func launchProcess(binary: URL) throws {
        let proc = Process()
        proc.executableURL = binary
        proc.arguments = ["serve"]

        var env = ProcessInfo.processInfo.environment
        env["OLLAMA_HOST"] = "127.0.0.1:\(port)"
        proc.environment = env

        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        try proc.run()
        process = proc
    }

    private func waitUntilReady(timeout: TimeInterval = 30) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await checkHealth() { return }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 s
        }
        throw OllamaManagerError.timeout
    }

    private func checkHealth() async -> Bool {
        guard let url = URL(string: "\(localBaseURL)/api/tags") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - Errors

enum OllamaManagerError: LocalizedError {
    case timeout
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .timeout:        return "Ollama failed to start within 30 seconds."
        case .downloadFailed: return "Failed to download Ollama binary."
        }
    }
}
