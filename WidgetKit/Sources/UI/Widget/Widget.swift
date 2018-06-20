//
// Widget.swift
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
import CoreData
import Alamofire

public typealias WidgetCompletion = ((_ widget: Widget?, _ error: Error?) -> Void)

public class Widget: NSObject {
    
    public private(set) static var widgets = [String: Widget]()
    
    public private(set) var bundle: Bundle!
    
    public private(set) var rootViewController: UIViewController!
    
    public private(set) var identifier: String!
    
    public var bundleIdentifier: String {
        return bundle.bundleIdentifier!
    }
    
    public private(set) var persistentContainer: NSPersistentContainer?
    
    public var defaultContext: NSManagedObjectContext? {
        return persistentContainer?.viewContext ?? NSManagedObjectContext.main
    }
    
    public func run() {
        UIApplication.shared.keyWindow!.rootViewController = rootViewController
    }
    
    init(identifier: String, bundle: Bundle, rootViewController: UIViewController) {
        super.init()
        self.identifier = identifier
        self.bundle = bundle
        self.rootViewController = rootViewController
        self.rootViewController.storyboard?.widget = self
        if let model = NSManagedObjectModel.mergedModel(from: [bundle]), model.entities.count > 0 {
            persistentContainer = NSPersistentContainer.containerForModel(model, identifier: identifier)
        }
        Widget.widgets[identifier] = self
    }
}

extension Widget {
    
    static var widgetsDir: URL {
        return FileManager.userDocumentDirectory.appendingPathComponent("Widgets")
    }
    
    static public let defaultEntryPoint = "Main"
    
    public static func loadBundle(with identifier: String, path: URL, entryPoint: String = defaultEntryPoint) -> Widget? {
        guard let bundle = Bundle(url: path) else {
            preconditionFailure("Failed to load bundle at \(path)")
        }
        let bundleIdentifier = bundle.bundleIdentifier!
        guard identifier.hasPrefix(bundleIdentifier) else {
            preconditionFailure("Failed to load bundle: '\(identifier)' shoud start with '\(bundleIdentifier)'")
        }
        let storyboard = UIStoryboard(name: entryPoint, bundle: bundle)
        guard let vc = storyboard.instantiateInitialViewController() else {
            preconditionFailure("Bundle must contain initial view controller.")
        }
        let widget = Widget(identifier: identifier, bundle: bundle, rootViewController: vc)
        return widget
    }
    
    public static func loadArchive(with identifier: String, path: URL, entryPoint: String = defaultEntryPoint, completion: @escaping WidgetCompletion) {
        let dir = widgetsDir
        let fileName = path.lastPathComponent
        FileManager.unzip(path, to: dir) { error in
            guard error == nil else {
                completion(nil, error)
                return
            }
            var pathUrl = dir.appendingPathComponent(fileName).deletingPathExtension()
            if pathUrl.pathExtension != "bundle" {
                pathUrl = pathUrl.appendingPathExtension("bundle")
            }
            if let widget = loadBundle(with: identifier, path: pathUrl, entryPoint: entryPoint) {
                completion(widget, nil)
            } else {
                completion(nil, nil)
            }
        }
    }
    
    public static func downloadArchive(with identifier: String, url: URL, entryPoint: String = defaultEntryPoint, completion: @escaping WidgetCompletion) {
        let fileName = url.lastPathComponent
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            let fileUrl = NSTemporaryDirectory() + fileName
            return (URL(fileURLWithPath: fileUrl), [.removePreviousFile, .createIntermediateDirectories])
        }
        Alamofire.download(url, to: destination).validate().response { response in
            if let error = response.error {
                print("Failed to download file at \(url): \(error)")
                completion(nil, error)
            } else if let path = response.destinationURL {
                loadArchive(with: identifier, path: path, entryPoint: entryPoint, completion: completion)
            }
        }
    }
    
    public static func run(url: URL, identifier: String, entryPoint: String = defaultEntryPoint, completion: @escaping WidgetCompletion) {
        downloadArchive(with: identifier, url: url, entryPoint: entryPoint) { widget, error in
            guard let widget = widget, error == nil else {
                print("Failed to download widget with identifier '\(identifier)'")
                completion(nil, error)
                return
            }
            widget.run()
        }
    }
}

extension UIStoryboard {
    
    private struct AssociatedKeys {
        static var WidgetKey: String?
    }
    
    var widget: Widget? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.WidgetKey) as? Widget }
        set { objc_setAssociatedObject(self, &AssociatedKeys.WidgetKey, newValue, .OBJC_ASSOCIATION_ASSIGN) }
    }
}
