//
// WidgetView.swift
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

public class WidgetView: ContainerView {
    
    public private(set) var widget: Widget?
    
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView?
    
    @objc public var scaled = true
    @objc public var autoload = false
    @objc public var margins: CGFloat = 2
    @objc public var headerHeight: CGFloat = 22
    
    private var baseView: UIView!
    private var contentView: UIView!
    
    private var downloading = false
    
    override func setup() {
        super.setup()
        let insets = UIEdgeInsets(top: headerHeight, left: margins, bottom: margins, right: margins)
        baseView = UIView(frame: UIEdgeInsetsInsetRect(bounds, insets))
        baseView.backgroundColor = backgroundColor
        baseView.cornerRadius = cornerRadius - margins
        baseView.clipsToBounds = true
        addSubview(baseView, withEdgeConstraints: insets)
        sendSubview(toBack: baseView)
    }
    
    @objc public var resourceName: String? {
        willSet {
            precondition(widget == nil, "Can't change resourceName with loaded widget!")
        }
        didSet {
            guard autoload, let resourceName = resourceName else { return }
            async {
                self.load(resource: resourceName)
            }
        }
    }
    
    @objc public var downloadUrl: String? {
        willSet {
            precondition(widget == nil, "Can't change downloadUrl with loaded widget!")
        }
        didSet {
            guard autoload, let downloadUrl = downloadUrl else { return }
            async {
                self.download(url: URL(string: downloadUrl)!)
            }
        }
    }
    
    @objc public var widgetIdentifier: String! {
        willSet {
            precondition(widget == nil, "Can't change widgetIdentifier with loaded widget!")
        }
    }
    
    @objc public var entryPoint = "Main"
    
    public func run() {
        guard contentView == nil else { return }
        contentView = widget!.rootViewController.view!
        contentView.alpha = 0
        if scaled {
            let containerSize = baseView.bounds.size
            let contentSize = contentView.bounds.size
            let k1 = containerSize.height / containerSize.width
            let targetSize = CGSize(width: contentSize.width, height: contentSize.width * k1)
            let k2 = containerSize.height / targetSize.height
            contentView.bounds = CGRect(origin: CGPoint.zero, size: targetSize)
            contentView.transform = CGAffineTransform(scaleX: k2, y: k2)
            contentView.center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
            baseView.addSubview(contentView)
        } else {
            baseView.addSubview(contentView, withEdgeConstraints: UIEdgeInsets.zero)
        }
        contentView.unveilAlpha = 1
    }
    
    public func load(bundle path: URL) {
        guard contentView == nil else {
            print("Widget is already loaded.")
            return
        }
        precondition(widgetIdentifier != nil, "You should set widgetIdentifier first!")
        if let widget = Widget.loadBundle(with: widgetIdentifier, path: path) {
            self.widget = widget
            async() {
                self.run()
            }
        }
    }
    
    public func load(archive path: URL) {
        guard contentView == nil else {
            print("Widget is already loaded.")
            return
        }
        precondition(widgetIdentifier != nil, "You should set widgetIdentifier first!")
        Widget.loadArchive(with: widgetIdentifier, path: path) { widget, error in
            guard let widget = widget, error == nil else {
                print("Failed to load widget with identifier '\(self.widgetIdentifier)'")
                return
            }
            self.widget = widget
            self.run()
        }
    }
    
    public func load(resource: String) {
        guard let path = Bundle.main.url(forResource: resource, withExtension: nil) else {
            preconditionFailure("File '\(resource)' was not found.")
        }
        if path.pathExtension == "zip" {
            load(archive: path)
        } else {
            load(bundle: path)
        }
    }
    
    public func download(url: URL, completion: Completion? = nil) {
        guard !downloading, contentView == nil else {
            print("Widget is already loaded.")
            completion?(widget, nil)
            return
        }
        precondition(widgetIdentifier != nil, "You should set widgetIdentifier first!")
        activityIndicatorView?.startAnimating()
        downloading = true
        Widget.downloadArchive(with: widgetIdentifier, url: url, entryPoint: entryPoint) { widget, error in
            self.downloading = false
            self.activityIndicatorView?.stopAnimating()
            guard let widget = widget, error == nil else {
                print("Failed to download widget with identifier '\(self.widgetIdentifier)'")
                completion?(nil, error)
                return
            }
            self.widget = widget
            self.run()
            completion?(widget, error)
        }
    }
    
    @IBAction public func load() {
        guard contentView == nil, let resourceName = resourceName else { return }
        load(resource: resourceName)
    }
    
    @IBAction public func download() {
        guard contentView == nil, let downloadUrl = downloadUrl else { return }
        download(url: URL(string: downloadUrl)!)
    }
    
    @IBAction public func unload() {
        guard contentView != nil else { return }
        contentView.unveilAlpha = 0
        after(0.25) {
            self.contentView.removeFromSuperview()
            self.contentView = nil
        }
    }
}
