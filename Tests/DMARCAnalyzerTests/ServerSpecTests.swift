//
//  File.swift
//  
//
//  Created by Andrew J Wagner on 8/25/20.
//

import XCTest
@testable import DMARCAnalyzer

class ServerSpecTests: XCTestCase {
    func testMatchingIPV4() {
        let spec = ServerSpec(raw: "192.168.0.1")
        XCTAssertTrue(spec.matches(ip: "192.168.0.1"))
        XCTAssertFalse(spec.matches(ip: "192.168.0.0"))
        XCTAssertFalse(spec.matches(ip: "192.168.1.1"))
        XCTAssertFalse(spec.matches(ip: "192.169.0.1"))
        XCTAssertFalse(spec.matches(ip: "193.168.0.1"))
    }

    func testMatchingIPV4WithSingleWildcard() {
        let spec = ServerSpec(raw: "192.168.0.x")
        XCTAssertTrue(spec.matches(ip: "192.168.0.1"))
        XCTAssertTrue(spec.matches(ip: "192.168.0.0"))
        XCTAssertTrue(spec.matches(ip: "192.168.0.212"))
        XCTAssertFalse(spec.matches(ip: "192.168.1.1"))
        XCTAssertFalse(spec.matches(ip: "192.169.0.1"))
        XCTAssertFalse(spec.matches(ip: "193.168.0.1"))
    }

    func testMatchingIPV6() {
        var spec = ServerSpec(raw: "2001:db8:85a3::8a2e:370:7334")
        XCTAssertTrue(spec.matches(ip: "2001:db8:85a3::8a2e:370:7334"))
        XCTAssertTrue(spec.matches(ip: "2001:0db8:85a3:0000:0000:8a2e:0370:7334"))
        XCTAssertFalse(spec.matches(ip: "2001:db8:85a3::8a2e:370:7335"))

        spec = ServerSpec(raw: "0:0:0:0:0:0:0:1")
        XCTAssertTrue(spec.matches(ip: "0:0:0:0:0:0:0:1"))
        XCTAssertTrue(spec.matches(ip: "::1"))
        XCTAssertFalse(spec.matches(ip: "::2"))
    }
}
