import PhotosUI
import SwiftUI
import UIKit

/// A photo chosen by the user: the JPEG that is uploaded plus a preview.
struct PickedImage: Identifiable, Equatable {
    let id = UUID()
    let data: Data
    let preview: UIImage

    /// Scales large photos down and re-encodes them as JPEG so uploads stay small.
    init?(data raw: Data, maxSide: CGFloat = 1600) {
        guard let image = UIImage(data: raw) else { return nil }
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { return nil }
        data = jpeg
        preview = resized
    }

    init?(image: UIImage) {
        guard let raw = image.jpegData(compressionQuality: 0.9) else { return nil }
        self.init(data: raw)
    }

    static func load(_ items: [PhotosPickerItem]) async -> [PickedImage] {
        var result: [PickedImage] = []
        for item in items {
            if let raw = try? await item.loadTransferable(type: Data.self), let image = PickedImage(data: raw) {
                result.append(image)
            }
        }
        return result
    }
}

/// Camera capture for the chat's "Camera" option.
struct CameraPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        nonisolated func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            MainActor.assumeIsolated {
                if let image { parent.onPick(image) }
                parent.dismiss()
            }
        }

        nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            MainActor.assumeIsolated { parent.dismiss() }
        }
    }
}
