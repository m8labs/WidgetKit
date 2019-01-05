//
// JSONSerialization.swift
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

extension JSONSerialization {
    
    static func loadDictionary(from url: URL) -> NSDictionary? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let json = try JSONSerialization.jsonObject(with: data as Data)
            return json as? NSDictionary
        } catch {
            print("JSON parsing error: \(error)")
        }
        return nil
    }
    
    static func loadDictionary(resource name: String, bundle: Bundle, ofType ext: String? = nil) -> NSDictionary? {
        guard let url = bundle.url(forResource: name, withExtension: ext) else { return nil }
        return loadDictionary(from: url)
    }
    
    public static func jsonObject(with string: String) -> Any? {
        guard let data = string.data(using: .utf8) else { return nil }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            return json
        } catch {
            print("JSON parsing error: \(error)")
        }
        return nil
    }
    
    public static func jsonObjectToString(_ object: Any, options: JSONSerialization.WritingOptions = [.prettyPrinted]) -> String? {
        do {
            let data = try JSONSerialization.data(withJSONObject: object, options: options)
            return String(data: data, encoding: .utf8)
        } catch {
            print("JSON serializing error: \(error)")
        }
        return nil
    }
}

extension Data {
    
    public func jsonObject() -> Any? {
        do {
            let json = try JSONSerialization.jsonObject(with: self, options: .allowFragments)
            return json
        } catch {
            print("JSON parsing error: \(error)")
        }
        return nil
    }
    
    public func jsonString() -> String? {
        do {
            let json = try JSONSerialization.jsonObject(with: self, options: .allowFragments)
            return JSONSerialization.jsonObjectToString(json)
        } catch {
            print("JSON parsing error: \(error)")
        }
        return nil
    }
}

extension Dictionary where Key == String {
    
    func substitute(_ object: NSObject) -> [String: Any] {
        return substituteJsonObject(self, with: object) as! [String: Any]
    }
    
    public func jsonString() -> String? {
        return JSONSerialization.jsonObjectToString(self)
    }
}

func substituteJsonObject(_ target: Any, with source: NSObject) -> Any {
    if var array = target as? [Any] {
        for i in 0..<array.count {
            array[i] = substituteJsonObject(array[i], with: source)
        }
        return array
    } else if var dict = target as? [String: Any] {
        for (key, value) in dict {
            if let string = value as? String {
                dict[key] = String(format: string, with: source, pattern: String.keyPathPattern)
            } else if let object = value as? [String: Any] {
                dict[key] = substituteJsonObject(object, with: source)
            } else if let array = value as? [Any] {
                dict[key] = substituteJsonObject(array, with: source)
            }
        }
        return dict
    }
    return target
}
