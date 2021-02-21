//
// StandardMediaPickerController.swift
//
// WidgetKit, Copyright (c) 2018 M8 Labs (http://m8labs.com)
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
import MobileCoreServices

public class PHAssetView: UIImageView {
    
    private static var imageCache = NSCache<NSString, UIImage>()
    
    @IBOutlet var progressView: UIProgressView?
    
    @objc public var largestSideInPixels = 0
    
    var targetSize: CGSize {
        return largestSideInPixels > 0 ? CGSize(width: largestSideInPixels, height: largestSideInPixels) :
            CGSize(width: DefaultSettings.shared.previewLargestSideInPixels, height: DefaultSettings.shared.previewLargestSideInPixels)
    }
    
    @objc public var asset: PHAsset? {
        didSet {
            guard let asset = self.asset else {
                self.image = nil
                return
            }
            if let image = PHAssetView.imageCache.object(forKey: asset.localIdentifier as NSString) {
                self.image = image
            } else {
                StandardMediaPickerController.requestImage(for: asset, targetSize: targetSize, progress: { [weak self] progress in
                    self?.progressView?.progress = progress
                }) { [weak self] image, error in
                    guard asset == self?.asset else { return }
                    self?.image = image
                    if image != nil {
                        PHAssetView.imageCache.setObject(image!, forKey: asset.localIdentifier as NSString)
                    }
                }
            }
        }
    }
    
    override open var wx_value: Any? {
        get { return super.wx_value }
        set {
            if let value = newValue as? PHAsset {
                asset = value
            } else {
                super.wx_value = newValue
            }
        }
    }
}

public class StandardMediaPickerController: ButtonActionController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet public weak var imageView: UIImageView?
    
    @objc public private(set) var pickerResult: MediaPickerResult? {
        didSet {
            refreshImageView()
        }
    }
    
    @objc public var showOptions = true
    
    @objc public var imagesOnly = false
    
    @objc public var saveCaperaOutput = true
    
    @objc public var cameraOptionTitle = NSLocalizedString("Take With Camera", comment: "")
    
    @objc public var libraryOptionTitle = NSLocalizedString("Choose From Library", comment: "")
    
    @objc public var cancelOptionTitle = NSLocalizedString("Cancel", comment: "")
    
    public var finished: ((Error?) -> Void)?
    
    public func pick(with sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.videoQuality = .typeIFrame1280x720
        if !imagesOnly {
            picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary) ?? []
        }
        viewController?.present(picker, animated: true)
    }
    
    public override func performAction(with object: Any? = nil) {
        let perform = {
            if self.showOptions && UIImagePickerController.isSourceTypeAvailable(.camera) {
                self.viewController?.showActionSheet(message: nil, options: [
                    (self.cameraOptionTitle, false, { [weak self] in self?.pick(with: .camera) }),
                    (self.libraryOptionTitle, false, { [weak self] in self?.pick(with: .photoLibrary) }),
                    (self.cancelOptionTitle, false, nil)])
            } else {
                self.pick(with: .photoLibrary)
            }
        }
        let showError = {
            self.viewController?.showAlert(message: NSLocalizedString("Photo access was not granted by the user.", comment: ""))
        }
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            perform()
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                asyncMain {
                    guard status == .authorized else { showError(); return }
                    perform()
                }
            }
        }
    }
    
    public static func saveFileWithObject(_ object: Any?, resourceType: PHAssetResourceType, completion: @escaping (PHAsset?, Error?)->Void) {
        guard object is UIImage || object is URL else {
            preconditionFailure("Saved object should be either UIImage or file's URL.")
        }
        let save = {
            var assetRequest:PHAssetChangeRequest? = nil
            var assetPlaceholder:PHObjectPlaceholder? = nil
            PHPhotoLibrary.shared().performChanges({
                assetRequest = object is UIImage ?
                    PHAssetChangeRequest.creationRequestForAsset(from: object as! UIImage) :
                    (resourceType == .video ? PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: object as! URL) : PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: object as! URL))
                assetPlaceholder = assetRequest!.placeholderForCreatedAsset
            }) { saved, error in
                asyncMain {
                    if error != nil {
                        completion(nil, error)
                    } else if saved {
                        completion(assetPlaceholder!.asset, nil)
                    } else {
                        completion(nil, nil) // wtf??
                    }
                }
            }
        }
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            save()
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                asyncMain {
                    guard status == .authorized else { completion(nil, nil); return }
                    save()
                }
            }
        }
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        pickerResult = MediaPickerResult(info: info)
        if saveCaperaOutput && pickerResult!.asset == nil {
            guard pickerResult!.mediaUrl != nil || pickerResult!.originalImage != nil else {
                preconditionFailure("Picker doesn't contain any useful objects.")
            }
            Self.saveFileWithObject(pickerResult!.mediaUrl ?? pickerResult!.originalImage,
                                    resourceType: pickerResult!.isMovie ? .video : .photo)
            { asset, error in
                guard error == nil else { self.finished?(error); return }
                var info = info
                info["UIImagePickerControllerPHAsset"] = asset
                self.pickerResult = MediaPickerResult(info: info)
                picker.dismiss(animated: true) { self.finished?(nil) }
            }
        } else {
            picker.dismiss(animated: true) { self.finished?(nil) }
        }
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { self.finished?(nil) }
    }
    
    public func resetSelection() {
        pickerResult = nil
    }
    
    private func refreshImageView() {
        if let assetView = imageView as? PHAssetView, let asset = pickerResult?.asset {
            assetView.asset = asset
        } else {
            imageView?.image = pickerResult?.currentImage
        }
    }
}

extension PHObjectPlaceholder {
    
    var asset: PHAsset? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        return result.firstObject
    }
}

public extension StandardMediaPickerController {
    
    static func requestImage(for asset: PHAsset, targetSize: CGSize, progress: @escaping (Float)->Void, completion: @escaping (UIImage?, Error?)->Void) {
        let options = PHImageRequestOptions()
        options.version = .current
        options.isNetworkAccessAllowed = true
        options.progressHandler = { percent, error, _, _ in
            progress(Float(percent))
        }
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
            completion(image, info?[PHImageErrorKey] as? Error)
        }
    }
    
    static func requestImageData(for asset: PHAsset, targetSize: CGSize?, progress: @escaping (Float)->Void, completion: @escaping (Data?, Error?)->Void) {
        let options = PHImageRequestOptions()
        options.version = .current
        options.isNetworkAccessAllowed = true
        if let targetSize = targetSize {
            options.isSynchronous = true
            asyncGlobal {
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
                    guard let image = image else {
                        return asyncMain {
                            completion(nil, info?[PHImageErrorKey] as? Error)
                        }
                    }
                    let resizedImage = image.sizedToFit(targetSize)
                    let data = UIImageJPEGRepresentation(resizedImage, UIImage.defaultJPEGCompression)
                    asyncMain {
                        completion(data, nil)
                    }
                }
            }
        } else {
            options.progressHandler = { percent, error, _, _ in
                progress(Float(percent))
            }
            PHImageManager.default().requestImageData(for: asset, options: options) { data, dataUti, orientation, info in
                guard let data = data else {
                    return completion(nil, info?[PHImageErrorKey] as? Error)
                }
                completion(data, nil)
            }
        }
    }
    
    static func requestImageFile(for asset: PHAsset, targetSize: CGSize?, progress: @escaping (Float)->Void, completion: @escaping (String?, UInt64?, Error?)->Void) {
        let outputPath = asset.tmpImagePath(with: targetSize != nil ? "\(Int(targetSize!.width))x\(Int(targetSize!.height))" : "original")
        if FileManager.default.fileExists(atPath: outputPath) {
            return completion(outputPath, outputPath.fileSize, nil)
        }
        StandardMediaPickerController.requestImageData(for: asset, targetSize: targetSize, progress: progress) { data, error in
            guard let data = data else {
                return completion(nil, nil, error)
            }
            asyncGlobal {
                do {
                    let url = URL(fileURLWithPath: outputPath)
                    try data.write(to: url, options: .atomic)
                    let fileSize = outputPath.fileSize
                    asyncMain {
                        completion(outputPath, fileSize, nil)
                    }
                } catch {
                    asyncMain {
                        completion(nil, nil, error)
                    }
                }
            }
        }
    }
    
    static func requestVideoFile(for asset: PHAsset, quality: VideoQuality, progress: @escaping (Float)->Void, completion: @escaping (String?, UInt64?, Error?)->Void) {
        let outputPath = asset.tmpVideoPath
        if FileManager.default.fileExists(atPath: outputPath) {
            return completion(outputPath, outputPath.fileSize, nil)
        }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = { percent, error, _, _ in
            progress(Float(percent))
        }
        PHImageManager.default().requestExportSession(forVideo: asset, options: options, exportPreset: quality.exportPreset) { exportSession, info in
            guard let session = exportSession else {
                return completion(nil, 0, info?[PHImageErrorKey] as? Error)
            }
            session.outputURL = URL(fileURLWithPath: outputPath)
            session.outputFileType = .mov
            session.shouldOptimizeForNetworkUse = true
            session.exportAsynchronously {
                let fileSize = session.outputURL?.path.fileSize
                asyncMain {
                    completion(session.outputURL?.path, fileSize, session.error)
                }
            }
            asyncGlobal {
                while session.status == .waiting || session.status == .exporting {
                    asyncMain {
                        progress(session.progress)
                    }
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }
    }
    
    static func requestMediaFile(for asset: PHAsset, imageSize: CGSize? = nil, videoQuality: VideoQuality = .medium, progress: @escaping (Float)->Void, completion: @escaping (String?, UInt64?, Error?)->Void) {
        switch asset.mediaType {
        case .image:
            StandardMediaPickerController.requestImageFile(for: asset, targetSize: imageSize, progress: progress, completion: completion)
        case .video:
            StandardMediaPickerController.requestVideoFile(for: asset, quality: videoQuality, progress: progress, completion: completion)
        default:
            completion(nil, nil, nil)
        }
    }
}

public class MediaPickerResult: NSObject {
    
    var info: [String: Any]
    
    public init(info: [String: Any]) {
        self.info = info
    }
    
    @objc public var mediaType: String { return info[UIImagePickerControllerMediaType] as! String }
    
    @objc public var editedImage: UIImage? { return info[UIImagePickerControllerEditedImage] as? UIImage }
    
    @objc public var originalImage: UIImage? { return info[UIImagePickerControllerOriginalImage] as? UIImage }
    
    @objc public var currentImage: UIImage? { return editedImage ?? originalImage }
    
    @objc public var asset: PHAsset? {
        if #available(iOS 11.0, *) {
            return info[UIImagePickerControllerPHAsset] as? PHAsset
        } else if let assetUrl = info[UIImagePickerControllerReferenceURL] as? URL {
            let result = PHAsset.fetchAssets(withALAssetURLs: [assetUrl], options: nil)
            return result.firstObject
        }
        return nil
    }
    
    @available(iOS 11.0, *)
    @objc public var imageUrl: URL? { return info[UIImagePickerControllerImageURL] as? URL }
    
    @objc public var mediaUrl: URL? { return info[UIImagePickerControllerMediaURL] as? URL }
    
    @available(iOS 11.0, *)
    @objc public var fileUrl: URL? { return imageUrl ?? mediaUrl }
    
    @objc public var isMovie: Bool { return mediaType == String(kUTTypeMovie) }
}

public enum VideoQuality {
    
    case unspecified, low, medium, max
    
    var exportPreset: String {
        switch self {
        case .low:
            return AVAssetExportPresetLowQuality
        case .max:
            return AVAssetExportPresetHighestQuality
        default:
            return AVAssetExportPresetMediumQuality
        }
    }
}

extension UIImage {
    
    public static let defaultJPEGCompression: CGFloat = 0.9
}

public extension URL {
    
    var contentDimensions: CGSize? {
        guard let source = CGImageSourceCreateWithURL(self as CFURL, nil) else {
            return nil
        }
        let propertiesOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, propertiesOptions) as? [CFString: Any] else {
            return nil
        }
        if let w = properties[kCGImagePropertyPixelWidth] as? CGFloat, let h = properties[kCGImagePropertyPixelHeight] as? CGFloat {
            return CGSize(width: w, height: h)
        } else {
            return nil
        }
    }
}

public extension String {
    
    var pathExtension: String {
        return (self as NSString).pathExtension
    }
    
    var contentDimensions: CGSize? {
        return URL(fileURLWithPath: self).contentDimensions
    }
    
    var fileSize: UInt64? {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: self) as NSDictionary {
            return attrs.fileSize()
        }
        return nil
    }
}

extension PHAsset {
    
    var tmpVideoPath: String {
        return NSTemporaryDirectory() + "tmp\(localIdentifier.replacingOccurrences(of: "/", with: "-")).mov"
    }
    
    func tmpImagePath(with tag: String) -> String {
        return NSTemporaryDirectory() + "tmp\(localIdentifier.replacingOccurrences(of: "/", with: "-"))-\(tag).jpeg"
    }
}

extension UIImage {
    
    func sizeThatFits(_ fitSize: CGSize) -> CGSize {
        let aspectRatio = size.width / size.height
        if aspectRatio > 1 {
            return CGSize(width: fitSize.width, height: fitSize.width / aspectRatio)
        } else {
            return CGSize(width: fitSize.height * aspectRatio, height: fitSize.height)
        }
    }
    
    func sizedTo(_ size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: CGSize(width: size.width + 1, height: size.height + 1))) // +1 crops last row/colomn - they can be empty because of inaccuracy in resizing
        }
    }
    
    func sizedToFit(_ size: CGSize) -> UIImage {
        sizedTo(sizeThatFits(size))
    }
}
