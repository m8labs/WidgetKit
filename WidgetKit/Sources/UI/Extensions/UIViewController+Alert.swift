//
// UIViewController+Alert.swift
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

extension UIViewController {
    
    public func showAlert(title: String? = nil, message: String?, actions: [(title: String, handler: (() -> Void)?)]) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        actions.forEach { option in
            if let handler = option.handler {
                alert.addAction(UIAlertAction(title: option.title, style: .default, handler: { _ in handler() }))
            } else {
                alert.addAction(UIAlertAction(title: option.title, style: .cancel, handler: nil))
            }
        }
        if alert.actions.count == 0 {
            let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel, handler: nil)
            alert.addAction(cancelAction)
        }
        present(alert, animated: true)
    }
    
    public func showAlert(title: String? = nil, message: String?, action: (title: String, cancelTitle: String, handler: (() -> Void)?)? = nil) {
        if let action = action {
            showAlert(title: title, message: message, actions: [(action.title, action.handler), (action.cancelTitle, nil)])
        } else {
            showAlert(title: title, message: message, actions: [])
        }
    }
    
    public func showActionSheet(title: String? = nil, message: String?, options: [(title: String, isDestructive: Bool, handler: (() -> Void)?)]) {
        let sheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        options.forEach { option in
            if let handler = option.handler {
                sheet.addAction(UIAlertAction(title: option.title, style: option.isDestructive ? .destructive : .default, handler: { _ in handler() }))
            } else {
                sheet.addAction(UIAlertAction(title: option.title, style: .cancel, handler: nil))
            }
        }
        present(sheet, animated: true)
    }
}

public func showGlobalAlert(title: String? = nil, message: String?, actions: [(title: String, handler: (() -> Void)?)]) {
    UIApplication.shared.keyWindow?.rootViewController?.showAlert(title: title, message: message, actions: actions)
}

public func showGlobalActionSheet(title: String? = nil, message: String?, actions: [(title: String, isDestructive: Bool, handler: (() -> Void)?)]) {
    UIApplication.shared.keyWindow?.rootViewController?.showActionSheet(title: title, message: message, options: actions)
}

public func showGlobalAlert(title: String? = nil, message: String?, action: (title: String, cancelTitle: String, handler: (() -> Void)?)? = nil) {
    if let action = action {
        showGlobalAlert(title: title, message: message, actions: [(action.title, action.handler), (action.cancelTitle, nil)])
    } else {
        showGlobalAlert(title: title, message: message, actions: [])
    }
}
