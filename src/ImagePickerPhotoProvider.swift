import Foundation
import UIKit


class ImagePickerPhotoProvider: NSObject, PhotoProvider, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let controller: UIViewController
    let sender: UIButton
    init(controller: UIViewController, sender: UIButton) {
        self.controller = controller
        self.sender = sender
    }

    var requestCompletion: (Photo?) -> Void = { _ in }
    func requestOne(completion: @escaping (Photo?) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) else {
            print("IMAGE PICKER: ERROR: Photos Album unavailable")
            completion(nil)
            return
        }

        requestCompletion = completion
        let picker = UIImagePickerController()
        picker.allowsEditing = false  // true shows funky crop-box without any way to change rect!
        picker.delegate = self
        if let presenter = picker.popoverPresentationController {
            let view = sender.titleLabel ?? sender
            presenter.sourceView = view
            presenter.sourceRect = view.bounds
        }

        print("IMAGE PICKER: INFO: Showing picker")
        controller.present(picker, animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("IMAGE PICKER: INFO: User canceled")
        defer { controller.dismiss(animated: true, completion: nil) }
        finish(with: nil)
    }

    func finish(with photo: Photo?) {
        requestCompletion(photo)
        requestCompletion = { _ in }
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        defer { controller.dismiss(animated: true, completion: nil) }

        print("IMAGE PICKER: DEBUG: User picked a photo: info", info)
        let edited = info[.editedImage] as? UIImage
        let raw = info[.originalImage] as? UIImage
        guard let image = edited ?? raw else {
            print("IMAGE PICKER: ERROR: Claimed finished picking, but neither edited nor raw image present! info", info)
            finish(with: nil)
            return
        }

        // (jeremy-w/2017-02-22)FIXME: Fish out original data from Photo Library
        let jpeg = image.jpegData(compressionQuality: 0.9)
        guard let data = jpeg ?? image.pngData() else {
            print("IMAGE PICKER: ERROR: Failed to get data for image", image, "- info", info)
            finish(with: nil)
            return
        }

        let title = NSLocalizedString("Image", comment: "photo title placeholder")
        let mime = (jpeg != nil) ? "image/jpeg" : "image/png"
        let photo = Photo(title: title, mime: mime, data: data)
        finish(with: photo)
    }
}
