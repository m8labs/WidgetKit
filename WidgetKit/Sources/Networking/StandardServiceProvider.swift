//
// StandardServiceProvider.swift
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

import UIKit
import Groot
import Alamofire

public typealias ServiceProvider = ServiceProviderProtocol & NSObject
public typealias Completion = ((_ result: Any?, _ error: Error?) -> Void)

@objc
public protocol ServiceProviderProtocol: class {
    
    func performAction(_ action: String, with object: Any?, from sender: Any?, completion: Completion?)
    
    func cancelRequest(for action: String, from sender: Any?)
    
    func serverError(for action: String, code: Int, data: Data?) -> Error?
}

open class StandardServiceConfiguration: ServiceConfiguration {
    
    public init(bundle: Bundle?) {
        #if DEBUG
        super.init(resource: "Service.dev.json", bundle: bundle)
        if configDict == nil {
            loadFrom(resource: "Service.json", bundle: bundle)
        }
        #else
        super.init(resource: "Service.json", bundle: bundle)
        #endif
    }
}

open class StandardServiceProvider: ServiceProvider {
    
    private static var sharedRequests = NSMutableDictionary()
    
    var requests: NSMutableDictionary {
        return type(of: self).sharedRequests
    }
    
    public internal(set) var widget: Widget? {
        didSet {
            if widget != nil {
                setup()
            }
        }
    }
    
    public var bundle: Bundle {
        return widget?.bundle ?? Bundle.main
    }
    
    public var persistentContainer: NSPersistentContainer {
        return widget?.persistentContainer ?? NSPersistentContainer.default
    }
    
    public var configuration: ServiceConfigurationProtocol!
    
    public required override init() {
        super.init()
        setup()
    }
    
    open func setup() {
        configuration = StandardServiceConfiguration(bundle: bundle)
    }
    
    public var printFullRequest = true
    public var printFullResponse = true
    
    public var errorDomain: String {
        return "\(bundle.bundleIdentifier!).Error"
    }
    
    func requestIdentifier(for action: String, from sender: NSObject?) -> String {
        return "\(widget?.identifier ?? bundle.bundleIdentifier!)_\(action)_\(sender?.wx.identifier ?? "0")"
    }
    
    open func cancelRequest(for action: String, from sender: Any? = nil) {
        let requestID = requestIdentifier(for: action, from: sender as? NSObject)
        let request = requests[requestID] as? Request
        request?.cancel()
        requests[requestID] = nil
    }
    
    open func serverError(for action: String, code: Int, data: Data?) -> Error? {
        guard code != 200, let json = data?.jsonObject() as? [String: Any] else { return nil }
        let errorKeyPath = configuration.errorKeyPath(for: action)
        return NSError(domain: errorDomain, code: code, userInfo: (json[errorKeyPath] as? [String: Any]) ?? json)
    }
    
    func request(for action: String, with object: Any? = nil, from sender: Any? = nil, completion: @escaping Completion) {
        if configuration.isUpload(for: action) {
            upload(for: action, with: object, from: sender, completion: completion); return
        }
        guard let request = configuration.urlRequest(for: action, with: object) else {
            print("Unable to initiate request for action '\(action)' with object '\(String(describing: object))'"); return
        }
        beforeAction(action, request: request)
        action.notification.onStart.post(object: sender)
        let requestID = requestIdentifier(for: action, from: sender as? NSObject)
        requests[requestID] = SessionManager.default.request(request)
            .validate { request, response, data in
                self.requests[requestID] = nil
                self.afterAction(action, request: request, response: response, data: data)
                if response.statusCode < 400 {
                    return .success
                } else if let error = self.serverError(for: action, code: response.statusCode, data: data) {
                    return .failure(error)
                } else if let data = data, let errorText = String(data: data, encoding: .utf8) {
                    return .failure(NSError(domain: self.errorDomain, code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText]))
                } else {
                    return .failure(NSError(domain: self.errorDomain, code: response.statusCode))
                }
            }
            .responseJSON { response in
                switch response.result {
                case .success:
                    completion(response.result.value, nil)
                case let .failure(error):
                    completion(nil, error)
                }
            }
    }
    
    private func handleResponse(_ notification: Notification.Name, sender: Any?, result: Any?, error: Error?, completion: Completion?) {
        if let error = error {
            print(error)
            completion?(nil, error)
            notification.post(object: sender, userInfo: [Notification.errorKey: error])
        } else if let objects = result as? [Any] {
            print("Objects count: \(objects.count)")
            completion?(objects, nil)
            notification.post(object: sender, userInfo: [Notification.objectKey: objects])
        } else if let object = result {
            print("Object: \(object)")
            completion?(object, nil)
            notification.post(object: sender, userInfo: [Notification.objectKey: object])
        } else {
            completion?(nil, nil)
            notification.post(object: sender)
        }
    }
    
    open func performAction(_ action: String, with object: Any?, from sender: Any?, completion: Completion? = nil) {
        guard let config = configuration else { preconditionFailure("Configuration not set.") }
        if config.clearPolicy(for: action) == .before, let resultType = config.resultType(for: action) {
            persistentContainer.clear(entityNames: [resultType])
        }
        request(for: action, with: object, from: sender) { data, error in
            guard error == nil else {
                self.handleResponse(action.notification.onError, sender: sender, result: nil, error: error, completion: completion)
                return
            }
            guard let resultType = config.resultType(for: action) else {
                print("Invalid configuration for action '\(action)'. Result type unknown.")
                self.handleResponse(action.notification.onReady, sender: sender, result: data, error: nil, completion: completion)
                return
            }
            var result = data
            if let resultKeyPath = config.resultKeyPath(for: action), resultKeyPath.count > 0 {
                if let dict = data as? NSDictionary {
                    result = dict.value(forKeyPath: resultKeyPath)
                } else {
                    print("Invalid data for action '\(action)'. Expected json object.")
                    self.handleResponse(action.notification.onError, sender: sender, result: nil, error: nil, completion: completion)
                    return
                }
            }
            if config.resultIsArray(for: action) {
                if let arr = result as? [JSONDictionary] {
                    action.notification.onReady.post(object: sender, userInfo: [Notification.objectKey: arr])
                    let clearOld = config.clearPolicy(for: action) == .after
                    let setters = config.setters(for: action)
                    self.persistentContainer.objects(withEntityName: resultType, fromJSONArray: arr, clearOld: clearOld, setters: setters) { objects, error in
                        if error != nil {
                            self.handleResponse(action.notification.onError, sender: sender, result: nil, error: error, completion: completion)
                        } else {
                            self.handleResponse(action.notification.onSuccess, sender: sender, result: objects, error: nil, completion: completion)
                            if let nextAction = config.nextAction(for: action) {
                                self.performAction(nextAction, with: object, from: sender)
                            }
                        }
                    }
                } else {
                    print("Invalid data for action '\(action)'. Expected json array.")
                    self.handleResponse(action.notification.onError, sender: sender, result: nil, error: nil, completion: completion)
                }
            } else {
                if let dict = result as? JSONDictionary {
                    action.notification.onReady.post(object: sender, userInfo: [Notification.objectKey: dict])
                    let clearOld = config.clearPolicy(for: action) == .after
                    let setters = config.setters(for: action)
                    self.persistentContainer.object(withEntityName: resultType, fromJSONDictionary: dict, clearOld: clearOld, setters: setters) { object, error in
                        if error != nil {
                            self.handleResponse(action.notification.onError, sender: sender, result: nil, error: error, completion: completion)
                        } else {
                            self.handleResponse(action.notification.onSuccess, sender: sender, result: object, error: nil, completion: completion)
                            if let nextAction = config.nextAction(for: action) {
                                self.performAction(nextAction, with: object, from: sender)
                            }
                        }
                    }
                } else {
                    print("Invalid data for action '\(action)'. Expected json object.")
                    self.handleResponse(action.notification.onError, sender: sender, result: nil, error: nil, completion: completion)
                }
            }
        }
    }
    
    private func setupUploadRequest(_ uploadRequest: UploadRequest, requestID: String, action: String, from sender: Any?, completion: @escaping Completion) {
        requests[requestID] = uploadRequest
        uploadRequest
            .uploadProgress { progress in
                print("\(action) progress: \(progress.fractionCompleted)")
                action.notification.onProgress.post(object: sender, userInfo: [Notification.objectKey: progress])
            }
            .validate { request, response, data in
                self.afterAction(action, request: request, response: response, data: data)
                if let error = self.serverError(for: action, code: response.statusCode, data: data) {
                    return .failure(error)
                }
                return .success
            }
            .responseJSON { response in
                self.requests[requestID] = nil
                switch response.result {
                case .success:
                    completion(response.result.value, nil)
                case let .failure(error):
                    completion(nil, error)
                }
        }
    }
    
    func upload(for action: String, with object: Any?, from sender: Any? = nil, completion: @escaping Completion) {
        guard let config = configuration else { print("Configuration not set."); return }
        let requestID = requestIdentifier(for: action, from: sender as? NSObject)
        guard let request = config.uploadRequest(for: action, with: object) else { return }
        if let params = config.multipartParams(for: action) {
            beforeAction(action, request: request)
            action.notification.onStart.post(object: sender)
            let fillData: (MultipartFormData) -> Void = { formData in
                params.forEach { name, keyPath in
                    if let object = object as? NSObject, let value = object.value(forKeyPath: keyPath as! String) {
                        if let image = value as? UIImage {
                            formData.append(UIImageJPEGRepresentation(image, UIImage.defaultJPEGCompression)!, withName: name)
                        } else if let data = value as? Data {
                            formData.append(data, withName: name)
                        } else if let fileUrl = value as? URL {
                            formData.append(fileUrl, withName: name)
                        }
                    }
                }
            }
            SessionManager.default.upload(multipartFormData: fillData, with: request, encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let uploadRequest, _, _):
                    self.setupUploadRequest(uploadRequest, requestID: requestID, action: action, from: sender, completion: completion)
                case .failure(let error):
                    print(error)
                    completion(nil, error)
                }
            })
        } else {
            if let image = object as? UIImage, let data = UIImageJPEGRepresentation(image, UIImage.defaultJPEGCompression) {
                let uploadRequest = SessionManager.default.upload(data, with: request)
                setupUploadRequest(uploadRequest, requestID: requestID, action: action, from: sender, completion: completion)
            } else if let data = object as? Data {
                let uploadRequest = SessionManager.default.upload(data, with: request)
                setupUploadRequest(uploadRequest, requestID: requestID, action: action, from: sender, completion: completion)
            } else if let fileUrl = object as? URL {
                let uploadRequest = SessionManager.default.upload(fileUrl, with: request)
                setupUploadRequest(uploadRequest, requestID: requestID, action: action, from: sender, completion: completion)
            } else {
                print("Couldn't create upload request for \(action).")
            }
        }
    }
    
    func printRequest(_ request: URLRequest?, for action: String, removePercentEncoding: Bool = false, printCloseLine: Bool = true) {
        guard let request = request else {
            print("\n<empty request>")
            return
        }
        let data = request.httpBody ?? Data()
        var requestBodyString = "\(data.count) bytes" + (printFullRequest ? ("\n" + (String(data: data, encoding: .utf8) ?? "<no data>").replacingOccurrences(of: "\\\"", with: "\"")) : ".")
        if removePercentEncoding {
            requestBodyString = requestBodyString.removingPercentEncoding ?? requestBodyString
        }
        print("\n-----------------------------------------------------------------------------------")
        print("Request '\(action)': \(request.httpMethod!) \(request.url!.absoluteString)\nBody: \(requestBodyString)")
        if printCloseLine {
            print("\n-----------------------------------------------------------------------------------")
        }
    }
    
    func printResponse(_ response: URLResponse?, data: Data?, for action: String) {
        if let data = data, data.count > 0 {
            print("\nResponse '\(action)': \(printFullResponse ? (data.jsonString() ?? String(data: data, encoding: .utf8) ?? "<binary data>") : String(data.count) + " bytes")")
        } else {
            print("\n<No response data>")
        }
        print("-----------------------------------------------------------------------------------\n")
    }
}

extension StandardServiceProvider: NetworkDiagnosticsProtocol {
    
    public func beforeAction(_ action: String, request: URLRequest) {
        printRequest(request, for: action)
    }
    
    public func afterAction(_ action: String, request: URLRequest?, response: URLResponse?, data: Data?) {
        printRequest(request, for: action, removePercentEncoding: true, printCloseLine: false)
        printResponse(response, data: data, for: action)
    }
}

extension StandardServiceProvider {
    public static var `default` = StandardServiceProvider()
}
