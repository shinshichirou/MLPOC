//
//  GGUFModelType.swift
//  MLPOC
//
//  Created by Codex on 11.12.2025.
//

import Foundation

struct GGUFModelConfiguration {
    let displayName: String
    let filename: String
    let systemPrompt: String
    let maxContext: Int
    let maxNewTokens: Int
    let temperature: Float
    let topP: Float
    let threadCount: Int
    let resourceSubdirectory: String?
}

enum GGUFModelType: String, CaseIterable, Identifiable {
    case empty = "Unconfigured"
    case llama3Instruct = "Llama-3.1 Instruct (Q4_K_M)"
    case tinyLlamaChat = "TinyLlama Chat (Q5_K_M)"
    case gemma3Instruction = "Gemma 3 1B Instruct (Q4_0)"

    var id: Self { self }

    var title: String {
        switch self {
        case .empty:
            return "No GGUF Model"
        case .llama3Instruct:
            return "Llama 3.1 Instruct (Q4_K_M)"
        case .tinyLlamaChat:
            return "TinyLlama 1.1B Chat (Q5_K_M)"
        case .gemma3Instruction:
            return "Gemma 3 1B Instruct (Q4_0)"
        }
    }

    var details: String {
        switch self {
        case .empty:
            return "Place a GGUF model in the app bundle to enable replies."
        case .llama3Instruct:
            return "Balanced quality for on-device responses. Expects a chat prompt template."
        case .tinyLlamaChat:
            return "Lightweight model for quick tests and low-memory devices."
        case .gemma3Instruction:
            return "Compact Google Gemma 3 Instruct tuned for short, helpful responses."
        }
    }

    var configuration: GGUFModelConfiguration? {
        switch self {
        case .empty:
            return nil
        case .llama3Instruct:
            return GGUFModelConfiguration(
                displayName: title,
                filename: "llama-3.1-8b-instruct-q4_k_m",
                systemPrompt: "You are a concise, helpful assistant that answers clearly.",
                maxContext: 4096,
                maxNewTokens: 256,
                temperature: 0.6,
                topP: 0.95,
                threadCount: max(1, ProcessInfo.processInfo.processorCount - 1),
                resourceSubdirectory: "GGUFModels"
            )
        case .tinyLlamaChat:
            return GGUFModelConfiguration(
                displayName: title,
                filename: "tinyllama-1.1b-chat-v1.0-q5_k_m",
                systemPrompt: "You are a lightweight assistant. Keep answers short.",
                maxContext: 2048,
                maxNewTokens: 200,
                temperature: 0.7,
                topP: 0.9,
                threadCount: max(1, ProcessInfo.processInfo.processorCount - 1),
                resourceSubdirectory: "GGUFModels"
            )
        case .gemma3Instruction:
            return GGUFModelConfiguration(
                displayName: title,
                filename: "gemma-3-1b-it-q4_0",
                systemPrompt: "You are Gemma, a concise helpful assistant. Respond briefly and clearly.",
                maxContext: 4096,
                maxNewTokens: 256,
                temperature: 0.6,
                topP: 0.95,
                threadCount: max(1, ProcessInfo.processInfo.processorCount - 1),
                resourceSubdirectory: "GGUFModels"
            )
        }
    }
}
