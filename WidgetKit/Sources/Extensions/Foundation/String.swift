//
// String.swift
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

import Foundation

extension String {
    
    public static let keyPattern = "\\$[\\w]+"
    
    public static let keyPathPattern = "\\$[\\w\\.]+"
    
    static func substitute(format: String, with object: NSObject, pattern: String) -> String {
        var result = String(format: format, with: object, pattern: pattern)
        if result.hash == format.hash {
            result = String(format: format, "\(object)")
        }
        return result
    }
    
    func ranges(of string: String, options: CompareOptions = .literal) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var start = startIndex
        while let range = range(of: string, options: options, range: start..<endIndex) {
            result.append(range)
            start = range.lowerBound < range.upperBound ? range.upperBound : index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
    
    init(format: String, with object: NSObject, pattern: String) {
        var result = format
        for range in format.ranges(of: pattern, options: .regularExpression).reversed() {
            let keyPath = String(format[range].dropFirst())
            let value = "\(object.value(forKeyPath: keyPath) ?? "")"
            result.replaceSubrange(range, with: value)
        }
        self = result
    }
}

public extension String {
    
    func size(fitting width: CGFloat, font: UIFont) -> CGSize {
        let textContainer: NSTextContainer = {
            let size = CGSize(width: width, height: .greatestFiniteMagnitude)
            let container = NSTextContainer(size: size)
            container.lineFragmentPadding = 0
            return container
        }()
        let textStorage = NSTextStorage(string: self, attributes: [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key(rawValue: "NSOriginalFont"): font
            ])
        let layoutManager: NSLayoutManager = {
            let layoutManager = NSLayoutManager()
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            return layoutManager
        }()
        return layoutManager.usedRect(for: textContainer).size
    }
}
