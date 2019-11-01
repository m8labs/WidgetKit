//
// JSONFileDataProvider.swift
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

public class JSONFileDataProvider: ItemsContentProvider {
    
    @objc public private(set) var fileName: String?
    
    @objc public private(set) var fileUrl: String?
    
    @objc public var downloadDelay: TimeInterval = 1
    
    func loadFromData(_ data: Data, completion: @escaping (Error?) -> ()) {
        asyncGlobal { [unowned self] in
            do {
                let object = try JSONSerialization.jsonObject(with: data)
                asyncMain {
                    if let arr = object as? [NSDictionary] {
                        self.items = [arr.map { return NSMutableDictionary(dictionary: $0) }]
                    } else if let dict = object as? NSDictionary {
                        self.items = [[NSMutableDictionary(dictionary: dict)]]
                    }
                    completion(nil)
                }
            } catch {
                print("Error parsing \(error).")
                asyncMain {
                    completion(error)
                }
            }
        }
    }
    
    func download() {
        guard let fileUrl = fileUrl else { return }
        guard let url = URL(string: fileUrl) else { return print("Invalid URL for \(self).") }
        print("Downloading \(url)")
        asyncGlobal { [weak self] in
            guard let this = self else { return }
            do {
                let data = try Data(contentsOf: url)
                this.loadFromData(data) { _ in
                    this.contentConsumer?.renderContent(from: this)
                }
            } catch {
                print("Error downloading \(this): \(error)")
            }
        }
    }
    
    public override func fetch() {
        guard let fileName = fileName, let path = bundle.path(forResource: fileName, ofType: "json") else { return print("JSON not found for \(self).") }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return print("Error loading \(self).") }
        loadFromData(data) { [unowned self] _ in
            self.contentConsumer?.renderContent(from: self)
            after(self.downloadDelay) {
                self.download()
            }
        }
    }
}
