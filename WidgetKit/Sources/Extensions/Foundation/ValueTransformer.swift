//
// ValueTransformer.swift
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

extension ValueTransformer {
    
    public static func setDateTransformer(name: String,
                                          dateFormat: String?,
                                          dateStyle: DateFormatter.Style = .none,
                                          timeStyle: DateFormatter.Style = .none,
                                          timeZone: TimeZone = TimeZone.current,
                                          locale: Locale = Locale.current) {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.dateFormat = dateFormat
        formatter.timeZone = timeZone
        formatter.locale = locale
        ValueTransformer.grt_setValueTransformer(withName: name, transform: { value -> Any? in
            if let date = value as? Date { // from CoreData to UI
                let string = formatter.string(from: date)
                return string
            } else if let string = value as? String { // from JSON to CoreData
                let date = formatter.date(from: string)
                return date
            }
            return nil
        }) { value -> Any? in // from CoreData to JSON
            if let date = value as? Date {
                let string = formatter.string(from: date)
                return string
            }
            return nil
        }
    }
    
    static func setDefaultTransformers() {
        func toString(_ value: Any) -> String? {
            return String(describing: value)
        }
        ValueTransformer.setValueTransformer(withName: "toString", transform: toString)
        
        func toInt(_ value: Any) -> Int? {
            return Int(String(describing: value))
        }
        ValueTransformer.setValueTransformer(withName: "strToInt", transform: toInt)
        
        func toDouble(_ value: Any) -> Double? {
            return Double(String(describing: value))
        }
        ValueTransformer.setValueTransformer(withName: "toDouble", transform: toDouble)
        
        func ago(_ value: Any) -> String? {
            guard let date = value as? Date else { return nil }
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .abbreviated
            formatter.maximumUnitCount = 1
            formatter.allowsFractionalUnits = true
            formatter.allowedUnits = [.year, .month, .day, .hour, .minute, .second]
            guard let s = formatter.string(from: date, to: Date()), let c = s.first else {
                return nil
            }
            if c == "-" || c == "0" {
                return NSLocalizedString("Now", comment: "")
            } else {
                let comps = s.components(separatedBy: CharacterSet(charactersIn: ","))
                return (comps.count > 0 ? comps[0] : s).trimmingCharacters(in: CharacterSet(charactersIn: " ")) // https://openradar.appspot.com/26354907
            }
        }
        ValueTransformer.setValueTransformer(withName: "ago", transform: ago)
    }
}
