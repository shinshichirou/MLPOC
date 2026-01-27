//
//  ChatEngineFactory.swift
//  MLPOC
//
//  Created by Codex on 31.10.2025.
//

import Foundation

enum ChatEngineFactoryError: LocalizedError {
    case modelUnavailable(ChatModelType)
    case failedToLoadModels
    case tokenizerUnavailable

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let model):
            return "\(model.title) is not configured yet. Add the chat Core ML resources to enable it."
        case .failedToLoadModels:
            return "Failed to load the selected chat Core ML models. Verify that the prefill and decode bundles are embedded in the app."
        case .tokenizerUnavailable:
            return "Failed to initialize the tokenizer for the selected chat model."
        }
    }
}

enum ChatEngineFactory {
    static func makeEngine(for model: ChatModelType, bundle: Bundle = .main) throws -> ChatViewModel.Engine {
        guard let modelConfiguration = model.configuration else {
            throw ChatEngineFactoryError.modelUnavailable(model)
        }

        let resourceSubdirectory = modelConfiguration.resourceSubdirectory
        let prefillDirectory = bundle
            .url(
                forResource: modelConfiguration.prefillResourceName,
                withExtension: "mlmodelc",
                subdirectory: resourceSubdirectory
            )?
            .deletingLastPathComponent()
            ?? bundle
                .url(forResource: modelConfiguration.prefillResourceName, withExtension: "mlmodelc")?
                .deletingLastPathComponent()

        let tokenizer = try HuggingFaceTokenizer(
            bundle: bundle,
            resourceSubdirectory: resourceSubdirectory,
            modelDirectory: prefillDirectory
        )

        let config = OnDeviceChatRunner.Config(
            maxContext: modelConfiguration.maxContext,
            maxNewTokens: modelConfiguration.maxNewTokens,
            temperature: modelConfiguration.temperature,
            topK: modelConfiguration.topK,
            topP: modelConfiguration.topP,
            prefillResourceName: modelConfiguration.prefillResourceName,
            decodeResourceName: modelConfiguration.decodeResourceName,
            resourceSubdirectory: resourceSubdirectory
        )

        guard let runner = OnDeviceChatRunner(config: config, bundle: bundle) else {
            throw ChatEngineFactoryError.failedToLoadModels
        }

        return ChatViewModel.Engine(
            runner: runner,
            tokenizer: tokenizer,
            systemPrompt: modelConfiguration.systemPrompt
        )
    }
}
