//
// TextInputView.swift
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

public class TextInputView: UIView, ObserversStorageProtocol {
    
    @IBOutlet var textInput: (UITextInput & UIView)?
    @IBOutlet var clearButton: UIButton?
    @IBOutlet var placeholder: UILabel?
    
    var textField: UITextField? {
        return textInput as? UITextField
    }
    
    var textView: UITextView? {
        return textInput as? UITextView
    }
    
    public var textTyped = [((text: String)->Void)]()
    
    public var textChanged = [((text: String)->Void)]()
    
    public var returnPressed = [((text: String)->Void)]()
    
    public var textCleared = [(()->Void)]()
    
    @objc public var text: String! {
        get {
            return (textField?.text ?? textView?.text) ?? ""
        }
        set {
            textField?.text = newValue
            textView?.text = newValue
            textDidChange(typed: false)
        }
    }
    
    public var cursorPosition: Int = 0 {
        didSet {
            if let textView = textView {
                textView.selectedRange = NSMakeRange(cursorPosition < textView.text.count ? cursorPosition : textView.text.count, 0)
            }
        }
    }
    
    func textDidChange(typed: Bool) {
        textChanged.forEach { [unowned self] in $0(self.text) }
        if typed {
            textTyped.forEach { [unowned self] in $0(self.text) }
        }
        update()
    }
    
    @objc func clearText() {
        text = ""
        textCleared.forEach { $0() }
    }
    
    func update() {
        placeholder?.isHidden = text.count > 0
        clearButton?.isHidden = text.count == 0
    }
    
    public func releaseKeyboard() {
        textView?.resignFirstResponder()
        textField?.resignFirstResponder()
    }
    
    public var observers: [Any] = []
    
    public func setupObservers() {
        if let textView = textView {
            observers = [
                Notification.Name.UITextViewTextDidChange.subscribe(to: textView) { [weak self] _ in
                    self?.textDidChange(typed: true)
                }]
        }
        else if let textField = textField {
            observers = [
                Notification.Name.UITextFieldTextDidChange.subscribe(to: textField) { [weak self] _ in
                    self?.textDidChange(typed: true)
                }]
        }
    }
    
    func setup() {
        clearButton?.addTarget(self, action: #selector(clearText), for: .touchUpInside)
        setupObservers()
        update()
        textField?.delegate = self
        textView?.delegate = self
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
}

extension TextInputView: UITextViewDelegate, UITextFieldDelegate {
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        returnPressed.forEach { [unowned self] in $0(self.text) }
        return true
    }
    
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" && textView.returnKeyType != .default {
            returnPressed.forEach { [unowned self] in $0(self.text) }
            return false
        }
        return true
    }
}

extension TextInputView {
    
    public override var wx_value: Any? {
        get {
            return text
        }
        set {
            text = newValue as? String
        }
    }
}

extension TextInputView {
    
    static let inputFieldName = "input"
}
