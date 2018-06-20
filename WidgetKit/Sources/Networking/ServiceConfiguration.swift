//
// ServiceConfiguration.swift
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

import Alamofire

public enum ClearPolicy: String {
    case none, before, after
}

public protocol ServiceConfigurationProtocol {
    
    var baseUrl: String? { get }
    
    var authUrl: String? { get }
    
    var socketUrl: String? { get }
    
    var authParameters: Parameters { get }
    
    var defaultHeaders: HTTPHeaders { get }
    
    var defaultParameters: Parameters { get }
    
    func needAuth(for action: String) -> Bool
    
    func httpMethod(for action: String) -> HTTPMethod
    
    func headers(for action: String) -> HTTPHeaders
    
    func parameters(for action: String) -> Parameters
    
    func multipartParams(for action: String) -> Parameters?
    
    func setters(for action: String) -> [String: Any]
    
    func url(for action: String) -> String?
    
    func isUpload(for action: String) -> Bool
    
    func resultType(for action: String) -> String?
    
    func resultIsArray(for action: String) -> Bool
    
    func resultKeyPath(for action: String) -> String?
    
    func errorKeyPath(for action: String) -> String
    
    func nextAction(for action: String) -> String?
    
    func clearPolicy(for action: String) -> ClearPolicy
    
    func setRequestModifier(_ closure: @escaping ((String, inout URLRequest) -> Void))
    
    func setRequestComposer(_ closure: @escaping ((String, HTTPMethod, String, Parameters?, HTTPHeaders?) -> URLRequest?))
    
    func urlRequest(for action: String, with object: Any?) -> URLRequest?
    
    func uploadRequest(for action: String, with object: Any?) -> URLRequest?
}

open class ServiceConfiguration {
    
    var configDict: NSMutableDictionary?
    
    private var dateTransformers: [String: [String: String]]? {
        return configDict?.value(forKeyPath: "options.transformers.date") as? [String: [String: String]]
    }
    
    private var requestModifier: ((String, inout URLRequest) -> Void)?
    
    private var requestComposer: ((String, HTTPMethod, String, Parameters?, HTTPHeaders?) -> URLRequest?)?
    
    private func setDateTransformers() {
        let style: (String?) -> DateFormatter.Style = { string in
            switch string {
            case "short": return .short
            case "medium": return .medium
            case "long": return .long
            case "full": return .full
            default: return .none
            }
        }
        dateTransformers?.forEach { t in
            ValueTransformer.setDateTransformer(name: t.key, dateFormat: t.value["format"], dateStyle: style(t.value["dateStyle"]),
                                                timeStyle: style(t.value["timeStyle"]), locale: Locale(identifier: t.value["locale"] ?? "en_US_POSIX"))
        }
    }
    
    public func loadFrom(resource: String, bundle: Bundle?) {
        if let dict = JSONSerialization.loadDictionary(resource: resource, bundle: bundle ?? Bundle.main)?.mutableCopy() as? NSMutableDictionary {
            configDict = dict
            setDateTransformers()
        } else {
            print("Couldn't load configuration file '\(resource)'")
        }
    }
    
    public init(resource: String, bundle: Bundle?) {
        loadFrom(resource: resource, bundle: bundle)
    }
}

extension ServiceConfiguration: ServiceConfigurationProtocol {
    
    public var baseUrl: String? {
        if let url = configDict?.value(forKeyPath: "defaults.baseUrl") as? String {
            return url.hasSuffix("/") ? url : "\(url)/"
        }
        return nil
    }
    
    public var authUrl: String? {
        return configDict?.value(forKeyPath: "auth.url") as? String
    }
    
    public var socketUrl: String? {
        return configDict?.value(forKeyPath: "defaults.socket") as? String
    }
    
    public var authParameters: Parameters {
        return (configDict?.value(forKeyPath: "auth") as? Parameters) ?? [:]
    }
    
    public var defaultHeaders: HTTPHeaders {
        return (configDict?.value(forKeyPath: "defaults.headers") as? HTTPHeaders) ?? [:]
    }
    
    public var defaultParameters: Parameters {
        return (configDict?.value(forKeyPath: "defaults.parameters") as? Parameters) ?? [:]
    }
    
    public func needAuth(for action: String) -> Bool {
        let needAuth = configDict?.value(forKeyPath: "actions.\(action).needAuth") ?? configDict?.value(forKeyPath: "defaults.needAuth")
        return needAuth as? Bool ?? false
    }
    
    public func httpMethod(for action: String) -> HTTPMethod {
        let httpMethod = configDict?.value(forKeyPath: "actions.\(action).httpMethod") ?? configDict?.value(forKeyPath: "defaults.httpMethod")
        return HTTPMethod(rawValue: httpMethod as? String ?? "GET") ?? .get
    }
    
    public func parameters(for action: String) -> Parameters {
        var params = configDict?.value(forKeyPath: "actions.\(action).parameters") as? Parameters ?? [:]
        params.merge(defaultParameters) { (current, _) in current }
        return params
    }
    
    public func multipartParams(for action: String) -> Parameters? {
        let params = configDict?.value(forKeyPath: "actions.\(action).multipart") as? Parameters
        return params
    }
    
    public func headers(for action: String) -> HTTPHeaders {
        var params = configDict?.value(forKeyPath: "actions.\(action).headers") as? HTTPHeaders ?? [:]
        params.merge(defaultHeaders) { (current, _) in current }
        return params
    }
    
    public func setters(for action: String) -> [String: Any] {
        let dict = configDict?.value(forKeyPath: "actions.\(action).set") as? [String: Any]
        return dict ?? [:]
    }
    
    public func url(for action: String) -> String? {
        if let action = configDict?.value(forKeyPath: "actions.\(action)") as? [String: Any] {
            if let path = action["path"] as? String  {
                return path.hasPrefix("http") ? path : (baseUrl ?? "") + path
            }
            return baseUrl
        }
        return nil
    }
    
    public func resultType(for action: String) -> String? {
        guard var resultType = configDict?.value(forKeyPath: "actions.\(action).resultType") as? String else { return nil }
        if resultType.hasPrefix("[") && resultType.hasSuffix("]") {
            resultType = String(resultType.dropFirst().dropLast())
        }
        return resultType
    }
    
    public func isUpload(for action: String) -> Bool {
        return configDict?.value(forKeyPath: "actions.\(action).isUpload") as? Bool ?? false
    }
    
    public func resultIsArray(for action: String) -> Bool {
        guard let resultType = configDict?.value(forKeyPath: "actions.\(action).resultType") as? String else { return false }
        return resultType.hasPrefix("[") && resultType.hasSuffix("]")
    }
    
    public func resultKeyPath(for action: String) -> String? {
        let keyPath = configDict?.value(forKeyPath: "actions.\(action).resultKeyPath") ?? configDict?.value(forKeyPath: "defaults.resultKeyPath")
        return keyPath as? String
    }
    
    public func errorKeyPath(for action: String) -> String {
        let keyPath = configDict?.value(forKeyPath: "actions.\(action).errorKeyPath") ?? configDict?.value(forKeyPath: "defaults.errorKeyPath")
        return keyPath as? String ?? "error"
    }
    
    public func nextAction(for action: String) -> String? {
        return configDict?.value(forKeyPath: "actions.\(action).nextAction") as? String
    }
    
    public func clearPolicy(for action: String) -> ClearPolicy {
        guard let ps = configDict?.value(forKeyPath: "actions.\(action).clearPolicy") as? String, let p = ClearPolicy(rawValue: ps) else {
            return .none
        }
        return p
    }
    
    public func setRequestComposer(_ closure: @escaping ((String, HTTPMethod, String, Parameters?, HTTPHeaders?) -> URLRequest?)) {
        requestComposer = closure
    }
    
    public func setRequestModifier(_ closure: @escaping ((String, inout URLRequest) -> Void)) {
        requestModifier = closure
    }
    
    public func urlRequest(for action: String, with object: Any?) -> URLRequest? {
        var request: URLRequest? = nil
        if var url = self.url(for: action) {
            if let object = object as? NSObject {
                url = String(format: url, with: object, pattern: String.keyPattern)
            }
            url = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "<url>"
            var parameters = self.parameters(for: action)
            if let object = object as? NSObject {
                parameters = parameters.substitute(object)
            }
            if let composer = requestComposer {
                request = composer(action, httpMethod(for: action), url, parameters, headers(for: action))
            }
            if request == nil {
                do {
                    request = try URLRequest(url: url, method: httpMethod(for: action), headers: headers(for: action))
                    request = try URLEncoding.httpBody.encode(request!, with: parameters)
                    requestModifier?(action, &request!)
                } catch {
                    print(error)
                }
            }
        }
        return request
    }
    
    public func uploadRequest(for action: String, with object: Any?) -> URLRequest? {
        var request: URLRequest? = nil
        if isUpload(for: action), var url = self.url(for: action) {
            if let object = object as? NSObject {
                url = String(format: url, with: object, pattern: String.keyPattern)
            }
            if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                url = escapedUrl
            }
            if let composer = requestComposer {
                request = composer(action, httpMethod(for: action), url, nil, headers(for: action))
            }
            if request == nil {
                do {
                    request = try URLRequest(url: url, method: httpMethod(for: action), headers: headers(for: action))
                    requestModifier?(action, &request!)
                } catch {
                    print(error)
                }
            }
        }
        return request
    }
}
