//
//  OnDeviceChatRunner.swift
//  MLPOC
//
//  Created by Codex on 31.10.2025.
//

import CoreML
import Foundation

// MARK: - Tokenizer bridge
protocol ChatTokenizer: Sendable {
    func encode(_ text: String) -> [Int32]
    func decode(_ ids: [Int32]) -> String
}

// MARK: - Generic chat runner
protocol ChatRunning: Sendable {
    /// Generates an assistant reply given a system and user prompt pair using the provided tokenizer.
    /// Implementations can ignore the tokenizer if their backend performs tokenization internally.
    func generate(system: String, user: String, tokenizer: ChatTokenizer) throws -> String
}

// MARK: - Split runner (prefill + decode)
final class OnDeviceChatRunner {
    struct Config {
        let maxContext: Int
        let maxNewTokens: Int
        let temperature: Float
        let topK: Int
        let topP: Float
        let prefillResourceName: String
        let decodeResourceName: String
        let resourceSubdirectory: String?

        init(
            maxContext: Int,
            maxNewTokens: Int,
            temperature: Float,
            topK: Int,
            topP: Float,
            prefillResourceName: String,
            decodeResourceName: String,
            resourceSubdirectory: String?
        ) {
            self.maxContext = maxContext
            self.maxNewTokens = maxNewTokens
            self.temperature = temperature
            self.topK = topK
            self.topP = topP
            self.prefillResourceName = prefillResourceName
            self.decodeResourceName = decodeResourceName
            self.resourceSubdirectory = resourceSubdirectory
        }
    }

    private let prefillModel: MLModel
    private let decodeModel: MLModel
    private let cfg: Config
    private let vocabSize: Int

    private var pastK: [MLShapedArray<Float16>] = []
    private var pastV: [MLShapedArray<Float16>] = []
    private var layerCount = 0
    private var lastLogits: [Float] = []
    private var pastKeyPrefix = "past_key_"
    private var pastValuePrefix = "past_value_"
    private var presentKeyPrefix = "present_key_"
    private var presentValuePrefix = "present_value_"

    init?(config: Config, bundle: Bundle = .main) {
        self.cfg = config

        guard
            let prefillURL = OnDeviceChatRunner.locateModel(
                named: config.prefillResourceName,
                subdirectory: config.resourceSubdirectory,
                in: bundle
            ),
            let decodeURL = OnDeviceChatRunner.locateModel(
                named: config.decodeResourceName,
                subdirectory: config.resourceSubdirectory,
                in: bundle
            )
        else {
            print("Unable to locate chat resources: \(config.prefillResourceName) / \(config.decodeResourceName)")
            return nil
        }

        let computeCandidates: [MLComputeUnits] = [.cpuAndGPU, .cpuOnly]
        var prefillModel: MLModel?
        var decodeModel: MLModel?
        var loadError: Error?

        for units in computeCandidates {
            do {
                let prefillCfg = MLModelConfiguration()
                prefillCfg.computeUnits = units

                let decodeCfg = MLModelConfiguration()
                decodeCfg.computeUnits = units

                prefillModel = try MLModel(contentsOf: prefillURL, configuration: prefillCfg)
                decodeModel = try MLModel(contentsOf: decodeURL, configuration: decodeCfg)
                break
            } catch {
                loadError = error
                continue
            }
        }

        guard let prefillModel, let decodeModel else {
            if let loadError {
                print("Failed to load chat models: \(loadError)")
            }
            return nil
        }

        self.prefillModel = prefillModel
        self.decodeModel = decodeModel

        guard
            let logitsDesc = prefillModel.modelDescription.outputDescriptionsByName["logits"],
            let shape = logitsDesc.multiArrayConstraint?.shape,
            let vocabDim = shape.last?.intValue
        else {
            print("Unable to infer vocab size from prefill output")
            return nil
        }

        self.vocabSize = vocabDim
    }

    // MARK: - Public API
    func generate(system: String, user: String, tokenizer: ChatTokenizer) throws -> String {
        let prompt = """
        <|system|>
        \(system)
        <|user|>
        \(user)
        <|assistant|>
        """

        let ids = tokenizer.encode(prompt)
        let ctxLen = min(ids.count, cfg.maxContext)
        var inputIds = [Int32](repeating: 0, count: cfg.maxContext)
        var attnMask = [Int32](repeating: 0, count: cfg.maxContext)
        for idx in 0..<ctxLen {
            inputIds[idx] = ids[idx]
            attnMask[idx] = 1
        }

        try runPrefill(inputIds: inputIds, attentionMask: attnMask, effectiveLength: ctxLen)

        var generated: [Int32] = []
        var token = sampleGreedy(from: lastLogits)

        for _ in 0..<cfg.maxNewTokens {
            generated.append(token)
            token = try runDecodeStep(lastToken: token)
            if isEndOfSequence(token) { break }
        }

        return tokenizer.decode(generated)
    }

    // MARK: - Prefill & decode passes
    private func runPrefill(inputIds: [Int32], attentionMask: [Int32], effectiveLength: Int) throws {
        let idsArray = try MLMultiArray(shape: [1, cfg.maxContext] as [NSNumber], dataType: .int32)
        let maskArray = try MLMultiArray(shape: [1, cfg.maxContext] as [NSNumber], dataType: .int32)
        for (index, value) in inputIds.enumerated() {
            idsArray[index] = NSNumber(value: value)
        }
        for (index, value) in attentionMask.enumerated() {
            maskArray[index] = NSNumber(value: value)
        }

        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": idsArray,
            "attention_mask": maskArray
        ])

        let output = try prefillModel.prediction(from: provider)

        guard let logitsMA = output.featureValue(for: "logits")?.multiArrayValue else {
            throw NSError(domain: "OnDeviceChatRunner", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing logits output"])
        }

        lastLogits = extractLogits(from: logitsMA, timestep: effectiveLength - 1)
        prepareCache(from: output)
    }

    private func runDecodeStep(lastToken: Int32) throws -> Int32 {
        guard layerCount > 0 else {
            throw NSError(domain: "OnDeviceChatRunner", code: -2, userInfo: [NSLocalizedDescriptionKey: "KV cache not prepared"])
        }

        let tokenArray = try MLMultiArray(shape: [1, 1] as [NSNumber], dataType: .int32)
        tokenArray[0] = NSNumber(value: lastToken)

        var dict: [String: MLMultiArray] = [
            "input_ids": tokenArray
        ]

        for layer in 0..<layerCount {
            dict["\(pastKeyPrefix)\(layer)"] = pastK[layer].makeMultiArray()
            dict["\(pastValuePrefix)\(layer)"] = pastV[layer].makeMultiArray()
        }

        let provider = try MLDictionaryFeatureProvider(dictionary: dict)
        let output = try decodeModel.prediction(from: provider)

        guard let logitsMA = output.featureValue(for: "logits")?.multiArrayValue else {
            throw NSError(domain: "OnDeviceChatRunner", code: -3, userInfo: [NSLocalizedDescriptionKey: "Missing decode logits"])
        }
        lastLogits = extractLogits(from: logitsMA, timestep: 0)

        updateCache(from: output)

        return sampleGreedy(from: lastLogits)
    }

    // MARK: - KV Cache helpers
    private func prepareCache(from provider: MLFeatureProvider) {
        pastK.removeAll()
        pastV.removeAll()

        resolvePastPrefixes(from: provider)

        var layer = 0
        while true {
            guard
                let kArray = provider.featureValue(for: "\(pastKeyPrefix)\(layer)")?.shapedArrayValue(of: Float16.self),
                let vArray = provider.featureValue(for: "\(pastValuePrefix)\(layer)")?.shapedArrayValue(of: Float16.self)
            else {
                break
            }

            pastK.append(kArray)
            pastV.append(vArray)
            layer += 1
        }

        layerCount = pastK.count
    }

    private func updateCache(from provider: MLFeatureProvider) {
        resolvePresentPrefixes(from: provider)

        for layer in 0..<layerCount {
            guard
                let kArray = provider.featureValue(for: "\(presentKeyPrefix)\(layer)")?.shapedArrayValue(of: Float16.self),
                let vArray = provider.featureValue(for: "\(presentValuePrefix)\(layer)")?.shapedArrayValue(of: Float16.self)
            else {
                continue
            }
            pastK[layer] = kArray
            pastV[layer] = vArray
        }
    }

    // MARK: - Sampling
    private func extractLogits(from array: MLMultiArray, timestep: Int) -> [Float] {
        let shape = array.shape.map { $0.intValue }
        guard let vocabDim = shape.last, vocabDim == vocabSize else {
            return []
        }

        if shape.count == 3 {
            let strideBatch = array.strides[0].intValue
            let strideSeq = array.strides[1].intValue
            let strideVocab = array.strides[2].intValue
            let clampedStep = max(0, min(timestep, shape[1] - 1))
            let base = 0 * strideBatch + clampedStep * strideSeq
            return (0..<vocabDim).map { idx in
                Float(truncating: array[base + idx * strideVocab])
            }
        } else if shape.count == 2 {
            let strideBatch = array.strides[0].intValue
            let strideVocab = array.strides[1].intValue
            let base = 0 * strideBatch
            return (0..<vocabDim).map { idx in
                Float(truncating: array[base + idx * strideVocab])
            }
        } else if shape.count == 1 {
            return (0..<vocabDim).map { idx in Float(truncating: array[idx]) }
        }

        return []
    }

    private func sampleGreedy(from logits: [Float]) -> Int32 {
        var bestIndex = 0
        var bestValue = logits[0]
        for (idx, value) in logits.enumerated() where value > bestValue {
            bestIndex = idx
            bestValue = value
        }
        return Int32(bestIndex)
    }

    private func isEndOfSequence(_ token: Int32) -> Bool {
        token == 2 || token == 128001
    }

    // MARK: - Utilities
    private static func locateModel(named name: String, subdirectory: String?, in bundle: Bundle) -> URL? {
        let fm = FileManager.default

        func normalizedURL(_ url: URL) -> URL? {
            let candidate = url.appendingPathComponent("coremldata.bin")
            if fm.fileExists(atPath: candidate.path) {
                return url
            }

            if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for entry in contents {
                    if entry.pathExtension == "mlmodelc" {
                        let nested = entry.appendingPathComponent("coremldata.bin")
                        if fm.fileExists(atPath: nested.path) {
                            return entry
                        }
                    }
                }
            }

            return nil
        }

        if let subdirectory,
           let url = bundle.url(forResource: name, withExtension: "mlmodelc", subdirectory: subdirectory),
           let normalized = normalizedURL(url) {
            return normalized
        }

        if let url = bundle.url(forResource: name, withExtension: "mlmodelc"),
           let normalized = normalizedURL(url) {
            return normalized
        }

        return nil
    }

    private func resolvePastPrefixes(from provider: MLFeatureProvider) {
        pastKeyPrefix = resolvePrefix(
            candidates: ["past_key_", "cache_key_", "key_cache_", "k_cache_"],
            provider: provider,
            fallback: pastKeyPrefix
        )
        pastValuePrefix = resolvePrefix(
            candidates: ["past_value_", "cache_value_", "value_cache_", "v_cache_"],
            provider: provider,
            fallback: pastValuePrefix
        )
    }

    private func resolvePresentPrefixes(from provider: MLFeatureProvider) {
        presentKeyPrefix = resolvePrefix(
            candidates: ["present_key_", "past_key_", "cache_key_", "key_cache_", "k_cache_"],
            provider: provider,
            fallback: presentKeyPrefix
        )
        presentValuePrefix = resolvePrefix(
            candidates: ["present_value_", "past_value_", "cache_value_", "value_cache_", "v_cache_"],
            provider: provider,
            fallback: presentValuePrefix
        )
    }

    private func resolvePrefix(candidates: [String], provider: MLFeatureProvider, fallback: String) -> String {
        for prefix in candidates {
            let probe = "\(prefix)0"
            if provider.featureValue(for: probe) != nil {
                return prefix
            }
        }
        return fallback
    }
}

extension OnDeviceChatRunner: ChatRunning {}
extension OnDeviceChatRunner: @unchecked Sendable {}

private extension MLShapedArray where Scalar == Float16 {
    func makeMultiArray() -> MLMultiArray {
        MLMultiArray(self)
    }
}
