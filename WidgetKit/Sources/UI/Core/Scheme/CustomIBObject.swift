//
// CustomIBObject.swift
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

import Foundation

open class CustomIBObject: NSObject {
    
    @objc public var alias: String?
    
    public internal(set) weak var viewController: ContentViewController?
    
    @IBOutlet public var dependency: CustomIBObject? {
        willSet {
            if newValue?.dependency == self {
                preconditionFailure("Cyclic dependency not allowed: \(type(of: newValue!)) to \(type(of: self))")
            }
        }
    }
    
    public var bundle: Bundle {
        return viewController?.nibBundle ?? Bundle.main
    }
    
    public var widget: Widget? {
        return viewController?.widget
    }
    
    public private(set) var isPrepared = false
    
    open func setup() {
        //
    }
    
    @discardableResult
    open func prepare() -> [CustomIBObject] {
        let preparedChain = (dependency?.prepare() ?? []) + [self]
        isPrepared = true
        return preparedChain
    }
    
    func dependencyDepth() -> Int {
        var depth = 0
        var obj: CustomIBObject? = dependency
        while obj != nil {
            depth += 1
            obj = obj!.dependency
        }
        return depth
    }
}

public class ObjectsDictionaryProxy: NSObject {
    
    static let contentKey = "content"
    
    private var dict = [String: Any]()
    
    public override func value(forKey key: String) -> Any? {
        let object = dict[key]
        return object
    }
    
    public override func setValue(_ value: Any?, forKey key: String) {
        dict[key] = value
    }
    
    func append(_ array: [NSObject]) {
        for object in array {
            guard let key = object.wx.identifier else { continue }
            if dict[key] == nil {
                dict[key] = object
            }
        }
        for case let object as CustomIBObject in array {
            guard let alias = object.alias else { continue }
            if dict[alias] == nil {
                dict[alias] = object
            }
        }
    }
    
    init(array: [NSObject]? = nil) {
        super.init()
        append(array ?? [])
    }
    
    init(copy: ObjectsDictionaryProxy) {
        super.init()
        self.dict = copy.dict
    }
}

open class DefaultSettings: NSObject {
    
    static let settingsKey = "Settings"
    
    public static var shared = DefaultSettings()
    
    @objc open var previewLargestSideInPixels: CGFloat {
        return 400
    }
    
    open override func value(forUndefinedKey key: String) -> Any? {
        let value = UserDefaults.standard.object(forKey: key)
        return value
    }
}

public extension DefaultSettings {
    
    @objc var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
    
    @objc var appBuildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
    
    @objc var appVersionFull: String? {
        "\(appVersion) (\(appBuildNumber))"
    }
}
