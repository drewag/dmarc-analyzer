//
//  EmailMessage.swift
//  SwiftServe
//
//  Created by Andrew J Wagner on 2/23/18.
//

struct EmailMessage {
    let part: MimePart

    var headers: [CaseInsensitiveKey:String] {
        return self.part.headers
    }

    var subject: String? {
        return self.headers["subject"]
    }

    var to: [NamedEmailAddress]? {
        let raw = self.headers["to"]
        return NamedEmailAddress.addresses(from: raw)
    }

    var content: MimePart.Content {
        return self.part.content
    }

    init(raw: String) throws {
        self.part = try MimePart(rawContents: raw)
    }
}
