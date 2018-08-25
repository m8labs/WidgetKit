//
// ContentDisplayView.swift
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

@objc
public protocol ContentAwareProtocol: class {
    var content: Any? { get set }
}

@objc
public protocol ContentDisplayProtocol: ContentAwareProtocol {
    
    var scheme: NSDictionary?  { get }
    
    var widget: Widget? { get }
    
    func configure()
    
    func refresh(elements: [NSObject]?)
}

@objc
public protocol ContentFormProtocol: class {
    
    weak var actionController: ActionController! { get set }
    
    var mandatoryFields: [UIView]! { get set }
    
    var optionalFields: [UIView]? { get set }
    
    var formValue: [String: Any]? { get }
    
    func highlightField(_ view: UIView, error: Error?)
}

open class ContentDisplayView: UIView, ContentDisplayProtocol, ObserversStorageProtocol {
    
    lazy var elements: [NSObject] = { return Array(wx_elements) }()
    
    lazy var resizingElements: [UIView] = { return wx_resizingElements }()
    
    var vars = ObjectsDictionaryProxy()
    
    public internal(set) weak var widget: Widget?
    
    public internal(set) var scheme: NSDictionary?
    
    @objc open var content: Any? {
        didSet {
            configure()
        }
    }
    
    public var observers: [Any] = []
    
    open func setupObservers() { }
    
    open func setup(scheme dict: NSDictionary? = nil) {
        vars.append(elements)
        vars.setValue(UserDefaultsProxy(), forKey: ObjectsDictionaryProxy.defaultsKey)
        setupObservers()
        if let dict = dict {
            self.scheme = dict
            Scheme.resolve(with: dict, vars: vars, viewController: viewController() as? ContentViewController)
        }
    }
    
    open func refresh(elements: [NSObject]? = nil) {
        vars.setValue(content, forKey: ObjectsDictionaryProxy.contentKey)
        (elements ?? self.elements)?.forEach { element in
            let info = element.wx.setupObject(using: vars, bind: false)
            info.forEach { item in
                (self as? SchemeDiagnosticsProtocol)?.assigned?(to: item.target, with: item.target.wx.identifier, keyPath: item.keyPath, source: item.source, value: item.value, valueType: item.value != nil ? "\(type(of: item.value!)): \(item.value!)" : "", binding: item.binding)
            }
        }
    }
    
    @objc open dynamic func configure() {
        refresh()
    }
}

extension UIView {
    
    var wx_elements: Set<NSObject> {
        var elements = Set<NSObject>()
        allSubviews { view in
            if view.wx.identifier != nil || view.wx.addBinding != nil {
                elements.insert(view)
            }
            view.constraints.forEach { c in
                if c.wx.identifier != nil || c.wx.addBinding != nil {
                    elements.insert(c)
                }
            }
        }
        return elements
    }
    
    var wx_resizingElements: [UIView] {
        var elements = [UIView]()
        allSubviews { view in
            if view.wx.layoutHint.isEmpty == false {
                elements.append(view)
            }
        }
        return elements
    }
}
