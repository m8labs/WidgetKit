//
// ContainerView.swift
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

public class ContainerView: UIView {
    
    @objc public var draggable = true
    @objc public var selectable = true
    
    public private(set) var isSelected = false
    
    @objc public var activeColor = UIColor(red: 0, green: 0.65, blue: 1, alpha: 1)
    @objc public var inactiveColor: UIColor!
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    func setup() {
        if draggable {
            addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        }
        if selectable {
            inactiveColor = backgroundColor
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.cancelsTouchesInView = false
            addGestureRecognizer(tap)
        }
    }
    
    func deselectAll() {
        superview?.subviews.forEach { view in
            guard let containerView = view as? ContainerView else { return }
            containerView.deselect()
        }
    }
    
    func select() {
        guard selectable, !isSelected else { return }
        deselectAll()
        isSelected = true
        backgroundColor = activeColor
        superview?.bringSubview(toFront: self)
        subviews.forEach { view in
            (view as? UILabel)?.isHighlighted = true
            (view as? UIControl)?.isSelected = true
            (view as? UIImageView)?.isHighlighted = true
        }
    }
    
    func deselect() {
        guard selectable, isSelected else { return }
        isSelected = false
        backgroundColor = inactiveColor
        subviews.forEach { view in
            (view as? UILabel)?.isHighlighted = false
            (view as? UIControl)?.isSelected = false
            (view as? UIImageView)?.isHighlighted = false
        }
    }
    
    @objc func handleTap(_ gesture: UIPanGestureRecognizer?) {
        select()
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        select()
        if gesture.state == .began || gesture.state == .changed {
            let translation = gesture.translation(in: self)
            gesture.view!.center = CGPoint(x: gesture.view!.center.x + translation.x, y: gesture.view!.center.y + translation.y)
            gesture.setTranslation(CGPoint.zero, in: self)
        }
    }
}

open class NibView: UIView {
    
    open override func awakeAfter(using coder: NSCoder) -> Any? {
        if subviews.count == 0 {
            return UINib(nibName: "\(Self.self)", bundle: nil).instantiate(withOwner: nil, options: nil)[0] as! UIView
        }
        return self
    }
}
