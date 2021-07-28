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

protocol InfiniteScrollable {
    
    var infiniteScrollUpAction: ScrollActionController? { get set }
    
    var infiniteScrollDownAction: ScrollActionController? { get set }
    
    var actionTriggerThreshhold: CGFloat { get set }
}

class InfiniteScrollHelper {
    
    var handleDraggingAllowed = true
    
    var lastContentOffset: CGFloat?
    
    var scrollable: InfiniteScrollable & BaseDisplayController
    
    init(scrollable: InfiniteScrollable & BaseDisplayController) {
        self.scrollable = scrollable
    }
    
    func pauseTracking() {
        handleDraggingAllowed = false
        after(0.25) { [weak self] in
            self?.handleDraggingAllowed = true
        }
    }
    
    func handleDraggingDecelerating(_ scrollView: UIScrollView) {
        
        guard handleDraggingAllowed, scrollable.actionTriggerThreshhold > 0, let lastContentOffset = lastContentOffset else { return }
        
        let edge = scrollView.scrolledToVerticalEdge(threshhold: scrollable.actionTriggerThreshhold,
                                                     previousContentOffset: lastContentOffset)
        if edge == .top {
            if let searchController = scrollable.searchController, searchController.isSearching, !searchController.status.inProgress {
                searchController.performAction(with: scrollable.contentProvider.first())
                pauseTracking()
            }
            else if let infiniteScrollUpAction = scrollable.infiniteScrollUpAction, !infiniteScrollUpAction.status.inProgress {
                infiniteScrollUpAction.performAction(with: scrollable.contentProvider.first())
                pauseTracking()
            }
            scrollable.infiniteScrollDownAction?.resetInfiniteLoading()
        }
        else if edge == .bottom {
            if let searchController = scrollable.searchController, searchController.isSearching, !searchController.status.inProgress {
                searchController.performAction(with: scrollable.contentProvider.last())
                pauseTracking()
            }
            else if let infiniteScrollDownAction = scrollable.infiniteScrollDownAction, !infiniteScrollDownAction.status.inProgress {
                infiniteScrollDownAction.performAction(with: scrollable.contentProvider.last())
                pauseTracking()
            }
            scrollable.infiniteScrollUpAction?.resetInfiniteLoading()
        }
    }
}

extension UIScrollView {
    
    enum VerticalEdge : Int {
        case none, top, bottom
    }
    
    func scrolledToVerticalEdge(threshhold: CGFloat, previousContentOffset: CGFloat) -> VerticalEdge {
        guard contentSize.height > frame.size.height else {
            return .none
        }
        let scrollingUp = contentOffset.y < previousContentOffset
        let scrollingDown = contentOffset.y > previousContentOffset
        let normalContentOffsetY = contentOffset.y + contentInset.top
        if (scrollingUp) {
            if (normalContentOffsetY <= threshhold) {
                return .top
            }
        }
        else if (scrollingDown) {
            let cHeight = contentSize.height > frame.size.height ? contentSize.height : frame.size.height
            let normalBottomOffset = cHeight - normalContentOffsetY - frame.size.height + contentInset.top
            if (normalBottomOffset <= threshhold) {
                return .bottom
            }
        }
        return .none
    }
}

open class ScrollActionController: ActionController {
    
    open private(set) var shouldStopInfiniteLoading = false
    
    open override func statusChanged(_ status: ActionStatusController, args: ActionArgs?, result: Any?, error: Error?) {
        guard let resultArray = result as? [Any] else { return }
        shouldStopInfiniteLoading = resultArray.count == 0
    }
    
    open override func performAction(with object: Any?) {
        guard !shouldStopInfiniteLoading else { return print("\(Self.self): call resetInfiniteLoading for unlock this action.") }
        super.performAction(with: object)
    }
    
    public func resetInfiniteLoading() {
        shouldStopInfiniteLoading = false
    }
}

open class TableInfiniteScrollController: TableDisplayController, InfiniteScrollable {
    
    @IBOutlet public var infiniteScrollUpAction: ScrollActionController?
    
    @IBOutlet public var infiniteScrollDownAction: ScrollActionController?
    
    @objc public var actionTriggerThreshhold: CGFloat = 200
    
    private lazy var infiniteScrollHelper = InfiniteScrollHelper(scrollable: self)
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isDragging || scrollView.isDecelerating {
            infiniteScrollHelper.handleDraggingDecelerating(scrollView)
        }
        infiniteScrollHelper.lastContentOffset = scrollView.contentOffset.y
    }
}
