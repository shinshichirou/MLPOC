//
//  DetectionPrediction.swift
//  MLPOC
//
//  Created by Igor Tudoran on 24.10.2025.
//

import Foundation

struct DetectionPrediction: Identifiable {
    let label: String
    let confidence: Double
    let boundingBox: CGRect

    var id: String { label + UUID().uuidString }
}
