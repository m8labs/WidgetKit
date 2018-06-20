//
// ActionStatusController.swift
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

open class ActionStatusController: CustomIBObject, ObserversStorageProtocol {
    
    @IBOutlet public var elements: [NSObject]?
    
    @IBOutlet public private(set) weak var owner: ActionController?
    
    @objc public private(set) var inProgress = false
    @objc public private(set) var isSuccess = false
    @objc public private(set) var isFailure = false
    
    @objc public var actionName: String?
    @objc public var errorTitle: String?
    @objc public var errorMessage: String?
    
    public var observers: [Any] = []
    
    public func setupObservers() {
        guard let action = self.actionName else {
            NSLog("'actionName' was not set to \(self)!")
            return
        }
        observers = [
            action.notification.onStart.subscribe(to: owner?.sender) { [weak self] _ in
                if let this = self {
                    this.inProgress = true
                    this.isSuccess = false
                    this.isFailure = false
                    this.viewController?.refresh(elements: this.elements)
                }
            },
            action.notification.onReady.subscribe(to: owner?.sender) { [weak self] n in
                if let this = self {
                    (this.viewController as? SchemeDiagnosticsProtocol)?.afterAction?(this.actionName!, result: n.objectFromUserInfo, error: nil, sender: this)
                    this.inProgress = false
                    this.isSuccess = true
                    this.isFailure = false
                    this.viewController?.refresh(elements: this.elements)
                }
            },
            action.notification.onError.subscribe(to: owner?.sender) { [weak self] n in
                if let this = self {
                    (this.viewController as? SchemeDiagnosticsProtocol)?.afterAction?(this.actionName!, result: n.objectFromUserInfo, error: n.errorFromUserInfo, sender: this)
                    this.inProgress = false
                    this.isSuccess = false
                    this.isFailure = true
                    this.viewController?.refresh(elements: this.elements)
                    if let error = n.errorFromUserInfo {
                        this.viewController?.handleError(error, sender: this)
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
