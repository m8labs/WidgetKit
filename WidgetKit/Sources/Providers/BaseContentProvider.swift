//
// BaseContentProvider.swift
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
    
    func totalCount() -> Int
    
    var allItems: [Any]  { get }
    
    var value: Any?  { get }
    
    func item(at indexPath: IndexPath) -> Any?
    
    func next(to indexPath: IndexPath) -> Any?
    
    func previous(to indexPath: IndexPath) -> Any?
    
    func items(at indexPaths: [IndexPath]) -> [Any]
    
    func indexPath(for item: Any) -> IndexPath?
    
    func first() -> Any?
    
    func last() -> Any?
    
    func firstIndexPath() -> IndexPath?
    
    func lastIndexPath() -> IndexPath?
    
    func insertItem(_ item: Any, at indexPath: IndexPath)
    
    func reset()
    
    func fetch()
}

open class BaseContentProvider: CustomIBObject, ContentProviderProtocol {
    
    var items = [Any]()
    
    public weak var contentConsumer: ContentConsumerProtocol?
    
    @objc public var masterKeyPath: String?
    
    @objc public var sortByFields: String?
    
    @objc public var sortAscending = true
    
    @objc public var masterObject: NSObject? = nil { didSet { reset() } }
    
    @objc public var predicateFormat: String? = nil { didSet { reset() } }
    
    @objc public var filterFormat: String?
    
    @objc open var searchString: String? { didSet { fetch() } }
    
    /// `resultChain` utilizes `NSExpression` engine, which is very powerful and can compete with
    /// objective-c/swift code with functionality. It's an array of `NSArray.wx_*` functions which
    /// you can apply on the result set. Each function applies on top of each other in the original order.
    /// If any or all functions in the result chain takes an argument, you can put these arguments in a
    /// `resultChainArgs` array. Each method can take only 1 argument. F.e. if you have a result array
    /// such as [A, B, C, D, E, F], then pair of `resultChain` - `resultChainArgs` such as
    /// [`wx_takeFirst:`, `wx_takeLast:`] - [4, 2] will produce [C, D]. `resultChain` and `resultChainArgs`
    /// shoud contain equal number of elements. If you need to call a method that doesn`t take arguments,
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
    @objc public var resultChain: [String]?         // f.e. ["wx_itemAt:", "valueForKeyPath:"]
    
    @objc public var resultChainArgs: [String]?     // ["-1", "@distinctUnionOfObjects.self"]
    
    @objc public var resultChainTxt: String? {      // f.e. "wx_itemAt:|valueForKeyPath:"
        didSet {
            if let value = resultChainTxt {
                resultChain = value.components(separatedBy: "|")
            }
        }
    }
    
    @objc public var resultChainArgsTxt: String? {    // "-1|@distinctUnionOfObjects.self"
        didSet {
            if let value = resultChainArgsTxt {
                resultChainArgs = value.components(separatedBy: "|")
            }
        }
    }
    
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
    
    public func next(to indexPath: IndexPath) -> Any? {
        return item(at:indexPath.next)
    }
    
    public func previous(to indexPath: IndexPath) -> Any? {
        guard let previous = indexPath.previous else { return nil }
        return item(at:previous)
    }
    
    public func items(at indexPaths: [IndexPath]) -> [Any] {
        var result = [Any]()
        for indexPath in indexPaths {
            result.append(item(at: indexPath)!)
        }
        return result
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
    
    @objc open var isEmpty: Bool {
        return first() == nil
    }
    
    @objc open var value: Any? {
        var some = allItems as Any?
        for expression in self.expressions ?? [] {
            some = expression.expressionValue(with: some, context: nil)
        }
        return some
    }
    
    open var sectionsCount: Int {
        return items.count > 0 ? 1 : 0
    }
    
    open func itemsCountInSection(_ section: Int) -> Int {
        return items.count
    }
    
    @objc open func totalCount() -> Int {
        return items.count
    }
    
    open func item(at indexPath: IndexPath) -> Any? {
        guard indexPath.section == 0 else { return nil }
        return items[indexPath.item]
    }
    
    open func indexPath(for item: Any) -> IndexPath? {
        return nil
    }
    
    @objc public func first() -> Any? {
        guard let indexPath = firstIndexPath() else { return nil }
        return item(at: indexPath)
    }
    
    @objc public func last() -> Any? {
        guard let indexPath = lastIndexPath() else { return nil }
        return item(at: indexPath)
    }
    
    public func firstIndexPath() -> IndexPath? {
        return IndexPath.first
    }
    
    open func lastIndexPath() -> IndexPath? {
        return IndexPath(row: allItems.count - 1, section: 0)
    }
    
    open func insertItem(_ item: Any, at indexPath: IndexPath = IndexPath.first) {
        return items.insert(item, at: indexPath.item)
    }
    
    open func reset() {
        items.removeAll()
        contentConsumer?.renderContent(from: self)
    }
    
    open var allItems: [Any] {
        return items
    }
    
    open func fetch() {
        //
    }
}

public class ItemsCollection: BaseContentProvider {
    
    public override func fetch() {
        guard let masterObject = self.masterObject, let masterKeyPath = self.masterKeyPath else { return }
        let value = masterObject.value(forKeyPath: masterKeyPath)
        if let items = ((value as? NSSet)?.allObjects ?? (value as? [Any])) as NSArray? {
            if let predicateFormat = self.predicateFormat {
                let predicate = NSPredicate(format: predicateFormat)
                let filtered = items.filtered(using: predicate) as NSArray
                self.items = filtered.sortedArray(using: sortDescriptors)
            } else {
                self.items = items.sortedArray(using: sortDescriptors)
            }
        }
    }
}

extension IndexPath {
    
    public static var first: IndexPath {
        return IndexPath(row: 0, section: 0)
    }
    
    public var previous: IndexPath? {
        return item > 0 ? IndexPath(item: item - 1, section: section) : nil
    }
    
    public var next: IndexPath {
        return IndexPath(item: item + 1, section: section)
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
