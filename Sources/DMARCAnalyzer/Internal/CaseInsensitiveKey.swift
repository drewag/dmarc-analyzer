//
//  HTTPHeader.swift
//  SwiftServe
//
//  Created by Andrew J Wagner on 8/7/19.
//

import Foundation

struct CaseInsensitiveKey: Hashable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }

    func hash(into hasher: inout Hasher) {
        let raw = self.rawValue.lowercased()
        raw.hash(into: &hasher)
    }

    static func ==(lhs: CaseInsensitiveKey, rhs: CaseInsensitiveKey) -> Bool {
        return lhs.rawValue.lowercased() == rhs.rawValue.lowercased()
    }

    static func ==(lhs: CaseInsensitiveKey, rhs: String) -> Bool {
        return lhs.rawValue.lowercased() == rhs.lowercased()
    }

    static func ==(lhs: String, rhs: CaseInsensitiveKey) -> Bool {
        return rhs == lhs
    }
}

extension Dictionary where Key == CaseInsensitiveKey, Value == String {
    subscript(key: String) -> String? {
        get {
            let key = CaseInsensitiveKey(rawValue: key)
            return self[key]
        }
        set {
            let key = CaseInsensitiveKey(rawValue: key)
            self[key] = newValue
        }
    }
}

extension CaseInsensitiveKey: CustomStringConvertible {
    var description: String {
        return self.rawValue
    }
}
