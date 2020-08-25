//
//  String+QuatedPrintable.swift
//  SwiftServe
//
//  Created by Andrew J Wagner on 3/2/18.
//

import Foundation

extension String {
    private enum QutableMode {
        case none
        case equal(String?)
        case carriageReturn
    }

    func decodingQuotedPrintable(using encoding: String.Encoding) -> String? {
        var output = ""
        var mode = QutableMode.none

        func cancelEscape(_ first: String?) {
            output.append("=")
            if let first = first {
                output += "\(first)"
            }
            mode = .none
        }

        func cancelCarraigeReturn() {
            output.append("=\r")
            mode = .none
        }

        for character in self {
            switch character {
            case "=":
                switch mode {
                case .none:
                    mode = .equal(nil)
                case .equal(let first):
                    cancelEscape(first)
                    mode = .equal(nil)
                case .carriageReturn:
                    output.append("=\r")
                    mode = .equal(nil)
                }
            case "\r\n":
                switch mode {
                case .carriageReturn:
                    cancelCarraigeReturn()
                    output.append(character)
                case .equal(let first):
                    if let first = first {
                        cancelEscape(first)
                        output.append(character)
                    }
                    else {
                        mode = .none
                    }
                case .none:
                    output.append("\n")
                }
            case "\r":
                switch mode {
                case .none:
                    output.append(character)
                case .carriageReturn:
                    cancelCarraigeReturn()
                    output.append(character)
                case .equal(let first):
                    if let first = first {
                        cancelEscape(first)
                    }
                    else {
                        mode = .carriageReturn
                    }
                }
            case "\n":
                switch mode {
                case .carriageReturn:
                    mode = .none
                case .equal(let first):
                    if let first = first {
                        cancelEscape(first)
                    }
                    else {
                        mode = .none
                    }
                case .none:
                    output.append(character)
                }
            case "0","1","2","3","4","5","6","7","8","9", "A", "B", "C", "D", "E", "F":
                switch mode {
                case .none:
                    output.append(character)
                case .equal(let first):
                    guard let first = first else {
                        mode = .equal("\(character)")
                        break
                    }
                    let hexString = "\(first)\(character)"
                    let bytes = [UInt8(hexString, radix: 16)!]
                    let decoded = String(data: Data(bytes), encoding: encoding) ?? "?"
                    output += decoded
                    mode = .none
                case .carriageReturn:
                    cancelCarraigeReturn()
                }
            default:
                switch mode {
                case .none:
                    output.append(character)
                case let .equal(first):
                    cancelEscape(first)
                case .carriageReturn:
                    cancelCarraigeReturn()
                }
            }
        }
        return output
    }

    var quotedPrintableEncoded: String {
        var charCount = 0

        var result = ""
        result.reserveCapacity(self.count)

        for character in self.utf8 {
            switch character {
            case 32...60, 62...126:
                charCount += 1
                result.append(String(UnicodeScalar(character)))
            case 13:
                continue
            case 10:
                if result.last == " " || result.last == "\t" {
                    result.append("=\r\n")
                    charCount = 0
                } else {
                    result.append("\r\n")
                    charCount = 0
                }
            default:
                if charCount > 72 {
                    result.append("=\r\n")
                    charCount = 0
                }
                result.append("=")
                result.append(character.hexString().uppercased())
                charCount+=3
            }

            if charCount == 75 {
                charCount = 0
                result.append("=\r\n")
            }
        }
        return result
    }
}

private extension UInt8 {
    func hexString(padded: Bool = true) -> String {
        let dict:[Character] = [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
        var result = ""

        let c1 = Int(self >> 4)
        let c2 = Int(self & 0xf)

        if c1 == 0 && padded {
            result.append(dict[c1])
        } else if c1 > 0 {
            result.append(dict[c1])
        }
        result.append(dict[c2])

        if (result.count == 0) {
            return "0"
        }
        return result
    }
}

private enum QuotedPrintableState {
    case Text
    case Equals
    case EqualsSecondDigit(firstDigit: UInt8)
}
