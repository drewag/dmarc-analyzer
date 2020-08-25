//
//  ContentDisposition.swift
//  SwiftServe
//
//  Created by Andrew J Wagner on 1/27/18.
//

import Foundation

enum ContentDisposition {
    case inline
    case attachment(fileName: String?)
    case formData(name: String)

    case none
    case other(String)

    init(_ string: String?) {
        guard let string = string, !string.isEmpty else {
            self = .none
            return
        }

        var parts = string.components(separatedBy: ";")

        switch parts.removeFirst().trimmingWhitespaceOnEnds.lowercased() {
        case "inline":
            self = .inline
        case "attachment" where parts.count > 0:
            let remaining = parts.joined(separator: ";")
            guard let fileName = StructuredHeader.parse(remaining)["filename"] else {
                self = .attachment(fileName: nil)
                return
            }
            self = .attachment(fileName: fileName)
        case "form-data" where parts.count > 0:
            let remaining = parts.joined(separator: ";")
            guard let name = StructuredHeader.parse(remaining)["name"] else {
                self = .other(string)
                return
            }
            self = .formData(name: name)
        case "attachment":
            self = .attachment(fileName: nil)
        default:
            self = .other(string)
        }
    }

    var raw: String? {
        switch self {
        case .attachment(let fileName):
            var output = "attachment"
            if let name = fileName {
                output += "; filename=\(name)"
            }
            return output
        case .formData(let name):
            return "form-data; name=\(name)"
        case .inline:
            return "inline"
        case .none:
            return nil
        case .other(let other):
            return other
        }
    }
}
