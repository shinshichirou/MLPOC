//
//  QwenRunner.swift
//  MLPOC
//
//  Created by Igor Tudoran on 28.10.2025.
//

import Foundation
import CoreML

// MARK: - Tokenizer bridge
// For production, bridge to your tokenizer (SentencePiece/BPE).
protocol Tokenizer {
    func encode(_ text: String) -> [Int32]
    func decode(_ ids: [Int32]) -> String
}

// MARK: - Qwen1.5 1.8B CoreML Runner
final class QwenRunner {
    struct Config {
        let maxContext: Int
        let maxNewTokens: Int
        let temperature: Float
        let topK: Int
        let topP: Float
        let promptResourceName: String
        let decodeResourceName: String
        let resourceSubdirectory: String?

        init(
            maxContext: Int,
            maxNewTokens: Int,
            temperature: Float,
            topK: Int,
            topP: Float,
            promptResourceName: String = "Prompt",
            decodeResourceName: String = "Decode",
            resourceSubdirectory: String? = nil
        ) {
            self.maxContext = maxContext
            self.maxNewTokens = maxNewTokens
            self.temperature = temperature
            self.topK = topK
            self.topP = topP
            self.promptResourceName = promptResourceName
            self.decodeResourceName = decodeResourceName
            self.resourceSubdirectory = resourceSubdirectory
        }
    }

    private let promptModel: MLModel
    private let decodeModel: MLModel
    private let cfg: Config
    private let vocabSize: Int

    // KV cache storage
    private var pastK: [MLShapedArray<Float16>] = []
    private var pastV: [MLShapedArray<Float16>] = []
    private var layerCount: Int = 0
    private var nKVHeads: Int = 0
    private var headDim: Int = 0

    init?(config: Config, bundle: Bundle = .main) {
        self.cfg = config

        guard
            let promptURL = QwenRunner.locateModel(
                named: cfg.promptResourceName,
                subdirectory: cfg.resourceSubdirectory,
                in: bundle
            ),
            let decodeURL = QwenRunner.locateModel(
                named: cfg.decodeResourceName,
                subdirectory: cfg.resourceSubdirectory,
                in: bundle
            )
        else {
            print("Model resources not found for \(cfg.promptResourceName) / \(cfg.decodeResourceName)")
            return nil
        }

        let computeCandidates: [MLComputeUnits] = [.cpuAndGPU, .cpuOnly]
        var lastError: Error?
        var selectedComputeUnits: MLComputeUnits = .all
        var promptModel: MLModel?
        var decodeModel: MLModel?

        for units in computeCandidates {
            do {
                let promptCfg = MLModelConfiguration()
                promptCfg.computeUnits = units
                let prompt = try MLModel(contentsOf: promptURL, configuration: promptCfg)

                let decodeCfg = MLModelConfiguration()
                decodeCfg.computeUnits = units
                let decode = try MLModel(contentsOf: decodeURL, configuration: decodeCfg)

                promptModel = prompt
                decodeModel = decode
                selectedComputeUnits = units
                break
            } catch {
                lastError = error
                continue
            }
        }

        guard let promptModel, let decodeModel else {
            if let error = lastError {
                print("Model load error after trying compute unit fallbacks: \(error)")
            } else {
                print("Model load error: unable to load models with any compute units.")
            }
            return nil
        }

        self.promptModel = promptModel
        self.decodeModel  = decodeModel

        if selectedComputeUnits != .all {
            print("Loaded Qwen models using computeUnits=\(selectedComputeUnits)")
        }

        guard
            let logitsDesc = promptModel.modelDescription.outputDescriptionsByName["logits"],
            let shape = logitsDesc.multiArrayConstraint?.shape,
            let vocabDim = shape.last?.intValue
        else {
            print("Unable to infer vocabulary size from prompt model output")
            return nil
        }
        self.vocabSize = vocabDim
    }

    // MARK: - Public chat API
    func generate(system: String, user: String, tokenizer: Tokenizer) throws -> String {
        let promptText = "System: \(system)\nUser: \(user)\nAssistant:"
        let ids = tokenizer.encode(promptText)
        let prefillLen = min(ids.count, cfg.maxContext)
        var inputIds = [Int32](repeating: 0, count: cfg.maxContext)
        var attnMask = [Int32](repeating: 0, count: cfg.maxContext)
        for i in 0..<prefillLen { inputIds[i] = ids[i]; attnMask[i] = 1 }

        // PROMPT pass
        try runPrompt(inputIds: inputIds, attentionMask: attnMask, effectiveLen: prefillLen)

        // DECODE loop
        var outTokens: [Int32] = []
        var lastToken = sampleGreedy(from: lastLogits) // or topP/topK

        for _ in 0..<cfg.maxNewTokens {
            outTokens.append(lastToken)
            lastToken = try runDecodeStep(lastToken: lastToken, generatedCount: outTokens.count)
            if isEos(lastToken) { break }
        }
        return tokenizer.decode(outTokens)
    }

    // MARK: - Internal state
    private var lastLogits: [Float] = []

    private static func locateModel(named name: String, subdirectory: String?, in bundle: Bundle) -> URL? {
        let fm = FileManager.default

        func validModelURL(_ url: URL) -> URL? {
            let coreDataPath = url.appendingPathComponent("coremldata.bin").path
            if fm.fileExists(atPath: coreDataPath) {
                return url
            }

            // Handle the case where the compiled model is nested one level deeper.
            if let nested = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for candidate in nested where candidate.pathExtension == "mlmodelc" {
                    let nestedCore = candidate.appendingPathComponent("coremldata.bin").path
                    if fm.fileExists(atPath: nestedCore) {
                        return candidate
                    }
                }
            }

            return nil
        }

        if let subdirectory,
           let url = bundle.url(forResource: name, withExtension: "mlmodelc", subdirectory: subdirectory),
           let valid = validModelURL(url) {
            return valid
        }

        if let url = bundle.url(forResource: name, withExtension: "mlmodelc"),
           let valid = validModelURL(url) {
            return valid
        }

        return nil
    }

    // MARK: - Prompt
    private func runPrompt(inputIds: [Int32], attentionMask: [Int32], effectiveLen: Int) throws {
        // Build MLMultiArray inputs
        let idsArr = try MLMultiArray(shape: [NSNumber(value: 1), NSNumber(value: cfg.maxContext)], dataType: .int32)
        let maskArr = try MLMultiArray(shape: [NSNumber(value: 1), NSNumber(value: cfg.maxContext)], dataType: .int32)
        idsArr.copy(from: inputIds)
        maskArr.copy(from: attentionMask)

        let out = try promptModel.prediction(from: MLDictionaryFeatureProvider(dictionary: [
            "inputIds": idsArr,
            "attentionMask": maskArr
        ]))

        // Extract logits @ last position
        guard let logitsMA = out.featureValue(for: "logits")?.multiArrayValue else {
            throw NSError(domain: "QwenRunner", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing logits"])
        }
        // logits shape: [1, N_CTX, vocab]
        let strideVocab = logitsMA.strides[2].intValue
        let base = (effectiveLen - 1) * logitsMA.strides[1].intValue
        lastLogits = (0..<vocabSize).map { i in
            Float(truncating: logitsMA[base + i * strideVocab])
        }

        // Discover layers by counting outputs
        var keys: [MLShapedArray<Float16>] = []
        var vals: [MLShapedArray<Float16>] = []
        var i = 0
        while true {
            guard let k = out.featureValue(for: "past_key_L\(i)")?.multiArrayValue,
                  let v = out.featureValue(for: "past_value_L\(i)")?.multiArrayValue else { break }
            keys.append(MLShapedArray<Float16>(k))
            vals.append(MLShapedArray<Float16>(v))
            i += 1
        }
        layerCount = i
        guard layerCount > 0 else { throw NSError(domain: "QwenRunner", code: -2, userInfo: [NSLocalizedDescriptionKey: "No KV layers found"]) }
        pastK = keys; pastV = vals

        // Infer head dims from first layer shape: (1, n_kv, T, head_dim)
        if let first = keys.first {
            nKVHeads = first.shape[1]
            headDim  = first.shape[3]
        }
    }

    // MARK: - Decode step
    private func runDecodeStep(lastToken: Int32, generatedCount: Int) throws -> Int32 {
        // Inputs
        let lastArr = try MLMultiArray(shape: [NSNumber(value: 1), NSNumber(value: 1)], dataType: .int32)
        lastArr[0] = NSNumber(value: lastToken)

        let attnLen = cfg.maxContext + generatedCount
        let attnArr = try MLMultiArray(shape: [NSNumber(value: 1), NSNumber(value: attnLen)], dataType: .int32)
        for i in 0..<attnLen { attnArr[i] = 1 }

        var dict: [String: MLFeatureValue] = [
            "lastToken": MLFeatureValue(multiArray: lastArr),
            "attentionMask": MLFeatureValue(multiArray: attnArr),
        ]

        // Thread KV
        for i in 0..<layerCount {
            dict["past_key_L\(i)"]   = MLFeatureValue(multiArray: pastK[i].makeMultiArray())
            dict["past_value_L\(i)"] = MLFeatureValue(multiArray: pastV[i].makeMultiArray())
        }

        let out = try decodeModel.prediction(from: MLDictionaryFeatureProvider(dictionary: dict))

        // logits: [1, 1, vocab]
        guard let logitsMA = out.featureValue(for: "logits")?.multiArrayValue else {
            throw NSError(domain: "QwenRunner", code: -3, userInfo: [NSLocalizedDescriptionKey: "Missing decode logits"])
        }
        lastLogits = (0..<vocabSize).map { i in Float(truncating: logitsMA[i]) }
        let next = sampleGreedy(from: lastLogits)

        // update KV
        var newK: [MLShapedArray<Float16>] = []
        var newV: [MLShapedArray<Float16>] = []
        for i in 0..<layerCount {
            guard let k = out.featureValue(for: "new_past_key_L\(i)")?.multiArrayValue,
                  let v = out.featureValue(for: "new_past_value_L\(i)")?.multiArrayValue else {
                throw NSError(domain: "QwenRunner", code: -4, userInfo: [NSLocalizedDescriptionKey: "Missing new KV at L\(i)"])
            }
            newK.append(MLShapedArray<Float16>(k))
            newV.append(MLShapedArray<Float16>(v))
        }
        pastK = newK; pastV = newV
        return next
    }

    // MARK: - Sampling (replace with your own)
    private func sampleGreedy(from logits: [Float]) -> Int32 {
        var argmax = 0
        var best = -Float.greatestFiniteMagnitude
        for (i, v) in logits.enumerated() { if v > best { best = v; argmax = i } }
        return Int32(argmax)
    }

    private func isEos(_ id: Int32) -> Bool {
        // Plug your EOS id(s) for Qwen here if desired
        return false
    }
}

// MARK: - MLMultiArray helpers
private extension MLMultiArray {
    func copy(from ints: [Int32]) {
        precondition(count == ints.count)
        for i in 0..<ints.count { self[i] = NSNumber(value: ints[i]) }
    }
}

private extension MLShapedArray where Scalar == Float16 {
    func makeMultiArray() -> MLMultiArray {
        let shape = self.shape.map { NSNumber(value: $0) }
        let ma = try! MLMultiArray(shape: shape, dataType: .float16)
        self.withUnsafeShapedBufferPointer { buffer, _, _ in
            guard let src = buffer.baseAddress else { return }
            let dst = ma.dataPointer.bindMemory(to: Float16.self, capacity: ma.count)
            dst.update(from: src, count: ma.count)
        }
        return ma
    }
}
