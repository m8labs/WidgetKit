//
// Bindings.swift
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

public struct BindingOption: RawRepresentable, Equatable, Hashable {
    
    public typealias RawValue = String
    
    public static var predicateFormat       = BindingOption(rawValue: "predicateFormat")
    public static var valueIfTrue           = BindingOption(rawValue: "ifTrue")
    public static var valueIfFalse          = BindingOption(rawValue: "ifFalse")
    public static var nullPlaceholder       = BindingOption(rawValue: "placeholder")
    public static var valueTransformerName  = BindingOption(rawValue: "transformer")
    public static var valueFormat           = BindingOption(rawValue: "format")
    
    public var rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static func ==(lhs: BindingOption, rhs: BindingOption) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    public var hashValue: Int {
        return rawValue.hashValue
    }
}

class Evaluation: NSObject {
    
    var predicateFormat: String?
    var valueIfTrue: Any?
    var valueIfFalse: Any?
    
    var valueFormat: String?
    var placeholder: String?
    var transformerName: String?
    
    lazy var predicate: NSPredicate? = {
        guard let predicateFormat = predicateFormat else { return nil }
        return NSPredicate(format: predicateFormat)
    }()
    
    lazy var transformer: ValueTransformer? = {
        guard let transformerName = transformerName else { return nil }
        return ValueTransformer(forName: NSValueTransformerName(rawValue: transformerName))
    }()
    
    fileprivate func evaluatePredicate(with value: Any?) -> Any? {
        guard let predicate = predicate else { return nil }
        var expr: Any?
        if let ifTrue = valueIfTrue, let ifFalse = valueIfFalse {
            expr = predicate.evaluate(with: value) ? ifTrue : ifFalse
        } else {
            expr = predicate.evaluate(with: value)
        }
        if let textExpr = expr as? String, let object = value as? NSObject {
            return String.substitute(format: textExpr, with: object, pattern: String.keyPathPattern)
        }
        return expr
    }
    
    func perform(with value: Any?) -> Any? {
        var value = value
        if value is NSNull {
            value = nil
        }
        if let evaluatedValue = evaluatePredicate(with: value) {
            value = evaluatedValue is NSNull ? nil : evaluatedValue
        }
        if let v = value, let transformedValue = transformer?.transformedValue(v) {
            value = transformedValue
        }
        if let format = valueFormat, let object = value as? NSObject {
            value = String.substitute(format: format, with: object, pattern: String.keyPathPattern)
        }
        let result: Any? = value ?? placeholder
        return result
    }
    
    override init() {
        super.init()
    }
    
    @discardableResult
    init(options: [BindingOption: Any]? = nil) {
        super.init()
        self.predicateFormat = options?[BindingOption.predicateFormat] as? String
        self.valueIfTrue = options?[BindingOption.valueIfTrue]
        self.valueIfFalse = options?[BindingOption.valueIfFalse]
        self.valueFormat = options?[BindingOption.valueFormat] as? String
        self.placeholder = options?[BindingOption.nullPlaceholder] as? String
        self.transformerName = options?[BindingOption.valueTransformerName] as? String
    }
}

class Binding: Evaluation {
    
    weak var target: NSObject!
    var targetKeyPath: String!
    var sourceKeyPath: String?
    var observable: NSObject?
    
    var order = 0
    
    private var _active = false
    
    @discardableResult
    fileprivate func set(with value: Any?) -> Any? {
        let result = perform(with: value)
        target.setValue(result, forKeyPath: targetKeyPath)
        return result
    }
    
    @discardableResult
    func assign(from source: NSObject) -> Any? {
        let value = sourceKeyPath != nil ? source.value(forKeyPath: sourceKeyPath!) : source
        let result = set(with: value)
        return result
    }
    
    func activate() {
        guard _active == false, let observable = observable, let sourceKeyPath = sourceKeyPath else { return }
        observable.addObserver(self, forKeyPath: sourceKeyPath, options: NSKeyValueObservingOptions.new, context: nil)
        _active = true
    }
    
    func deactivate() {
        guard _active, let sourceKeyPath = sourceKeyPath else { return }
        observable?.removeObserver(self, forKeyPath: sourceKeyPath)
        _active = false
    }
    
    @discardableResult
    func bind(to observable: NSObject) -> Any? {
        deactivate()
        self.observable = observable
        let value = assign(from: observable)
        activate()
        return value
    }
    
    func unbind() {
        deactivate()
        observable = nil
    }
    
    override init() {
        super.init()
    }
    
    init(target: NSObject, bindingKey: String, observable: NSObject, keyPath: String, options: [BindingOption: Any]? = nil) {
        super.init(options: options)
        self.target = target
        self.targetKeyPath = bindingKey
        self.sourceKeyPath = keyPath
        bind(to: observable)
    }
    
    deinit {
        unbind()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        set(with: change?[NSKeyValueChangeKey.newKey])
    }
}

public class ObjectAssistant: NSObject {
    
    weak private var object: NSObject!
    
    private(set) var evals = [String: Evaluation]()
    private(set) var bindings = [String: Binding]()
    private(set) var orderedBindings = [Binding]()
    
    @objc public var identifier: String?
    @objc public var name: String?
    
    @objc public lazy var layoutHint = LayoutHint()
    
    init(for object: NSObject) {
        super.init()
        self.object = object
    }
    
    @discardableResult
    func setupObject(using source: NSObject, bind: Bool = false) -> [(binding: NSObject, target: NSObject, source: NSObject, keyPath: String, value: Any?)] {
        var info = [(binding: NSObject, target: NSObject, source: NSObject, keyPath: String, value: Any?)]()
        orderedBindings.forEach { binding in
            binding.unbind()
            binding.target = self.object
            let value = bind ? binding.bind(to: source) : binding.assign(from: source)
            info.append((binding: binding, target: self.object, source: source, keyPath: binding.targetKeyPath, value: value))
        }
        return info
    }
    
    private func addBinding(jsonString string: String) {
        if let json = JSONSerialization.jsonObject(with: string) as? [String: Any] {
            addBinding(dictionary: json)
        } else {
            print("Invalid binding JSON for object: \(object!)\nJSON: \(string)")
        }
    }
    
    @objc public var addBinding: String? {
        didSet {
            if let value = addBinding {
                addBinding(jsonString: "{\(value)}")
            }
        }
    }
    
    @discardableResult
    func addEval(_ name: String, dictionary: [String: Any]) -> NSObject? {
        let eval = Evaluation()
        eval.predicateFormat = dictionary[BindingOption.predicateFormat.rawValue] as? String
        eval.transformerName = dictionary[BindingOption.valueTransformerName.rawValue] as? String
        if let v = dictionary[BindingOption.valueIfTrue.rawValue] {
            eval.valueIfTrue = v is String ? NSLocalizedString(v as! String, comment: "") : v
        }
        if let v = dictionary[BindingOption.valueIfFalse.rawValue] {
            eval.valueIfFalse = v is String ? NSLocalizedString(v as! String, comment: "") : v
        }
        if let v = dictionary[BindingOption.valueFormat.rawValue] as? String {
            eval.valueFormat = NSLocalizedString(v, comment: "")
        }
        if let v = dictionary[BindingOption.nullPlaceholder.rawValue] as? String {
            eval.placeholder = NSLocalizedString(v, comment: "")
        }
        evals[name] = eval
        return eval
    }
    
    @discardableResult
    public func addBinding(dictionary: [String: Any]) -> NSObject? {
        let targetKeyPath = dictionary[ObjectAssistant.bindTo] as? String ?? ObjectAssistant.valuePropertyName
        if bindings[targetKeyPath] != nil {
            print("Warning: Binding already exists: '\(targetKeyPath)'. Ignoring new binding for object \(object!).")
            return nil
        }
        let binding = Binding()
        binding.targetKeyPath = targetKeyPath
        binding.sourceKeyPath = dictionary[ObjectAssistant.bindFrom] as? String
        binding.predicateFormat = dictionary[BindingOption.predicateFormat.rawValue] as? String
        binding.transformerName = dictionary[BindingOption.valueTransformerName.rawValue] as? String
        if let v = dictionary[BindingOption.valueIfTrue.rawValue] {
            binding.valueIfTrue = v is String ? NSLocalizedString(v as! String, comment: "") : v
        }
        if let v = dictionary[BindingOption.valueIfFalse.rawValue] {
            binding.valueIfFalse = v is String ? NSLocalizedString(v as! String, comment: "") : v
        }
        if let v = dictionary[BindingOption.valueFormat.rawValue] as? String {
            binding.valueFormat = NSLocalizedString(v, comment: "")
        }
        if let v = dictionary[BindingOption.nullPlaceholder.rawValue] as? String {
            binding.placeholder = NSLocalizedString(v, comment: "")
        }
        if let order = (dictionary["order"] as? Int) {
            binding.order = order
            orderedBindings.append(binding)
            orderedBindings.sort { $0.order < $1.order }
        } else {
            orderedBindings.append(binding)
        }
        bindings[binding.targetKeyPath] = binding
        return binding
    }
    
    func bind(_ binding: String, to observable: NSObject, withKeyPath keyPath: String, options: [BindingOption: Any]? = nil) {
        bindings[binding] = Binding(target: object, bindingKey: binding, observable: observable, keyPath: keyPath, options: options)
    }
}

extension ObjectAssistant {
    
    public static var bindTo = "to"
    public static var bindFrom = "from"
    
    private static var valuePropertyName = "\(#selector(getter: NSObject.wx_value))"
}

public extension NSObject {
    
    private struct AssociatedKeys {
        static var ObjectAssistantKey: String?
    }
    
    @objc var wx: ObjectAssistant {
        var wx = objc_getAssociatedObject(self, &AssociatedKeys.ObjectAssistantKey) as? ObjectAssistant
        if wx == nil {
            wx = ObjectAssistant(for: self)
            objc_setAssociatedObject(self, &AssociatedKeys.ObjectAssistantKey, wx, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return wx!
    }
}
