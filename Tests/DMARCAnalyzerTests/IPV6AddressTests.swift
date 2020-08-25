//
//  File.swift
//  
//
//  Created by Andrew J Wagner on 8/25/20.
//

import XCTest
@testable import DMARCAnalyzer

class IPV6AddressTests: XCTestCase {
    func testBasicRepeatingZeroHextets() throws {
        XCTAssertEqual(
            try IPV6Address(string: "2001:0db8:85a3:0000:0000:8a2e:0370:7334").normalized,
            "2001:db8:85a3::8a2e:370:7334"
        )
    }

    func testRetainingAtLeastOneZero() throws {
        XCTAssertEqual(
            try IPV6Address(string: "2001:0db8::0001:0000").normalized,
            "2001:db8::1:0"
        )
    }

    func testMultipleRepeatingZeroHextets() throws {
        XCTAssertEqual(
            try IPV6Address(string: "2001:db8:0:0:1:0:0:1").normalized,
            "2001:db8::1:0:0:1"
        )
    }

    func testTrailingHextets() throws {
        XCTAssertEqual(
            try IPV6Address(string: "0:0:0:0:0:0:0:1").normalized,
            "::1"
        )
    }

    func testAllZeroes() throws {
        XCTAssertEqual(
            try IPV6Address(string: "0:0:0:0:0:0:0:0").normalized,
            "::"
        )
    }

    func testSingleZeroHextet() throws {
        XCTAssertEqual(
            try IPV6Address(string: "2001:db8:0000:1:1:1:1:1").normalized,
            "2001:db8:0:1:1:1:1:1"
        )
    }

    func testAlreadyShortened() throws {
        XCTAssertEqual(try IPV6Address(string: "2001:db8:85a3::8a2e:370:7334").normalized, "2001:db8:85a3::8a2e:370:7334")
        XCTAssertEqual(try IPV6Address(string: "2001:db8::1:0").normalized, "2001:db8::1:0")
        XCTAssertEqual(try IPV6Address(string: "2001:db8::1:0:0:1").normalized, "2001:db8::1:0:0:1")
        XCTAssertEqual(try IPV6Address(string: "::1").normalized, "::1")
        XCTAssertEqual(try IPV6Address(string: "::").normalized, "::")
        XCTAssertEqual(try IPV6Address(string: "2001:db8:0:1:1:1:1:1").normalized, "2001:db8:0:1:1:1:1:1")
    }
}
