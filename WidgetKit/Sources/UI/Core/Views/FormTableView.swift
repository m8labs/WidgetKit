//
// FormTableView.swift
//
// WidgetKit, Copyright (c) 2019 M8 Labs (http://m8labs.com)
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
import Groot

open class FormTableView: UITableView {
    
    @objc public var allowedKeys: String?
    
    lazy var allowedKeysArray: Set<String> = {
        return Set(allowedKeys?.components(separatedBy: CharacterSet(charactersIn: ", ")) ?? [])
    }()
    
    open override var wx_fieldValue: Any? {
        get {
            guard let displayController = dataSource as? TableDisplayController else { return nil }
            guard let objects = Array(displayController.selectedObjects) as? [NSManagedObject], objects.count > 0 else { return nil }
            var arr = [[String: Any]]()
            for object in objects {
                var dict = json(fromObject: object)
                for (key, _) in dict {
                    if !allowedKeysArray.contains(key) {
                        dict.removeValue(forKey: key)
                    }
                }
                arr.append(dict)
            }
            return arr
        }
        set { }
    }
}
