//
//  BindingsTests.swift
//  WidgetKit
//
//  Created by Marat on 11/05/2018.
//  Copyright © 2018 Favio Mobile. All rights reserved.
//

import XCTest
@testable import WidgetKit

class EvaluationTests: XCTestCase {
    
    let eval = Evaluation()
    var value: Any?
    
    override func setUp() {
        eval.predicateFormat = "a = 5"
        super.setUp()
    }
    
    override func tearDown() {
        value = nil
        super.tearDown()
    }
    
    func testEvaluationPredicateFormat() {
        value = eval.perform(with: ["a": 5])
        XCTAssertEqual(value as? Bool, true)
        value = eval.perform(with: ["a": 6])
        XCTAssertNotEqual(value as? Bool, true)
    }
    
    func testEvaluationPredicateValueIfTrueOrFalse() {
        eval.valueIfTrue = "yo"
        eval.valueIfFalse = "pff"
        value = eval.perform(with: ["a": 5])
        XCTAssertEqual(value as? String, "yo")
        value = eval.perform(with: ["a": 1])
        XCTAssertEqual(value as? String, "pff")
    }
    
    func testEvaluationPredicateValueFormat() {
        eval.valueIfTrue = "yo"
        eval.valueIfFalse = "pff"
        eval.valueFormat = "v = '%@'"
        value = eval.perform(with: ["a": 5])
        XCTAssertEqual(value as? String, "v = 'yo'")
    }
    
    func testEvaluationPredicateValuePlaceholder() {
        eval.valueIfTrue = "yo"
        eval.valueIfFalse = NSNull()
        eval.placeholder = "Oops"
        eval.valueFormat = "v = '%@'"
        value = eval.perform(with: ["a": 0])
        XCTAssertEqual(value as? String, "Oops")
    }
    
    func testEvaluationPredicateValueTransformer() {
        eval.valueIfTrue = "3"
        eval.valueIfFalse = NSNull()
        eval.transformerName = "strToInt"
        ValueTransformer.setDefaultTransformers()
        value = eval.perform(with: ["a": 5])
        XCTAssertEqual(value as? Int, 3)
    }
    
    func testEvaluationPredicateValueSubstitution() {
        eval.valueIfTrue = "$a is 5"
        eval.valueIfFalse = "$a is not 5"
        value = eval.perform(with: ["a": 5])
        XCTAssertEqual(value as? String, "5 is 5")
        value = eval.perform(with: ["a": 7])
        XCTAssertEqual(value as? String, "7 is not 5")
    }
    
    func testEvaluationPredicateValueSubstitutionWithFormat() {
        eval.valueIfTrue = "$a is 5"
        eval.valueIfFalse = "$a is not 5"
        eval.valueFormat = "number %@"
        value = eval.perform(with: ["a": 5])
        XCTAssertEqual(value as? String, "number 5 is 5")
        value = eval.perform(with: ["a": 7])
        XCTAssertEqual(value as? String, "number 7 is not 5")
    }
    
    func testEvaluationPredicateValueSubstitutionWithFormat_withString() {
        eval.predicateFormat = "a = '5'"
        eval.valueIfTrue = "$a is 5"
        eval.valueIfFalse = "$a is not 5"
        eval.valueFormat = "symbol %@"
        value = eval.perform(with: ["a": "5"])
        XCTAssertEqual(value as? String, "symbol 5 is 5")
        value = eval.perform(with: ["a": "7"])
        XCTAssertEqual(value as? String, "symbol 7 is not 5")
    }
}

class BindingsTests: XCTestCase {
    
    class TestInfoObject: NSObject {
        @objc dynamic var info = ""
        @objc dynamic var tagInfo = 0
    }
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testBinding() {
        let source = TestInfoObject()
        let label = UILabel(frame: CGRect.zero)
        let binding = Binding(target: label, bindingKey: "text", observable: source, keyPath: "info")
        XCTAssertEqual(label.text, source.info)
        source.info = "test"
        XCTAssertEqual(label.text, "test")
        binding.deactivate()
        source.info = "test 2"
        XCTAssertEqual(label.text, "test")
        binding.assign(from: source)
        XCTAssertEqual(label.text, "test 2")
    }
    
    func testAddBinding() {
        let label = UILabel(frame: CGRect.zero)
        let source = TestInfoObject()
        label.wx.addBinding(dictionary: [
//            ObjectAssistant.bindFrom: "", // keyPath, defaults to source object itself
//            ObjectAssistant.bindTo: "wx_value", // default
            BindingOption.predicateFormat.rawValue: "info = 'test'",
            BindingOption.valueIfTrue.rawValue: "$info is 'test'",
            BindingOption.valueIfFalse.rawValue: "$info is not 'test'",
            BindingOption.valueFormat.rawValue: "string %@"
            ])
        label.wx.addBinding(dictionary: [
            ObjectAssistant.bindFrom: "tagInfo",
            ObjectAssistant.bindTo: "tag"
            ])
        source.tagInfo = 5
        source.info = "test"
        label.wx.setupObject(using: source)
        XCTAssertEqual(label.text, "string test is 'test'")
        XCTAssertEqual(label.tag, 5)
    }
}
