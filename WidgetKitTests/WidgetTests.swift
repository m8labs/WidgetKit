//
//  BundleTests.swift
//  WidgetKit
//
//  Created by Marat on 22/05/2018.
//  Copyright © 2018 Favio Mobile. All rights reserved.
//

import XCTest
import UIKit
import CoreData
@testable import WidgetKit

class BundleTests: XCTestCase {
    
    let bundleIdentifier = "mobi.favio.WidgetDemo"
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testLoadBundle() {
        let testBundle = Bundle(for: type(of: self))
        let path = testBundle.url(forResource: "WidgetDemo", withExtension: "bundle")
        XCTAssertNotNil(path)
        continueAfterFailure = false
        let widget = Widget.loadBundle(with: bundleIdentifier, path: path!)
        XCTAssertNotNil(widget)
        XCTAssertNotNil(widget!.bundleIdentifier)
        XCTAssertNotNil(widget!.persistentContainer)
        XCTAssertNotNil(widget!.rootViewController.storyboard?.widget)
    }
    
    func testLoadArchive() {
        let testBundle = Bundle(for: type(of: self))
        let archivePath = testBundle.url(forResource: "WidgetDemo", withExtension: "zip")!
        let ex = expectation(description: "Load archive")
        Widget.loadArchive(with: self.bundleIdentifier, path: archivePath) { widget, error in
            if error != nil {
                XCTFail("Failed loading archive")
            } else {
                ex.fulfill()
            }
        }
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testWidgetView() {
        let testBundle = Bundle(for: type(of: self))
        let path = testBundle.url(forResource: "WidgetDemo", withExtension: "bundle")!
        let wv = WidgetView(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 100, height: 150)))
        wv.widgetIdentifier = bundleIdentifier
        wv.load(bundle: path)
        continueAfterFailure = false
        XCTAssert(wv.widget != nil)
        wv.layoutIfNeeded()
        wv.run()
        XCTAssert(wv.frame.contains(wv.widget!.rootViewController.view.frame))
    }
}
