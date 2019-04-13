//
// TextSizeCalculator.swift
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

@objcMembers
public class LayoutHint: NSObject {
    
    public var top: CGFloat = 0
    public var bottom: CGFloat = 0
    public var left: CGFloat = 0
    public var right: CGFloat = 0
    public var maxWidth: CGFloat = 0
    public var minHeight: CGFloat = -1
    public var maxHeight: CGFloat = -1
    
    var isEmpty: Bool {
        return top == 0 && bottom == 0 && left == 0 && right == 0
    }
}

class TextSizeCalculator: NSObject {
    
    class TextLayoutItem {
        
        var text: String!
        var font: UIFont!
        var layoutHint: LayoutHint!
        var textSize = CGSize.zero
        
        func calculateSize() -> CGSize {
            textSize = text.size(fitting: layoutHint.maxWidth, font: font)
            var size = CGSize(width: textSize.width + layoutHint.left + layoutHint.right, height: textSize.height + layoutHint.top + layoutHint.bottom)
            if layoutHint.minHeight >= 0 && size.height < layoutHint.minHeight {
                size.height = layoutHint.minHeight
            }
            if layoutHint.maxHeight >= 0 && size.height > layoutHint.maxHeight {
                size.height = layoutHint.maxHeight
            }
            return size
        }
    }
    
    class TextLayoutSubject: NSObject {
        
        var totalHeight: CGFloat = 0
        var minTotalHeight: CGFloat = 0
        private var items = [TextLayoutItem]()
        
        var height: CGFloat {
            return totalHeight < minTotalHeight ? minTotalHeight : totalHeight
        }
        
        func add(_ item: TextLayoutItem) {
            items.append(item)
        }
        
        func calculateSize() {
            totalHeight = 0
            items.forEach { item in
                let itemHeight = item.calculateSize().height
                totalHeight += itemHeight
            }
        }
    }
    
    func calculateSubject(_ subject: [(text: String, font: UIFont, layoutHint: LayoutHint)], minTotalHeight: CGFloat) -> CGFloat {
        let layoutSubject = TextLayoutSubject()
        layoutSubject.minTotalHeight = minTotalHeight
        subject.forEach { item in
            let layoutItem = TextLayoutItem()
            layoutItem.text = item.text
            layoutItem.font = item.font
            layoutItem.layoutHint = item.layoutHint
            layoutSubject.add(layoutItem)
        }
        layoutSubject.calculateSize()
        return layoutSubject.totalHeight
    }
}

extension UIView {
    
    public func wx_fitContent() {
        var subject = [(text: String, font: UIFont, layoutHint: LayoutHint)]()
        for element in wx_resizingElements {
            element.wx.layoutHint.maxWidth = element.bounds.width
            subject.append((text: element.value(forKey: "text") as! String,
                            font: element.value(forKey: "font") as! UIFont,
                            layoutHint: element.wx.layoutHint))
        }
        let h = TextSizeCalculator().calculateSubject(subject, minTotalHeight: bounds.height)
        bounds = CGRect(origin: CGPoint.zero, size: CGSize(width: bounds.width, height: h))
    }
}
