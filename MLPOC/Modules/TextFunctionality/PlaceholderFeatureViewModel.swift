//
//  PlaceholderFeatureViewModel.swift
//  MLPOC
//
//  Created by Igor Tudoran on 24.10.2025.
//

import Foundation
import Combine

final class PlaceholderFeatureViewModel: ObservableObject {
    @Published var message = "Another ML-powered feature is on its way."
}
