//
// UIView+Animations.swift
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

extension UIView {
    
    @objc public func shake(count: Float = 2, duration: TimeInterval = 0.1, translation: Float = 5) {
        let animation: CABasicAnimation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.repeatCount = count
        animation.duration = duration / TimeInterval(animation.repeatCount)
        animation.autoreverses = true
        animation.byValue = translation
        layer.add(animation, forKey: "shake")
    }
    
    @objc public var unveilAlpha: CGFloat {
        get {
            return alpha
        }
        set {
            guard isHidden || newValue != alpha else { return }
            if isHidden {
                alpha = 0
                isHidden = false
                UIView.animate(withDuration: 0.25) { self.alpha = newValue }
            } else {
                UIView.animate(withDuration: 0.25, animations: { self.alpha = 0 }) { _ in
                    self.isHidden = true
                }
            }
        }
    }
}

public extension UIImage {
    
    convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}

public extension UIButton {
    
    @objc var normalBackgroundColor: UIColor? {
        get { return nil }
        set { setBackgroundColor(newValue, for: .normal) }
    }
    
    @objc var highlightedBackgroundColor: UIColor? {
        get { return nil }
        set { setBackgroundColor(newValue, for: .highlighted) }
    }
    
    func setBackgroundColor(_ color: UIColor?, for state: UIControl.State) {
        setBackgroundImage(color == nil ? nil : UIImage(color: color!), for: state)
    }
}
