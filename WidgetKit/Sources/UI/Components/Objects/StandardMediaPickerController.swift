//
// StandardMediaPickerController.swift
//
// WidgetKit, Copyright (c) 2018 Favio Mobile (http://favio.mobi)
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
import Alamofire
import MobileCoreServices

public class MediaUploadFormView: FormDisplayView {
    
    @IBOutlet var uploadContainer: UploadContainerView! {
        didSet {
            mandatoryFields = [uploadContainer]
        }
    }
    
    @IBOutlet var progressBar: UIView?
    
    var resultInfo: Any?
    
    @objc public var resultInfoValueKey: String?
    
    public var result: Any? {
        guard let resultInfo = resultInfo as? NSObject, let resultInfoValueKey = resultInfoValueKey, uploadContainer.hasMedia else { return nil }
        return resultInfo.value(forKeyPath: resultInfoValueKey)
    }
    
    @objc public var autoUpload = true
    
    var progress: Double = 0 {
        didSet {
            progressBar?.isHidden = progress == 1.0 || progress == 0
            progressBar?.wx_value = progress
        }
    }
    
    public override func setupObservers() {
        let observersForAction: ((String) -> [Any]) = { action in
            return [
                action.notification.onProgress.subscribe(to: self) { [weak self] n in
                    if let progress = n.objectFromUserInfo as? Progress {
                        self?.progress = progress.fractionCompleted
                    }
                },
                action.notification.onReady.subscribe(to: self) { [weak self] n in
                    self?.progress = 1.0
                    self?.actionController.cancelButton?.isHidden = true
                    self?.resultInfo = n.objectFromUserInfo
                },
                action.notification.onError.subscribe(to: self) { [weak self] n in
                    self?.progress = 0
                    self?.actionController.cancelButton?.isHidden = true
                }
            ]
        }
        // We can't know beforehand what action will be chosen, so we set both
        if let action = actionController.actionName {
            observers.append(contentsOf: observersForAction(action))
        }
        if let elseAction = actionController.elseActionName {
            observers.append(contentsOf: observersForAction(elseAction))
        }
    }
    
    public func beginUpload() {
        uploadContainer.prepare { [weak self] in
            self?.actionController.cancelButton?.isHidden = false
            self?.actionController.sender = self
            self?.actionController.performAction()
        }
    }
    
    public func shouldBeginUpload(with info: MediaPickerResultInfo) {
        progress = 0
        unveilAlpha = 1
        uploadContainer.pickerResult = info
        if autoUpload {
            beginUpload()
        }
    }
    
    @IBAction func detachAction(_ sender: Any?) {
        actionController.cancelAction()
        progress = 0
        unveilAlpha = 0
        uploadContainer.pickerResult = nil
        actionController.viewController.configure()
    }
}

extension MediaUploadFormView {
    /*
     Any UIView can have wx_fieldValue, including FormDisplayView, because forms can be nested
     This form field value is not for this form, but for outside form.
     */
    public override var wx_fieldValue: Any? {
        get { return result }
        set { }
    }
}

public class UploadContainerView: UIView {
    
    @IBOutlet var previewView: UIView?
    @IBOutlet var prepareIndicator: UIView?
    
    func requestPreview() {
        guard let asset = asset, let previewView = previewView else { return }
        prepareIndicator?.wx_value = true
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset,
                                              targetSize: previewView.bounds.size,
                                              contentMode: .aspectFill,
                                              options: options)
        { [weak self] image, info in
            self?.preview = image
            self?.prepareIndicator?.wx_value = false
        }
    }
    
    var pickerResult: MediaPickerResultInfo? {
        didSet {
            objectToUpload = nil
            guard let pickerResult = pickerResult else {
                image = nil
                asset = nil
                fileUrl = nil
                return
            }
            if let image = pickerResult.editedImage {
                self.image = image
            } else if let image = pickerResult.originalImage {
                self.image = image
            }
            if pickerResult.isMovie {
                if #available(iOS 11.0, *) {
                    if let asset = pickerResult.asset {
                        self.asset = asset
                    }
                }
                if let fileUrl = pickerResult.fileUrl {
                    self.fileUrl = fileUrl
                }
            }
        }
    }
    
    fileprivate var objectToUpload: Any?
    
    func prepare(with finish: @escaping () -> Void) {
        if let fileUrl = fileUrl {
            objectToUpload = fileUrl
            finish()
        } else if let image = image {
            prepareIndicator?.wx_value = true
            let compression = self.imageCompression
            asyncGlobal {
                let data = UIImageJPEGRepresentation(image, compression)
                async { [weak self] in
                    self?.objectToUpload = data
                    self?.prepareIndicator?.wx_value = false
                    finish()
                }
            }
        }
    }
    
    public var preview: Any? {
        get {
            return previewView?.wx_value
        }
        set {
            previewView?.wx_value = newValue
        }
    }
    
    public var image: UIImage? {
        didSet {
            preview = image
        }
    }
    
    public var asset: PHAsset? {
        didSet {
            if asset != nil {
                requestPreview()
            }
        }
    }
    
    public var fileUrl: URL?
    
    @objc public var isMovie: Bool {
        return pickerResult?.isMovie ?? false
    }
    
    @objc public var hasMedia: Bool {
        return pickerResult != nil
    }
    
    @objc public var imageCompression = UIImage.defaultJPEGCompression
}

extension UploadContainerView {
    
    public override var wx_fieldValue: Any? {
        get { return objectToUpload }
        set { }
    }
}

public class StandardMediaPickerController: ButtonActionController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet var forms: [MediaUploadFormView]?
    
    @objc public var pickedNumber: Int {
        return forms?.filter({ $0.uploadContainer.pickerResult != nil }).count ?? 0
    }
    
    @objc public var showOptions = true
    
    @objc public var imagesOnly = false
    
    @objc public var cameraOptionTitle = NSLocalizedString("Take With Camera", comment: "")
    
    @objc public var libraryOptionTitle = NSLocalizedString("Choose From Library", comment: "")
    
    @objc public var cancelOptionTitle = NSLocalizedString("Cancel", comment: "")
    
    public override func performAction() {
        let picker = UIImagePickerController()
        picker.delegate = self
        let pick: (UIImagePickerControllerSourceType) -> Void = { sourceType in
            picker.sourceType = sourceType
            if !self.imagesOnly {
                picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary) ?? []
            }
            self.viewController.present(picker, animated: true)
        }
        if showOptions && UIImagePickerController.isSourceTypeAvailable(.camera) {
            viewController.showActionSheet(message: nil, options: [
                (cameraOptionTitle,  { pick(.camera) }),
                (libraryOptionTitle, { pick(.photoLibrary) }),
                (cancelOptionTitle,  nil)])
        } else {
            pick(.photoLibrary)
        }
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        if let form = forms?.filter({ $0.uploadContainer.pickerResult == nil }).first {
            form.shouldBeginUpload(with: MediaPickerResultInfo(info: info))
            picker.dismiss(animated: true)
        }
    }
}

public class MediaPickerResultInfo {
    
    var info: [String: Any]
    
    public init(info: [String: Any]) {
        self.info = info
    }
    
    public var mediaType: CFString { return info[UIImagePickerControllerMediaType] as! CFString }
    
    public var originalImage: UIImage? { return info[UIImagePickerControllerOriginalImage] as? UIImage }
    
    public var editedImage: UIImage? { return info[UIImagePickerControllerEditedImage] as? UIImage }
    
    @available(iOS 11.0, *)
    public var asset: PHAsset? { return info[UIImagePickerControllerPHAsset] as? PHAsset }
    
    public var fileUrl: URL? { return info[UIImagePickerControllerMediaURL] as? URL }
    
    var isMovie: Bool { return mediaType == kUTTypeMovie }
}

extension UIImage {
    
    public static let defaultJPEGCompression: CGFloat = 0.9
}
