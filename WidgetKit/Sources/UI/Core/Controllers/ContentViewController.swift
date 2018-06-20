//
// ContentViewController.swift
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

open class ContentViewController: UIViewController, ContentDisplayProtocol, ObserversStorageProtocol {
    
    lazy var elements: [NSObject] = { return Array(wx_elements.union(wx_navbarElements)) }()
    
    @IBOutlet var objects: [NSObject]?
    
    public var widget: Widget? { return storyboard?.widget }
    
    var vars = ObjectsDictionaryProxy()
    var defaults = UserDefaultsProxy()
    
    public internal(set) var scheme: NSDictionary?
    
    @objc public var deriveSegueContent: Bool = true
    
    @objc public var serviceProviderClassName = "\(StandardServiceProvider.self)"
    
    @objc open var content: Any? {
        didSet {
            if isViewLoaded {
                configure()
            }
        }
    }
    
    public var observers: [Any] = []
    
    @objc var useDynamicBindings = false
    
    open func setupObservers() { }
    
    @objc open dynamic func setup() {
        vars.append(elements + (objects ?? []))
        vars.setValue(content, forKey: ObjectsDictionaryProxy.contentKey)
        vars.setValue(defaults, forKey: ObjectsDictionaryProxy.defaultsKey)
        loadScheme()
        if let objects = objects {
            for case let object as CustomIBObject in objects {
                object.viewController = self
            }
            for case let object as CustomIBObject in objects {
                object.setup()
            }
            for case let object as CustomIBObject in objects {
                object.prepare()
            }
        }
        for case let view as ContentDisplayView in elements {
            view.setup()
        }
        setupObservers()
    }
    
    open func refresh(elements: [NSObject]? = nil) {
        vars.setValue(content, forKey: ObjectsDictionaryProxy.contentKey)
        let all = (elements ?? self.elements) + [self]
        all.forEach { element in
            let info = element.wx.setupObject(using: vars, bind: useDynamicBindings)
            info.forEach { item in
                (self as? SchemeDiagnosticsProtocol)?.assigned?(to: item.target, with: item.target.wx.identifier, keyPath: item.keyPath, source: item.source, value: item.value, valueType: item.value != nil ? "\(type(of: item.value!)): \(item.value!)" : "", binding: item.binding)
            }
        }
    }
    
    @objc open dynamic func configure() {
        refresh()
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configure()
    }
    
    open override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let source = (sender as? ContentAwareProtocol) ?? (sender as? UIView)?.contentContainer()
        let destination = (segue.destination as? UINavigationController)?.topViewController ?? segue.destination
        guard let content = source?.content, let target = destination as? ContentViewController, target.deriveSegueContent else { return }
        target.storyboard?.widget = widget
        target.content = content
    }
}

extension ContentViewController {
    
    @objc open dynamic func handleError(_ error: Error, sender: ActionStatusController) {
        if let message = sender.errorMessage {
            let title = sender.errorTitle ?? NSLocalizedString("Error", comment: "")
            showAlert(title: title, message: "\(message)\n\n\(error.localizedDescription)")
        }
    }
}

extension UIViewController {
    
    var wx_elements: Set<NSObject> {
        return (view.wx.identifier != nil || view.wx.addBinding != nil) ? view.wx_elements.union([view]) : view.wx_elements
    }
    
    var wx_navbarElements: Set<NSObject> {
        var elements = Set<NSObject>()
        func addElement(_ element: NSObject?) {
            if element?.wx.identifier != nil || element?.wx.addBinding != nil {
                elements.insert(element!)
            }
        }
        if let titleView = navigationItem.titleView {
            addElement(titleView)
            titleView.allSubviews { view in
                addElement(view)
            }
        }
        let items = (navigationItem.leftBarButtonItems ?? []) + (navigationItem.rightBarButtonItems ?? [])
        items.forEach { item in
            addElement(item)
            addElement(item.customView)
            item.customView?.allSubviews { view in
                addElement(view)
            }
        }
        return elements
    }
}
