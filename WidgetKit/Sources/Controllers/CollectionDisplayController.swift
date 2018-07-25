//
// CollectionDisplayController.swift
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
import CoreData

open class CollectionDisplayController: BaseDisplayController {
    
    @objc public var cellIdentifier: String?
    
    @objc public var searchCellIdentifier: String?
    
    @objc public var performSegueForCells = -1
    
    @objc public var collectSelectedObjects = false
    
    @objc public var centerContent = false
    
    public var dynamicCellIdentifier: ((Any, IndexPath) -> String?)?
    
    public var cellSelected: ((ContentCollectionViewCell, Any, IndexPath) -> Void)?
    
    public var cellDeselected: ((ContentCollectionViewCell, Any, IndexPath) -> Void)?
    
    @objc public var cellWidthHint: CGFloat = -1
    
    @objc public var cellHeightHint: CGFloat = -1
    
    @IBOutlet var collectionView: UICollectionView! {
        get { return elements?.first as! UICollectionView }
        set { elements = [newValue] }
    }
    
    @IBOutlet public var emptyDataView: UIView?
    
    public private(set) var selectedObjectsIDs = NSMutableArray()
    
    public var selectedObjects: [Any] {
        return contentProvider.allItems.filter { a in
            if let objectId = (a as? NSObject)?.objectId {
                return selectedObjectsIDs.contains(objectId)
            }
            return false
        }
    }
    
    fileprivate var cachedItemSize: CGSize?
    
    fileprivate var vars: ObjectsDictionaryProxy!
    
    open func cellIdentifier(for object: Any, at indexPath: IndexPath) -> String {
        vars.setValue(object, forKey: ObjectsDictionaryProxy.contentKey)
        var cellId = ""
        let key = (searchController?.isSearching ?? false) ? type(of: self).searchCellIdentifierKey : type(of: self).cellIdentifierKey
        if let eval = wx.evals[key] ?? wx.evals[type(of: self).cellIdentifierKey] {
            cellId = eval.perform(with: vars) as! String
        } else {
            cellId = dynamicCellIdentifier?(object, indexPath) ?? (cellIdentifier ?? type(of: self).defaultCellIdentifier)
        }
        return cellId
    }
    
    open func configureCell(_ cell: ContentCollectionViewCell, object: Any, indexPath: IndexPath) {
        cell.widget = widget
        cell.scheme = viewController.scheme
        cell.content = object
    }
    
    open override func renderContent(from source: ContentProviderProtocol? = nil) {
        collectionView?.reloadData()
        if centerContent {
            alignToCenter()
        }
    }
    
    open override func setup() {
        if let collectionView = self.collectionView {
            collectionView.dataSource = self
            if collectionView.delegate == nil {
                collectionView.delegate = self
            }
        }
        super.setup()
    }
    
    open override func prepare() {
        super.prepare()
        vars = ObjectsDictionaryProxy(copy: viewController.vars)
    }
}

extension CollectionDisplayController {
    
    func alignToCenter() {
        if collectionView.contentSize.width < collectionView.bounds.width {
            collectionView.contentInset = UIEdgeInsets(top: 0, left: (collectionView.bounds.width - collectionView.contentSize.width) / 2, bottom: 0, right: 0)
        }
    }
}

// MARK: -

extension CollectionDisplayController: UICollectionViewDataSource {
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        emptyDataView?.isHidden = !contentProvider.isEmpty
        return contentProvider.sectionsCount
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let count = contentProvider.itemsCountInSection(section)
        return count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let object = contentProvider.item(at: indexPath) else { preconditionFailure("Cell object should not be nil.") }
        let cellId = cellIdentifier(for: object, at: indexPath)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath)
        precondition(cell is ContentCollectionViewCell, "Cell must be of '\(ContentCollectionViewCell.self)' type.")
        configureCell(cell as! ContentCollectionViewCell, object: object, indexPath: indexPath)
        return cell
    }
}

// MARK: -

extension CollectionDisplayController: UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? ContentCollectionViewCell {
            if performSegueForCells > 0 {
                viewController.performSegue(withIdentifier: cell.reuseIdentifier!, sender: cell)
            } else if let item = contentProvider.item(at: indexPath) {
                if collectSelectedObjects {
                    if let object = item as? NSObject {
                        if selectedObjectsIDs.contains(object.objectId) {
                            selectedObjectsIDs.remove(object.objectId)
                            collectionView.deselectItem(at: indexPath, animated: false)
                        } else {
                            if !collectionView.allowsMultipleSelection {
                                selectedObjectsIDs.removeAllObjects()
                            }
                            if !selectedObjectsIDs.contains(object.objectId) {
                                selectedObjectsIDs.add(object.objectId)
                            }
                        }
                    }
                }
                cellSelected?(cell, item, indexPath)
            }
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? ContentCollectionViewCell, let item = contentProvider.item(at: indexPath) {
            if let object = item as? NSObject {
                selectedObjectsIDs.remove(object.objectId)
            }
            cellDeselected?(cell, item, indexPath)
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let object = contentProvider.item(at: indexPath) as? NSObject  {
            let isSelected = selectedObjectsIDs.contains(object.objectId)
            cell.isSelected = isSelected
        }
    }
}

// MARK: - Cell Sizing

extension CollectionDisplayController: UICollectionViewDelegateFlowLayout {
    
    var itemSize: CGSize {
        if cachedItemSize == nil {
            let layout = collectionView!.collectionViewLayout as? UICollectionViewFlowLayout
            var width = layout?.itemSize.width ?? collectionView!.bounds.width
            var height = layout?.itemSize.height ?? collectionView!.bounds.height
            if cellWidthHint >= 0 {
                if cellWidthHint <= 1 {
                    width = collectionView!.bounds.width * cellWidthHint
                } else {
                    width = cellWidthHint
                }
            }
            if cellHeightHint >= 0 {
                if cellHeightHint <= 1 {
                    height = collectionView!.bounds.height * cellHeightHint
                } else {
                    height = cellHeightHint
                }
            }
            cachedItemSize = CGSize(width: width, height: height)
        }
        return cachedItemSize!
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return itemSize
    }
}

// MARK: - Identifiers

extension CollectionDisplayController {
    
    static let defaultCellIdentifier = "Cell"
    
    static let cellIdentifierKey = "\(#selector(getter: cellIdentifier))"
    
    static let searchCellIdentifierKey = "\(#selector(getter: searchCellIdentifier))"
}

// MARK: -

open class ContentCollectionViewCell: UICollectionViewCell, ContentDisplayProtocol {
    
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
    
    @IBOutlet var contentDisplayView: ContentDisplayView?
    
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
