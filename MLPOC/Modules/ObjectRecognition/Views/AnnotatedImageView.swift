//
//  AnnotatedImageView.swift
//  MLPOC
//
//  Created by ChatGPT on 26.10.2025.
//

import SwiftUI
import UIKit

struct AnnotatedImageView: View {
    let image: UIImage
    let detections: [DetectionPrediction]

    var body: some View {
        GeometryReader { geometry in
            let displayRect = calculateDisplayRect(for: image.size,
                                                   in: geometry.size)

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width,
                           height: geometry.size.height)
                    .clipped()

                ForEach(detections) { detection in
                    DetectionBoundingBoxView(
                        rect: convertToViewRect(boundingBox: detection.boundingBox,
                                                displayRect: displayRect),
                        label: detection.label,
                        confidence: detection.confidence
                    )
                }
            }
        }
    }

    private func calculateDisplayRect(for imageSize: CGSize,
                                      in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let scale = min(containerSize.width / imageSize.width,
                        containerSize.height / imageSize.height)
        let displaySize = CGSize(width: imageSize.width * scale,
                                 height: imageSize.height * scale)
        let origin = CGPoint(x: (containerSize.width - displaySize.width) / 2,
                             y: (containerSize.height - displaySize.height) / 2)

        return CGRect(origin: origin, size: displaySize)
    }

    private func convertToViewRect(boundingBox: CGRect,
                                   displayRect: CGRect) -> CGRect {
        let width = boundingBox.size.width * displayRect.size.width
        let height = boundingBox.size.height * displayRect.size.height

        let x = displayRect.origin.x + (boundingBox.origin.x * displayRect.size.width)
        let y = displayRect.origin.y + ((1 - boundingBox.origin.y - boundingBox.size.height) * displayRect.size.height)

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private struct DetectionBoundingBoxView: View {
    let rect: CGRect
    let label: String
    let confidence: Double

    private var confidenceText: String {
        String(format: "%.0f%%", confidence * 100)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(rect)
            }
            .stroke(Color.accentColor, lineWidth: 2)

            Text("\(label) \(confidenceText)")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.85))
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .offset(x: rect.minX + 4, y: rect.minY + 4)
        }
    }
}
