//
// ActionController.swift
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

open class ActionController: CustomIBObject {
    
    static let targetSelectorSignatureFormat = "%@:sender:"
    
    @IBOutlet public var target: NSObject?
    @IBOutlet public weak var sender: NSObject?
    @IBOutlet public weak var cancelButton: UIButton?
    @IBOutlet public weak var form: ContentFormProtocol?
    @IBOutlet public weak var serviceProvider: ServiceProvider?
    
    @objc public var actionName: String!
    @objc public var elseActionName: String?
    @objc public var predicateFormat: String?
    @objc public var actionDelay: Double = 0.0
    @objc public var serviceProviderClassName: String?
    
    @objc public private(set) var status: ActionStatusController?
    
    @objc open var params: Any? {
        return form?.formValue
    }
    
    @objc open var content: Any? {
        return viewController.content
    }
    
    var args: [String: Any] {
        var dict = [String: Any]()
        dict["content"] = content
        dict["params"] = params
        return dict
    }
    
    var predicate: NSPredicate? {
        guard let format = predicateFormat else { return nil }
        return NSPredicate(format: format)
    }
    
    var predicateValue: Bool {
        return predicate?.evaluate(with: viewController.vars) ?? true
    }
    
    var resolvedActionName: String? {
        return predicateValue ? actionName : elseActionName
    }
    
    var resolvedServiceProvider: ServiceProvider {
        var sp = serviceProvider
        if sp == nil {
            if let className = serviceProviderClassName ?? viewController?.serviceProviderClassName {
                sp = NSObject.create(withClassName: className) as? ServiceProvider
                (sp as? StandardServiceProvider)?.widget = widget
            }
        }
        return sp ?? StandardServiceProvider.default
    }
    
    var targetSelector: Selector? {
        guard let resolvedActionName = resolvedActionName else { return nil }
        let selector = Selector(String(format: ActionController.targetSelectorSignatureFormat, resolvedActionName))
        return selector
    }
    
    var cancelSelector: Selector? {
        guard let resolvedActionName = resolvedActionName else { return nil }
        let selector = Selector("cancel" + String(format: ActionController.targetSelectorSignatureFormat, resolvedActionName).capitalized)
        return selector
    }
    
    func performServiceAction(with object: Any? = nil) {
        guard let actionName = resolvedActionName else {
            return print("Action for the \(self) was resolved to nil.")
        }
        let object = object ?? args
        let service = resolvedServiceProvider
        status = ActionStatusController(owner: self, actionName: actionName)
        (viewController as? SchemeDiagnosticsProtocol)?.beforeAction?(actionName, content: object, sender: self)
        let selector = targetSelector
        if service.responds(to: selector) {
            service.perform(selector, with: object, with: self)
        } else {
            service.performAction(actionName, with: object, from: self, completion: nil)
        }
    }
    
    func cancelServiceAction(with object: Any? = nil) {
        guard viewController != nil else {
            return print("Warning: view controller for this action doesn't exist.")
        }
        let service = resolvedServiceProvider
        let object = object ?? args
        let selector = cancelSelector
        if service.responds(to: selector) {
            service.perform(selector, with: object)
        } else if let actionName = resolvedActionName {
            service.cancelRequest(for: actionName, from: self)
        }
    }
    
    private func _performAction() {
        if let target = target {
            let selector = targetSelector
            if target.responds(to: selector) {
                target.perform(selector, with: args, with: self)
            } else {
                performServiceAction()
            }
        } else {
            performServiceAction()
        }
    }
    
    @objc open func performAction() {
        guard viewController != nil else {
            return print("Warning: view controller for this action doesn't exist.")
        }
        guard form == nil || form!.formValue != nil else {
            return print("Warning: Form exists but value was nil - aborting action \(actionName!).")
        }
        after(actionDelay) {
            self._performAction()
        }
    }
    
    @objc open func cancelAction() {
        cancelServiceAction()
    }
    
    open override func setup() {
        form?.actionController = self
        cancelButton?.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        super.setup()
    }
}

extension ActionController: ActionStatusControllerDelegate {
    
    @discardableResult
    @objc open func statusChanged(_ status: ActionStatusController, result: Any?, error: Error?) -> Bool {
        return true
    }
}

public class CellDetailActionController: ActionController {
    
    @objc var segue: String!
    @objc var keyPath: String?
    
    var masterObject: NSObject!
    
    public override var params: Any? {
        return masterObject
    }
    
    func performSegue(_ segue: String, with object: Any) {
        viewController?.performSegue(withIdentifier: segue, sender: ContentWrapper(content: object))
    }
    
    public override func statusChanged(_ status: ActionStatusController, result: Any?, error: Error?) -> Bool {
        if status.isSuccess, let segue = segue, let object = result {
            performSegue(segue, with: object)
        }
        return true
    }
    
    public override func performAction() {
        guard let masterObject = masterObject, let keyPath = keyPath, let segue = segue else {
            return print("\(self) should have `masterObject`, `segue` and `keyPath`.")
        }
        if let object = masterObject.value(forKeyPath: keyPath) {
            performSegue(segue, with: object)
        } else if actionName != nil {
            super.performAction()
        }
    }
}

public class ButtonActionController: ActionController {
    
    var button: UIButton? {
        return sender as? UIButton
    }
    
    public override func setup() {
        super.setup()
        button?.addTarget(self, action: #selector(performAction), for: .touchUpInside)
    }
}

public class BarButtonActionController: ActionController {
    
    var barButtonItem: UIBarButtonItem? {
        return sender as? UIBarButtonItem
    }
    
    public override func setup() {
        super.setup()
        barButtonItem?.target = self
        barButtonItem?.action = #selector(performAction)
    }
}

public class TableRefreshActionController: ActionController {
    
    var tableView: UITableView? {
        return sender as? UITableView
    }
    
    public override func setup() {
        super.setup()
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(performAction), for: .valueChanged)
        tableView?.refreshControl = refreshControl
    }
}

public class OnLoadActionController: ActionController {
    
    public override func setup() {
        super.setup()
        perform(#selector(performAction), with: nil, afterDelay: 0)
    }
}

public class TimerActionController: ActionController {
    
    @objc public var interval: TimeInterval = 60
    @objc public var runImmediately: Bool = true
    
    public override func performAction() {
        guard viewController != nil else {
            return NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performAction), object: nil)
        }
        super.performAction()
        perform(#selector(performAction), with: nil, afterDelay: interval)
    }
    
    public override func setup() {
        super.setup()
        perform(#selector(performAction), with: nil, afterDelay: runImmediately ? 0 : interval)
    }
}
