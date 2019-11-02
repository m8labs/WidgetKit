//
// UIView+Containers.swift
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
    
    public func addSubview(_ view: UIView, withEdgeConstraints edges: UIEdgeInsets) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        let views = ["view": view]
        var formatString = "H:|-\(edges.left)-[view]-\(edges.right)-|"
        var constraints = NSLayoutConstraint.constraints(withVisualFormat: formatString, options: .alignAllLastBaseline, metrics: nil, views: views)
        NSLayoutConstraint.activate(constraints)
        formatString = "V:|-\(edges.top)-[view]-\(edges.bottom)-|"
        constraints = NSLayoutConstraint.constraints(withVisualFormat: formatString, options: .alignAllLastBaseline, metrics: nil, views: views)
        NSLayoutConstraint.activate(constraints)
    }
}

extension UIView {
    
    func viewController() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            responder = responder!.next
            if (responder is UINavigationController) {
                let controller: UIViewController? = (responder as? UINavigationController)?.topViewController
                responder = controller
                break
            }
            else if (responder is UIViewController) {
                break
            }
        }
        return responder as? UIViewController
    }
    
    func allSubviews(with closure: (UIView) -> Void) {
        subviews_.forEach { view in
            closure(view)
            if view.subviews_.count > 0  {
                view.allSubviews(with: closure)
            }
        }
    }
    
    public func contentContainer() -> ContentDisplayProtocol? {
        var view: UIView? = self
        while view != nil && !(view is ContentDisplayProtocol) {
            view = view!.superview
        }
        return (view as? ContentDisplayProtocol) ?? (viewController() as? ContentDisplayProtocol)
    }
}

extension UIView {
    
    @objc var subviews_: [UIView] {
        return subviews
    }
}

extension UITableView {
    
    override var subviews_: [UIView] {
        return [tableHeaderView, tableFooterView, backgroundView].compactMap { $0 }
    }
}

extension UICollectionView {
    
    override var subviews_: [UIView] {
        return [backgroundView].compactMap { $0 }
    }
}

public extension UIViewController {
    
    var presentingContentViewController: ContentViewController? {
        return ((presentingViewController as? UINavigationController)?.viewControllers.last ?? presentingViewController) as? ContentViewController
    }
    
    var previousViewController: UIViewController? {
        if let navigationController = self.navigationController, let index = navigationController.viewControllers.index(of: self) {
            return index > 0 ? navigationController.viewControllers[index - 1] : nil
        }
        return presentingViewController
    }
}
