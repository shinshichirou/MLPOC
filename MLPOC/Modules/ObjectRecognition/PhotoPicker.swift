//
//  PhotoPicker.swift
//  MLPOC
//
//  Created by Igor Tudoran on 24.10.2025.
//

import SwiftUI
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PhotoPicker
        private let onImagePicked: (UIImage) -> Void

        init(parent: PhotoPicker, onImagePicked: @escaping (UIImage) -> Void) {
            self.parent = parent
            self.onImagePicked = onImagePicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                guard
                    let self,
                    let uiImage = image as? UIImage
                else {
                    return
                }

                DispatchQueue.main.async {
                    self.parent.selectedImage = uiImage
                    self.onImagePicked(uiImage)
                }
            }
        }
    }
}
