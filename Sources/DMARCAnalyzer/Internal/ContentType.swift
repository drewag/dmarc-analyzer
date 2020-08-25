//
//  ContentType.swift
//  file-sync-services
//
//  Created by Andrew J Wagner on 4/16/17.
//
//

import Foundation

enum ContentType {
    case pdf
    case png
    case jpg
    case octetStream
    case csv
    case json(String.Encoding)
    case mp4
    case html(String.Encoding)
    case plainText(String.Encoding)
    case zip(name: String?)
    case gzip(name: String?)
    case deliveryStatus
    case email

    case multipartFormData(boundary: String)
    case multipartAlternative(boundary: String)
    case multipartMixed(boundary: String)
    case multipartRelated(boundary: String)
    case multipartReport(boundary: String, reportType: String)

    case none
    case other(String)

    init(_ string: String?) {
        guard let string = string else {
            self = .none
            return
        }

        var parts = string.components(separatedBy: ";")

        switch parts.removeFirst().trimmingWhitespaceOnEnds.lowercased() {
        case "multipart/form-data" where parts.count > 0:
            let remaining = parts.joined(separator: ";")
            guard let boundary = StructuredHeader.parse(remaining)["boundary"] else {
                self = .other(string)
                return
            }
            self = .multipartFormData(boundary: boundary)
        case "multipart/alternative" where parts.count > 0:
            let remaining = parts.joined(separator: ";")
            guard let boundary = StructuredHeader.parse(remaining)["boundary"] else {
                self = .other(string)
                return
            }
            self = .multipartAlternative(boundary: boundary)
        case "multipart/mixed" where parts.count > 0:
            let remaining = parts.joined(separator: ";")
            guard let boundary = StructuredHeader.parse(remaining)["boundary"] else {
                self = .other(string)
                return
            }
            self = .multipartMixed(boundary: boundary)
        case "multipart/related" where parts.count > 0:
            let remaining = parts.joined(separator: ";")
            guard let boundary = StructuredHeader.parse(remaining)["boundary"] else {
                self = .other(string)
                return
            }
            self = .multipartRelated(boundary: boundary)
        case "multipart/report" where parts.count > 0:
            let remaining = parts.joined(separator: ";")
            let parsedHeader = StructuredHeader.parse(remaining)
            guard let boundary = parsedHeader["boundary"] else {
                self = .other(string)
                return
            }
            guard let reportType = parsedHeader["report-type"] else {
                self = .other(string)
                return
            }
            self = .multipartReport(boundary: boundary, reportType: reportType)
        case "text/html":
            let remaining = parts.joined(separator: ";")
            var encoding: String.Encoding = .utf8
            if let encodingString = StructuredHeader.parse(remaining)["charset"] {
                encoding = String.Encoding(string: encodingString)
            }
            self = .html(encoding)
        case "text/plain":
            let remaining = parts.joined(separator: ";")
            var encoding: String.Encoding = .utf8
            if let encodingString = StructuredHeader.parse(remaining)["charset"] {
                encoding = String.Encoding(string: encodingString)
            }
            self = .plainText(encoding)
        case "application/zip", "application/x-zip-compressed":
            let remaining = parts.joined(separator: ";")
            self = .zip(name: StructuredHeader.parse(remaining)["name"])
        case "application/gzip":
            let remaining = parts.joined(separator: ";")
            self = .gzip(name: StructuredHeader.parse(remaining)["name"])
        case "application/pdf":
            self = .pdf
        case "application/json":
            let remaining = parts.joined(separator: ";")
            var encoding: String.Encoding = .utf8
            if let encodingString = StructuredHeader.parse(remaining)["charset"] {
                encoding = String.Encoding(string: encodingString)
            }
            self = .json(encoding)
        case "video/mp4":
            self = .mp4
        case "application/octet-stream":
            self = .octetStream
        case "text/csv":
            self = .csv
        case "message/delivery-status":
            self = .deliveryStatus
        case "message/rfc822":
            self = .email
        case "image/jpg", "image/jpeg":
            self = .jpg
        case "image/png":
            self = .png
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
        case .csv:
            return "text/csv"
        case .deliveryStatus:
            return "message/delivery-status"
        case .html(let encoding):
            return "text/html; charset=\(encoding.raw)"
        case .jpg:
            return "image/jpeg"
        case .multipartAlternative(let boundary):
            return "multipart/alternative; boundary=\(boundary)"
        case .multipartFormData(let boundary):
            return "multipart/form-data; boundary=\(boundary)"
        case .multipartMixed(let boundary):
            return "multipart/mixed; boundary=\(boundary)"
        case .multipartRelated(let boundary):
            return "multipart/related; boundary=\(boundary)"
        case .multipartReport(let boundary, let reportType):
            return "multipart/report; boundary=\(boundary); report-type=\(reportType)"
        case .none:
            return nil
        case .octetStream:
            return "application/octet-stream"
        case .other(let other):
            return other
        case .pdf:
            return "application/pdf"
        case .mp4:
            return "video/mp4"
        case .plainText(let encoding):
            return "text/plain; charset=\(encoding.raw)"
        case .json(let encoding):
            return "application/json;  charset=\(encoding.raw)"
        case .png:
            return "image/png"
        case .email:
            return "message/rfc822"
        case .zip(let name):
            var output = "application/zip"
            if let name = name {
                output += "; name=\(name)"
            }
            return output
        case .gzip(let name):
            var output = "application/gzip"
            if let name = name {
                output += "; name=\(name)"
            }
            return output
        }
    }
}

extension String.Encoding {
    init(string: String) {
        switch string.lowercased() {
        case "us-ascii":
            self = .ascii
        case "windows-1252":
            self = .windowsCP1252
        default:
            self = .utf8
        }
    }

    var raw: String {
        switch self {
        case .ascii:
            return "us-ascii"
        case .windowsCP1252:
            return "windows-1252"
        default:
            return "utf-8"
        }
    }
}

extension ContentType: Equatable {
    static func ==(lhs: ContentType, rhs: ContentType) -> Bool {
        switch lhs {
        case .pdf:
            switch rhs {
            case .pdf:
                return true
            default:
                return false
            }
        case .json:
            switch rhs {
            case .json:
                return true
            default:
                return false
            }
        case .mp4:
            switch rhs {
            case .mp4:
                return true
            default:
                return false
            }
        case .email:
            switch rhs {
            case .email:
                return true
            default:
                return false
            }
        case .png:
            switch rhs {
            case .png:
                return true
            default:
                return false
            }
        case .jpg:
            switch rhs {
            case .jpg:
                return true
            default:
                return false
            }
        case .html:
            switch rhs {
            case .html:
                return true
            default:
                return false
            }
        case .deliveryStatus:
            switch rhs {
            case .deliveryStatus:
                return true
            default:
                return false
            }
        case .csv:
            switch rhs {
            case .csv:
                return true
            default:
                return false
            }
        case .plainText:
            switch rhs {
            case .plainText:
                return true
            default:
                return false
            }
        case .octetStream:
            switch rhs {
            case .octetStream:
                return true
            default:
                return false
            }
        case .multipartReport:
            switch rhs {
            case .multipartReport:
                return true
            default:
                return false
            }
        case .multipartFormData:
            switch rhs {
            case .multipartFormData:
                return true
            default:
                return false
            }
        case .zip:
            switch rhs {
            case .zip:
                return true
            default:
                return false
            }
        case .gzip:
            switch rhs {
            case .gzip:
                return true
            default:
                return false
            }
        case .multipartMixed:
            switch rhs {
            case .multipartMixed:
                return true
            default:
                return false
            }
        case .multipartAlternative:
            switch rhs {
            case .multipartAlternative:
                return true
            default:
                return false
            }
        case .multipartRelated:
            switch rhs {
            case .multipartRelated:
                return true
            default:
                return false
            }
        case .none:
            switch rhs {
            case .none:
                return true
            default:
                return false
            }
        case .other(let left):
            switch rhs {
            case .other(let right):
                return left == right
            default:
                return false
            }
        }
    }
}
