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
    
    @objc public var handleSelection = false
    
    @objc public var defaultSelectionBehavior = false
    
    @objc public var performSegueForCells = -1
    
    public var cellSelected: ((ContentTableViewCell, Any, IndexPath) -> Void)?
    
    public var cellDeselected: ((ContentTableViewCell, Any, IndexPath) -> Void)?
    
    @IBOutlet public var tableView: UITableView! {
        get {
            guard let view = elements?.first as? UITableView else {
                preconditionFailure("\(TableDisplayController.self) should be connected to UITableView.")
            }
            return view
        }
        set {
            elements = [newValue]
        }
    }
    
    @IBOutlet var emptyDataView: UIView?
    
    @IBOutlet var contentHeightConstraint: NSLayoutConstraint?
    
    @IBOutlet var deleteController: ActionController?
    
    public private(set) var selectedObjects = Set<NSObject>()
    
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
    
    open func shouldDisplayObject(_ object: Any) -> Bool {
        if let managedObject = object as? NSManagedObject {
            return managedObject != objectToDelete
        }
        return true
    }
    
    open func cellIdentifier(for object: Any, at indexPath: IndexPath) -> String {
        let isSearching = searchController?.isSearching ?? false
        if let vars = vars {
            vars.setValue(object, forKey: ObjectsDictionaryProxy.contentKey)
            let key = isSearching ? type(of: self).searchCellIdentifierKey : type(of: self).cellIdentifierKey
            if let eval = wx.evals[key] ?? wx.evals[type(of: self).cellIdentifierKey] {
                return eval.perform(with: vars) as! String
            }
        }
        return (isSearching ? searchCellIdentifier : cellIdentifier) ?? type(of: self).defaultCellIdentifier
    }
    
    open func configureCell(_ cell: ContentTableViewCell, object: Any, indexPath: IndexPath) {
        cell.widget = widget
        cell.scheme = viewController?.scheme
        cell.content = object
    }
    
    open func configureSection(_ view: ContentDisplayView, object: Any?, section: Int) {
        if view.scheme == nil, let scheme = viewController?.scheme {
            view.widget = widget
            view.setup(scheme: scheme)
        }
        view.content = object
    }
    
    override open func renderContent(from source: ContentProviderProtocol?) {
        reloadData(animated: animateReload)
    }
    
    override open func prepareRenderContent(from source: ContentProviderProtocol?) {
//        tableView.beginUpdates()
    }
    
    override open func renderContent(_ content: Any, change: ContentChange, at indexPath: IndexPath, from source: ContentProviderProtocol?) {
        // This looks bad even with .none!
//        switch change {
//        case .insert:
//            tableView.insertRows(at: [indexPath], with: animateReload ? .automatic : .none)
//        case .delete:
//            tableView.deleteRows(at: [indexPath], with: animateReload ? .automatic : .none)
//        case .update:
//            tableView.reloadRows(at: [indexPath], with: animateReload ? .automatic : .none)
//        }
    }
    
    override open func finalizeRenderContent(from source: ContentProviderProtocol?) {
//        tableView.endUpdates()
        reloadData(animated: animateReload)
    }
    
    override open func setupObservers() {
        if let renderOn = renderOn {
            observers = [
                NSNotification.Name(rawValue: renderOn).subscribe { [weak self] _ in
                    self?.reloadData()
                }
            ]
        }
    }
    
    override open func setup() {
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
    
    override open func prepare() -> [CustomIBObject] {
        let prepared = super.prepare()
        vars = ObjectsDictionaryProxy(copy: viewController!.vars)
        return prepared
    }
}

// MARK: -

extension TableDisplayController: UITableViewDataSource {
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        let count = contentProvider.totalCount
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
    
    private func handleSelectionForCell(_ cell: UITableViewCell, object: NSObject, at indexPath: IndexPath) {
        if selectedObjects.contains(object) {
            handleDeselectionForCell(cell, object: object, at: indexPath)
        } else {
            if !tableView.allowsMultipleSelection {
                selectedObjects.removeAll()
            }
            selectedObjects.insert(object)
            if defaultSelectionBehavior {
                cell.accessoryType = .checkmark
            }
            cell.isSelected = true
        }
    }
    
    private func handleDeselectionForCell(_ cell: UITableViewCell, object: NSObject, at indexPath: IndexPath) {
        selectedObjects.remove(object)
        if defaultSelectionBehavior {
            cell.accessoryType = .none
        }
        cell.isSelected = false
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? ContentTableViewCell else { return }
        guard let object = contentProvider.item(at: indexPath) as? NSObject else { return }
        if cell.detailSegue != nil {
            cell.performDetailSegueWith(object)
        }
        if performSegueForCells > 0 && cell.reuseIdentifier != nil {
            viewController?.performSegue(withIdentifier: cell.reuseIdentifier!, sender: cell)
        } else {
            if handleSelection {
                handleSelectionForCell(cell, object: object, at: indexPath)
            }
            cellSelected?(cell, object, indexPath)
        }
    }
    
    open func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? ContentTableViewCell else { return }
        guard let object = contentProvider.item(at: indexPath) as? NSObject else { return }
        if handleSelection {
            handleDeselectionForCell(cell, object: object, at: indexPath)
        }
        cellDeselected?(cell, object, indexPath)
    }
    
    open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard handleSelection, let object = contentProvider.item(at: indexPath) as? NSObject else { return }
        let isSelected = selectedObjects.contains(object)
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
        guard let customView = cell?.contentView.subviews.first as? ContentDisplayView, let object = contentProvider.item(at: IndexPath(row: 0, section: section)) else {
            return nil
        }
        systemView!.backgroundView = customView
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
        deleteController?.performServiceAction(with: object)
        after(0.75) { // waiting for animation finished
            self.objectToDelete = nil
            object.delete()
        }
    }
    
    open func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        guard allowDeletion, let object = contentProvider.item(at: indexPath) as? NSManagedObject else { return .none }
        return object.isMine ? .delete : .none
    }
    
    // Cell Sizing
    
    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let object = contentProvider.item(at: indexPath), shouldDisplayObject(object) else { return 0 }
        return UITableViewAutomaticDimension
    }
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let identifier = sectionFooterIdentifier ?? type(of: self).defaultSectionFooterIdentifier
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
        let count = contentProvider.itemsCountInSection(section)
        return cell == nil || count == 0 ? 0 : tableView.sectionFooterHeight
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let identifier = sectionHeaderIdentifier ?? type(of: self).defaultSectionHeaderIdentifier
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
        let count = contentProvider.itemsCountInSection(section)
        return cell == nil || count == 0 ? 0 : tableView.sectionHeaderHeight
    }
    
    @available(iOS 13.0, *)
    @objc(tableView:contextMenuConfigurationForRowAtIndexPath:point:)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let object = contentProvider.item(at: indexPath) as? NSObject else { return nil }
        guard let viewController = self.viewController, let items = viewController.previewMenuItemsForObject(object) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            var actions = [UIAction]()
            for item in items {
                actions.append(UIAction(title: item.title, image: item.image, attributes: item.isDestructive ? .destructive : []) { _ in
                    item.handler()
                })
            }
            return UIMenu(title: viewController.previewMenuTitle, children: actions)
        }
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
    
    @objc public var detailSegue: String?
    @objc public var detailKeyPath: String?
    @objc public var detailSegueDelay = 0.0
    @objc public var performDetailSegueOnPresenter = false
    
    @objc public var detailActionName: String?
    @objc lazy var detailActionController = ActionController()
    
    private var viewController: ContentViewController {
        guard let vc = viewController() as? ContentViewController else {
            preconditionFailure("Invalid view controller type: \(ContentViewController.self) needed.")
        }
        return vc
    }
    
    fileprivate func performDetailSegueWith(_ masterObject: NSObject) {
        guard let detailSegue = detailSegue, let detailKeyPath = detailKeyPath else { return }
        if let detailObject = masterObject.value(forKeyPath: detailKeyPath) {
            if performDetailSegueOnPresenter, let presenter = viewController.previousViewController {
                viewController.close()
                after(detailSegueDelay) {
                    presenter.performSegue(withIdentifier: detailSegue, sender: ContentWrapper(content: detailObject))
                }
            } else {
                viewController.performSegue(withIdentifier: detailSegue, sender: ContentWrapper(content: detailObject))
            }
        } else if let detailActionName = self.detailActionName { // detailObject doesn't exist yet, so create it, if detailActionName != nil
            detailActionController.viewController = viewController
            detailActionController.actionName = detailActionName
            detailActionController.status.successSegue = detailSegue
            detailActionController.status.successSegueDelay = detailSegueDelay
            detailActionController.status.closeOnSuccess = performDetailSegueOnPresenter
            detailActionController.performAction(with: masterObject)
        }
    }
    
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
