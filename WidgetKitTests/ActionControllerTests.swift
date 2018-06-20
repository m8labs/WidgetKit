//
//  ActionControllerTests.swift
//  WidgetKit
//
//  Created by Marat on 19/05/2018.
//  Copyright © 2018 Favio Mobile. All rights reserved.
//

import XCTest
import CoreData
@testable import WidgetKit

class ActionControllerTests: XCTestCase {
    
    class ActionTestDelegate: NSObject {
        
        var testActionCalled = false
        var altActionCalled = false
        
        var actionObject: Any?
        var actionSender: NSObject?
        
        @objc func testAction(_ object: Any?, sender: NSObject?) {
            actionObject = object
            actionSender = sender
            testActionCalled = true
            print("testAction called!")
        }
        
        @objc func altAction(_ object: Any?, sender: NSObject?) {
            actionObject = object
            actionSender = sender
            altActionCalled = true
            print("altAction called!")
        }
    }
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testActionControllerPredicateFormat() {
        let ac = ActionController()
        let target = ActionTestDelegate()
        let vars = ObjectsDictionaryProxy()
        vars.setValue(["field1": "value1"], forKey: "object1")
        ac.vars = vars
        ac.target = target
        ac.actionName = "testAction"
        ac.elseActionName = "altAction"
        ac.predicateFormat = "object1.field1 == 'value1'"
        ac.performAction()
        XCTAssertTrue(target.testActionCalled, "'testActionCalled' should be equal to true")
        ac.predicateFormat = "object1.field1 == 'value2'"
        ac.performAction()
        XCTAssertTrue(target.altActionCalled, "'altActionCalled' should be equal to true")
    }
    
    func testActionControllerForm() {
        let ac = ButtonActionController()
        let target = ActionTestDelegate()
        let form = FormDisplayView(frame: CGRect.zero)
        let textField1 = UITextField(frame: CGRect.zero)
        textField1.text = "text 1"
        textField1.wx_fieldName = "field1"
        let textField2 = UITextField(frame: CGRect.zero)
        textField2.text = "text 2"
        textField2.wx_fieldName = "field2"
        form.mandatoryFields = [textField1, textField2]
        let sender = UIButton(type: .system)
        ac.target = target
        ac.form = form
        ac.sender = sender
        ac.actionName = "testAction"
        ac.performAction()
        XCTAssertEqual(sender, target.actionSender, "'sender' should not be ignored")
        XCTAssertNotNil(target.actionObject as? [String: Any], "target.actionObject should be a dictionary")
        let d = target.actionObject as! [String: Any]
        XCTAssertEqual(d["field1"] as? String, "text 1", "'field1' should not be equal to 'text 1'")
        XCTAssertEqual(d["field2"] as? String, "text 2", "'field2' should not be equal to 'text 2'")
    }
    
    func testActionStatusController() {
        let sp = StubServiceProvider()
        sp.widget = Widget(identifier: "test", bundle: Bundle(for: type(of: self)), rootViewController: UIViewController())
        let ac = ActionController()
        ac.actionName = "testAction"
        ac.serviceProvider = sp
        let sender = UIButton(type: .system)
        ac.sender = sender
        ac.performAction()
        expectation(forNotification: ac.actionName.notification.onSuccess, object: sender) { n in
            if ac.status!.isSuccess, let objects = n.userInfo?[Notification.objectKey] as? [Item] {
                return objects.count == 3
            }
            return false
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
}
