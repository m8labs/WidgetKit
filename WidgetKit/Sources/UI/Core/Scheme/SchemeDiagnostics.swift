//
// SchemeDiagnostics.swift
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

import Foundation

@objc
public protocol SchemeDiagnosticsProtocol: class {
    
    @objc optional func created(object: NSObject, identifier: String)
    
    @objc optional func updated(object: NSObject, identifier: String)
    
    @objc optional func outlet(_ object: NSObject, addedTo: NSObject, propertyKey: String, outletKey: String)
    
    @objc optional func binded(_ bindings: [NSObject], in container: NSObject)
    
    @objc optional func assigned(to target: NSObject, with identifier: String?, keyPath: String, source: NSObject, value: Any?, valueType: String, binding: NSObject)
    
    @objc optional func beforeAction(_ action: String, content: Any?, sender: ActionController)
    
    @objc optional func afterAction(_ action: String, result: Any?, error: Error?, sender: ActionStatusController)
}

@objc
public protocol NetworkDiagnosticsProtocol: class {
    
    @objc optional func before(action: String, request: URLRequest)
    
    @objc optional func after(action: String, request: URLRequest?, response: URLResponse?, data: Data?)
}
