//
//  ObjectRecognitionViewModel.swift
//  MLPOC
//
//  Created by Igor Tudoran on 24.10.2025.
//

import SwiftUI
import Combine
import Vision
import CoreML

final class ObjectRecognitionViewModel: ObservableObject {
    let modelType: MLModelType

    @Published var selectedImage: UIImage?
    @Published var classifications: [ClassificationPrediction] = []
    @Published var detections: [DetectionPrediction] = []
    @Published var isShowingPicker = false

    private let queue = DispatchQueue(label: "mlpoc.inference", qos: .userInitiated)

    init(modelType: MLModelType) {
        self.modelType = modelType
    }

    func showPhotoPicker() {
        isShowingPicker = true
    }

    func handleImagePicked(_ image: UIImage) {
        selectedImage = image
        classify(image)
    }

    private func classify(_ image: UIImage) {
        DispatchQueue.main.async { [weak self] in
            self?.classifications = []
            self?.detections = []
        }

        guard let ciImage = CIImage(image: image) else {
            return
        }

        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        guard
            let model = modelType.makeModel(with: configuration),
            let mlModel = try? VNCoreMLModel(for: model)
        else {
            return
        }

        let cropOption: VNImageCropAndScaleOption = {
            switch modelType {
            case .mobileNetV2, .resnet50, .fastViTMA36F16:
                return .centerCrop
            case .yolo11:
                return .scaleFill
            }
        }()

        let request = VNCoreMLRequest(model: mlModel) { [weak self] request, _ in
            guard let self else { return }

            // Route 1: Object Detection (YOLO + NMS -> VNRecognizedObjectObservation)
            if let objects = request.results as? [VNRecognizedObjectObservation] {
                let mapped: [DetectionPrediction] = objects.compactMap { o in
                    guard let top = o.labels.first else { return nil }
                    return DetectionPrediction(label: top.identifier,
                                               confidence: Double(top.confidence),
                                               boundingBox: o.boundingBox) // normalized [0,1]
                }
                DispatchQueue.main.async { self.detections = mapped }
                return
            }

            // Route 2: Image Classification
            if let classes = request.results as? [VNClassificationObservation] {
                let top = classes.prefix(10).map {
                    ClassificationPrediction(label: $0.identifier,
                                             confidence: Double($0.confidence))
                }
                DispatchQueue.main.async { self.classifications = top }
                return
            }
        }
        request.imageCropAndScaleOption = cropOption

        let handler = VNImageRequestHandler(ciImage: ciImage,
                                            orientation: image.cgImageOrientation,
                                            options: [:])

        queue.async {
            do {
                try handler.perform([request])
            } catch {
                print("Object recognition failed: \(error)")
            }
        }
    }
}
