//
//  ContentProviderTests.swift
//  WidgetKit
//
//  Created by Marat on 16/05/2018.
//  Copyright © 2018 Favio Mobile. All rights reserved.
//

import XCTest
import CoreData
@testable import WidgetKit

extension NSManagedObjectModel {
    
    static var testModel: NSManagedObjectModel {
        let bundle = Bundle(for: Item.self)
        return NSManagedObjectModel.mergedModel(from: [bundle])!
    }
}

class ContentProviderTests: XCTestCase {
    
    let items = [
        ["id": 1, "name": "item1"],
        ["id": 2, "name": "item2"],
        ["id": 3, "name": "item3"],
        ["id": 4, "name": "item4"],
        ["id": 5, "name": "item5"]
        ]
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testSectionCount() {
        let content = BaseContentProvider()
        content.items = items
        XCTAssertEqual(content.sectionsCount, 1)
    }
    
    func testResultChain() {
        let content = BaseContentProvider()
        content.items = items
        content.resultChain = ["wx_takeLast:", "wx_map:", "wx_joinedBy:"]
        content.resultChainArgs = ["2", "name", ", "]
        let result = content.value as? String
        XCTAssertEqual("item4, item5", result)
    }
    
    func testResultChainWithEmptyArray() {
        let content = BaseContentProvider()
        content.items = []
        content.resultChain = ["wx_takeFirst:"]
        content.resultChainArgs = ["1"]
        let result = content.value as? String
        XCTAssertNil(result)
    }
    
    func testMasterObject() {
        let collection = ItemsCollection()
        collection.masterKeyPath = "items"
        collection.masterObject = self
        collection.fetch()
        XCTAssertEqual(collection.allItems.count, items.count)
    }
}

class ManagedObjectsProviderTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    var content: ManagedObjectsProvider!
    
    var item1: Item!
    var item2: Item!
    var category: Category!
    
    override func setUp() {
        super.setUp()
        context = NSPersistentContainer.containerForModel(NSManagedObjectModel.testModel).viewContext
        ValueTransformer.setDefaultTransformers()
        category = Category.create(context: context) as! Category
        category.title = "Category 1"
        item1 = Item.create(context: context) as! Item
        item1.identifier = 1
        item1.name = "test 1"
        item1.groupTitle = "G1"
        item2 = Item.create(context: context) as! Item
        item2.identifier = 2
        item2.name = "test 2"
        item2.groupTitle = "G1"
        content = ManagedObjectsProvider()
        content.entityName = "\(Item.self)"
        content.managedObjectContext = context
    }
    
    override func tearDown() {
        super.tearDown()
        category = nil
        item1 = nil
        item2 = nil
        context = nil
        content = nil
    }
    
    func testSortByFields() {
        content.sortByFields = "name"
        content.fetch()
        XCTAssertEqual("test 1", (content.first() as? Item)?.name)
    }
    
    func testSortByFieldsDescending() {
        content.sortByFields = "name"
        content.sortAscending = false
        content.fetch()
        XCTAssertEqual("test 2", (content.first() as! Item).name)
    }
    
    func testPredicateFormat() {
        let item = Item.create(context: context) as! Item
        item.identifier = 3
        item.name = "sample"
        item.category = category
        content.predicateFormat = "category != nil"
        content.fetch()
        XCTAssertEqual("sample", (content.first() as! Item).name)
    }
    
    func testFilterFormat() {
        let item = Item.create(context: context) as! Item
        item.identifier = 3
        item.name = "sample"
        content.filterFormat = "name BEGINSWITH[c] $input"
        content.searchString = "sam"
        content.fetch()
        XCTAssertEqual("sample", (content.first() as! Item).name)
        content.searchString = "test"
        content.fetch()
        XCTAssertEqual((content.first() as! Item).name!.hasPrefix(content.searchString!), true)
    }
    
    func testMasterObject() {
        content.masterObject = Category.all(context: context).first
        content.masterKeyPath = "category"
        item1.category = category
        content.fetch()
        XCTAssertEqual(1, content.allItems.count)
        XCTAssertEqual("test 1", (content.first() as! Item).name)
        item2.category = category
        content.fetch()
        XCTAssertEqual(2, content.allItems.count)
    }
    
    func testGroupByField() {
        let item = Item.create(context: context) as! Item
        item.identifier = 3
        item.groupTitle = "G2"
        content.groupByField = "groupTitle"
        content.fetch()
        XCTAssertEqual(content.sectionsCount, 2)
    }
}
