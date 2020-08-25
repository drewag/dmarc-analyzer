//
//  StringKeyValueParser.swift
//  file-sync-services
//
//  Created by Andrew J Wagner on 4/16/17.
//
//

public protocol StringKeyValueParser {
    static func parse(_ string: String) -> [String:String]
}

extension Dictionary where Key == String, Value == String {
    func appending(_ string: String, parsedWith parser: StringKeyValueParser.Type) -> [String:String] {
        var output = self
        output.append(string, parsedWith: parser)
        return output
    }

    mutating func append(_ string: String, parsedWith parser: StringKeyValueParser.Type) {
        for (key,value) in parser.parse(string) {
            self[key] = value
        }
    }
}
