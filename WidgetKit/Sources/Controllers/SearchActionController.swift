//
// SearchActionController.swift
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

public class SearchActionController: ActionController {
    
    @IBOutlet public weak var contentProvider: BaseContentProvider?
    
    var searchBar: UISearchBar? { return sender as? UISearchBar }
    
    public var textInput: TextInputView? {
        get {
            return sender as? TextInputView
        }
        set {
            sender = newValue
            setupTextInput()
        }
    }
    
    public var searchText: String! {
        get {
            return (textInput?.text ?? searchBar?.text) ?? ""
        }
        set {
            searchBar?.text = newValue
            textInput?.text = newValue
            performSearch()
        }
    }
    
    open override var content: Any? {
        return [TextInputView.inputFieldName: searchText ?? ""]
    }
    
    @objc public var filterFormat: String?
    
    public var isSearching: Bool {
        return actionName != nil && (searchText?.count ?? 0) > 0
    }
    
    @objc public var dynamicSearch = false
    
    @objc public var searchOnReturn = true
    
    @objc public var minimumTextLength = 1
    
    @objc public var filterThrottleInterval = 0.5
    
    @objc public var actionThrottleInterval = 0.5 {
        didSet { actionDelay = 0 }
    }
    
    public func releaseKeyboard() {
        searchBar?.resignFirstResponder()
        textInput?.releaseKeyboard()
    }
    
    public func resetSearch() {
        searchBar?.text = ""
        textInput?.text = ""
        contentProvider?.reset()
    }
    
    var canSearch: Bool {
        return (searchText?.count ?? 0) >= minimumTextLength
    }
    
    @objc func _filter() {
        contentProvider!.filterFormat = filterFormat
        contentProvider!.searchString = searchText
    }
    
    @objc func _performAction() {
        guard actionName != nil, canSearch else { return }
        super.performAction()
    }
    
    func _performSearch() {
        _filter()
        _performAction()
    }
    
    func filter() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(_filter), object: nil)
        perform(#selector(_filter), with: nil, afterDelay: filterThrottleInterval)
    }
    
    public override func performAction() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(_performAction), object: nil)
        perform(#selector(_performAction), with: nil, afterDelay: actionThrottleInterval)
    }
    
    public func performSearch() {
        filter()
        performAction()
    }
    
    func setupTextInput() {
        textInput?.textTyped.append { [weak self] _ in
            if self?.dynamicSearch ?? false {
                self?.performSearch()
            }
        }
        textInput?.textCleared.append { [weak self] in
            self?.resetSearch()
        }
        textInput?.returnPressed.append { [weak self] _ in
            if self?.searchOnReturn ?? false {
                self?.performSearch()
            }
        }
    }
    
    public override func setup() {
        searchBar?.delegate = self
        setupTextInput()
        super.setup()
    }
}

extension SearchActionController: UISearchBarDelegate {
    
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        performSearch()
    }
    
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(_filter), object: nil)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(_performAction), object: nil)
        _performSearch()
    }
    
    public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        viewController.navigationController?.setNavigationBarHidden(true, animated: true)
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    public func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        viewController.navigationController?.setNavigationBarHidden(false, animated: true)
        searchBar.setShowsCancelButton(false, animated: true)
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
    }
    
    public func searchBarBookmarkButtonClicked(_ searchBar: UISearchBar) {
        //
    }
    
    public func searchBarResultsListButtonClicked(_ searchBar: UISearchBar) {
        //
    }
    
    public func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        //
    }
}
