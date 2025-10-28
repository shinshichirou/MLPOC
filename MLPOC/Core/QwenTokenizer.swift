//
//  QwenTokenizer.swift
//  MLPOC
//
//  Created by Codex on 01.11.2025.
//

import Foundation

#if canImport(Tokenizers)
import Hub
import Tokenizers
#endif

enum QwenTokenizerError: LocalizedError {
    case missingResource
    case missingConfigResource
    case bridgeUnavailable
    case failedToDecodeURL
    case encodingFailed
    case decodingFailed
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "tokenizer.json is missing from the app bundle. Add it to the project and make sure it is included in the main target."
        case .missingConfigResource:
            return "tokenizer_config.json is missing from the app bundle. Download it from the same model repository and include it in the app target."
        case .bridgeUnavailable:
            return "The Hugging Face Tokenizers bridge is not available. Add the Tokenizers Swift package to the project."
        case .failedToDecodeURL:
            return "Failed to load tokenizer.json from the bundle."
        case .encodingFailed:
            return "Could not encode the text with the Qwen tokenizer."
        case .decodingFailed:
            return "Could not decode token IDs with the Qwen tokenizer."
        case .invalidJSON:
            return "Failed to parse tokenizer JSON files."
        }
    }
}

/// Tokenizer that reads the Hugging Face tokenizer.json generated for Qwen.
///
/// Make sure to add tokenizer.json to the application bundle.
final class QwenTokenizer: Tokenizer {
    #if canImport(Tokenizers)
    private let tokenizer: any Tokenizers.Tokenizer
    #endif

    init(bundle: Bundle = .main, resourceSubdirectory: String? = nil) throws {
        #if canImport(Tokenizers)
        let tokenizerURL: URL? = {
            if let subdir = resourceSubdirectory,
               let url = bundle.url(forResource: "tokenizer", withExtension: "json", subdirectory: subdir) {
                return url
            }
            return bundle.url(forResource: "tokenizer", withExtension: "json")
        }()

        let tokenizerConfigURL: URL? = {
            if let subdir = resourceSubdirectory,
               let url = bundle.url(forResource: "tokenizer_config", withExtension: "json", subdirectory: subdir) {
                return url
            }
            return bundle.url(forResource: "tokenizer_config", withExtension: "json")
        }()

        guard let tokenizerURL else { throw QwenTokenizerError.missingResource }
        guard let tokenizerConfigURL else { throw QwenTokenizerError.missingConfigResource }

        let tokenizerData = try QwenTokenizer.loadConfigJSON(from: tokenizerURL)
        let tokenizerConfig = try QwenTokenizer.loadConfigJSON(from: tokenizerConfigURL)

        tokenizer = try Tokenizers.AutoTokenizer.from(tokenizerConfig: tokenizerConfig, tokenizerData: tokenizerData)
        #else
        throw QwenTokenizerError.bridgeUnavailable
        #endif
    }

    func encode(_ text: String) -> [Int32] {
        #if canImport(Tokenizers)
        let ids = tokenizer.encode(text: text)
        return ids.map { Int32($0) }
        #else
        return []
        #endif
    }

    func decode(_ ids: [Int32]) -> String {
        #if canImport(Tokenizers)
        let ints = ids.map { Int($0) }
        return tokenizer.decode(tokens: ints)
        #else
        return ""
        #endif
    }

    #if canImport(Tokenizers)
    private static func loadConfigJSON(from url: URL) throws -> Config {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data, options: [])

        if let dict = json as? [NSString: Any] {
            return Config(dict)
        } else if let dict = json as? [String: Any] {
            var converted: [NSString: Any] = [:]
            for (key, value) in dict {
                converted[key as NSString] = value
            }
            return Config(converted)
        } else {
            throw QwenTokenizerError.invalidJSON
        }
    }
    #endif
}
