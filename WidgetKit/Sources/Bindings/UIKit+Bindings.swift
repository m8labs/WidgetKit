//
// UIKit+Bindings.swift
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
import AlamofireImage

@objc
extension NSObject {
    
    open var wx_value: Any? {
        get { return nil }
        set { }
    }
}

@objc
extension UIView {
    
    open var wx_fieldName: String? {
        get { return wx.name }
        set { wx.name = newValue }
    }
    
    open var wx_fieldValue: Any? {
        get { return wx_value }
        set { wx_value = newValue }
    }
    
    open var wx_visible: Bool {
        get { return !isHidden }
        set { isHidden = !newValue }
    }
    
    open var wx_disabled: Bool {
        get { return !isUserInteractionEnabled }
        set { isUserInteractionEnabled = !newValue }
    }
}

@objc
extension UIImageView {
    
    open var wx_imageUrl: String? {
        get { return nil }
        set {
            image = nil
            if let placeholder = wx.valueBinding?.placeholder {
                image = UIImage(named: placeholder)
            }
            if let url = newValue {
                af_setImage(withURL: URL(string: url)!)
            }
        }
    }
    
    open var wx_imageName: String? {
        get { return nil }
        set {
            if let value = newValue {
                image = UIImage(named: value, in: contentContainer()?.widget?.bundle, compatibleWith: nil)
            } else {
                image = nil
            }
        }
    }
    
    open var wx_autoValue: Any? {
        get { return nil }
        set {
            if let string = newValue as? String {
                if string.hasPrefix("http") {
                    wx_imageUrl = string
                } else {
                    wx_imageName = string
                }
            } else if let url = newValue as? URL {
                wx_imageUrl = url.absoluteString
            }
        }
    }
    
    open override var wx_value: Any? {
        get { return image }
        set { image = newValue as? UIImage }
    }
}

@objc
extension UILabel {
    
    open override var wx_value: Any? {
        get { return text }
        set { text = "\(newValue ?? "")" }
    }
}

@objc
extension UITextField {
    
    open override var wx_value: Any? {
        get { return text }
        set { text = "\(newValue ?? "")" }
    }
    
    open override var wx_fieldValue: Any? {
        get { return (text ?? "").count > 0 ? text : nil }
        set { wx_value = newValue }
    }
    
    open override var wx_disabled: Bool {
        get { return !isEnabled }
        set { isEnabled = !newValue }
    }
}

@objc
extension UITextView {
    
    open override var wx_value: Any? {
        get { return text }
        set { text = "\(newValue ?? "")" }
    }
    
    open override var wx_fieldValue: Any? {
        get { return text.count > 0 ? text : nil }
        set { wx_value = newValue }
    }
    
    open var wx_readOnly: Bool {
        get { return !isEditable }
        set { isEditable = !newValue }
    }
}

@objc
extension UIButton {
    
    open override var wx_value: Any? {
        get { return title(for: .normal) }
        set { setTitle("\(newValue ?? "")", for: .normal) }
    }
    
    open override var wx_disabled: Bool {
        get { return !isEnabled }
        set { isEnabled = !newValue }
    }
}

@objc
extension UIBarButtonItem {
    
    open override var wx_value: Any? {
        get { return title }
        set { title = "\(newValue ?? "")" }
    }
    
    open var wx_disabled: Bool {
        get { return !isEnabled }
        set { isEnabled = !newValue }
    }
}

@objc
extension UIRefreshControl {
    
    open override var wx_value: Any? {
        get { return isRefreshing }
        set {
            if let isRefreshing = (newValue as? NSNumber)?.boolValue {
                if isRefreshing {
                    beginRefreshing()
                } else {
                    endRefreshing()
                }
            }
        }
    }
}

@objc
extension UIActivityIndicatorView {
    
    open override var wx_value: Any? {
        get { return isAnimating }
        set {
            if let isAnimating = (newValue as? NSNumber)?.boolValue {
                if isAnimating {
                    startAnimating()
                } else {
                    stopAnimating()
                }
            }
        }
    }
}

@objc
extension NSLayoutConstraint {
    
    open override var wx_value: Any? {
        get { return constant }
        set {
            if let value = newValue, let floatValue = Float("\(value)") {
                constant = CGFloat(floatValue)
            }
        }
    }
}

@objc
extension UIViewController {
    
    public var wx_dismissed: Bool {
        get { return false }
        set {
            if newValue {
                dismiss(animated: true)
            }
        }
    }
    
    public var wx_poppedBack: Bool {
        get { return false }
        set {
            if newValue {
                navigationController?.popViewController(animated: true)
            }
        }
    }
}

@objc
extension UIProgressView {
    
    open override var wx_value: Any? {
        get { return progress }
        set {
            if let progress = newValue as? NSNumber {
                setProgress(progress.floatValue, animated: true)
            }
        }
    }
}

@objc
extension UISwitch {
    
    open override var wx_value: Any? {
        get { return isOn }
        set {
            if let value = newValue {
                isOn = NSString(string: "\(value)").boolValue
            }
        }
    }
}
