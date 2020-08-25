//
//  StructuredHeader.swift
//  file-sync-services
//
//  Created by Andrew J Wagner on 4/16/17.
//
//

struct StructuredHeader: StringKeyValueParser {
    private enum Mode {
        case quoted
        case none
    }

    static func parse(_ string: String) -> [String:String] {
        // https://www.w3.org/Protocols/rfc1341/4_Content-Type.html
        var output = [String:String]()

        var mode = Mode.none
        var currentKey = ""
        var currentValue: String? = nil

        for character in string {
            switch character {
            case ";" where mode == .none:
                output[currentKey] = currentValue ?? ""
                currentKey = ""
                currentValue = nil
            case "=" where currentValue == nil && mode == .none:
                currentValue = ""
            case " " where mode == .none:
                continue
            case "\"" where currentValue == "":
                mode = .quoted
            case "\"" where mode == .quoted:
                mode = .none
            default:
                if let value = currentValue {
                    currentValue = value + "\(character)"
                }
                else {
                    currentKey.append(character)
                }
            }
        }

        if !currentKey.isEmpty {
            output[currentKey] = currentValue ?? ""
        }

        return output
    }
}
