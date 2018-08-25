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
    
    @objc public var animatedConstant: CGFloat {
        get {
            return constant
        }
        set {
            after(animationDelay) { [weak self] in
                if let this = self {
                    this.constant = newValue
                    AnimatedConstraint.animateConstraint(this, duration: this.animationDuration)
                }
            }
        }
    }
    
    static func animateConstraint(_ constraint: NSLayoutConstraint, duration: TimeInterval) {
        if let view = constraint.firstItem as? UIView {
            UIView.animate(withDuration: duration) {
                view.superview?.layoutIfNeeded()
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
    
    public func expand() {
        animatedConstant = initialHeight
    }
    
    public func collapse() {
        animatedConstant = 0
    }
    
    public func toggle() {
        if constant == 0 {
            expand()
        } else {
            collapse()
        }
    }
}
