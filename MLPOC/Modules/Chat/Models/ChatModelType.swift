//
//  ChatModelType.swift
//  MLPOC
//
//  Created by Codex on 11.11.2025.
//

import Foundation

struct ChatModelConfiguration {
    let displayName: String
    let resourceSubdirectory: String?
    let prefillResourceName: String
    let decodeResourceName: String
    let maxContext: Int
    let maxNewTokens: Int
    let temperature: Float
    let topK: Int
    let topP: Float
    let systemPrompt: String
}

enum ChatModelType: String, CaseIterable, Identifiable {
    case empty = "Unconfigured"

    var id: Self { self }

    var title: String {
        "No On-Device Model"
    }

    var capabilityDescription: String {
        "Add a Core ML chat model bundle to enable responses."
    }

    var memorySummary: String {
        "Not available"
    }

    var configuration: ChatModelConfiguration? {
        nil
    }
}
