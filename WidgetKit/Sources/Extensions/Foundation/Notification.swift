//
// Notification.swift
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

class ObserverWrapper {
    
    var name: String?!
    var observer: NSObjectProtocol!
    
    init(observer: NSObjectProtocol, name: String) {
        self.name = name
        self.observer = observer
    }
    
    deinit {
        NotificationCenter.default.removeObserver(observer!)
    }
}

public protocol ObserversStorageProtocol: class {
    
    var observers: [Any] { get set }
    
    func setupObservers()
}

extension Notification.Name: ExpressibleByStringLiteral {
    
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

public extension Notification.Name {
    
    @discardableResult
    func addObserver(object: Any? = nil, _ block: @escaping (Notification) -> Swift.Void) -> Any {
        return ObserverWrapper(observer: NotificationCenter.default.addObserver(forName: self, object: object, queue: OperationQueue.main, using: block),
                               name: self.rawValue)
    }
    
    @discardableResult
    func subscribe(to object: Any? = nil, _ block: @escaping (Notification) -> Swift.Void) -> Any {
        return addObserver(object: object, block)
    }
    
    func post(object: Any? = nil, error: Error?) {
        NotificationCenter.default.post(name: self, object: object, userInfo: error != nil ? [Notification.errorKey: error!] : nil)
    }
    
    func post(object: Any? = nil, userInfo: [String: Any]? = nil) {
        NotificationCenter.default.post(name: self, object: object, userInfo: userInfo)
    }
}

protocol NetworkRequestStatusProtocol {
    
    var onStart: Notification.Name { get }
    
    var onProgress: Notification.Name { get }
    
    var onReady: Notification.Name { get }
    
    var onSuccess: Notification.Name { get }
    
    var onError: Notification.Name { get }
}

extension Notification.Name: NetworkRequestStatusProtocol {
    
    public var onStart: Notification.Name {
        return Notification.Name(rawValue + "Start")
    }
    
    public var onProgress: Notification.Name {
        return Notification.Name(rawValue + "Progress")
    }
    
    public var onReady: Notification.Name {
        return Notification.Name(rawValue + "Ready")
    }
    
    public var onSuccess: Notification.Name {
        return Notification.Name(rawValue + "Success")
    }
    
    public var onError: Notification.Name {
        return Notification.Name(rawValue + "Error")
    }
}

public extension Notification {
    
    static let errorKey = "error"
    static let objectKey = "object"
    
    var errorFromUserInfo: Error? {
        return userInfo?[Notification.errorKey] as? Error
    }
    
    public var objectFromUserInfo: Any? {
        return userInfo?[Notification.objectKey]
    }
}

public extension String {
    
    var notification: Notification.Name {
        return Notification.Name(self)
    }
}
