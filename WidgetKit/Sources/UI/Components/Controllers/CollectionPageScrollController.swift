//
// CollectionPageScrollController.swift
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

open class CollectionPageScrollController: CollectionDisplayController {
    
    private var currentPage: Int = 0
    
    @IBOutlet var pageControl: UIPageControl?
    
    @objc public var pagingEnabled = true
    
    public var pageChanged: ((ContentCollectionViewCell, Any, IndexPath) -> Void)?
    
    open override func setup() {
        super.setup()
        collectionView?.decelerationRate = UIScrollViewDecelerationRateFast
    }
}

extension CollectionPageScrollController {
    
    public func nextPage(animated: Bool = true) {
        let contentOffset = collectionView!.contentOffset
        let nextPage = CGFloat(currentPage + 1)
        collectionView.setContentOffset(CGPoint(x: CGFloat(nextPage * itemSize.width), y: contentOffset.y), animated: animated)
    }
    
    public func scrollToPage(_ page: Int, animated: Bool = false) {
        let contentOffset = collectionView!.contentOffset
        let nextPage = CGFloat(page)
        collectionView.setContentOffset(CGPoint(x: CGFloat(nextPage * itemSize.width), y: contentOffset.y), animated: animated)
    }
}

extension CollectionPageScrollController {
    
    open override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let count = contentProvider.itemsCountInSection(section)
        pageControl?.numberOfPages = section == 0 ? count : 0
        return count
    }
}

extension CollectionPageScrollController {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let width = itemSize.width
        let newPage = Int(floor((collectionView!.contentOffset.x - width / 2) / width)) + 1
        guard newPage != currentPage else {
            return
        }
        currentPage = newPage
        pageControl?.currentPage = currentPage
        if let pageChanged = pageChanged {
            let indexPath = IndexPath(item: currentPage, section: 0)
            if let cell = collectionView.cellForItem(at: indexPath) as? ContentCollectionViewCell, let item = contentProvider.item(at: indexPath) {
                pageChanged(cell, item, indexPath)
            }
        }
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        let width = itemSize.width
        currentPage = Int(floor((collectionView!.contentOffset.x - width / 2) / width)) + 1;
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard pagingEnabled && !scrollView.isPagingEnabled else { return }
        let width = itemSize.width
        var newPage = CGFloat(0)
        if velocity.x == 0 {
            newPage = floor((targetContentOffset.pointee.x - width / 2) / width) + 1;
        } else {
            newPage = CGFloat(velocity.x > 0 ? currentPage + 1 : currentPage - 1)
            if newPage < 0 {
                newPage = 0
            }
            if newPage > (scrollView.contentSize.width / width) {
                newPage = ceil(scrollView.contentSize.width / width) - 1.0;
            }
        }
        let point = CGPoint(x: CGFloat(newPage * width), y: targetContentOffset.pointee.y)
        targetContentOffset.pointee = point
    }
}
