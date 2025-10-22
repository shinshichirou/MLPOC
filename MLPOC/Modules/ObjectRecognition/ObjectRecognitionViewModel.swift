//
//  ObjectRecognitionViewModel.swift
//  MLPOC
//
//  Created by Igor Tudoran on 24.10.2025.
//

import SwiftUI
import Vision
import CoreML
import Combine

final class ObjectRecognitionViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var predictions: [ClassificationPrediction] = []
    @Published var selectedModel: MLModelType = .mobileNetV2
    @Published var isShowingPicker = false

    func showPhotoPicker() {
        isShowingPicker = true
    }

    func handleImagePicked(_ image: UIImage) {
        selectedImage = image
        classify(image)
    }

    func handleModelChange() {
        guard let image = selectedImage else { return }
        classify(image)
    }

    private func classify(_ image: UIImage) {
        DispatchQueue.main.async { [weak self] in
            self?.predictions = []
        }
        guard let ciImage = CIImage(image: image) else { return }

        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        guard
            let model = selectedModel.makeModel(with: configuration),
            let mlModel = try? VNCoreMLModel(for: model)
        else {
            return
        }

        let request = VNCoreMLRequest(model: mlModel) { [weak self] request, _ in
            guard let results = request.results as? [VNClassificationObservation] else { return }
            let topResults = results.prefix(3).map {
                ClassificationPrediction(label: $0.identifier,
                                         confidence: Double($0.confidence))
            }
            DispatchQueue.main.async {
                self?.predictions = topResults
            }
        }
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(ciImage: ciImage,
                                            orientation: image.cgImageOrientation,
                                            options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}
