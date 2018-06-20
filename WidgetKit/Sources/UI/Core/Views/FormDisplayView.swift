//
// FormDisplayView.swift
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

open class FormDisplayView: ContentDisplayView, ContentFormProtocol {
    
    enum DublicateKeyPolicy: String {
        case overwrite, join, array
    }
    
    weak public var actionController: ActionController!
    
    @IBOutlet public var optionalFields: [UIView]?
    
    @IBOutlet public var mandatoryFields: [UIView]!
    
    @objc public var dublicateKeyPolicy = DublicateKeyPolicy.overwrite.rawValue
    
    open func highlightField(_ view: UIView, error: Error?) {
        view.shake()
    }
    
    private func scanForm() -> [String: Any]? {
        let mandatoryFields = self.mandatoryFields.filter { $0.wx_fieldName != nil && $0.wx_fieldValue != nil }
        guard mandatoryFields.count == self.mandatoryFields.count else {
            for view in self.mandatoryFields {
                async { self.highlightField(view, error: nil) }
            }
            return nil
        }
        let mandatoryDict = mandatoryFields.reduce(into: [String: Any]()) { form, field in
            form[field.wx_fieldName!] = field.wx_fieldValue!
        }
        let optionalFields = self.optionalFields?.filter { $0.wx_fieldName != nil && $0.wx_fieldValue != nil }
        let optionalDict = optionalFields?.reduce(into: [String: Any]()) { form, field in
            if let oldValue = form[field.wx_fieldName!] {
                if dublicateKeyPolicy == DublicateKeyPolicy.join.rawValue {
                    form[field.wx_fieldName!] = "\(oldValue as! String),\(field.wx_fieldValue as! String)"
                } else if dublicateKeyPolicy == DublicateKeyPolicy.array.rawValue {
                    // TODO
                } else {
                    form[field.wx_fieldName!] = field.wx_fieldValue!
                }
            } else {
                form[field.wx_fieldName!] = field.wx_fieldValue!
            }
        }
        return mandatoryDict.merging(optionalDict ?? [:]) { (current, _) in current }
    }
    
    public var formValue: [String: Any]? {
        return scanForm()
    }
}
