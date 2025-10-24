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
