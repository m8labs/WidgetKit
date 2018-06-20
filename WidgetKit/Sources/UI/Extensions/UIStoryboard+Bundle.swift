//
// UIStoryboard+Bundle.swift
//
// WidgetKit, Copyright (c) 2018 Favio Mobile (http://favio.mobi)
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

extension UIStoryboard {
    
    static let main: UIStoryboard = {
        let mainStoryboard = UIStoryboard(name: Bundle.main.infoDictionary!["UIMainStoryboardFile"] as! String, bundle: nil)
        return mainStoryboard
    }()
}

extension Bundle {
    
    static var mainBundleName: String {
        return Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? ""
    }
    
    var moduleName: String {
        let name = String(reflecting: CustomIBObject.self).split(separator: ".").first!
        return "\(name)"
    }
    
    func type(with className: String) -> NSObject.Type? {
        if let type = NSClassFromString(moduleName + "." + className) as? NSObject.Type {
            return type
        } else if let type = NSClassFromString(Bundle.mainBundleName + "." + className) as? NSObject.Type {
            return type
        }
        return NSClassFromString(className) as? NSObject.Type
    }
}

extension UIView {
    
    static func loadNib<T: UIView>(_ nibName: String, bundle: Bundle, size: CGSize = CGSize.zero) -> T? {
        let view = bundle.loadNibNamed(nibName, owner: nil, options: nil)?.first as? T
        view?.frame = CGRect(origin: CGPoint.zero, size: size)
        return view
    }
}
