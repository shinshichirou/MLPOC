//
//  PlaceholderFeatureView.swift
//  MLPOC
//
//  Created by Igor Tudoran on 24.10.2025.
//

import SwiftUI

struct PlaceholderFeatureView: View {
    @StateObject private var viewModel = PlaceholderFeatureViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)

                Text(viewModel.message)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Upcoming Feature")
        }
    }
}

#Preview {
    PlaceholderFeatureView()
}
