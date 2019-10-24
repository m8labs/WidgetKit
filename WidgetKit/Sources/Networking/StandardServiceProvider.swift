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

import Groot
import Alamofire

public typealias ServiceProvider = ServiceProviderProtocol & NSObject
public typealias Completion = ((_ result: Any?, _ error: Error?) -> Void)

@objc
public protocol ServiceProviderProtocol: AnyObject {
    
    func performAction(_ action: String, with args: ActionArgs?, from sender: Any?, completion: Completion?)
    
    func cancelRequest(for action: String, with args: ActionArgs?, from sender: Any?)
    
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
    
    public var configuration: ServiceConfiguration!
    
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
    
    open func cancelRequest(for action: String, with args: ActionArgs?, from sender: Any? = nil) {
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
    
    open func prepareRequest(_ request: URLRequest, body: inout [String: Any]?, for action: String, from sender: Any?) -> URLRequest? {
        return request
    }
    
    open func prepareResponse(_ response: Any?, for action: String, from sender: Any?) -> Any? {
        return response
    }
    
    func request(for action: String, with args: ActionArgs? = nil, from sender: Any? = nil, completion: @escaping Completion) {
        if let _ = configuration.multipartParams(for: action) {
            return upload(for: action, with: args, from: sender, completion: completion)
        }
        guard let requestInfo = configuration.urlRequest(for: action, with: args), let rawRequest = requestInfo.request else {
            return print("Unable to initiate request for action '\(action)' with object '\(String(describing: args))'")
        }
        var body = requestInfo.body
        var request = prepareRequest(rawRequest, body: &body, for: action, from: sender)
        if let parameters = body {
            do {
                switch configuration.encoding(for: action) {
                case .url:
                    request = try URLEncoding.httpBody.encode(rawRequest, with: parameters)
                case .plist:
                    request = try PropertyListEncoding.default.encode(rawRequest, with: parameters)
                default:
                    request = try JSONEncoding.default.encode(rawRequest, with: parameters)
                }
            } catch {
                print(error)
            }
        }
        guard request != nil else {
            return print("Unable to compose request for action '\(action)' with object '\(String(describing: args))'")
        }
        before(action: action, request: request!)
        action.notification.onStart.post(object: sender, userInfo: args == nil ? nil : [Notification.argsKey: args!])
        let requestID = requestIdentifier(for: action, from: sender as? NSObject)
        requests[requestID] = SessionManager.default.request(request!)
            .validate { request, response, data in
                self.requests[requestID] = nil
                self.after(action: action, request: request, response: response, data: data)
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
    
    private func performUploadRequest(_ uploadRequest: UploadRequest, requestID: String, action: String, with args: ActionArgs?, from sender: Any?, completion: @escaping Completion) {
        requests[requestID] = uploadRequest
        uploadRequest
            .uploadProgress { progress in
                print("'\(action)' progress: \(progress.fractionCompleted)")
                action.notification.onProgress.post(object: sender, userInfo: [Notification.valueKey: NSNumber(value: progress.fractionCompleted), Notification.argsKey: args!])
            }
            .validate { request, response, data in
                self.after(action: action, request: request, response: response, data: data)
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
    
    func upload(for action: String, with args: ActionArgs?, from sender: Any? = nil, completion: @escaping Completion) {
        guard var parameters = configuration.multipartParams(for: action) else {
            return print("Unable to initiate upload request for action '\(action)'. Multipart params requered.")
        }
        guard let requestInfo = configuration.urlRequest(for: action, with: args), let rawRequest = requestInfo.request else {
            return print("Unable to initiate request for action '\(action)' with object '\(String(describing: args))'")
        }
        var body = requestInfo.body // shoud be nil for uploads
        let request = prepareRequest(rawRequest, body: &body, for: action, from: sender)
        guard request != nil else {
            return print("Unable to compose request for action '\(action)' with object '\(String(describing: args))'")
        }
        let requestID = requestIdentifier(for: action, from: sender as? NSObject)
        if let object = args {
            parameters = parameters.substitute(object)
        }
        let fillData: (MultipartFormData) -> Void = { formData in
            parameters.forEach { name, value in
                if let data = value as? Data {
                    formData.append(data, withName: name)
                } else if let fileUrl = value as? URL {
                    formData.append(fileUrl, withName: name)
                } else if let stringValue = value as? String {
                    if stringValue.hasPrefix("/") {
                        formData.append(URL(fileURLWithPath: stringValue), withName: name)
                    } else if stringValue.hasPrefix("file"), let fileUrl = URL(string: stringValue) {
                        formData.append(fileUrl, withName: name)
                    } else if let data = stringValue.data(using: .utf8) {
                        formData.append(data, withName: name)
                    }
                } else if let image = value as? UIImage {
                    guard let data = UIImageJPEGRepresentation(image, UIImage.defaultJPEGCompression) else {
                        return print("Error: Failed to create data with UIImage parameter '\(name)'")
                    }
                    formData.append(data, withName: name)
                }
            }
            self.before(action: action, request: request!)
            action.notification.onStart.post(object: sender, userInfo: args == nil ? nil : [Notification.argsKey: args!])
        }
        SessionManager.default.upload(multipartFormData: fillData, with: request!, encodingCompletion: { encodingResult in
            switch encodingResult {
            case .success(let uploadRequest, _, _):
                self.performUploadRequest(uploadRequest, requestID: requestID, action: action, with: args, from: sender, completion: completion)
            case .failure(let error):
                print(error)
                completion(nil, error)
            }
        })
    }
    
    private func handleResponse(_ notification: Notification.Name, with args: ActionArgs?, sender: Any?, result: Any?, error: Error?, completion: Completion?) {
        if let error = error {
            print(error)
            completion?(nil, error)
            notification.post(object: sender, userInfo: args == nil ? [Notification.errorKey: error] : [Notification.errorKey: error, Notification.argsKey: args!])
        } else if let result = result as? [Any] {
            print("Objects count: \(result.count)")
            completion?(result, nil)
            notification.post(object: sender, userInfo: args == nil ? [Notification.valueKey: result] : [Notification.valueKey: result, Notification.argsKey: args!])
        } else if let result = result {
            print("Object: \(result)")
            completion?(result, nil)
            notification.post(object: sender, userInfo: args == nil ? [Notification.valueKey: result] : [Notification.valueKey: result, Notification.argsKey: args!])
        } else {
            completion?(nil, nil)
            notification.post(object: sender, userInfo: args == nil ? nil : [Notification.argsKey: args!])
        }
    }
    
    open func performAction(_ action: String, with args: ActionArgs?, from sender: Any?, completion: Completion? = nil) {
        guard let config = configuration else { preconditionFailure("Configuration not set.") }
        if config.clearPolicy(for: action) == .before, let resultType = config.resultType(for: action) {
            persistentContainer.clear(entityNames: [resultType])
        }
        request(for: action, with: args, from: sender) { data, error in
            guard error == nil else {
                return self.handleResponse(action.notification.onError, with: args, sender: sender, result: nil, error: error, completion: completion)
            }
            guard let resultType = config.resultType(for: action) else {
                print("Empty result type for action '\(action)'.")
                return self.handleResponse(action.notification.onSuccess, with: args, sender: sender, result: nil, error: nil, completion: completion)
            }
            var result = data
            if let resultKeyPath = config.resultKeyPath(for: action), resultKeyPath.count > 0 {
                if let dict = data as? NSDictionary {
                    result = dict.value(forKeyPath: resultKeyPath)
                } else {
                    print("Invalid data for action '\(action)'. Expected json object.")
                    return self.handleResponse(action.notification.onError, with: args, sender: sender, result: nil, error: nil, completion: completion)
                }
            }
            if config.resultIsArray(for: action) {
                if let arr = result as? [JSONDictionary] {
                    action.notification.onReady.post(object: sender, userInfo: args == nil ? [Notification.valueKey: arr] : [Notification.valueKey: arr, Notification.argsKey: args!])
                    let clearOld = config.clearPolicy(for: action) == .after
                    let setters = config.setters(for: action)
                    asyncGlobal {
                        let arr_ = self.prepareResponse(arr, for: action, from: sender) as! [JSONDictionary]
                        asyncMain {
                            self.persistentContainer.objects(withEntityName: resultType, fromJSONArray: arr_, clearOld: clearOld, setters: setters) { objects, error in
                                if error != nil {
                                    self.handleResponse(action.notification.onError, with: args, sender: sender, result: nil, error: error, completion: completion)
                                } else {
                                    self.handleResponse(action.notification.onSuccess, with: args, sender: sender, result: objects, error: nil, completion: completion)
                                    if let nextAction = config.nextAction(for: action) {
                                        self.performAction(nextAction, with: args, from: sender)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    print("Invalid data for action '\(action)'. Expected json array.")
                    self.handleResponse(action.notification.onError, with: args, sender: sender, result: nil, error: nil, completion: completion)
                }
            } else {
                if let dict = result as? JSONDictionary {
                    action.notification.onReady.post(object: sender, userInfo: args == nil ? [Notification.valueKey: dict] : [Notification.valueKey: dict, Notification.argsKey: args!])
                    let clearOld = config.clearPolicy(for: action) == .after
                    let setters = config.setters(for: action)
                    asyncGlobal {
                        let dict_ = self.prepareResponse(dict, for: action, from: sender) as! JSONDictionary
                        asyncMain {
                            self.persistentContainer.object(withEntityName: resultType, fromJSONDictionary: dict_, clearOld: clearOld, setters: setters) { object, error in
                                if error != nil {
                                    self.handleResponse(action.notification.onError, with: args, sender: sender, result: nil, error: error, completion: completion)
                                } else {
                                    self.handleResponse(action.notification.onSuccess, with: args, sender: sender, result: object, error: nil, completion: completion)
                                    if let nextAction = config.nextAction(for: action) {
                                        self.performAction(nextAction, with: ActionArgs(content: args?.content, params: object), from: sender)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    print("Invalid data for action '\(action)'. Expected json object.")
                    self.handleResponse(action.notification.onError, with: args, sender: sender, result: nil, error: nil, completion: completion)
                }
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
    
    public func before(action: String, request: URLRequest) {
        printRequest(request, for: action)
    }
    
    public func after(action: String, request: URLRequest?, response: URLResponse?, data: Data?) {
        printRequest(request, for: action, removePercentEncoding: true, printCloseLine: false)
        printResponse(response, data: data, for: action)
    }
}

extension StandardServiceProvider {
    public static var `default` = StandardServiceProvider()
}
