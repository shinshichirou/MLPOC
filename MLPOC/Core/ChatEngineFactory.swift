//
//  ChatEngineFactory.swift
//  MLPOC
//
//  Created by Codex on 31.10.2025.
//

import Foundation

enum ChatEngineFactoryError: LocalizedError {
    case failedToLoadModels
    case tokenizerUnavailable

    var errorDescription: String? {
        switch self {
        case .failedToLoadModels:
            return "Failed to load the Llama CoreML models. Check that Llama32_3B_prefill and Llama32_3B_decode are embedded in the app bundle."
        case .tokenizerUnavailable:
            return "Failed to initialize the tokenizer for the chat model."
        }
    }
}

enum ChatEngineFactory {
    static func makeDefaultEngine(bundle: Bundle = .main) throws -> ChatViewModel.Engine {
        let resourceSubdirectory = "Llama32_3B"
        let prefillDirectory = bundle
            .url(forResource: "Llama32_3B_prefill", withExtension: "mlmodelc", subdirectory: resourceSubdirectory)?
            .deletingLastPathComponent()
            ?? bundle
                .url(forResource: "Llama32_3B_prefill", withExtension: "mlmodelc")?
                .deletingLastPathComponent()

        let tokenizer = try HuggingFaceTokenizer(
            bundle: bundle,
            resourceSubdirectory: resourceSubdirectory,
            modelDirectory: prefillDirectory
        )

        let config = OnDeviceChatRunner.Config(
            maxContext: 2048,
            maxNewTokens: 256,
            temperature: 0.7,
            topK: 40,
            topP: 0.9,
            prefillResourceName: "Llama32_3B_prefill",
            decodeResourceName: "Llama32_3B_decode",
            resourceSubdirectory: resourceSubdirectory
        )

        guard let runner = OnDeviceChatRunner(config: config, bundle: bundle) else {
            throw ChatEngineFactoryError.failedToLoadModels
        }

        let systemPrompt = """
        You are a helpful on-device assistant based on Llama 3.2 3B. \
        Provide concise, factual replies and mention when you are unsure.
        """

        return ChatViewModel.Engine(
            runner: runner,
            tokenizer: tokenizer,
            systemPrompt: systemPrompt
        )
    }
}
