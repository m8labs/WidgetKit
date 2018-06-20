//
// Scheme.swift
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

enum SchemeKey: String {
    case type, alias, attrs, evals, objects, elements, bindings, outlets, action, target, selector, `self` = "@self", comment = "***"
}

class Scheme {
    
    private static let topLevelAttributes = [SchemeKey.type.rawValue, SchemeKey.alias.rawValue, SchemeKey.attrs.rawValue, SchemeKey.evals.rawValue, SchemeKey.outlets.rawValue, SchemeKey.comment.rawValue]
    
    static func updateObject(_ object: CustomIBObject, with dict: [String: Any]) {
        dict.keys.forEach { key in
            precondition(Scheme.topLevelAttributes.contains(key), "Unrecognized top level attribute: '\(key)'.")
        }
        object.alias = dict[SchemeKey.alias.rawValue] as? String
        if let rawAttrs = dict[SchemeKey.attrs.rawValue] as? [String: Any] {
            NSObject.update(object, with: rawAttrs)
        }
        if let rawEvals = dict[SchemeKey.evals.rawValue] as? [String: [String: Any]] {
            rawEvals.forEach { key, value in
                object.wx.addEval(key, dictionary: value)
            }
        }
    }
    
    static func createObject(withDictionary dict: [String: Any], identifier: String) -> CustomIBObject? {
        if let className = dict[SchemeKey.type.rawValue] as? String, let object = NSObject.create(withClassName: className) as? CustomIBObject {
            object.wx.identifier = identifier
            updateObject(object, with: dict)
            return object
        }
        return nil
    }
    
    static func resolveOutlets(_ rawObjects: [String: Any], vars: ObjectsDictionaryProxy, viewController: ContentViewController?) {
        rawObjects.forEach { objectKey, rawObject in
            if let rawDict = rawObject as? [String: Any], let rawOutlets = rawDict[SchemeKey.outlets.rawValue] as? [String: Any] {
                rawOutlets.forEach { attrKey, rawOutlet in
                    if let outletSchemeKeys = rawOutlet as? [String] {
                        outletSchemeKeys.forEach { outletKey in
                            if let object = vars.value(forKey: objectKey) as? NSObject, let outlet = vars.value(forKey: outletKey) as? NSObject {
                                var outlets = object.value(forKey: attrKey) as? [NSObject] ?? [NSObject]()
                                outlets.append(outlet)
                                object.setValue(outlets, forKey: attrKey)
                                (viewController as? SchemeDiagnosticsProtocol)?.outlet?(outlet, addedTo: object, propertyKey: attrKey, outletKey: outletKey)
                            }
                        }
                    } else if let outletKey = rawOutlet as? String {
                        if let object = vars.value(forKey: objectKey) as? NSObject, let outlet = vars.value(forKey: outletKey) as? NSObject {
                            object.setValue(outlet, forKey: attrKey)
                            (viewController as? SchemeDiagnosticsProtocol)?.outlet?(outlet, addedTo: object, propertyKey: attrKey, outletKey: outletKey)
                        }
                    }
                }
            }
        }
    }
    
    static func updateUIElements(_ rawElements: [String: Any], vars: ObjectsDictionaryProxy, viewController: ContentViewController?) {
        rawElements.forEach { elementKey, rawElement in
            // IBAction
            if let rawDict = rawElement as? [String: Any], let rawAction = rawDict[SchemeKey.action.rawValue] as? [String: Any] {
                if let targetId = rawAction[SchemeKey.target.rawValue] as? String, let selector = rawAction[SchemeKey.selector.rawValue] as? String {
                    if let target = (vars.value(forKey: targetId) ?? viewController?.vars.value(forKey: targetId)) as? NSObject {
                        if let button = vars.value(forKey: elementKey) as? UIButton {
                            button.addTarget(target, action: Selector(selector), for: .primaryActionTriggered)
                        }
                        else if let button = vars.value(forKey: elementKey) as? UIBarButtonItem {
                            button.target = target
                            button.action = Selector(selector)
                        }
                    }
                }
            }
            // Runtime Attributes
            if let rawDict = rawElement as? [String: Any], let rawAttrs = rawDict[SchemeKey.attrs.rawValue] as? [String: Any] {
                if let element = (elementKey == SchemeKey.`self`.rawValue ? viewController : vars.value(forKey: elementKey) as? NSObject) {
                    NSObject.update(element, with: rawAttrs)
                }
            }
            // Bindings
            if let rawDict = rawElement as? [String: Any], let rawBindings = rawDict[SchemeKey.bindings.rawValue] as? [[String: Any]] {
                if let element = (elementKey == SchemeKey.`self`.rawValue ? viewController : vars.value(forKey: elementKey) as? NSObject) {
                    var bindings = [NSObject]()
                    rawBindings.forEach { rawBinding in
                        if let binding = element.wx.addBinding(dictionary: rawBinding) {
                            bindings.append(binding)
                        }
                    }
                    (viewController as? SchemeDiagnosticsProtocol)?.binded?(bindings, in: element)
                }
            }
        }
    }
    
    static func resolve(with dict: NSDictionary, vars: ObjectsDictionaryProxy, viewController: ContentViewController?) {
        let rawObjects = (dict[SchemeKey.objects.rawValue] as? [String: Any]) ?? [:]
        let rawUIElements = (dict[SchemeKey.elements.rawValue] as? [String: Any]) ?? [:]
        resolveOutlets(rawObjects.merging(rawUIElements, uniquingKeysWith: { current, _ in current }), vars: vars, viewController: viewController)
        updateUIElements(rawUIElements, vars: vars, viewController: viewController)
    }
}

extension ContentViewController {
    
    private func fetchCustomIBObjects() {
        guard let rawObjects = scheme?[SchemeKey.objects.rawValue] as? [String: Any], rawObjects.count > 0 else { return }
        if objects == nil {
            objects = [CustomIBObject]()
        }
        rawObjects.forEach { key, rawObject in
            if let rawDict = rawObject as? [String: Any] {
                if let object = vars.value(forKey: key) as? CustomIBObject {
                    Scheme.updateObject(object, with: rawDict)
                    (self as? SchemeDiagnosticsProtocol)?.updated?(object: object, identifier: key)
                } else if let object = Scheme.createObject(withDictionary: rawDict, identifier: key) {
                    objects!.append(object)
                    (self as? SchemeDiagnosticsProtocol)?.created?(object: object, identifier: key)
                } else {
                    print("Warning: Failed to create object for key '\(key)'. Type not found.")
                }
            }
        }
        vars.append(objects ?? [])
    }
    
    func loadScheme() {
        guard let identifier = restorationIdentifier,
            let doc = JSONSerialization.loadDictionary(resource: "\(identifier).json", bundle: nibBundle ?? Bundle.main),
            let dict = doc[identifier] as? NSDictionary else { return }
        self.scheme = dict
        fetchCustomIBObjects()
        Scheme.resolve(with: dict, vars: vars, viewController: self)
    }
}
