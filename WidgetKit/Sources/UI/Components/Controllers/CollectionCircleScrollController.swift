//
// CollectionCircleScrollController.swift
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

open class CollectionCircleScrollController: CollectionPageScrollController {
    
    @objc public var circleScrollFactor = 100
    
    open override func renderContent(from source: ContentProviderProtocol?) {
        super.renderContent(from: source)
        setInitialContentOffset()
    }
}

extension CollectionCircleScrollController {
    
    func setInitialContentOffset() {
        let count = contentProvider.totalCount()
        collectionView?.contentOffset = CGPoint(x: (collectionView?.contentInset.left ?? 0) + CGFloat((circleScrollFactor / 2) * count) * itemSize.width, y: 0)
    }
}

extension CollectionCircleScrollController {
    
    public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let count = contentProvider.itemsCountInSection(section)
        pageControl?.numberOfPages = section == 0 ? count : 0
        return count * (section == 0 ? circleScrollFactor : 1)
    }
    
    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let indexPath = indexPath.section == 0 && circleScrollFactor > 1 ? IndexPath(item: indexPath.item % contentProvider.itemsCountInSection(0), section: 0) : indexPath
        let object = contentProvider.item(at: indexPath)!
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: dynamicCellIdentifier?(object, indexPath) ?? (cellIdentifier ?? CollectionDisplayController.defaultCellIdentifier), for: indexPath)
        assert(cell is ContentCollectionViewCell, "Cell must be of '\(ContentCollectionViewCell.self)' type.")
        configureCell(cell as! ContentCollectionViewCell, object: object, indexPath: indexPath)
        return cell
    }
}
