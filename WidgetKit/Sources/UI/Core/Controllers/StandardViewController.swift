//
// StandardViewController.swift
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

open class StandardViewController: ContentViewController {
    
    @IBOutlet public var tableView: UITableView?
    @IBOutlet public var collectionView: UICollectionView?
    
    @IBOutlet public var titleLabel: UILabel?
    @IBOutlet public var activityIndicator: UIActivityIndicatorView?
    
    @objc public var clearsSelectionOnViewWillAppear = true
    
    public var tableController: TableDisplayController? {
        return tableView?.dataSource as? TableDisplayController
    }
    
    public var collectionController: CollectionDisplayController? {
        return collectionView?.dataSource as? CollectionDisplayController
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let indexPath = tableView?.indexPathForSelectedRow, clearsSelectionOnViewWillAppear {
            tableView!.deselectRow(at: indexPath, animated: true)
        }
    }
}

public class ContentWrapper: ContentAwareProtocol {
    
    public var content: Any?
    
    public init(content: Any?) {
        self.content = content
    }
}

extension StandardViewController {
    
    func performNext(from sender: Any? = nil) {
        performSegue(withIdentifier: "Next", sender: sender)
    }
    
    func performNext(with object: Any?) {
        performSegue(withIdentifier: "Next", sender: ContentWrapper(content: object))
    }
    
    @IBAction func nextAction(_ sender: Any?) {
        performNext(from: sender)
    }
}

public class UINavigationItemTitleView: UIView {
    
    public override var intrinsicContentSize: CGSize {
        return UILayoutFittingExpandedSize
    }
}
