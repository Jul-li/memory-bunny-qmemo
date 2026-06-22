import SwiftUI
import UIKit

struct EditorStickerOption: Identifiable {
    let assetName: String
    let title: String

    var id: String {
        assetName
    }
}
struct PlacedEditorSticker: Identifiable, Equatable {
    private static let baseSize: CGFloat = 120
    private static let wrapPadding: CGFloat = 4
    private static let wrapVisualScale: CGFloat = 1.02

    let id: UUID
    let assetName: String
    var position: CGPoint = CGPoint(x: 254, y: 184)
    var scale: CGFloat = 1
    var rotation: Angle = .zero

    init(
        id: UUID = UUID(),
        assetName: String,
        position: CGPoint = CGPoint(x: 254, y: 184),
        scale: CGFloat = 1,
        rotation: Angle = .zero
    ) {
        self.id = id
        self.assetName = assetName
        self.position = position
        self.scale = scale
        self.rotation = rotation
    }

    init(memoSticker: MemoSticker) {
        self.init(
            id: memoSticker.id,
            assetName: memoSticker.assetName,
            position: CGPoint(x: memoSticker.positionX, y: memoSticker.positionY),
            scale: CGFloat(memoSticker.scale),
            rotation: .degrees(memoSticker.rotationDegrees)
        )
    }

    var displaySize: CGFloat {
        Self.baseSize * scale
    }

    var textExclusionPaths: [UIBezierPath] {
        EditorStickerWrapShapeCache.shared.normalizedBandRects(for: assetName).map { normalizedRect in
            let displayRect = CGRect(
                x: position.x - displaySize / 2 + normalizedRect.minX * displaySize,
                y: position.y - displaySize / 2 + normalizedRect.minY * displaySize,
                width: normalizedRect.width * displaySize,
                height: normalizedRect.height * displaySize
            )
                .insetBy(dx: -Self.wrapPadding, dy: -Self.wrapPadding)

            let scaledRect = displayRect.insetBy(
                dx: -(displayRect.width * (Self.wrapVisualScale - 1)) / 2,
                dy: -(displayRect.height * (Self.wrapVisualScale - 1)) / 2
            )
            let path = UIBezierPath(rect: scaledRect)

            guard abs(rotation.degrees) > 0.1 else {
                return path
            }

            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(x: position.x, y: position.y)
            transform = transform.rotated(by: CGFloat(rotation.radians))
            transform = transform.translatedBy(x: -position.x, y: -position.y)
            path.apply(transform)
            return path
        }
    }

    var deleteBubbleY: CGFloat {
        let preferredY = position.y - displaySize / 2 - 24
        if preferredY < 22 {
            return position.y + displaySize / 2 + 24
        }

        return preferredY
    }

    var memoSticker: MemoSticker {
        MemoSticker(
            id: id,
            assetName: assetName,
            positionX: Double(position.x),
            positionY: Double(position.y),
            scale: Double(scale),
            rotationDegrees: rotation.degrees
        )
    }
}

final class EditorStickerWrapShapeCache {
    static let shared = EditorStickerWrapShapeCache()

    private let alphaThreshold: UInt8 = 18
    private let bandCount = 18
    private var cachedRects: [String: [CGRect]] = [:]

    func normalizedBandRects(for assetName: String) -> [CGRect] {
        if let rects = cachedRects[assetName] {
            return rects
        }

        let rects = buildNormalizedBandRects(for: assetName)
        cachedRects[assetName] = rects
        return rects
    }

    private func buildNormalizedBandRects(for assetName: String) -> [CGRect] {
        guard
            let image = UIImage(named: assetName),
            let cgImage = image.cgImage,
            let alphaData = alphaData(from: cgImage)
        else {
            return [CGRect(x: 0, y: 0, width: 1, height: 1)]
        }

        let imageWidth = cgImage.width
        let imageHeight = cgImage.height
        let fittedRect = fittedImageRect(width: imageWidth, height: imageHeight)
        let rowsPerBand = max(1, Int(ceil(Double(imageHeight) / Double(bandCount))))
        var rects: [CGRect] = []

        for bandStartY in stride(from: 0, to: imageHeight, by: rowsPerBand) {
            let bandEndY = min(imageHeight, bandStartY + rowsPerBand)
            var minX = imageWidth
            var maxX = -1
            var minY = imageHeight
            var maxY = -1

            for y in bandStartY..<bandEndY {
                for x in 0..<imageWidth {
                    let alphaIndex = (y * imageWidth + x) * 4 + 3
                    guard alphaData[alphaIndex] > alphaThreshold else { continue }

                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }

            guard maxX >= minX, maxY >= minY else { continue }

            let normalizedRect = CGRect(
                x: fittedRect.minX + (CGFloat(minX) / CGFloat(imageWidth)) * fittedRect.width,
                y: fittedRect.minY + (CGFloat(minY) / CGFloat(imageHeight)) * fittedRect.height,
                width: (CGFloat(maxX - minX + 1) / CGFloat(imageWidth)) * fittedRect.width,
                height: (CGFloat(maxY - minY + 1) / CGFloat(imageHeight)) * fittedRect.height
            )
            rects.append(normalizedRect)
        }

        return rects.isEmpty ? [CGRect(x: 0, y: 0, width: 1, height: 1)] : rects
    }

    private func alphaData(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    private func fittedImageRect(width: Int, height: Int) -> CGRect {
        let imageWidth = CGFloat(width)
        let imageHeight = CGFloat(height)
        guard imageWidth > 0, imageHeight > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        let aspect = imageWidth / imageHeight
        if aspect >= 1 {
            let fittedHeight = 1 / aspect
            return CGRect(x: 0, y: (1 - fittedHeight) / 2, width: 1, height: fittedHeight)
        }

        let fittedWidth = aspect
        return CGRect(x: (1 - fittedWidth) / 2, y: 0, width: fittedWidth, height: 1)
    }
}

struct EditableEditorStickerView: View {
    @Binding var sticker: PlacedEditorSticker
    let onSelect: () -> Void
    let onRequestDelete: () -> Void

    @State private var dragStartPosition: CGPoint?
    @GestureState private var gestureScale: CGFloat = 1
    @GestureState private var gestureRotation: Angle = .zero

    var body: some View {
        let drag = DragGesture()
            .onChanged { value in
                let startPosition = dragStartPosition ?? sticker.position
                dragStartPosition = startPosition
                sticker.position = CGPoint(
                    x: startPosition.x + value.translation.width,
                    y: startPosition.y + value.translation.height
                )
            }
            .onEnded { _ in
                dragStartPosition = nil
            }

        let magnify = MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                sticker.scale = min(max(sticker.scale * value, 0.45), 2.2)
            }

        let rotate = RotationGesture()
            .updating($gestureRotation) { value, state, _ in
                state = value
            }
            .onEnded { value in
                sticker.rotation += value
            }

        Image(sticker.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
            .scaleEffect(min(max(sticker.scale * gestureScale, 0.45), 2.2))
            .rotationEffect(sticker.rotation + gestureRotation)
            .contentShape(Rectangle())
            .position(
                x: sticker.position.x,
                y: sticker.position.y
            )
            .onTapGesture {
                onSelect()
            }
            .gesture(drag.simultaneously(with: magnify).simultaneously(with: rotate))
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.55)
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                            onRequestDelete()
                        }
                    }
            )
            .accessibilityLabel("贴纸")
    }
}
