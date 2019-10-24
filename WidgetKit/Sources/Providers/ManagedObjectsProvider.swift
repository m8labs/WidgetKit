//
// ManagedObjectsProvider.swift
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

public class ManagedObjectsProvider: BaseContentProvider, NSFetchedResultsControllerDelegate {
    
    @objc public var entityName: String?
    @objc public var groupByField: String?
    @objc public var cacheName: String?
    
    var _fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
    
    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> {
        if _fetchedResultsController == nil {
            fetch()
        }
        return _fetchedResultsController!
    }
    
    private func masterPredicate() -> NSPredicate? {
        guard let masterObject = masterObject, let masterKeyPath = masterKeyPath else { return nil }
        return NSPredicate(format: "%K = %@", masterKeyPath, masterObject)
    }
    
    private func filterPredicate() -> NSPredicate? {
        guard let filterFormat = filterFormat, let searchString = searchString, searchString.count > 0 else { return nil }
        let predicate = NSPredicate(format: filterFormat).withSubstitutionVariables([TextInputView.inputFieldName: searchString])
        return predicate
    }
    
    private func predicateFromString(_ format: String) -> NSPredicate {
        guard let content = viewController?.content else { return NSPredicate(format: format) }
        return NSPredicate(format: format).withSubstitutionVariables(["content": content])
    }
    
    private func predicate() -> NSPredicate? {
        var predicates = [NSPredicate]()
        if let format = predicateFormat {
            predicates.append(predicateFromString(format))
        }
        if let masterPredicate = masterPredicate() {
            predicates.append(masterPredicate)
        }
        if let filterPredicate = filterPredicate() {
            predicates.append(filterPredicate)
        }
        return NSCompoundPredicate.init(andPredicateWithSubpredicates: predicates)
    }
    
    private var _managedObjectContext: NSManagedObjectContext?
    public var managedObjectContext: NSManagedObjectContext {
        get {
            return _managedObjectContext ?? (widget?.defaultContext ?? NSManagedObjectContext.main)
        }
        set {
            _managedObjectContext = newValue
        }
    }
    
    public override var sectionsCount: Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    public override func itemsCountInSection(_ section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    public override var allItems: [Any] {
        return fetchedResultsController.fetchedObjects ?? []
    }
    
    public override func item(at indexPath: IndexPath) -> Any? {
        return itemsCountInSection(indexPath.section) > 0 ? fetchedResultsController.object(at: indexPath) : nil
    }
    
    public override func indexPath(for item: Any) -> IndexPath? {
        return fetchedResultsController.indexPath(forObject: item as! NSFetchRequestResult)
    }
    
    public override func totalCount() -> Int {
        guard let sections = fetchedResultsController.sections else { return 0 }
        var count = 0
        for section in sections {
            count += section.numberOfObjects
        }
        return count
    }
    
    public override func firstIndexPath() -> IndexPath? {
        guard let firstSection = fetchedResultsController.sections?.first else { return nil }
        let count = firstSection.numberOfObjects
        return count > 0 ? IndexPath.first : nil
    }
    
    public override func lastIndexPath() -> IndexPath? {
        guard let sections = fetchedResultsController.sections, let lastSection = sections.last else { return nil }
        let count = lastSection.numberOfObjects
        return count > 0 ? IndexPath(row: count - 1, section: sections.count - 1) : nil
    }
    
    public override func reset() {
        _fetchedResultsController = nil
        super.reset()
    }
    
    public override func insertItem(_ item: Any, at indexPath: IndexPath) {
        assert(false, "Inserting items directly is not supported for 'ManagedObjectsProvider'.")
    }
    
    public override func fetch() {
        var sortDescriptors = self.sortDescriptors
        if groupByField != nil && groupByField != "" {
            sortDescriptors.insert(NSSortDescriptor(key: groupByField!, ascending: sortAscending), at: 0)
        }
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: entityName!, in: managedObjectContext)!
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.predicate = predicate()
        _fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                               managedObjectContext: managedObjectContext,
                                                               sectionNameKeyPath: groupByField,
                                                               cacheName: cacheName)
        _fetchedResultsController!.delegate = self
        do {
            try _fetchedResultsController!.performFetch()
            contentConsumer?.renderContent(from: self)
        }
        catch let error {
            print(error)
        }
    }
}

extension ManagedObjectsProvider {
    
    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let prepareRenderContent = contentConsumer?.prepareRenderContent, let _ = contentConsumer?.finalizeRenderContent {
            prepareRenderContent(self)
        }
    }
    
    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let finalizeRenderContent = contentConsumer?.finalizeRenderContent {
            finalizeRenderContent(self)
        } else {
            contentConsumer?.renderContent(from: self)
        }
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if type == .insert, let newIndexPath = newIndexPath {
            contentConsumer?.renderContent?(anObject, change: .insert, at: newIndexPath, from: self)
        }
        else if type == .update, let indexPath = indexPath {
            contentConsumer?.renderContent?(anObject, change: .update, at: indexPath, from: self)
        }
        else if type == .delete, let indexPath = indexPath {
            contentConsumer?.renderContent?(anObject, change: .delete, at: indexPath, from: self)
        }
        else if type == .move, let oldIndexPath = indexPath, let newIndexPath = newIndexPath, newIndexPath != oldIndexPath {
            contentConsumer?.renderContent?(anObject, change: .delete, at: oldIndexPath, from: self)
            contentConsumer?.renderContent?(anObject, change: .insert, at: newIndexPath, from: self)
        }
    }
}

public class ManagedObjectsCollection: BaseContentProvider {
    
    private var _provider = ManagedObjectsProvider()
    
    public override func fetch() {
        _provider.masterKeyPath = masterKeyPath
        _provider.sortByFields = sortByFields
        _provider.sortAscending = sortAscending
        _provider.searchString = searchString
        _provider.resultChain = resultChain
        _provider.resultChainArgs = resultChainArgs
        _provider.predicateFormat = predicateFormat
        if let value = _provider.value {
            items = value as? [Any] ?? [value]
        }
    }
}
