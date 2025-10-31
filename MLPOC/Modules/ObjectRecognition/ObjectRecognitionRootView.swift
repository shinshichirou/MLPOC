//
//  ObjectRecognitionRootView.swift
//  MLPOC
//
//  Created by Codex on 31.10.2025.
//

import SwiftUI

struct ObjectRecognitionRootView: View {
    @State private var path: [MLModelType] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(MLModelType.allCases) { model in
                        NavigationLink(value: model) {
                            modelRow(for: model)
                        }
                    }
                } footer: {
                    Text("Choose a model to load it on demand. Only one Core ML model stays active, which keeps memory usage manageable.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Vision Models")
            .navigationDestination(for: MLModelType.self) { model in
                ObjectRecognitionDetailView(modelType: model)
            }
        }
    }

    private func modelRow(for model: MLModelType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.title)
                .font(.headline)
            Text(model.capabilityDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label(model.memorySummary, systemImage: "memorychip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(model.outputSummary, systemImage: model.isDetector ? "viewfinder" : "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ObjectRecognitionRootView()
}
