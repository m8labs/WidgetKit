//
// BaseDisplayController.swift
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

public enum ContentChange: UInt {
    case insert, delete, update
}

public protocol ContentConsumerProtocol: class {
    
    func renderContent(from source: ContentProviderProtocol?)
    
    func prepareRenderContent(from source: ContentProviderProtocol?)
    
    func renderContent(_ content: Any, change: ContentChange, at indexPath: IndexPath, from source: ContentProviderProtocol?)
    
    func finalizeRenderContent(from source: ContentProviderProtocol?)
}

open class BaseDisplayController: CustomIBObject, ContentConsumerProtocol, ObserversStorageProtocol {
    
    @IBOutlet public var mainContentProvider: BaseContentProvider?
    
    @IBOutlet public var searchController: SearchActionController?
    
    @IBOutlet public var elements: [NSObject]?
    
    public var contentProvider: BaseContentProvider! {
        return (searchController?.isSearching ?? false) ? searchController!.contentProvider : mainContentProvider
    }
    
    @objc public var renderOn: String?
    
    public var observers: [Any] = []
    
    open func setupObservers() {
        guard let renderOn = renderOn else { return }
        observers = [
            NSNotification.Name(rawValue: renderOn).subscribe { [weak self] _ in
                if let this = self {
                    this.renderContent(from: this.contentProvider)
                }
            }
        ]
    }
    
    open func renderContent(from source: ContentProviderProtocol?) {
        viewController?.refresh(elements: elements)
    }
    
    open func prepareRenderContent(from source: ContentProviderProtocol?) { }
    
    open func renderContent(_ content: Any, change: ContentChange, at indexPath: IndexPath, from source: ContentProviderProtocol?) { }
    
    open func finalizeRenderContent(from source: ContentProviderProtocol?) {
        viewController?.refresh(elements: elements)
    }
    
    open override func setup() {
        super.setup()
        dependency = mainContentProvider
        mainContentProvider?.contentConsumer = self
        if let searchController = searchController {
            if searchController.contentProvider == nil {
                searchController.contentProvider = mainContentProvider
            } else {
                searchController.contentProvider?.contentConsumer = self
            }
        }
        setupObservers()
    }
}

open class ContentDisplayController: BaseDisplayController {
    
    override open func renderContent(from source: ContentProviderProtocol?) {
        viewController?.content = source?.value
    }
    
    override open func finalizeRenderContent(from source: ContentProviderProtocol?) {
        viewController?.content = source?.value
    }
}
