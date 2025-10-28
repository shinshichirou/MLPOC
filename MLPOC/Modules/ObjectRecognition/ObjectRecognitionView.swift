//
//  ObjectRecognitionView.swift
//  MLPOC
//
//  Created by Igor Tudoran on 24.10.2025.
//

import SwiftUI

struct ObjectRecognitionView: View {
    @StateObject private var viewModel = ObjectRecognitionViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                VStack(spacing: 20) {
                    Picker("Choose a model", selection: $viewModel.selectedModel) {
                        ForEach(MLModelType.allCases) { modelType in
                            Text(modelType.title).tag(modelType)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let uiImage = viewModel.selectedImage {
                        AnnotatedImageView(
                            image: uiImage,
                            detections: viewModel.selectedModel == .yolo11 ? viewModel.detections : []
                        )
                        .frame(height: 250)
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 250)
                            .overlay {
                                Text("Tap to choose a photo")
                                    .foregroundStyle(.secondary)
                            }
                    }

                    Button("Choose Photo") {
                        viewModel.showPhotoPicker()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
                switch viewModel.selectedModel {
                case .fastViTMA36F16, .resnet50, .mobileNetV2:
                    if !viewModel.classifications.isEmpty {
                        List(viewModel.classifications) { prediction in
                            HStack {
                                Text(prediction.label)
                                Spacer()
                                Text(String(format: "%.1f %%", prediction.confidence * 100))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 200)
                    }
                case .yolo11:
                    if !viewModel.detections.isEmpty {
                        List(viewModel.detections) { detections in
                            HStack {
                                Text(detections.label)
                                Spacer()
                                Text(String(format: "%.1f %%", detections.confidence * 100))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 200)
                    }
                }
            }
            .padding()
            .navigationTitle("Object Recognition")
        }
        .onChange(of: viewModel.selectedModel) { _, _ in
            viewModel.handleModelChange()
        }
        .sheet(isPresented: isShowingPickerBinding) {
            PhotoPicker(selectedImage: selectedImageBinding,
                        onImagePicked: viewModel.handleImagePicked)
        }
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
    ObjectRecognitionView()
}
