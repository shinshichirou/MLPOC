//
//  GGUFChatRunner.swift
//  MLPOC
//
//  Created by Codex on 11.12.2025.
//

import Foundation

enum GGUFChatRunnerError: LocalizedError {
    case wrapperUnavailable
    case executableMissing
    case inferenceFailed(status: Int32, output: String)
    case missingModel

    var errorDescription: String? {
        switch self {
        case .wrapperUnavailable:
            return "Llama.cpp Swift bindings are not linked in this build. Add the wrapper package to run GGUF models in-process."
        case .executableMissing:
            return "Unable to find a llama.cpp executable. Provide a path in GGUFChatRunner.Config."
        case .inferenceFailed(let status, let output):
            return "llama.cpp inference failed with status \(status): \(output)"
        case .missingModel:
            return "GGUF model file is missing."
        }
    }
}

/// Thin adapter that can either call an in-process llama.cpp Swift wrapper (preferred)
/// or fall back to the bundled CLI if the wrapper is not available.
struct GGUFChatRunner: ChatRunning {
    struct Config {
        let modelURL: URL?
        let maxContext: Int
        let maxNewTokens: Int
        let temperature: Float
        let topP: Float
        let threadCount: Int
        /// Optional path to the llama.cpp CLI executable (e.g. `main` or `llama`).
        /// If nil, the runner will try `/usr/bin/env llama`.
        let executableURL: URL?

        init(
            modelURL: URL?,
            maxContext: Int = 2048,
            maxNewTokens: Int = 256,
            temperature: Float = 0.7,
            topP: Float = 0.95,
            threadCount: Int = max(1, ProcessInfo.processInfo.processorCount - 1),
            executableURL: URL? = nil
        ) {
            self.modelURL = modelURL
            self.maxContext = maxContext
            self.maxNewTokens = maxNewTokens
            self.temperature = temperature
            self.topP = topP
            self.threadCount = threadCount
            self.executableURL = executableURL
        }
    }

    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func generate(system: String, user: String, tokenizer: ChatTokenizer) throws -> String {
#if canImport(LlamaCppSwift)
        return try generateWithSwiftWrapper(system: system, user: user)
#else
        return try generateWithCLI(system: system, user: user)
#endif
    }

    // MARK: - Swift wrapper path (compile-time gated)
    #if canImport(LlamaCppSwift)
    private func generateWithSwiftWrapper(system: String, user: String) throws -> String {
        // The actual wrapper API depends on the chosen package.
        // Hook up your preferred llama.cpp Swift bindings here.
        throw GGUFChatRunnerError.wrapperUnavailable
    }
    #endif

    // MARK: - CLI fallback
    private func generateWithCLI(system: String, user: String) throws -> String {
#if os(iOS)
        // iOS cannot spawn external processes, so we require the Swift wrapper path on device builds.
        throw GGUFChatRunnerError.wrapperUnavailable
#else
        guard let modelURL = config.modelURL else { throw GGUFChatRunnerError.missingModel }

        let prompt = makePrompt(system: system, user: user)

        let process = Process()
        var arguments: [String] = []

        if let execURL = config.executableURL {
            process.executableURL = execURL
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            arguments.append("llama")
        }

        arguments.append(contentsOf: [
            "-m", modelURL.path,
            "-p", prompt,
            "-n", "\(config.maxNewTokens)",
            "--ctx-size", "\(config.maxContext)",
            "--temp", "\(config.temperature)",
            "--top-p", "\(config.topP)",
            "-t", "\(config.threadCount)"
        ])

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw GGUFChatRunnerError.executableMissing
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let stdout = String(data: data, encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw GGUFChatRunnerError.inferenceFailed(status: process.terminationStatus, output: stderr.isEmpty ? stdout : stderr)
        }

        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
#endif
    }

    private func makePrompt(system: String, user: String) -> String {
        """
        <|system|>
        \(system)
        <|user|>
        \(user)
        <|assistant|>
        """
    }
}
