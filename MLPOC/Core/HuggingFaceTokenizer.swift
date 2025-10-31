//
//  HuggingFaceTokenizer.swift
//  MLPOC
//
//  Created by Codex on 31.10.2025.
//

import Foundation

#if canImport(Tokenizers)
import Hub
import Tokenizers
#endif

enum TokenizerBridgeError: LocalizedError {
    case missingTokenizerJSON
    case missingConfigJSON
    case bridgeUnavailable
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .missingTokenizerJSON:
            return "tokenizer.json is missing from the app bundle."
        case .missingConfigJSON:
            return "tokenizer_config.json is missing from the app bundle."
        case .bridgeUnavailable:
            return "Add the Hugging Face Tokenizers Swift package to enable on-device tokenization."
        case .invalidJSON:
            return "Failed to parse tokenizer JSON files."
        }
    }
}

/// Generic wrapper around Hugging Face `tokenizer.json` for on-device chat models.
final class HuggingFaceTokenizer: ChatTokenizer {
    #if canImport(Tokenizers)
    private let tokenizer: any Tokenizers.Tokenizer
    #endif

    init(bundle: Bundle = .main, resourceSubdirectory: String? = nil, modelDirectory: URL? = nil) throws {
        #if canImport(Tokenizers)
        let hints = HuggingFaceTokenizer.hintDirectories(
            bundle: bundle,
            resourceSubdirectory: resourceSubdirectory,
            modelDirectory: modelDirectory
        )

        guard let tokenizerURL = HuggingFaceTokenizer.locateResource(
            named: "tokenizer",
            extension: "json",
            bundle: bundle,
            resourceSubdirectory: resourceSubdirectory,
            hintDirectories: hints
        ) else {
            throw TokenizerBridgeError.missingTokenizerJSON
        }

        guard let configURL = HuggingFaceTokenizer.locateResource(
            named: "tokenizer_config",
            extension: "json",
            bundle: bundle,
            resourceSubdirectory: resourceSubdirectory,
            hintDirectories: hints
        ) else {
            throw TokenizerBridgeError.missingConfigJSON
        }

        let tokenizerData = try HuggingFaceTokenizer.loadConfigJSON(from: tokenizerURL)
        let tokenizerConfig = try HuggingFaceTokenizer.loadConfigJSON(from: configURL)

        tokenizer = try Tokenizers.AutoTokenizer.from(tokenizerConfig: tokenizerConfig, tokenizerData: tokenizerData)
        #else
        throw TokenizerBridgeError.bridgeUnavailable
        #endif
    }

    func encode(_ text: String) -> [Int32] {
        #if canImport(Tokenizers)
        return tokenizer.encode(text: text).map { Int32($0) }
        #else
        return []
        #endif
    }

    func decode(_ ids: [Int32]) -> String {
        #if canImport(Tokenizers)
        return tokenizer.decode(tokens: ids.map { Int($0) })
        #else
        return ""
        #endif
    }

    #if canImport(Tokenizers)
    private static func loadConfigJSON(from url: URL) throws -> Config {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data, options: [])

        if let dictionary = json as? [NSString: Any] {
            return Config(dictionary)
        } else if let dictionary = json as? [String: Any] {
            var converted: [NSString: Any] = [:]
            for (key, value) in dictionary {
                converted[key as NSString] = value
            }
            return Config(converted)
        } else {
            throw TokenizerBridgeError.invalidJSON
        }
    }

    private static func locateResource(
        named name: String,
        extension ext: String,
        bundle: Bundle,
        resourceSubdirectory: String?,
        hintDirectories: [URL]
    ) -> URL? {
        if let subdirectory = resourceSubdirectory,
           let url = bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            return url
        }

        if let url = bundle.url(forResource: name, withExtension: ext) {
            return url
        }

        let fm = FileManager.default
        for directory in hintDirectories {
            let candidate = directory.appendingPathComponent("\(name).\(ext)")
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    private static func hintDirectories(
        bundle: Bundle,
        resourceSubdirectory: String?,
        modelDirectory: URL?
    ) -> [URL] {
        var hints: [URL] = []
        if let modelDirectory {
            hints.append(modelDirectory)
            hints.append(modelDirectory.deletingLastPathComponent())
        }
        if let resourceSubdirectory {
            hints.append(bundle.bundleURL.appendingPathComponent(resourceSubdirectory))
        }
        hints.append(bundle.bundleURL)
        return hints
    }
    #endif
}
