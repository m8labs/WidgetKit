//
// NSObject.swift
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

extension NSObject {
    
    @objc public var objectId: String {
        return "\(hash)" as String
    }
}

extension NSObject {
    
    static func create(withClassName className: String) -> NSObject? {
        guard let objectType = Bundle.main.type(with: className) else {
            print("Warning: Class '\(className)' doesn't exist.")
            return nil
        }
        let object = objectType.init()
        return object
    }
    
    static func update(_ object: NSObject, with attributes: [String: Any]) {
        attributes.forEach { key, value in
            object.setValue(value, forKey: key)
        }
    }
}

extension Error {
    
    public var localizedFailureReason: String? {
        (self as NSError).localizedFailureReason
    }
    
    public var userInfo: [String: Any] {
        (self as NSError).userInfo
    }
}
