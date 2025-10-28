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
    @Published var classifications: [ClassificationPrediction] = []
    @Published var detections: [DetectionPrediction] = []
    @Published var selectedModel: MLModelType = .mobileNetV2
    @Published var isShowingPicker = false

    private let queue = DispatchQueue(label: "mlpoc.inference", qos: .userInitiated)

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
            self?.classifications = []
        }
        guard let ciImage = CIImage(image: image) else {
            return
        }

        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        guard
            let model = selectedModel.makeModel(with: configuration),
            let mlModel = try? VNCoreMLModel(for: model)
        else {
            return
        }

        let cropOption: VNImageCropAndScaleOption = {
            switch selectedModel {
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
                let top = classes.map {
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
