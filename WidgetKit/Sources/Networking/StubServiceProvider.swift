//
// StubServiceProvider.swift
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

open class StubServiceConfiguration: ServiceConfiguration {
    
    var debugDelay: Double {
        return configDict?.value(forKeyPath: "options.debugDelay") as? Double ?? 0
    }
    
    func responseObject(for action: String, substitute object: Any?) -> Any? {
        let response = configDict?.value(forKeyPath: "actions.\(action).response")
        if let dict = response as? [String: Any] {
            return object is NSObject ? dict.substitute(object as! NSObject) : dict
        } else {
            return response
        }
    }
    
    public init(bundle: Bundle?) {
        super.init(resource: "StubService.json", bundle: bundle)
    }
}

open class StubServiceProvider: StandardServiceProvider {
    
    override open func setup() {
        configuration = StubServiceConfiguration(bundle: bundle)
    }
    
    override open func serverError(for action: String, code: Int, data: Data?) -> Error? {
        return NSError(domain: "\(bundle.bundleIdentifier!).Error", code: code, userInfo: [NSLocalizedDescriptionKey: "Test response not implemented."])
    }
    
    override func request(for action: String, with args: ActionArgs? = nil, from sender: Any? = nil, completion: @escaping Completion) {
        guard let config = configuration as? StubServiceConfiguration else { preconditionFailure("Configuration not set.") }
        guard let requestInfo = configuration.urlRequest(for: action, with: args), let request = requestInfo.request else {
            print("Unable to initiate request for action '\(action)' with object '\(args?.params ?? "<nil>")'"); return
        }
        before(action: action, request: request)
        action.notification.onStart.post(object: sender)
        afterTimeout(config.debugDelay) {
            if let response = config.responseObject(for: action, substitute: args) {
                self.after(action: action, request: request, response: nil, data: nil)
                completion(response, nil)
            } else {
                let error = self.serverError(for: action, code: 404, data: nil)
                self.after(action: action, request: request, response: nil, data: nil)
                completion(nil, error)
            }
        }
    }
    
    override func printRequest(_ request: URLRequest?, for action: String, removePercentEncoding: Bool = false, printCloseLine: Bool = true) {
        print("\n-----------------------------------------------------------------------------------")
        print("Fake request for '\(action)'")
    }
    
    override func printResponse(_ response: URLResponse?, data: Data?, for action: String) {
        print("\nFake response for '\(action)'")
        print("-----------------------------------------------------------------------------------\n")
    }
}
