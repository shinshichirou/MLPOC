//
//  GGUFChatEngineFactory.swift
//  MLPOC
//
//  Created by Codex on 11.12.2025.
//

import Foundation

enum GGUFChatEngineFactoryError: LocalizedError {
    case modelUnavailable(GGUFModelType)
    case missingModelFile(GGUFModelType)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let model):
            return "\(model.title) is not configured yet."
        case .missingModelFile(let model):
            return "Could not find \(model.title) GGUF file in the bundle. Place the .gguf file under MLPOC/MLModels/GGUFModels."
        }
    }
}

enum GGUFChatEngineFactory {
    static func makeEngine(for model: GGUFModelType, bundle: Bundle = .main) throws -> ChatViewModel.Engine {
        guard let modelConfiguration = model.configuration else {
            throw GGUFChatEngineFactoryError.modelUnavailable(model)
        }

        guard let modelURL = locateModel(
            named: modelConfiguration.filename,
            subdirectory: modelConfiguration.resourceSubdirectory,
            in: bundle
        ) else {
            throw GGUFChatEngineFactoryError.missingModelFile(model)
        }

        let runnerConfig = GGUFChatRunner.Config(
            modelURL: modelURL,
            maxContext: modelConfiguration.maxContext,
            maxNewTokens: modelConfiguration.maxNewTokens,
            temperature: modelConfiguration.temperature,
            topP: modelConfiguration.topP,
            threadCount: modelConfiguration.threadCount,
            executableURL: nil
        )

        let runner = GGUFChatRunner(config: runnerConfig)
        let tokenizer = PassThroughTokenizer()

        return ChatViewModel.Engine(
            runner: runner,
            tokenizer: tokenizer,
            systemPrompt: modelConfiguration.systemPrompt
        )
    }

    private static func locateModel(named name: String, subdirectory: String?, in bundle: Bundle) -> URL? {
        let fm = FileManager.default

        if let subdirectory,
           let url = bundle.url(forResource: name, withExtension: "gguf", subdirectory: subdirectory),
           fm.fileExists(atPath: url.path) {
            return url
        }

        if let url = bundle.url(forResource: name, withExtension: "gguf"),
           fm.fileExists(atPath: url.path) {
            return url
        }

        // Try raw file path relative to bundle resources to aid development builds
        let candidate = bundle.bundleURL
            .appendingPathComponent(subdirectory ?? "")
            .appendingPathComponent("\(name).gguf")

        if fm.fileExists(atPath: candidate.path) {
            return candidate
        }

        return nil
    }
}
