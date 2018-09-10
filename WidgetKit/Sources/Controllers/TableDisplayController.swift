//
// TableDisplayController.swift
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
import CoreData

open class TableDisplayController: BaseDisplayController {
    
    @objc public var cellIdentifier: String?
    
    @objc public var searchCellIdentifier: String?
    
    @objc public var sectionHeaderIdentifier: String?
    
    @objc public var sectionFooterIdentifier: String?
    
    @objc public var cellNibNames: [String]?
    
    @objc public var animateReload = false
    
    @objc public var maxHeight: CGFloat = 0
    
    @objc public var systemAutomaticDimensionEnabled = true
    
    @objc public var allowDeletion = false
    
    @objc public var collectSelectedObjects = false
    
    @objc public var defaultSelectionBehavior = false
    
    @objc public var performSegueForCells = -1
    
    public var dynamicCellIdentifier: ((Any, IndexPath) -> String?)?
    
    public var cellSelected: ((ContentTableViewCell, Any, IndexPath) -> Void)?
    
    public var cellDeselected: ((ContentTableViewCell, Any, IndexPath) -> Void)?
    
    @IBOutlet public var tableView: UITableView! {
        get { return elements?.first as! UITableView }
        set { elements = [newValue] }
    }
    
    @IBOutlet var emptyDataView: UIView?
    
    @IBOutlet var contentHeightConstraint: NSLayoutConstraint?
    
    @IBOutlet var deleteController: ActionController?
    
    public private(set) var selectedObjectsIDs = NSMutableArray()
    
    public var selectedObjects: [Any] {
        return contentProvider.allItems.filter { a in
            if let objectId = (a as? NSObject)?.objectId {
                return selectedObjectsIDs.contains(objectId)
            }
            return false
        }
    }
    
    fileprivate var cellSizeCalculator = TextSizeCalculator()
    
    fileprivate var cellTemplates = [String: ContentTableViewCell]()
    
    fileprivate weak var objectToDelete: NSManagedObject?
    
    fileprivate var vars: ObjectsDictionaryProxy!
    
    func registerNibs() {
        cellNibNames?.forEach { nibName in
            let nib = UINib(nibName: nibName, bundle: bundle)
            tableView.register(nib, forCellReuseIdentifier: nibName)
        }
    }
    
    func reloadData(animated: Bool = false) {
        if animated {
            if contentProvider != nil && contentProvider.sectionsCount > 0 {
                tableView.reloadSections(IndexSet(integersIn: 0...contentProvider.sectionsCount - 1), with: .automatic)
                fitContentIfNecessary()
            }
        } else {
            tableView.reloadData()
            fitContentIfNecessary()
        }
    }
    
    open func cellIdentifier(for object: Any, at indexPath: IndexPath) -> String {
        vars.setValue(object, forKey: ObjectsDictionaryProxy.contentKey)
        var cellId = ""
        let isSearching = searchController?.isSearching ?? false
        let key = isSearching ? type(of: self).searchCellIdentifierKey : type(of: self).cellIdentifierKey
        if let eval = wx.evals[key] ?? wx.evals[type(of: self).cellIdentifierKey] {
            cellId = eval.perform(with: vars) as! String
        } else {
            cellId = dynamicCellIdentifier?(object, indexPath) ?? ((isSearching ? searchCellIdentifier : cellIdentifier) ?? type(of: self).defaultCellIdentifier)
        }
        return cellId
    }
    
    open func configureCell(_ cell: ContentTableViewCell, object: Any, indexPath: IndexPath) {
        cell.widget = widget
        cell.scheme = viewController.scheme
        cell.content = object
    }
    
    open func configureSection(_ view: ContentDisplayView, object: Any?, section: Int) {
        if view.scheme == nil, let scheme = viewController.scheme {
            view.widget = widget
            view.setup(scheme: scheme)
        }
        view.content = object
    }
    
    open override func renderContent(from source: ContentProviderProtocol? = nil) {
        reloadData(animated: animateReload)
    }
    
    open override func setupObservers() {
        observers = [
            Notification.Name.TextSizeCalculatorReady.subscribe(to: cellSizeCalculator) { [weak self] n in
                self?.reloadData()
            }
        ]
        if let renderOn = renderOn {
            observers.append(
                NSNotification.Name(rawValue: renderOn).subscribe { [weak self] _ in
                    self?.resetLayoutCache()
                    self?.reloadData()
                }
            )
        }
    }
    
    open override func setup() {
        guard let tableView = self.tableView else { return }
        tableView.dataSource = self
        if tableView.delegate == nil {
            tableView.delegate = self
        }
        if cellNibNames != nil {
            registerNibs()
            if performSegueForCells < 0 {
                performSegueForCells = 1
            }
        }
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: type(of: self).systemHeaderFooterIdentifier)
        super.setup()
    }
    
    open override func prepare() {
        super.prepare()
        vars = ObjectsDictionaryProxy(copy: viewController.vars)
    }
}

// MARK: -

extension TableDisplayController: UITableViewDataSource {
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        let count = contentProvider.totalCount()
        emptyDataView?.isHidden = count > 0
        return contentProvider.sectionsCount
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = contentProvider.itemsCountInSection(section)
        return count
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let object = contentProvider.item(at: indexPath) else { preconditionFailure("Cell object should not be nil.") }
        let cellId = cellIdentifier(for: object, at: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        precondition(cell is ContentTableViewCell, "Cell must be of '\(ContentTableViewCell.self)' type.")
        configureCell(cell as! ContentTableViewCell, object: object, indexPath: indexPath)
        return cell
    }
}

// MARK: -

extension TableDisplayController: UITableViewDelegate {
    
    // Object selection handling
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? ContentTableViewCell else { return }
        guard let object = contentProvider.item(at: indexPath) as? NSObject else { return }
        if performSegueForCells > 0 {
            viewController.performSegue(withIdentifier: cell.reuseIdentifier!, sender: cell)
        } else {
            if collectSelectedObjects {
                if selectedObjectsIDs.contains(object.objectId) {
                    selectedObjectsIDs.remove(object.objectId)
                    tableView.deselectRow(at: indexPath, animated: false)
                } else {
                    if !tableView.allowsMultipleSelection {
                        selectedObjectsIDs.removeAllObjects()
                    }
                    if !selectedObjectsIDs.contains(object.objectId) {
                        selectedObjectsIDs.add(object.objectId)
                    }
                }
            }
            if defaultSelectionBehavior {
                cell.accessoryType = .checkmark
            }
            cellSelected?(cell, object, indexPath)
        }
    }
    
    open func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? ContentTableViewCell else { return }
        guard let object = contentProvider.item(at: indexPath) as? NSObject else { return }
        selectedObjectsIDs.remove(object.objectId)
        if defaultSelectionBehavior {
            cell.accessoryType = .none
        }
        cellDeselected?(cell, object, indexPath)
    }
    
    open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let object = contentProvider.item(at: indexPath) as? NSObject else { return }
        let isSelected = selectedObjectsIDs.contains(object.objectId)
        cell.isSelected = isSelected
        if defaultSelectionBehavior {
            cell.accessoryType = isSelected ? .checkmark : .none
        }
    }
    
    // Header/Footer views
    
    func viewForHeaderOrFooter(withIdentifier identifier: String, inSection section: Int) -> UIView? {
        let systemView: UITableViewHeaderFooterView? = tableView.dequeueReusableHeaderFooterView(withIdentifier: type(of: self).systemHeaderFooterIdentifier)
        guard systemView != nil else { return nil }
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
        guard let customView = cell?.contentView.subviews.first as? ContentDisplayView else { return nil }
        systemView!.backgroundView = customView
        let object = contentProvider.item(at: IndexPath(row: 0, section: section))
        configureSection(customView, object: object, section: section)
        return systemView
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let identifier = sectionHeaderIdentifier ?? type(of: self).defaultSectionHeaderIdentifier
        return viewForHeaderOrFooter(withIdentifier: identifier, inSection: section)
    }
    
    open func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let identifier = sectionFooterIdentifier ?? type(of: self).defaultSectionFooterIdentifier
        return viewForHeaderOrFooter(withIdentifier: identifier, inSection: section)
    }
    
    // Editing rows
    
    open func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, let object = contentProvider.item(at: indexPath) as? NSManagedObject else { return }
        objectToDelete = object
        tableView.reloadRows(at: [indexPath], with: .automatic) // animation
        objectToDelete = nil
        deleteController?.performServiceAction(with: object)
        after(0.75) { // waiting for animation finished
            object.delete()
        }
    }
    
    open func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        guard allowDeletion, let object = contentProvider.item(at: indexPath) as? NSManagedObject else { return .none }
        return object.isMine ? .delete : .none
    }
    
    // Cell Sizing
    
    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let object = contentProvider.item(at: indexPath) as? NSObject else { return UITableViewAutomaticDimension }
        guard object != objectToDelete else { return 0 }
        guard !systemAutomaticDimensionEnabled else { return UITableViewAutomaticDimension }
        return heightForObject(object, at: indexPath)
    }
    
    open func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard !systemAutomaticDimensionEnabled else { return UITableViewAutomaticDimension }
        guard let object = contentProvider.item(at: indexPath) as? NSObject else { return UITableViewAutomaticDimension }
        guard let h = cellSizeCalculator.heightForObject(with: object.objectId) else { return UITableViewAutomaticDimension }
        return h
    }
}

// MARK: - Layout

extension TableDisplayController {
    
    fileprivate func fitContentIfNecessary() {
        guard let tableView = tableView, let constraint = contentHeightConstraint else { return }
        if maxHeight == 0 {
            maxHeight = tableView.bounds.height
        }
        var height = tableView.contentSize.height
        if height > maxHeight {
            height = maxHeight
        }
        if let constraint = constraint as? AnimatedConstraint {
            constraint.animatedConstant = height
        } else {
            constraint.constant = height
        }
        tableView.isScrollEnabled = height < tableView.contentSize.height
        if tableView.isScrollEnabled {
            tableView.flashScrollIndicators()
        }
    }
    
    fileprivate func resetLayoutCache() {
        cellSizeCalculator.resetCache()
    }
    
    fileprivate func heightForObject(_ object: NSObject, at indexPath: IndexPath) -> CGFloat {
        let objectId = object.objectId
        if let h = cellSizeCalculator.heightForObject(with: objectId) {
            return h
        }
        if !cellSizeCalculator.checkIfObjectEnqueued(with: objectId) {
            let cellId = cellIdentifier(for: object, at: indexPath)
            let size = CGSize(width: tableView.bounds.width, height: tableView.rowHeight)
            guard let ct: ContentTableViewCell = cellTemplates[cellId] ?? UIView.loadNib(cellId, bundle: bundle, size: size) else {
                return UITableViewAutomaticDimension
            }
            guard let elements = ct.contentDisplayView?.resizingElements else {
                return UITableViewAutomaticDimension
            }
            configureCell(ct, object: object, indexPath: indexPath)
            cellTemplates[cellId] = ct
            cellSizeCalculator.enqueueElementsForCalculation(elements, with: objectId, fitSize: size)
        }
        return 0
    }
}

// MARK: - Identifiers

extension TableDisplayController {
    
    static let defaultCellIdentifier = "Cell"
    
    static let defaultSectionHeaderIdentifier = "Header"
    
    static let defaultSectionFooterIdentifier = "Footer"
    
    static let systemHeaderFooterIdentifier = "HeaderFooter"
    
    static let cellIdentifierKey = "\(#selector(getter: cellIdentifier))"
    
    static let searchCellIdentifierKey = "\(#selector(getter: searchCellIdentifier))"
}

// MARK: -

open class ContentTableViewCell: UITableViewCell, ContentDisplayProtocol {
    
    public fileprivate(set) var scheme: NSDictionary? {
        didSet {
            if oldValue == nil {
                contentDisplayView?.setup(scheme: scheme)
            }
        }
    }
    
    public internal(set) weak var widget: Widget? {
        didSet {
            if oldValue == nil {
                contentDisplayView?.widget = widget
            }
        }
    }
    
    @IBOutlet public var contentDisplayView: ContentDisplayView?
    
    public var content: Any? {
        didSet {
            configure()
        }
    }
    
    public func refresh(elements: [NSObject]? = nil) {
        contentDisplayView?.content = content
    }
    
    public func configure() {
        refresh()
    }
}
