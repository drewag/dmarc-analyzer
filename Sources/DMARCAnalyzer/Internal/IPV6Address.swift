//
//  IPV6Address.swift
//  
//
//  Created by Andrew J Wagner on 8/25/20.
//

struct IPV6Address: Equatable {
    enum Error: Swift.Error {
        case invalidAddress
    }

    let normalized: String

    init(string: String) throws {
        self.normalized = try IPV6Address.normalize(string)
    }
}

private extension IPV6Address {
    static func normalize(_ string: String) throws -> String {
        var normalized = ""

        var foundNonZeroInThisHextet = false
        var currentZeroHextetCount = 0
        var usedDoubleColon = false
        var hasAddedColon = false
        var prev: Character = " "

        for char in string {
            defer {
                prev = char
            }

            let char = char.lowercased()
            switch char {
            case ":":
                defer {
                    foundNonZeroInThisHextet = false
                }
                if prev == ":" {
                    if (normalized.isEmpty) {
                        normalized += "::"
                    }
                    else {
                        normalized.append(char)
                    }
                    usedDoubleColon = true
                    currentZeroHextetCount = 0
                    break
                }
                if foundNonZeroInThisHextet {
                    normalized.append(char)
                    hasAddedColon = true
                }
                else {
                    currentZeroHextetCount += 1

                    if usedDoubleColon {
                        normalized += "0:"
                    }
                }
            case "0":
                if foundNonZeroInThisHextet {
                    normalized.append(char)
                }
            case "1","2","3","4","5","6","7","8","9","a","b","c","d","e","f":
                defer {
                    foundNonZeroInThisHextet = true
                    currentZeroHextetCount = 0
                }
                if currentZeroHextetCount == 1 {
                    normalized += "0:"
                }
                else if currentZeroHextetCount > 1 && !usedDoubleColon {
                    if (hasAddedColon) {
                        normalized += ":"
                    }
                    else {
                        normalized += "::"
                    }
                    usedDoubleColon = true
                }
                normalized.append(char)
            default:
                throw Error.invalidAddress
            }
        }

        if !foundNonZeroInThisHextet {
            if usedDoubleColon {
                if !normalized.hasSuffix("::") {
                    normalized.append("0")
                }
            }
            else {
                normalized += "::"
            }
        }

        return normalized
    }
}
