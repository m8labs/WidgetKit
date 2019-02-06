//
// TableInfiniteScrollController.swift
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

open class TableInfiniteScrollController: TableDisplayController {
    
    @objc public var scrollUpThreshhold: CGFloat = 200
    
    @objc public var scrollDownThreshhold: CGFloat = 200
    
    fileprivate var handleDraggingAllowed = true
    
    fileprivate var lastContentOffset: CGFloat = 0.0
    
    fileprivate var infiniteScrollUp: (() -> Void)?
    
    fileprivate var infiniteScrollDown: (() -> Void)?
}

enum ScrollUpDownEdge : Int {
    case none, top, bottom
}

extension TableInfiniteScrollController {
    
    private class func reachedEdgeWithThreshhold(_ threshhold: CGFloat,
                                                 contentOffsetY: CGFloat,
                                                 contentInsetTop: CGFloat,
                                                 contentHeight: CGFloat,
                                                 viewHeight: CGFloat,
                                                 previousContentOffset: CGFloat) -> ScrollUpDownEdge {
        let scrollingUp = contentOffsetY < previousContentOffset
        let scrollingDown = contentOffsetY > previousContentOffset
        let normalContentOffsetY = contentOffsetY + contentInsetTop
        if (scrollingUp) {
            if (normalContentOffsetY <= threshhold) {
                return .top
            }
        }
        else if (scrollingDown) {
            let cHeight = contentHeight > viewHeight ? contentHeight : viewHeight
            let normalBottomOffset = cHeight - normalContentOffsetY - viewHeight + contentInsetTop
//            print("\nbottomOffset(\(normalBottomOffset)) = contentHeight(\(cHeight)) - contentOffset(\(normalContentOffsetY)) - viewHeight(\(viewHeight))\n")
            if (normalBottomOffset <= threshhold) {
                return .bottom
            }
        }
        return .none
    }
    
    func handleDraggingDecelerating(_ scrollView: UIScrollView) {
        guard handleDraggingAllowed else { return }
        if scrollUpThreshhold > 0 {
            let edge = TableInfiniteScrollController.reachedEdgeWithThreshhold(scrollUpThreshhold,
                                                                        contentOffsetY: scrollView.contentOffset.y,
                                                                        contentInsetTop: scrollView.contentInset.top,
                                                                        contentHeight: scrollView.contentSize.height,
                                                                        viewHeight: scrollView.frame.size.height,
                                                                        previousContentOffset: lastContentOffset)
            if edge == .top {
                infiniteScrollUp?()
            }
        }
        if scrollDownThreshhold > 0 {
            let edge = TableInfiniteScrollController.reachedEdgeWithThreshhold(scrollDownThreshhold,
                                                                        contentOffsetY: scrollView.contentOffset.y,
                                                                        contentInsetTop: scrollView.contentInset.top,
                                                                        contentHeight: scrollView.contentSize.height,
                                                                        viewHeight: scrollView.frame.size.height,
                                                                        previousContentOffset: lastContentOffset)
            if edge == .bottom {
                infiniteScrollDown?()
            }
        }
        handleDraggingAllowed = false
        after(0.25) { self.handleDraggingAllowed = true }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isDragging || scrollView.isDecelerating {
            handleDraggingDecelerating(scrollView)
        }
        lastContentOffset = scrollView.contentOffset.y
    }
}

public class InfiniteScrollActionController: ActionController {
    
    @objc public var trackScrollDown = true
    
    var contentController: TableInfiniteScrollController? {
        return (sender as? UITableView)?.dataSource as? TableInfiniteScrollController
    }
    
    public override var params: Any? {
        return trackScrollDown ? contentController?.contentProvider.last() : contentController?.contentProvider.first()
    }
    
    public override func performAction(with object: Any? = nil) {
        if let searchController = contentController?.searchController, searchController.isSearching {
            searchController.performAction()
        } else {
            super.performAction()
        }
    }
    
    public override func setup() {
        super.setup()
        if trackScrollDown {
            contentController?.infiniteScrollDown = { [weak self] in
                guard let this = self else { return }
                if !this.status.inProgress {
                    this.performAction()
                }
            }
        } else {
            contentController?.infiniteScrollUp = { [weak self] in
                guard let this = self else { return }
                if !this.status.inProgress {
                    this.performAction()
                }
            }
        }
    }
}
