//
//  ObjectRecognitionDetailView.swift
//  MLPOC
//
//  Created by Igor Tudoran on 24.10.2025.
//

import SwiftUI

struct ObjectRecognitionDetailView: View {
    let modelType: MLModelType
    @StateObject private var viewModel: ObjectRecognitionViewModel

    init(modelType: MLModelType, viewModel: ObjectRecognitionViewModel? = nil) {
        self.modelType = modelType
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: ObjectRecognitionViewModel(modelType: modelType))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                infoCard

                VStack(alignment: .leading, spacing: 16) {
                    if let image = viewModel.selectedImage {
                        AnnotatedImageView(
                            image: image,
                            detections: modelType.isDetector ? viewModel.detections : []
                        )
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2))
                        )
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 250)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.secondary)
                                    Text("Tap “Select Photo” to analyse an image")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                    }

                    Button {
                        viewModel.showPhotoPicker()
                    } label: {
                        Label("Select Photo", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                resultsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(modelType.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: isShowingPickerBinding) {
            PhotoPicker(
                selectedImage: selectedImageBinding,
                onImagePicked: viewModel.handleImagePicked
            )
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(modelType.capabilityDescription)
                .font(.headline)

            Divider()

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Label(modelType.memorySummary, systemImage: "memorychip")
                    .font(.footnote)
                Label(modelType.outputSummary, systemImage: modelType.isDetector ? "viewfinder" : "list.bullet")
                    .font(.footnote)
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private var resultsSection: some View {
        if modelType.isDetector {
            if viewModel.detections.isEmpty {
                emptyState(label: "No detections yet")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Detections")
                        .font(.headline)
                    ForEach(viewModel.detections) { detection in
                        resultRow(primary: detection.label,
                                  secondary: detection.formattedConfidence)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            if viewModel.classifications.isEmpty {
                emptyState(label: "No classifications yet")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Predictions")
                        .font(.headline)
                    ForEach(viewModel.classifications) { prediction in
                        resultRow(primary: prediction.label,
                                  secondary: prediction.formattedConfidence)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func resultRow(primary: String, secondary: String) -> some View {
        HStack {
            Text(primary)
                .font(.body)
            Spacer(minLength: 12)
            Text(secondary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private func emptyState(label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Select a photo to run inference with \(modelType.title).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedImageBinding: Binding<UIImage?> {
        Binding(
            get: { viewModel.selectedImage },
            set: { viewModel.selectedImage = $0 }
        )
    }

    private var isShowingPickerBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isShowingPicker },
            set: { viewModel.isShowingPicker = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        ObjectRecognitionDetailView(modelType: .mobileNetV2)
    }
}
