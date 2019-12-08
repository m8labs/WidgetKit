//
// CollectionDisplayController.swift
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

open class CollectionDisplayController: BaseDisplayController {
    
    @objc public var cellIdentifier: String?
    
    @objc public var searchCellIdentifier: String?
    
    @objc public var handleSelection = false
    
    @objc public var centerContent = false
    
    @objc public var cellNibNames: String?
    
    public var cellSelected: ((ContentCollectionViewCell, Any, IndexPath) -> Void)?
    
    public var cellDeselected: ((ContentCollectionViewCell, Any, IndexPath) -> Void)?
    
    @objc public var cellWidthHint: CGFloat = -1
    
    @objc public var cellHeightHint: CGFloat = -1
    
    @objc public var cellAspectRatio: CGFloat = -1
    
    @IBOutlet public var collectionView: UICollectionView! {
        get {
            guard let view = elements?.first as? UICollectionView else {
                preconditionFailure("\(CollectionDisplayController.self) should be connected to UICollectionView.")
            }
            return view
        }
        set {
            elements = [newValue]
        }
    }
    
    @IBOutlet public var emptyDataView: UIView?
    
    public private(set) var selectedObjects = Set<NSObject>()
    
    fileprivate var cachedItemSize: CGSize?
    
    fileprivate var vars: ObjectsDictionaryProxy!
    
    func registerCellNibs() {
        (cellNibNames ?? "").components(separatedBy: CharacterSet(charactersIn: ", ")).forEach { nibName in
            let nib = UINib(nibName: nibName, bundle: bundle)
            collectionView.register(nib, forCellWithReuseIdentifier: nibName)
        }
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
        return (isSearching && searchCellIdentifier != nil ? searchCellIdentifier : cellIdentifier) ?? type(of: self).defaultCellIdentifier
    }
    
    open func configureCell(_ cell: ContentCollectionViewCell, object: Any, indexPath: IndexPath) {
        if let contentView = cell.contentDisplayView {
            contentView.widget = widget
            contentView.scheme = viewController?.scheme
        }
        cell.content = object
    }
    
    open override func renderContent(from source: ContentProviderProtocol?) {
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
            if cellNibNames != nil {
                registerCellNibs()
            }
        }
        super.setup()
    }
    
    open override func prepare() -> [CustomIBObject] {
        let prepared = super.prepare()
        vars = ObjectsDictionaryProxy(copy: viewController!.vars)
        return prepared
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
    
    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        emptyDataView?.isHidden = !contentProvider.isEmpty
        return contentProvider.sectionsCount
    }
    
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let count = contentProvider.itemsCountInSection(section)
        return count
    }
    
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let object = contentProvider.item(at: indexPath) else { preconditionFailure("Cell's object should not be nil.") }
        let cellId = cellIdentifier(for: object, at: indexPath)
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as? ContentCollectionViewCell else {
            preconditionFailure("Cell must be of '\(ContentCollectionViewCell.self)' type.")
        }
        configureCell(cell, object: object, indexPath: indexPath)
        return cell
    }
}

// MARK: -

extension CollectionDisplayController: UICollectionViewDelegate {
    
    // Object selection handling
    
    private func handleSelectionForCell(_ cell: UICollectionViewCell, object: NSObject, at indexPath: IndexPath) {
        if selectedObjects.contains(object) {
            handleDeselectionForCell(cell, object: object, at: indexPath)
        } else {
            if !collectionView.allowsMultipleSelection {
                selectedObjects.removeAll()
            }
            selectedObjects.insert(object)
            cell.isSelected = true
        }
    }
    
    private func handleDeselectionForCell(_ cell: UICollectionViewCell, object: NSObject, at indexPath: IndexPath) {
        selectedObjects.remove(object)
        cell.isSelected = false
    }
    
    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ContentCollectionViewCell else { return }
        guard let object = contentProvider.item(at: indexPath) as? NSObject else { return }
        if handleSelection {
            handleSelectionForCell(cell, object: object, at: indexPath)
        }
        cellSelected?(cell, object, indexPath)
        collectionView.reloadData()
    }
    
    open func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ContentCollectionViewCell else { return }
        guard let object = contentProvider.item(at: indexPath) as? NSObject else { return }
        if handleSelection {
            handleDeselectionForCell(cell, object: object, at: indexPath)
        }
        cellDeselected?(cell, object, indexPath)
        collectionView.reloadData()
    }
    
    open func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard handleSelection, let object = contentProvider.item(at: indexPath) as? NSObject else { return }
        let isSelected = selectedObjects.contains(object)
        cell.isSelected = isSelected
    }
    
    open func selectObjects(_ objects: [NSObject]) {
        selectedObjects.removeAll()
        objects.forEach { object in
            selectedObjects.insert(object)
        }
        collectionView?.reloadData()
    }
}

// MARK: - Cell Sizing

extension CollectionDisplayController: UICollectionViewDelegateFlowLayout {
    
    var itemSize: CGSize {
        if cachedItemSize == nil {
            let flowLayout = collectionView!.collectionViewLayout as? UICollectionViewFlowLayout
            var width = collectionView!.bounds.width
            var height = collectionView!.bounds.height
            let vSpacing = flowLayout?.minimumInteritemSpacing ?? 0
            let hSpacing = flowLayout?.minimumLineSpacing ?? 0
            if cellWidthHint > 0 {
                if cellWidthHint <= 1 {
                    let hNumber = 1.0 / cellWidthHint
                    width = (collectionView!.bounds.width - vSpacing * (hNumber - 1)) * cellWidthHint
                } else {
                    width = cellWidthHint
                }
            } else if flowLayout != nil {
                width = flowLayout!.itemSize.width
            }
            if cellHeightHint > 0 {
                if cellHeightHint <= 1 {
                    let vNumber = 1.0 / cellHeightHint
                    height = (collectionView!.bounds.height - hSpacing * (vNumber - 1)) * cellHeightHint
                } else {
                    height = cellHeightHint
                }
            } else if flowLayout != nil {
                height = flowLayout!.itemSize.height
            }
            if flowLayout != nil, cellAspectRatio > 0 {
                if flowLayout!.scrollDirection == .vertical {
                    height = width * cellAspectRatio
                } else {
                    width = height * cellAspectRatio
                }
            }
            cachedItemSize = CGSize(width: width, height: height)
        }
        return cachedItemSize!
    }
    
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
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

open class ContentCollectionViewCell: UICollectionViewCell, ContentAwareProtocol {
    
    public var contentDisplayView: ContentDisplayView? {
        contentView as? ContentDisplayView ?? contentView.subviews.first as? ContentDisplayView
    }
    
    open var content: Any? {
        didSet {
            contentDisplayView?.content = content
        }
    }
}
