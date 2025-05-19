// The MIT License (MIT)
//
// Copyright (c) 2019 Joakim Gyllström
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit
import Photos

/// Closure convenience API.
/// Keep this simple enough for most users. More niche features can be added to ImagePickerControllerDelegate.
@objc extension UIViewController {
    
    /// Present a image picker
    ///
    /// - Parameters:
    ///   - imagePicker: The image picker to present
    ///   - animated: Should presentation be animated
    ///   - select: Selection callback
    ///   - deselect: Deselection callback
    ///   - cancel: Cancel callback
    ///   - finish: Finish callback
    ///   - completion: Presentation completion callback
    public func presentImagePicker(_ imagePicker: ImagePickerController, animated: Bool = true, select: ((_ asset: PHAsset) -> Void)?, deselect: ((_ asset: PHAsset) -> Void)?, cancel: (([PHAsset]) -> Void)?, finish: (([PHAsset]) -> Void)?, completion: (() -> Void)? = nil) {
        authorize {
            // Set closures
            imagePicker.onSelection = select
            imagePicker.onDeselection = deselect
            imagePicker.onCancel = cancel
            imagePicker.onFinish = finish

            // And since we are using the blocks api. Set ourselfs as delegate
            imagePicker.imagePickerDelegate = imagePicker

            // Present
            self.present(imagePicker, animated: animated, completion: completion)
        }
    }

    private func authorize(_ authorized: @escaping () -> Void) {
        if #available(iOS 15, *) {
            // iOS 15 and above: Handle new limited access case
            authorizePhotoLibrary(authorized)
        } else {
            authorizePhotoLibraryLegacy(authorized)
        }
    }
    
    @available(iOS 14, *)
    private func authorizePhotoLibrary(_ authorized: @escaping () -> Void) {
        // Check photo library authorization status with .readWrite access (iOS 14+)
        // Use authorizationStatus(for:) to handle the new 'limited' access case
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized:
            DispatchQueue.main.async(execute: authorized)
        case .limited:
            let fetchOptions = PHFetchOptions()
            let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            if result.count > 0 {
                // Proceed if user has access to some photos
                DispatchQueue.main.async(execute: authorized)
            } else {
                guard #available(iOS 15, *) else {
                    DispatchQueue.main.async(execute: authorized)
                    return
                }
                
                // If no photos accessible, prompt user with system's limited library picker (iOS 15+)
                // so they can select more photos to grant access to.
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self) { selected in
                    // Ensure user selected at least one photo, otherwise don't proceed
                    guard !selected.isEmpty else { return }
                    DispatchQueue.main.async(execute: authorized)
                }
            }
        default:
            break
        }
    }
    
    private func authorizePhotoLibraryLegacy(_ authorized: @escaping () -> Void) {
        PHPhotoLibrary.requestAuthorization { (status) in
            switch status {
            case .authorized:
                DispatchQueue.main.async(execute: authorized)
            default:
                break
            }
        }
    }
}

extension ImagePickerController {
    public static var currentAuthorization : PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus()
    }
}

/// ImagePickerControllerDelegate closure wrapper
extension ImagePickerController: ImagePickerControllerDelegate {
    public func imagePicker(_ imagePicker: ImagePickerController, didSelectAsset asset: PHAsset) {
        onSelection?(asset)
    }

    public func imagePicker(_ imagePicker: ImagePickerController, didDeselectAsset asset: PHAsset) {
        onDeselection?(asset)
    }

    public func imagePicker(_ imagePicker: ImagePickerController, didFinishWithAssets assets: [PHAsset]) {
        onFinish?(assets)
    }

    public func imagePicker(_ imagePicker: ImagePickerController, didCancelWithAssets assets: [PHAsset]) {
        onCancel?(assets)
    }

    public func imagePicker(_ imagePicker: ImagePickerController, didReachSelectionLimit count: Int) {
        
    }
}
