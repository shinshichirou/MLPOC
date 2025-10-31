//
//  MLModelType.swift
//  MLPOC
//
//  Created by Igor Tudoran on 24.10.2025.
//

import CoreML

enum MLModelType: String, CaseIterable, Identifiable {
    case mobileNetV2 = "MobileNetV2"
    case resnet50 = "Resnet50"
    case fastViTMA36F16 = "FastViTMA36F16"
    case yolo11 = "yolo11n"

    var id: Self { self }

    var title: String {
        rawValue
    }

    var isDetector: Bool {
        switch self {
        case .yolo11:
            return true
        default:
            return false
        }
    }

    var capabilityDescription: String {
        switch self {
        case .mobileNetV2:
            return "MobileNetV2 — lightweight image classification"
        case .resnet50:
            return "ResNet50 — high-accuracy image classification"
        case .fastViTMA36F16:
            return "FastViT MA36 — transformer-based image classification"
        case .yolo11:
            return "YOLO11n — real-time object detection"
        }
    }

    var memorySummary: String {
        switch self {
        case .mobileNetV2:
            return "~15 MB runtime memory"
        case .resnet50:
            return "~100 MB runtime memory"
        case .fastViTMA36F16:
            return "~55 MB runtime memory"
        case .yolo11:
            return "~35 MB runtime memory"
        }
    }

    var outputSummary: String {
        switch self {
        case .yolo11:
            return "Bounding boxes & labels"
        default:
            return "Top-1 / Top-N labels"
        }
    }

    func makeModel(with configuration: MLModelConfiguration) -> MLModel? {
        switch self {
        case .mobileNetV2:
            return try? MobileNetV2(configuration: configuration).model
        case .resnet50:
            return try? Resnet50(configuration: configuration).model
        case .fastViTMA36F16:
            return try? FastViTMA36F16(configuration: configuration).model
        case .yolo11:
            return try? yolo11n(configuration: configuration).model
        }
    }
}
