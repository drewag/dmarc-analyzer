//
//  Person.swift
//  dmarc-analyzer
//
//  Created by Andrew J Wagner on 2/22/18.
//

import Swiftlier

struct Person: CustomStringConvertible, Codable {
    let name: String?
    let email: EmailAddress

    static func people(from string: String?) -> [Person]? {
        guard let string = string else {
            return nil
        }

        let components = string.components(separatedBy: ",")
        return components.map({$0.trimmingWhitespaceOnEnds}).flatMap({Person($0)})
    }

    private init?(rawName: String?, rawEmail: String) {
        let name = rawName?.trimmingWhitespaceOnEnds

        guard let email = try? EmailAddress(string: rawEmail.trimmingCarrots) else {
            return nil
        }
        self.email = email
        if name?.lowercased() == email.string {
            self.name = nil
        }
        else if name?.contains(where: {!"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz ".contains($0)}) ?? false {
            self.name = nil
        }
        else {
            self.name = name
        }
    }

    init?(_ string: String?) {
        guard let string = string else {
            return nil
        }

        let quotedComponents = string.components(separatedBy: "\"")
        switch quotedComponents.count {
        case 3 where quotedComponents[0].isEmpty:
            // Break down based on quotes
            self.init(rawName: quotedComponents[1], rawEmail: quotedComponents[2...].joined(separator: "\""))
        default:
            // Break down based on carrots
            let components = string.components(separatedBy: "<")
            switch components.count {
            case 0:
                return nil
            case 1:
                self.init(rawName: nil, rawEmail: string)
            default:
                var remaining = components[1...].joined(separator: "<")
                if remaining.hasSuffix(">") {
                    remaining.removeLast()
                }
                self.init(rawName: components[0], rawEmail: remaining)
            }
        }
    }

    var description: String {
        if let name = name {
            return "\(name) <\(email.string)>"
        }
        return "<\(email.string)>"
    }
}

private extension String {
    var trimmingCarrots: String {
        var trimmed = self.trimmingWhitespaceOnEnds
        if trimmed.hasPrefix("<") && trimmed.hasSuffix(">") {
            trimmed.removeFirst()
            trimmed.removeLast()
        }
        return trimmed
    }
}

