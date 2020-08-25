//
//  CaseInsensitiveKeyTests.swift
//  SwiftServeTests
//
//  Created by Andrew J Wagner on 8/7/19.
//

import XCTest
@testable import DMARCAnalyzer

class CaseInsensitiveKeyTests: XCTestCase {
    func testDictionary() {
        var dict = [CaseInsensitiveKey:String]()

        dict["SomeKey"] = "one"
        dict["other"] = "two"
        dict["THIRD"] = "three"

        XCTAssertEqual(dict["SOMEKEY"], "one")
        XCTAssertEqual(dict["somekey"], "one")
        XCTAssertEqual(dict["SoMeKeY"], "one")

        XCTAssertEqual(dict["OTHER"], "two")
        XCTAssertEqual(dict["other"], "two")
        XCTAssertEqual(dict["oThEr"], "two")

        XCTAssertEqual(dict["THIRD"], "three")
        XCTAssertEqual(dict["third"], "three")
        XCTAssertEqual(dict["ThIrD"], "three")

        XCTAssertNil(dict["nonexistent"])
    }

    func testDictionaryLiteralInitialization() {
        let dict: [CaseInsensitiveKey:String] = [
            "SomeKey": "one",
            "other": "two",
            "THIRD": "three",
        ]

        XCTAssertEqual(dict["SOMEKEY"], "one")
        XCTAssertEqual(dict["somekey"], "one")
        XCTAssertEqual(dict["SoMeKeY"], "one")

        XCTAssertEqual(dict["OTHER"], "two")
        XCTAssertEqual(dict["other"], "two")
        XCTAssertEqual(dict["oThEr"], "two")

        XCTAssertEqual(dict["THIRD"], "three")
        XCTAssertEqual(dict["third"], "three")
        XCTAssertEqual(dict["ThIrD"], "three")

        XCTAssertNil(dict["nonexistent"])
    }

    func testEqualityToStrings() {
        XCTAssertTrue(CaseInsensitiveKey(rawValue: "SomeKey") == "SOMEKEY" as String)
        XCTAssertTrue(CaseInsensitiveKey(rawValue: "SomeKey") == "somekey" as String)
        XCTAssertTrue(CaseInsensitiveKey(rawValue: "SomeKey") == "SoMeKeY" as String)

        XCTAssertTrue("SOMEKEY" as String == CaseInsensitiveKey(rawValue: "SomeKey"))
        XCTAssertTrue("somekey" as String == CaseInsensitiveKey(rawValue: "SomeKey"))
        XCTAssertTrue("SoMeKeY" as String == CaseInsensitiveKey(rawValue: "SomeKey"))
    }
}
