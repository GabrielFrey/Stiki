import AVFoundation
import SwiftUI
import UIKit

/// UIKit camera wrapper.
///
/// SwiftUI has no first-party still-camera picker that writes a `Data` we can
/// feed the import pipeline, so this is a thin `UIImagePickerController`
/// representable. Permission denied is reported rather than presenting an
/// empty camera.
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void
    var onCancel: () -> Void
    var onDenied: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            onDenied()
            onCancel()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    Task { @MainActor in
                        onDenied()
                        onCancel()
                    }
                }
            }
        default:
            break
        }

        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.cameraCaptureMode = .photo
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onCapture: (Data) -> Void
        var onCancel: () -> Void

        init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.originalImage] as? UIImage)
            let data = image.flatMap { $0.jpegData(compressionQuality: 0.95) ?? $0.pngData() }
            if let data {
                onCapture(data)
            }
            onCancel()
        }
    }
}
