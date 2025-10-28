//
//  QwenEngineFactory.swift
//  MLPOC
//
//  Created by Codex on 01.11.2025.
//

import Foundation

enum QwenEngineFactoryError: LocalizedError {
    case failedToLoadModels

    var errorDescription: String? {
        switch self {
        case .failedToLoadModels:
            return "Failed to load the Qwen CoreML models. Make sure Qwen1p5_1_8B_prompt_int4.mlmodelc and Qwen1p5_1_8B_decode_int4.mlmodelc are included in the app bundle."
        }
    }
}

enum QwenEngineFactory {
    static func makeDefaultEngine(bundle: Bundle = .main) throws -> QwenChatViewModel.Engine {
        let resourceSubdirectory = "Qwen-1_8B"
        let tokenizer = try QwenTokenizer(bundle: bundle, resourceSubdirectory: resourceSubdirectory)

        let config = QwenRunner.Config(
            maxContext: 2048,
            maxNewTokens: 256,
            temperature: 0.7,
            topK: 40,
            topP: 0.9,
            promptResourceName: "Qwen1p5_1_8B_prompt_int4",
            decodeResourceName: "Qwen1p5_1_8B_decode_int4",
            resourceSubdirectory: resourceSubdirectory
        )

        guard let runner = QwenRunner(config: config, bundle: bundle) else {
            throw QwenEngineFactoryError.failedToLoadModels
        }

        let systemPrompt = """
        You are Qwen, a helpful and concise assistant that runs entirely on-device. \
        Provide short, factual answers and mention when you are uncertain.
        """

        return QwenChatViewModel.Engine(
            runner: runner,
            tokenizer: tokenizer,
            systemPrompt: systemPrompt
        )
    }
}
