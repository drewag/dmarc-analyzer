//
//  ContentTranserEncoding.swift
//  SwiftServe
//
//  Created by Andrew J Wagner on 1/26/18.
//

import Foundation

enum ContentTransferEncoding {
    case quotedPrintable
    case base64
    case eightbit
    case sevenBit
    case binary

    case none
    case other(String)

    init(_ string: String?) {
        guard let string = string, !string.isEmpty else {
            self = .none
            return
        }

        switch string.trimmingWhitespaceOnEnds.lowercased() {
        case "quoted-printable":
            self = .quotedPrintable
        case "base64":
            self = .base64
        case "8bit":
            self = .eightbit
        case "7bit":
            self = .sevenBit
        default:
            self = .other(string)
        }
    }

    static func types(from string: String?) -> [ContentType] {
        guard let string = string else {
            return []
        }

        var output = [ContentType]()
        for type in string.components(separatedBy: ",") {
            output.append(ContentType(type))
        }
        return output
    }

    var raw: String? {
        switch self {
        case .base64:
            return "BASE64"
        case .binary:
            return "BINARY"
        case .eightbit:
            return "8BIT"
        case .none:
            return nil
        case .other(let other):
            return other
        case .quotedPrintable:
            return "QUOTED-PRINTABLE"
        case .sevenBit:
            return "7BIT"
        }
    }
}
