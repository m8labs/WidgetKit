//
// BaseContentProvider.swift
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

public protocol ContentProviderProtocol: class {
    
    var contentConsumer: ContentConsumerProtocol? { get set }
    
    var masterKeyPath: String? { get set }
    
    var masterObject: NSObject? { get set }
    
    var sortByFields: String? { get set }
    
    var sortAscending: Bool { get set }
    
    var filterFormat: String?  { get set }
    
    var searchString: String?  { get set }
    
    var predicateFormat: String?  { get set }
    
    var sectionsCount: Int { get }
    
    var sortDescriptors: [NSSortDescriptor] { get }
    
    var isEmpty: Bool { get }
    
    func itemsCountInSection(_ section: Int) -> Int
    
    var totalCount: Int { get }
    
    var allItems: [Any] { get }
    
    var value: Any?  { get }
    
    func item(at indexPath: IndexPath) -> Any?
    
    func indexPath(for item: Any) -> IndexPath?
    
    func first() -> Any?
    
    func last() -> Any?
    
    func reset()
    
    func fetch()
}

extension ContentProviderProtocol {
    
    public var sortDescriptors: [NSSortDescriptor] {
        var sortDescriptors = [NSSortDescriptor]()
        if let sortByFields = self.sortByFields {
            let sortDescriptorsStrings = sortByFields.components(separatedBy: ",").map({ $0.trimmingCharacters(in: CharacterSet.whitespaces) })
            for fieldName: String in sortDescriptorsStrings {
                sortDescriptors.append(NSSortDescriptor(key: fieldName, ascending: sortAscending))
            }
        }
        return sortDescriptors
    }
    
    public var isEmpty: Bool {
        return first() == nil
    }
    
    public func first() -> Any? {
        return item(at: IndexPath.first)
    }
}

open class BaseContentProvider: ContentProviderProtocol & CustomIBObject {
    
    public weak var contentConsumer: ContentConsumerProtocol?
    
    @objc open var masterKeyPath: String?
    
    @objc open var sortByFields: String?
    
    @objc open var sortAscending = true
    
    @objc open var filterFormat: String?
    
    @objc open var predicateFormat: String? { didSet { if isPrepared { fetch() } } }
    
    @objc open var searchString: String? { didSet { if isPrepared { fetch() } } }
    
    open var masterObject: NSObject? { didSet { if isPrepared { fetch() } } }
    
    /// `resultChain` utilizes `NSExpression` engine, which is very powerful and can compete with
    /// objective-c/swift code with functionality. It's an array of `NSArray.wx_*` functions which
    /// you can apply on the result set. Each function applies on top of each other in the original order.
    /// If any or all functions in the result chain takes an argument, you can put these arguments in a
    /// `resultChainArgs` array. Each method can take only 1 argument. F.e. if you have a result array
    /// such as [A, B, C, D, E, F], then pair of `resultChain` - `resultChainArgs` such as
    /// [`wx_takeFirst:`, `wx_takeLast:`] - [4, 2] will produce [C, D]. `resultChain` and `resultChainArgs`
    /// should contain equal number of elements. If you need to call a method that doesn`t take arguments,
    /// pass an empty string or 0.
    ///
    /// You can also call some of the `NSArray` functions directly, but `wx_*` wrappers are more safe.
    /// All args will be anyway converted to strings and then interpreted by `NSExpression` engine as
    /// expected by method being called.,
    ///
    /// The following wrappers currently implemented:
    /// `wx_itemAt:`, `wx_first`, `wx_last`, `wx_count`, `wx_takeFirst:`, `wx_takeLast:`, `wx_joinedBy:`, `wx_map:`
    /// Refer to the `NSExpression` documentation and the `NSArray` collection operators for additional details.
    ///
    /// The `resultChain` affects only `BaseContentProvider.value` object, which you can refer in bindings.
    /// For selecting data use `BaseContentProvider.predicateFormat` (see below).
    /// If you need the `resultChain` to filter data set, use `ManagedObjectsCollection` instead of `ManagedObjectsProvider`.
    /// You can set `resultChain` and `resultChainArgs` in the storyboard via `resultChainTxt` and `resultChainArgsTxt`
    /// textual counterparts using `|` as a delimeter.
    ///
    /// Keep in mind possible perfomance issues when using `NSExpression`.
    /// The order of functions in the `resultChain` can affect perfomance a lot.
    @objc open var resultChain: [String]?         // f.e. ["wx_itemAt:", "valueForKeyPath:"]
    
    @objc open var resultChainArgs: [String]?     // ["-1", "@distinctUnionOfObjects.self"]
    
    @objc open var resultChainTxt: String? {      // f.e. "wx_itemAt:|valueForKeyPath:"
        didSet {
            if let value = resultChainTxt {
                resultChain = value.components(separatedBy: "|")
            }
        }
    }
    
    @objc open var resultChainArgsTxt: String? {    // "-1|@distinctUnionOfObjects.self"
        didSet {
            if let value = resultChainArgsTxt {
                resultChainArgs = value.components(separatedBy: "|")
            }
        }
    }
    
    private lazy var expressions: [NSExpression]? = {
        guard let functions = resultChain else { return nil }
        if let params = resultChainArgs, params.count != functions.count {
            preconditionFailure("The number of items in 'resultChainArgs' should be equal to the number of items in 'resultChain'. Use an empty string for the functions that take no arguments.")
        }
        var expressions = [NSExpression]()
        for var i in 0 ..< functions.count {
            expressions.append(NSExpression(format: "FUNCTION(SELF, '\(functions[i])', '\(resultChainArgs?[i] ?? "")')"))
            i += 1
        }
        return expressions
    }()
    
    @objc open var value: Any? {
        var some = allItems as Any?
        for expression in self.expressions ?? [] {
            some = expression.expressionValue(with: some, context: nil)
        }
        return some
    }
    
    public func last() -> Any? {
        preconditionFailure("Should be implemented in a successor class.")
    }
    
    public var sectionsCount: Int {
        preconditionFailure("Should be implemented in a successor class.")
    }
    
    public func itemsCountInSection(_ section: Int) -> Int {
        preconditionFailure("Should be implemented in a successor class.")
    }
    
    public var totalCount: Int {
        preconditionFailure("Should be implemented in a successor class.")
    }
    
    public func item(at indexPath: IndexPath) -> Any? {
        preconditionFailure("Should be implemented in a successor class.")
    }
    
    public func indexPath(for item: Any) -> IndexPath? {
        preconditionFailure("Should be implemented in a successor class.")
    }
    
    public func reset() {
        preconditionFailure("Should be implemented in a successor class.")
    }
    
    public var allItems: [Any] {
        preconditionFailure("Should be implemented in a successor class.")
    }
    
    public func fetch() {
        preconditionFailure("Should be implemented in a successor class.")
    }
    
    open override func setup() {
        super.setup()
        // Taking vc's content object as the `masterObject` for all content providers if it's nil and `masterKeyPath` was set.
        if masterKeyPath != nil && masterObject == nil {
            masterObject = viewController?.content as? NSObject
        }
    }
    
    @discardableResult
    open override func prepare() -> [CustomIBObject] {
        let preparedChain = super.prepare()
        fetch()
        return preparedChain
    }
}

open class ItemsContentProvider: BaseContentProvider {
    
    open var items = [[Any]]()
    
    override open var sectionsCount: Int {
        return items.count
    }
    
    override open func itemsCountInSection(_ section: Int) -> Int {
        guard section < items.count else { return 0 }
        return items[section].count
    }
    
    override open var totalCount: Int {
        return items.reduce(0) { count, array in count + array.count }
    }
    
    override open func item(at indexPath: IndexPath) -> Any? {
        guard indexPath.section < items.count, indexPath.row < items[indexPath.section].count else { return nil }
        return items[indexPath.section][indexPath.item]
    }
    
    override public func indexPath(for item: Any) -> IndexPath? {
        return nil
    }
    
    override open func reset() {
        items.removeAll()
        contentConsumer?.renderContent(from: self)
    }
    
    override open var allItems: [Any] {
        return items
    }
    
    override open func fetch() {
        contentConsumer?.renderContent(from: self)
    }
}

public class ItemsCollection: ItemsContentProvider {
    
    override public func fetch() {
        guard let masterKeyPath = self.masterKeyPath else { return }
        guard let masterObject = self.masterObject else {
            self.items = []
            contentConsumer?.renderContent(from: self)
            return
        }
        let value = masterObject.value(forKeyPath: masterKeyPath)
        if let items = ((value as? NSSet)?.allObjects ?? (value as? [Any])) as NSArray? {
            if let predicateFormat = self.predicateFormat {
                let predicate = NSPredicate(format: predicateFormat)
                let filtered = items.filtered(using: predicate) as NSArray
                self.items = [filtered.sortedArray(using: sortDescriptors)]
            } else {
                self.items = [items.sortedArray(using: sortDescriptors)]
            }
            contentConsumer?.renderContent(from: self)
        }
    }
}

extension IndexPath {
    
    public static var first: IndexPath {
        return IndexPath(row: 0, section: 0)
    }
}

extension NSArray {
    
    @objc(wx_itemAt:)
    public func wx_item(at index: NSNumber) -> Any? {
        let i = index.intValue
        guard i >= 0 && i < count || i < 0 && (count + i) >= 0 else { return nil }
        return i >= 0 ? object(at: i) : object(at: count + i)
    }
    
    @objc(wx_first)
    public func wx_first() -> Any? { return firstObject }
    
    @objc(wx_last)
    public func wx_last() -> Any? { return lastObject }
    
    @objc(wx_count)
    public func wx_count() -> NSNumber { return NSNumber(value: count) }
    
    @objc(wx_takeFirst:)
    public func wx_take(first n: NSNumber) -> [Any] { return Array(prefix(n.intValue)) }
    
    @objc(wx_takeLast:)
    public func wx_take(last n: NSNumber) -> [Any] { return Array(suffix(n.intValue)) }
    
    @objc(wx_joinedBy:)
    public func wx_joined(by string: String) -> String { return componentsJoined(by: string) }
    
    @objc(wx_map:)
    public func wx_map(to keyPath: String) -> Any? { return value(forKeyPath: keyPath) }
}
