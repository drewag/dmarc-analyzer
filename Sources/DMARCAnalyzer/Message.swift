//
//  Message.swift
//  dmarc-analyzer
//
//  Created by Andrew J Wagner on 2/22/18.
//

import Foundation
import Swiftlier
import SwiftServe

struct Message: CustomStringConvertible, ErrorGenerating, Codable {
    //    let path: FilePath

    let headers: [String:String]

    let messageId: String
    let from: Person
    let to: [Person]?
    let date: Date
    let returnPath: String?
    let references: [String]

    var subject: String? {
        return self.headers["subject"]
    }

    enum Content {
        case plain(String)
        case html(String)
    }
    let content: Content

    struct Attachment: Codable {
        let name: String
        let data: Data
    }
    let attachments: [Attachment]

    var description: String {
        var output = "\(date.iso8601DateTime) \(messageId) '\(from)' -> "
        if let to = to {
            output += to.map({$0.description}).joined(separator: ", ")
        }
        return output
    }

    init(path: FilePath) throws {
        //        print("=================================================================")

        //        self.path = path

        guard let contents = (try? path.string()) ?? nil else {
            throw Message.error("processing", because: "The contents could not be loaded from \(path)")
        }

        try self.init(contents: contents)
    }

    init(contents: String) throws {
        var headers = [String:String]()
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

        let newline: String
        if contents.contains("\r\n") {
            newline = "\r\n"
        }
        else {
            newline = "\n"
        }

        for line in contents.components(separatedBy: newline) {
            guard !startedBody else {
                body += "\n" + line
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

        guard let messageId = headers["message-id"] else {
            throw Message.error("processing", because: "A 'message id' could not be found from \(headers["message-id"] ?? "NONE").")
        }

        guard let from = Person(headers["from"]) else {
            throw Message.error("processing", because: "A 'from' could not be found from \(headers["from"] ?? "NONE").")
        }

        if let toHeader = headers["to"] {
            guard let to = Person.people(from: toHeader) else {
                throw Message.error("processing", because: "An invalid 'to' was found from \(toHeader).")
            }
            self.to = to
        }
        else {
            self.to = nil
        }

        guard let date = Message.date(from: headers["date"]) else {
            throw Message.error("processing", because: "An invalid 'date' was found from \(headers["date"] ?? "NONE").")
        }

        if let rawReferences = headers["references"] {
            self.references = rawReferences.components(separatedBy: " ").filter({!$0.isEmpty})
        }
        else {
            self.references = []
        }

        (self.content, self.attachments) = try Message.content(
            from: body,
            contentType: ContentType(headers["content-type"]),
            transferEncoding: ContentTransferEncoding(headers["content-transfer-encoding"])
        )

        self.date = date
        self.messageId = messageId
        self.from = from
        self.returnPath = headers["return-path"]

        self.headers = headers
    }
}

private extension Message {
    static var dateFormatters: [DateFormatter] {
        var formatters = [DateFormatter]()

        // Wed, 6 Sep 2017 01:27:00 +0000
        var formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss x"
        formatters.append(formatter)

        // Tue,  9 Jan 2018 08:12:06 -0700 (MST)
        formatter = DateFormatter()
        formatter.dateFormat = "E, d MMM yyyy HH:mm:ss x '('z')'"
        formatters.append(formatter)

        return formatters
    }

    static func date(from string: String?) -> Date? {
        guard let string = string?.trimmingWhitespaceOnEnds else {
            return nil
        }

        for formatter in self.dateFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    static func content(from body: String, contentType: ContentType, transferEncoding: ContentTransferEncoding) throws -> (Content, [Attachment]) {
        func processMultipartMixed(boundary: String) throws -> (Content, [Attachment]) {
            var attachments = [Attachment]()
            var plain: String?
            var html: String?
            let trimmed = body.trimmingWhitespaceOnEnds
            for part in MultiFormPart.parts(in: trimmed.data(using: .utf8) ?? Data(), usingBoundary: boundary) {
                switch part.contentType ?? .none {
                case .plainText, .none:
                    if let existing = html {
                        html = existing + "<p>" + (part.contents ?? "") + "</p>"
                    }
                    else {
                        plain = part.contents ?? ""
                    }
                case .html:
                    if let existing = html {
                        html = existing + (part.contents ?? "")
                    }
                    else {
                        html = part.contents ?? ""
                    }
                case .octetStream:
                    switch part.contentDisposition {
                    case .none, .inline:
                        attachments.append(Attachment(name: "unknown.bin", data: part.parsedBody))
                    case .attachment(fileName: let fileName):
                        attachments.append(Attachment(name: fileName ?? "unknown.bin", data: part.parsedBody))
                    case .other(let string):
                        throw self.error("processing", because: "An unknown octet stream disposition was found '\(string)'.")
                    }
                case .zip(let name):
                    attachments.append(Attachment(name: name ?? "unknown.zip", data: part.parsedBody))
                case .multipartAlternative(boundary: let innerBoundary):
                    for part in MultiFormPart.parts(in: part.parsedBody, usingBoundary: innerBoundary) {
                        let (content, _) = try self.content(from: part.contents ?? "", contentType: part.contentType ?? .none, transferEncoding: part.contentTransferEncoding)
                        switch content {
                        case .html(let content):
                            html = content
                        case .plain(let content):
                            plain = content
                        }
                    }
                default:
                    continue
                }
            }
            if let plain = plain {
                return (.plain(plain), attachments)
            }
            else if let html = html {
                return (.html(html), attachments)
            }
            else {
                throw self.error("processing", because: "A plain text nor an html version could be found.")
            }
        }

        switch contentType {
        case .none:
            return (.plain(String(string: body, transferEncoding: transferEncoding, characterEncoding: .utf8)), [])
        case .plainText(let encoding):
            return (.plain(String(string: body, transferEncoding: transferEncoding, characterEncoding: encoding)), [])
        case .html(let encoding):
            return (.html(String(string: body, transferEncoding: transferEncoding, characterEncoding: encoding)), [])
        case .zip(let name):
            let base64Data = body.data(using: .ascii) ?? Data()
            let body = Data(data: base64Data, transferEncoding: transferEncoding, characterEncoding: .ascii)
            return (.plain(""), [Attachment(name: name ?? "unknown.zip", data: body)])
        case .multipartAlternative(boundary: let boundary):
            var html: String? = nil
            var plain: String? = nil
            let trimmed = body.trimmingWhitespaceOnEnds
            for part in MultiFormPart.parts(in: trimmed.data(using: .utf8) ?? Data(), usingBoundary: boundary) {
                switch part.contentType ?? .none {
                case .plainText, .none:
                    plain = part.contents ?? ""
                case .html:
                    html = part.contents ?? ""
                default:
                    continue
                }

            }
            if let plain = plain {
                return (.plain(plain), [])
            }
            else if let html = html {
                return (.html(html), [])
            }
            else {
                throw self.error("processing", because: "A plain text nor an html version could be found.")
            }
        case .multipartMixed(boundary: let boundary):
            return try processMultipartMixed(boundary: boundary)
        case .multipartRelated(boundary: let boundary):
            return try processMultipartMixed(boundary: boundary)
        default:
            throw self.error("processing", because: "An invalid 'content type' was found \(contentType).")
        }
    }
}

extension Message.Attachment {
    var contentType: String {
        guard let ext = self.name.components(separatedBy: ".").last else {
            return "application/octet-stream"
        }

        switch ext {
        case "csv":
            return "text/csv"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "html", "htm":
            return "text/html"
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        default:
            return "application/octet-stream"
        }
    }
}

extension Message.Content: Codable {
    enum CodingKeys: String, CodingKey {
        case kind
        case content
    }

    var html: String {
        switch self {
        case .plain(let plain):
            let lines = plain.trimmingWhitespaceOnEnds.components(separatedBy: "\n")
                .map({ line in
                    if line.isEmpty {
                        return "<br />"
                    }
                    else {
                        return line
                    }
                })
                .joined(separator: "</p><p>")
            return "<p>" + lines + "</p>"
        case .html(let html):
            return html
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let content = try container.decode(String.self, forKey: .content)
        let kind = try container.decode(Int.self, forKey: .kind)
        switch kind {
        case 0:
            self = .plain(content)
        case 1:
            self = .html(content)
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown content type: \(kind)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .plain(let content):
            try container.encode(0, forKey: .kind)
            try container.encode(content, forKey: .content)
        case .html(let content):
            try container.encode(1, forKey: .kind)
            try container.encode(content, forKey: .content)
        }
    }
}

