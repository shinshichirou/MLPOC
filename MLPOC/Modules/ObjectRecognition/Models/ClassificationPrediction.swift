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
}
