//
//  ClassificationPrediction.swift
//  MLPOC
//
//  Created by Igor Tudoran on 24.10.2025.
//

import Foundation

struct ClassificationPrediction: Identifiable {
    let label: String
    let confidence: Double

    var id: String { label }

    var formattedConfidence: String {
        String(format: "%.1f %%", confidence * 100)
    }
}
