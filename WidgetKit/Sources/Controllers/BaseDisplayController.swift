//
// BaseDisplayController.swift
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

import UIKit

@objc
public enum ContentChange: UInt {
    case insert, delete, update
}

@objc
public protocol ContentConsumerProtocol: class {
    
    @objc func renderContent(from source: ContentProviderProtocol?)
    
    @objc optional func prepareRenderContent(from source: ContentProviderProtocol?)
    
    @objc optional func renderContent(_ content: Any, change: ContentChange, at indexPath: IndexPath, from source: ContentProviderProtocol?)
    
    @objc optional func finalizeRenderContent(from source: ContentProviderProtocol?)
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
    
    open func renderContent(from source: ContentProviderProtocol? = nil) {
        viewController.refresh(elements: elements)
    }
    
    open override func setup() {
        super.setup()
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
    
    open override func prepare() {
        super.prepare()
        if let mainContentProvider = mainContentProvider {
            mainContentProvider.fetch()
        }
    }
}

open class ContentDisplayController: BaseDisplayController {
    
    open override func renderContent(from source: ContentProviderProtocol? = nil) {
        viewController.content = source?.value
    }
}
