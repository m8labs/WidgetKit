//
// ActionStatusController.swift
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

protocol ActionStatusControllerDelegate {
    
    func statusChanged(_ status: ActionStatusController, result: Any?, error: Error?) -> Bool
}

enum ActionStatus {
    case initial, inProgress, isReady, isSuccess, isFailure
}

open class ActionStatusController: CustomIBObject, ObserversStorageProtocol {
    
    @IBOutlet public var elements: [NSObject]?
    
    @IBOutlet public private(set) weak var owner: ActionController?
    
    var statusValue = ActionStatus.initial
    
    @objc public var inProgress: Bool { return statusValue == .inProgress }
    @objc public var isReady: Bool { return statusValue == .isReady }
    @objc public var isSuccess: Bool { return statusValue == .isSuccess }
    @objc public var isFailure: Bool { return statusValue == .isFailure }
    
    @objc public var actionName: String?
    @objc public var errorTitle: String?
    @objc public var errorMessage: String?
    
    @objc public var needAuthSegue: String?
    @objc public var needAuthErrorCodes = [401]
    
    public var observers: [Any] = []
    
    public func setupObservers() {
        guard let action = self.actionName else {
            NSLog("'actionName' was not set to \(self)!")
            return
        }
        observers = [
            action.notification.onStart.subscribe(to: owner) { [weak self] _ in
                if let this = self {
                    this.statusValue = .inProgress
                    this.viewController?.refresh(elements: this.elements)
                    this.owner?.statusChanged(this, result: nil, error: nil)
                }
            },
            action.notification.onReady.subscribe(to: owner) { [weak self] n in
                if let this = self {
                    (this.viewController as? SchemeDiagnosticsProtocol)?.afterAction?(this.actionName!, result: n.objectFromUserInfo, error: nil, sender: this)
                    this.statusValue = .isReady
                    this.viewController?.refresh(elements: this.elements)
                    this.owner?.statusChanged(this, result: n.objectFromUserInfo, error: nil)
                }
            },
            action.notification.onSuccess.subscribe(to: owner) { [weak self] n in
                if let this = self {
                    (this.viewController as? SchemeDiagnosticsProtocol)?.afterAction?(this.actionName!, result: n.objectFromUserInfo, error: nil, sender: this)
                    this.statusValue = .isSuccess
                    this.viewController?.refresh(elements: this.elements)
                    this.owner?.statusChanged(this, result: n.objectFromUserInfo, error: nil)
                }
            },
            action.notification.onError.subscribe(to: owner) { [weak self] n in
                if let this = self {
                    (this.viewController as? SchemeDiagnosticsProtocol)?.afterAction?(this.actionName!, result: n.objectFromUserInfo, error: n.errorFromUserInfo, sender: this)
                    this.statusValue = .isFailure
                    this.viewController?.refresh(elements: this.elements)
                    if let error = n.errorFromUserInfo {
                        if this.owner?.statusChanged(this, result: nil, error: error) ?? true {
                            if this.needAuthErrorCodes.contains((error as NSError).code), let segue = this.needAuthSegue {
                                this.viewController?.performSegue(withIdentifier: segue, sender: this)
                            } else {
                                this.viewController?.handleError(error, sender: this)
                            }
                        }
                    }
                }
            }
        ]
    }
    
    open override func setup() {
        super.setup()
        setupObservers()
    }
    
    public convenience init(owner: ActionController, actionName: String) {
        self.init()
        self.actionName = actionName
        self.owner = owner
        self.viewController = owner.viewController
        setup()
    }
}
