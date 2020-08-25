//
//  MimeDecoder.swift
//  SwiftServe
//
//  Created by Andrew J Wagner on 2/23/18.
//

import Foundation
import Swiftlier

struct MimePart {
    struct MessageDeliveryStatus {
        public let originalRecipient: String?
        public let finalRecipient: String
        public let status: String

        public var raw: String {
            var output = ""
            if let originalRecipient = self.originalRecipient {
                output += "Original-Recipient: rfc822; \(originalRecipient)\r\n"
            }
            output += "Final-Recipient: rfc822; \(self.finalRecipient)"
            output += "\r\nStatus: \(self.status)"
            return output
        }
    }

    enum Content {
        case pdf(Data)
        case png(Data)
        case jpg(Data)
        case octetStream(Data)
        case html(String)
        case plain(String)
        case json(String)
        case zip(Data)
        case gzip(Data)
        case csv(Data)
        case mp4(Data)
        case deliveryStatus(MessageDeliveryStatus)
        case email(raw: String)

        case multipartFormData([MimePart])
        case multipartAlternative([MimePart])
        case multipartMixed([MimePart])
        case multipartRelated([MimePart])
        case multipartReport([MimePart], type: String)

        case none
    }

    let name: String?
    let content: Content
    let headers: [CaseInsensitiveKey:String]
    var contentType: ContentType

    var plain: String? {
        switch self.content {
        case .plain(let plain):
            return plain
        default:
            return nil
        }
    }

    init(data: Data, characterEncoding: String.Encoding = .isoLatin1) throws {
        guard let string = String(data: data, encoding: characterEncoding) else {
            throw GenericSwiftlierError("parsing", because: "data is not valid")
        }
        try self.init(rawContents: string)
    }

    init(content: Content, name: String?) {
        self.content = content
        self.headers = [:]
        self.contentType = content.contentType(withName: name)
        self.name = name
    }

    init(body: Data, headers: [CaseInsensitiveKey:String], contentType: ContentType, contentTransferEncoding: ContentTransferEncoding, contentDisposition: ContentDisposition, characterEncoding: String.Encoding = .isoLatin1) throws {
        guard let string = String(data: body, encoding: characterEncoding) else {
            throw GenericSwiftlierError("parsing", because: "data is not valid")
        }
        try self.init(body: string, headers: headers, contentType: contentType, contentTransferEncoding: contentTransferEncoding, contentDisposition: contentDisposition)
    }

    init(body: String, headers: [CaseInsensitiveKey:String], contentType: ContentType, contentTransferEncoding: ContentTransferEncoding, contentDisposition: ContentDisposition) throws {
        switch contentDisposition {
        case .attachment(let name):
            self.name = name
        case .formData(let name):
            self.name = name
        case .none, .other, .inline:
            self.name = nil
        }
//        print("Content Type: \(contentType)")

        switch contentType {
        case .other(let other):
            throw GenericSwiftlierError("parsing", because: "an unknown content type was found '\(other)'")
        case .html(let encoding):
            self.content = .html(type(of: self).string(from: body, transferEncoding: contentTransferEncoding, characterEncoding: encoding))
        case .none:
            self.content = .plain(type(of: self).string(from: body, transferEncoding: contentTransferEncoding, characterEncoding: .isoLatin1))
        case .plainText(let encoding):
            self.content = .plain(type(of: self).string(from: body, transferEncoding: contentTransferEncoding, characterEncoding: encoding))
        case .csv:
            self.content = .csv(type(of: self).data(from: body, transferEncoding: contentTransferEncoding, characterEncoding: .isoLatin1))
        case .json(let encoding):
            self.content = .json(type(of: self).string(from: body, transferEncoding: contentTransferEncoding, characterEncoding: encoding))
        case .mp4:
            self.content = .mp4(type(of: self).data(from: body, transferEncoding: contentTransferEncoding, characterEncoding: .isoLatin1))
        case .jpg:
            self.content = .jpg(type(of: self).data(from: body, transferEncoding: contentTransferEncoding, characterEncoding: .isoLatin1))
        case .png:
            self.content = .png(type(of: self).data(from: body, transferEncoding: contentTransferEncoding, characterEncoding: .isoLatin1))
        case .pdf:
            self.content = .pdf(type(of: self).data(from: body, transferEncoding: contentTransferEncoding, characterEncoding: .isoLatin1))
        case .octetStream:
            self.content = .octetStream(type(of: self).data(from: body, transferEncoding: contentTransferEncoding, characterEncoding: .isoLatin1))
        case .zip:
            self.content = .zip(type(of: self).data(from: body, transferEncoding: contentTransferEncoding, characterEncoding: .isoLatin1))
        case .gzip:
            self.content = .gzip(type(of: self).data(from: body, transferEncoding: contentTransferEncoding, characterEncoding: .isoLatin1))
        case .multipartFormData(let boundary):
            let parts = try MimePart.parts(in: body, usingBoundary: boundary)
            self.content = .multipartFormData(parts)
        case .multipartAlternative(let boundary):
            let parts = try MimePart.parts(in: body, usingBoundary: boundary)
            self.content = .multipartAlternative(parts)
        case .multipartMixed(let boundary):
            let parts = try MimePart.parts(in: body, usingBoundary: boundary)
            self.content = .multipartMixed(parts)
        case .multipartRelated(let boundary):
            let parts = try MimePart.parts(in: body, usingBoundary: boundary)
            self.content = .multipartRelated(parts)
        case let .multipartReport(boundary, reportType):
            let parts = try MimePart.parts(in: body, usingBoundary: boundary)
            self.content = .multipartReport(parts, type: reportType)
        case .deliveryStatus:
            self.content = .deliveryStatus(try .init(body: body))
        case .email:
            self.content = .email(raw: type(of: self).string(from: body, transferEncoding: contentTransferEncoding, characterEncoding: .isoLatin1))
        }

        self.headers = headers
        self.contentType = contentType
    }

    init(rawContents: String, newline: String? = nil) throws {
        var headers = [CaseInsensitiveKey:String]()
        var fullLine = ""

        func processFullLine() {
            guard !fullLine.isEmpty else {
                return
            }

            //            print("Processing: \(fullLine)")
            let components = fullLine.components(separatedBy: ": ")
            guard components.count >= 2 else {
                return
            }

            headers[components[0].lowercased()] = components[1...].joined(separator: ": ")
        }

        var startedBody = false
        var body = ""

        let finalNewLine: String
        if let newline = newline {
            finalNewLine = newline
        }
        else {
            if rawContents.contains("\r\n") {
                finalNewLine = "\r\n"
            }
            else {
                finalNewLine = "\n"
            }
        }

        for line in rawContents.components(separatedBy: finalNewLine) {
            guard !startedBody else {
                if !body.isEmpty {
                    body += finalNewLine
                }
                body += line
                continue
            }

            guard !line.isEmpty else {
                // End of headers
                startedBody = true
                continue
            }

            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                // Continuation of last line
                fullLine += " " + line.trimmingWhitespaceOnEnds
            }
            else {
                // New line

                // Process previous line
                processFullLine()

                // Setup next line
                fullLine = line
            }
        }

        processFullLine()

        try self.init(
            body: body,
            headers: headers,
            contentType: ContentType(headers["content-type"]),
            contentTransferEncoding: ContentTransferEncoding(headers["content-transfer-encoding"]),
            contentDisposition: ContentDisposition(headers["content-disposition"])
        )
    }

    subscript(name: String) -> MimePart? {
        let foundParts: [MimePart]
        switch content {
        case .multipartAlternative(let parts):
            foundParts = parts
        case .multipartMixed(let parts):
            foundParts = parts
        case .multipartRelated(let parts):
            foundParts = parts
        case .multipartReport(let parts, type: _):
            foundParts = parts
        case .multipartFormData(let parts):
            foundParts = parts
        default:
            return nil
        }

        return foundParts.first(where: {$0.name == name})
    }

    func part(ofType type: ContentType) -> MimePart? {
        if self.contentType == type {
            return self
        }

        let childParts: [MimePart]
        switch self.content {
        case .csv, .deliveryStatus, .gzip, .html, .jpg, .none, .pdf, .png, .octetStream, .plain, .zip, .mp4, .json:
            return nil
        case .email(let raw):
            guard let part = try? MimePart(rawContents: raw) else {
                return nil
            }
            childParts = [part]
        case .multipartAlternative(let parts):
            childParts = parts
        case .multipartFormData(let parts):
            childParts = parts
        case .multipartMixed(let parts):
            childParts = parts
        case .multipartRelated(let parts):
            childParts = parts
        case .multipartReport(let parts, type: _):
            childParts = parts
        }

        for part in childParts {
            if let found = part.part(ofType: type) {
                return found
            }
        }
        return nil
    }

    static func parts(in body: String, usingBoundary boundary: String) throws -> [MimePart] {
        let data = body.data(using: .isoLatin1) ?? Data()
        return try self.parts(in: data, usingBoundary: boundary, characterEncoding: .isoLatin1)
    }

    static func parts(in data: Data, usingBoundary boundary: String, characterEncoding: String.Encoding) throws -> [MimePart] {
        let firstBoundaryRange: Range<Data.Index>
        let midBoundaryData: Data
        let endBoundaryData: Data
        let newLine: String

        if let bothFirstBoundaryData = "--\(boundary)\r\n".data(using: characterEncoding)
            , let bothMidBoundaryData = "\r\n--\(boundary)\r\n".data(using: characterEncoding)
            , let bothEndBoundaryData = "\r\n--\(boundary)--".data(using: characterEncoding)
            , let bothFirstBoundaryRange = data.range(of: bothFirstBoundaryData)
        {
            firstBoundaryRange = bothFirstBoundaryRange
            midBoundaryData = bothMidBoundaryData
            endBoundaryData = bothEndBoundaryData
            newLine = "\r\n"
        }
        else if let singleFirstBoundaryData = "--\(boundary)\n".data(using: characterEncoding)
            , let singleMidBoundaryData = "\n--\(boundary)\n".data(using: characterEncoding)
            , let singleEndBoundaryData = "\n--\(boundary)--".data(using: characterEncoding)
            , let singleFirstBoundaryRange = data.range(of: singleFirstBoundaryData)
        {
            firstBoundaryRange = singleFirstBoundaryRange
            midBoundaryData = singleMidBoundaryData
            endBoundaryData = singleEndBoundaryData
            newLine = "\n"
        }
        else {
            return []
        }

        var output = [MimePart]()

        let ranges = data.ranges(separatedBy: midBoundaryData, in: firstBoundaryRange.upperBound ..< data.count)
        for (index, range) in ranges.enumerated() {
            let finalRange: Range<Data.Index>
            if index == ranges.count - 1, let endRange = data.range(of: endBoundaryData, in: range) {
                finalRange = range.lowerBound ..< endRange.lowerBound
            }
            else {
                finalRange = range
            }
            guard let string = String(data: data.subdata(in: finalRange), encoding: characterEncoding)
                , let part = try? MimePart(rawContents: string, newline: newLine)
                else
            {
                continue
            }
            output.append(part)
        }

        return output
    }

    var raw: String {
        var output = ""

        var finalHeaders = self.headers
        let (body, extraHeaders) = self.content.generateRaw(withName: self.name)
        for (key, value) in extraHeaders {
            finalHeaders[key] = value
        }

        for (key, value) in finalHeaders {
            output += "\(key): \(value)\r\n"
        }
        output += "\r\n"
        output += body
        return output
    }

    var rawBodyAndHeaders: (body: String, headers: [CaseInsensitiveKey:String]) {
        let (body, extraHeaders) = self.content.generateRaw(withName: self.name)

        var finalHeaders = self.headers
        for (key, value) in extraHeaders {
            finalHeaders[key] = value
        }
        return (body: body, headers: finalHeaders)
    }
}

private extension MimePart {
    static func data(from data: Data, transferEncoding: ContentTransferEncoding, characterEncoding: String.Encoding) -> Data {
        switch transferEncoding {
        case .base64:
            guard let base64String = String(data: data, encoding: characterEncoding)?.replacingOccurrences(of: "\n", with: "") else {
                return data
            }
            return Data(base64Encoded: base64String) ?? data
        default:
            return data
        }
    }

    static func data(from string: String, transferEncoding: ContentTransferEncoding, characterEncoding: String.Encoding) -> Data {
        switch transferEncoding {
        case .base64:
            let base64String = string
                .replacingOccurrences(of: "\r\n", with: "")
                .replacingOccurrences(of: "\n", with: "")
            return Data(base64Encoded: base64String) ?? Data()
        default:
            return string.data(using: characterEncoding) ?? Data()
        }
    }

    static func string(from string: String, transferEncoding: ContentTransferEncoding, characterEncoding: String.Encoding) -> String {
        switch transferEncoding {
        case .quotedPrintable:
            return string.decodingQuotedPrintable(using: characterEncoding) ?? string
        case .eightbit, .sevenBit, .none, .other, .binary:
            return string
        case .base64:
            let raw = string.replacingOccurrences(of: "\n", with: "")
            guard let data = Data(base64Encoded: raw) else {
                return string
            }
            return String(data: data, encoding: characterEncoding) ?? string
        }
    }

    static func string(data: Data, transferEncoding: ContentTransferEncoding, characterEncoding: String.Encoding) -> String? {
        switch transferEncoding {
        case .quotedPrintable:
            return String(data: data, encoding: characterEncoding)?.decodingQuotedPrintable(using: characterEncoding)
        case .eightbit, .sevenBit, .none, .other:
            return String(data: data, encoding: characterEncoding)
        case .binary:
            return nil
        case .base64:
            guard let base64String = String(data: data, encoding: characterEncoding)?.replacingOccurrences(of: "\n", with: "")
                , let base64 = Data(base64Encoded: base64String) else {
                    return nil
            }
            return String(data: base64, encoding: characterEncoding)
        }
    }
}

extension MimePart.Content {
    func contentType(withName name: String?) -> ContentType {
        switch self {
        case .csv:
            return .csv
        case .json:
            return .json(.utf8)
        case .deliveryStatus:
            return .deliveryStatus
        case .html:
            return .html(.utf8)
        case .jpg:
            return .jpg
        case .mp4:
            return .mp4
        case .multipartAlternative:
            return .multipartAlternative(boundary: "")
        case .multipartFormData:
            return .multipartFormData(boundary: "")
        case .multipartMixed:
            return .multipartMixed(boundary: "")
        case .multipartRelated:
            return .multipartRelated(boundary: "")
        case .multipartReport(_, let type):
            return .multipartReport(boundary: "", reportType: type)
        case .none:
            return .none
        case .octetStream:
            return .octetStream
        case .pdf:
            return .pdf
        case .plain:
            return .plainText(.utf8)
        case .png:
            return .png
        case .zip:
            return .zip(name: name)
        case .gzip:
            return .gzip(name: name)
        case .email:
            return .email
        }
    }

    func generateRaw(withName name: String?) -> (body: String, extraHeaders: [String:String]) {
        var extraHeaders = [String:String]()

        let body: String
        switch self {
        case .csv(let data):
            extraHeaders["Content-Type"] = ContentType.csv.raw
            extraHeaders["Content-Disposition"] = ContentDisposition.attachment(fileName: name).raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.base64.raw
            body = data.base64
        case .deliveryStatus(let status):
            extraHeaders["Content-Type"] = ContentType.deliveryStatus.raw
            extraHeaders["Content-Disposition"] = ContentDisposition.none.raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.quotedPrintable.raw
            body = status.raw.quotedPrintableEncoded
        case .html(let html):
            extraHeaders["Content-Type"] = ContentType.html(.utf8).raw
            extraHeaders["Content-Disposition"] = ContentDisposition.none.raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.quotedPrintable.raw
            body = html.quotedPrintableEncoded
        case .json(let json):
            extraHeaders["Content-Type"] = ContentType.json(.utf8).raw
            extraHeaders["Content-Disposition"] = ContentDisposition.none.raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.quotedPrintable.raw
            body = json.quotedPrintableEncoded
        case .email(let raw):
            extraHeaders["Content-Type"] = ContentType.email.raw
            extraHeaders["Content-Disposition"] = ContentDisposition.attachment(fileName: name).raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.quotedPrintable.raw
            body = raw.quotedPrintableEncoded
        case .jpg(let jpg):
            extraHeaders["Content-Type"] = ContentType.jpg.raw
            extraHeaders["Content-Disposition"] = ContentDisposition.attachment(fileName: name).raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.base64.raw
            body = jpg.base64
        case .mp4(let data):
            extraHeaders["Content-Type"] = ContentType.mp4.raw
            extraHeaders["Content-Disposition"] = ContentDisposition.attachment(fileName: name).raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.base64.raw
            body = data.base64
        case .multipartAlternative(let parts):
            let boundary = UUID().uuidString
            extraHeaders["Content-Type"] = ContentType.multipartAlternative(boundary: boundary).raw
            extraHeaders["Content-Disposition"] = ContentDisposition.none.raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.none.raw
            body = parts.rawMIME(withBoundary: boundary)
        case .multipartFormData(let parts):
            let boundary = UUID().uuidString
            extraHeaders["Content-Type"] = ContentType.multipartFormData(boundary: boundary).raw
            extraHeaders["Content-Disposition"] = ContentDisposition.none.raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.none.raw
            body = parts.rawMIME(withBoundary: boundary)
        case .multipartMixed(let parts):
            let boundary = UUID().uuidString
            extraHeaders["Content-Type"] = ContentType.multipartMixed(boundary: boundary).raw
            extraHeaders["Content-Disposition"] = ContentDisposition.none.raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.none.raw
            body = parts.rawMIME(withBoundary: boundary)
        case .multipartRelated(let parts):
            let boundary = UUID().uuidString
            extraHeaders["Content-Type"] = ContentType.multipartRelated(boundary: boundary).raw
            extraHeaders["Content-Disposition"] = ContentDisposition.none.raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.none.raw
            body = parts.rawMIME(withBoundary: boundary)
        case .multipartReport(let parts, let type):
            let boundary = UUID().uuidString
            extraHeaders["Content-Type"] = ContentType.multipartReport(boundary: boundary, reportType: type).raw
            extraHeaders["Content-Disposition"] = ContentDisposition.none.raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.none.raw
            body = parts.rawMIME(withBoundary: boundary)
        case .none:
            body = ""
        case .octetStream(let data):
            extraHeaders["Content-Type"] = ContentType.octetStream.raw
            extraHeaders["Content-Disposition"] = ContentDisposition.attachment(fileName: name).raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.base64.raw
            body = data.base64
        case .pdf(let data):
            extraHeaders["Content-Type"] = ContentType.pdf.raw
            extraHeaders["Content-Disposition"] = ContentDisposition.attachment(fileName: name).raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.base64.raw
            body = data.base64
        case .plain(let plain):
            extraHeaders["Content-Type"] = ContentType.plainText(.utf8).raw
            extraHeaders["Content-Disposition"] = ContentDisposition.none.raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.quotedPrintable.raw
            body = plain.quotedPrintableEncoded
        case .png(let data):
            extraHeaders["Content-Type"] = ContentType.png.raw
            extraHeaders["Content-Disposition"] = ContentDisposition.attachment(fileName: name).raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.base64.raw
            body = data.base64
        case .zip(let data):
            extraHeaders["Content-Type"] = ContentType.zip(name: name).raw
            extraHeaders["Content-Disposition"] = ContentDisposition.attachment(fileName: name).raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.base64.raw
            body = data.base64
        case .gzip(let data):
            extraHeaders["Content-Type"] = ContentType.gzip(name: name).raw
            extraHeaders["Content-Disposition"] = ContentDisposition.attachment(fileName: name).raw
            extraHeaders["Content-Transfer-Encoding"] = ContentTransferEncoding.base64.raw
            body = data.base64
        }

        return (body: body, extraHeaders: extraHeaders)
    }
}

private extension MimePart.MessageDeliveryStatus {
    init(body: String) throws {
        var originalRecipient: String?
        var finalRecipient: String?
        var foundStatus: String?

        let newLine: String
        if body.contains("\r\n") {
            newLine = "\r\n"
        }
        else {
            newLine = "\n"
        }

        for line in body.components(separatedBy: newLine) {
            let parts = line.components(separatedBy: ":")
            let remaining = parts[1...].joined(separator: ":").trimmingWhitespaceOnEnds
            switch parts[0].lowercased() {
            case "final-recipient":
                finalRecipient = MimePart.MessageDeliveryStatus.recipient(from: remaining)
            case "original-recipient":
                originalRecipient = MimePart.MessageDeliveryStatus.recipient(from: remaining)
            case "status":
                foundStatus = remaining
            default:
                continue
            }
        }

        guard let final = finalRecipient else {
            throw GenericSwiftlierError("parsing", because: "the delivery status is missing a final recipient")
        }

        guard let status = foundStatus else {
            throw GenericSwiftlierError("parsing", because: "the delivery status is missing a status")
        }


        self.finalRecipient = final
        self.status = status
        self.originalRecipient = originalRecipient
    }

    static func recipient(from string: String) -> String? {
        let components = string.components(separatedBy: ";")
        guard components.count >= 2 else {
            return nil
        }
        return components[1].trimmingWhitespaceOnEnds
    }
}

private extension String {
    enum PercentMode {
        case none, percent(String?)
    }

    func removingPercentEncoding(using encoding: String.Encoding) -> String? {
        var output = ""
        var mode = PercentMode.none

        func cancelEscape(_ first: String?) {
            output.append("%")
            if let first = first {
                output += "\(first)"
            }
            mode = .none
        }

        for character in self {
            switch character {
            case "%":
                switch mode {
                case .none:
                    mode = .percent(nil)
                case .percent(let first):
                    cancelEscape(first)
                }
            case "0","1","2","3","4","5","6","7","8","9", "A", "B", "C", "D", "E", "F":
                switch mode {
                case .none:
                    output.append(character)
                case .percent(let first):
                    guard let first = first else {
                        mode = .percent("\(character)")
                        break
                    }
                    let hexString = "\(first)\(character)"
                    let bytes = [UInt8(hexString, radix: 16)!]
                    let decoded = String(data: Data(bytes), encoding: encoding) ?? "?"
                    output += decoded
                }
            default:
                switch mode {
                case .none:
                    output.append(character)
                case let .percent(first):
                    cancelEscape(first)
                }
            }
        }
        return output
    }
}

private extension Array where Element == MimePart {
    func rawMIME(withBoundary boundary: String) -> String {
        var output = ""
        for part in self {
            output += "--\(boundary)\r\n\(part.raw)\r\n"
        }
        if !output.isEmpty {
            output += "--\(boundary)--"
        }
        return output
    }
}
