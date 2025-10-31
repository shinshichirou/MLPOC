//
//  DetectionPrediction.swift
//  MLPOC
//
//  Created by Igor Tudoran on 24.10.2025.
//

import Foundation

struct DetectionPrediction: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Double
    let boundingBox: CGRect

    var formattedConfidence: String {
        String(format: "%.1f %%", confidence * 100)
    }
}
