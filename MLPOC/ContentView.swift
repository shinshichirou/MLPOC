//
//  ContentView.swift
//  MLPOC
//
//  Created by Igor Tudoran on 21.10.2025.
//

import SwiftUI
import PhotosUI
import Vision
import CoreML

struct ContentView: View {
    enum MLModels: String, CaseIterable, Identifiable {
        case MobileNetV2, Resnet50, FastViTMA36F16
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var predictions: [(label: String, confidence: Double)] = []
    @State private var showingPicker = false
    @State private var selectedModel: MLModels = .MobileNetV2

    var body: some View {
        NavigationStack {
            VStack {
                VStack(spacing: 20.0) {
                    // Picker
                    Picker("Choose a model", selection: $selectedModel) {
                        ForEach(MLModels.allCases) { modelType in
                            Text(modelType.title).tag(modelType)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Image
                    if let uiImage = selectedImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 250)
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 250)
                            .overlay(Text("Tap to choose a photo"))
                    }

                    // Button
                    Button("Choose Photo") {
                        showingPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()

                // Labels with predictions
                if !predictions.isEmpty {
                    List(predictions, id: \.label) { item in
                        HStack {
                            Text(item.label)
                            Spacer()
                            Text(String(format: "%.1f %%", item.confidence * 100))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 200)
                }
            }
            .padding()
            .navigationTitle("MobileNetV2 Demo")
            .sheet(isPresented: $showingPicker) {
                PhotoPicker(selectedImage: $selectedImage, onImagePicked: classify)
            }
            .onChange(of: selectedModel) { oldValue, newValue in
                if let img = selectedImage {
                    classify(img)
                }
            }
        }
    }

    private func classify(_ image: UIImage) {
        predictions = []
        guard let ciImage = CIImage(image: image) else { return }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        var model: MLModel?
        switch selectedModel {
        case .MobileNetV2:
            guard let mnv2Model = try? MobileNetV2(configuration: configuration).model else { return }
            model = mnv2Model
        case .Resnet50:
            guard let rn50Model = try? Resnet50(configuration: configuration).model else { return }
            model = rn50Model
        case .FastViTMA36F16:
            guard let fvma36f16Model = try? FastViTMA36F16(configuration: configuration).model else { return }
            model = fvma36f16Model
        }

        guard let model else { return }
        guard let mlModel = try? VNCoreMLModel(for: model) else { return }

        let request = VNCoreMLRequest(model: mlModel) { (request, error) in
            if let results = request.results as? [VNClassificationObservation] {
                let top3 = results.prefix(3).map {
                    ($0.identifier, Double($0.confidence))
                }
                DispatchQueue.main.async {
                    predictions = top3
                }
            }
        }
        request.imageCropAndScaleOption = .centerCrop
        let handler = VNImageRequestHandler(ciImage: ciImage,
                                            orientation: image.cgImageOrientation,
                                            options: [:])
        print("+ ", model.modelDescription.metadata)
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, onImagePicked: onImagePicked)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        let onImagePicked: (UIImage) -> Void

        init(_ parent: PhotoPicker, onImagePicked: @escaping (UIImage) -> Void) {
            self.parent = parent
            self.onImagePicked = onImagePicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                if let uiImage = image as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.selectedImage = uiImage
                        self.onImagePicked(uiImage)
                    }
                }
            }
        }
    }
}

extension UIImage {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

#Preview {
    ContentView()
}
