//
// ExpandingConstraint.swift
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

public class AnimatedConstraint: NSLayoutConstraint {
    
    @objc public var animationDuration = 0.0
    @objc public var animationDelay = 0.0
    
    public var view: UIView? {
        return self.firstItem as? UIView
    }
    
    @objc public var animatedConstant: CGFloat {
        get {
            return constant
        }
        set {
            super.constant = newValue
            after(animationDelay) { [weak self] in
                if let view = self?.view {
                    UIView.animate(withDuration: self?.animationDuration ?? 0) {
                        view.superview?.layoutIfNeeded()
                    }
                }
            }
        }
    }
}

public class ExpandingConstraint: AnimatedConstraint {

    private var initialHeight: CGFloat = 0
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        initialHeight = constant
    }
    
    public func setExpanded(_ expanded: Bool, animated: Bool = false) {
        if animated {
            animatedConstant = expanded ? initialHeight : 0
        } else {
            constant = expanded ? initialHeight : 0
        }
    }
    
    @objc public var expanded: Bool {
        @objc(isExpanded)
        get {
            return constant == initialHeight
        }
        set {
            setExpanded(newValue)
        }
    }
    
    public func toggle(animated: Bool = false) {
        setExpanded(!expanded, animated: animated)
    }
}
