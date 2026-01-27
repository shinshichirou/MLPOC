//
//  PassThroughTokenizer.swift
//  MLPOC
//
//  Created by Codex on 11.12.2025.
//

import Foundation

/// Minimal tokenizer placeholder for backends that tokenize internally (e.g. llama.cpp).
/// It keeps the ChatViewModel happy without changing its API surface.
struct PassThroughTokenizer: ChatTokenizer {
    func encode(_ text: String) -> [Int32] { [] }
    func decode(_ ids: [Int32]) -> String { "" }
}
