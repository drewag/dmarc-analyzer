//
//  DMARCAnalyzerCommand.swift
//  DMARCAnalyzer
//
//  Created by Andrew J Wagner on 2/22/18.
//

import Foundation
import Swiftlier
import SwiftServe
import SWCompression
import CommandLineParser

struct DMARCAnalysisOptions {
    let sourceEmail: EmailAddress
    let problemEmail: EmailAddress
    let approvedServers: [String]
    let domainSpecificServers: [String:[String]]?
}

public struct DMARCAnalyzerCommand: CommandHandler {
    public static let name = "analyze-dmarc"
    public static let shortDescription: String? = "Analyze passed in DMARC report emails"
    public static let longDescription: String? = nil

    public static func handler(parser: Parser) throws {
        let optionsPath = parser.string(named: "options-path")
        let path = parser.optionalString(named: "email-path")

        try parser.parse()

        let optionsUrl = URL(fileURLWithPath: optionsPath.parsedValue)
        guard let optionsFile = FileSystem.default.path(from: optionsUrl).file else {
            throw GenericSwiftlierError("analyzing", because: "options file not found exist")
        }
        let decoder = JSONDecoder()
        let options = try decoder.decode(DMARCAnalysisOptions.self, from:  try optionsFile.contents())

        let rawEmail: String
        if let filePath = path.parsedValue {
            let fileUrl = URL(fileURLWithPath: filePath)
            guard let file = FileSystem.default.path(from: fileUrl).file else {
                throw GenericSwiftlierError("analyzing", because: "email file does not exist")
            }
            rawEmail = try file.string() ?? ""
        }
        else {
            let handle = FileHandle.standardInput
            var data = Data()
            while true {
                let read = handle.availableData
                guard !read.isEmpty else {
                    break
                }
                data.append(read)
            }

            guard let contents = String(data: data, encoding: .ascii) else {
                throw GenericSwiftlierError("analyzing", because: "error converting input to a string")
            }
            rawEmail = contents
        }

        let emailMessage = try EmailMessage(raw: rawEmail)

        guard let xmlData = try emailMessage.xmlData() else {
            throw GenericSwiftlierError("analyzing", because: "no xml file found")
        }

        let xml = try XML(xmlData)
        let domain = emailMessage.to?.first?.email.domain ?? ""
        let (orgName, records) = try xml.parseDMARC()

        var isAllGood = true
        let email = Email(
            to: options.problemEmail.string,
            subject: "Problematic \(domain) DMARC Report",
            from: options.sourceEmail.string,
            build: { builder in
                builder.appendAttachment(withContent: .email(raw: rawEmail), named: "original-report.eml")

                builder.append(html: "<h1>Problems with \(domain) from \(orgName):</h1><table>")
                builder.append(html: "<tr><th>IP Address</th><th>Is Approved Server</th><th>Problem</th></tr>")

                for record in records {
                    let isApproved = options.approves(ip: record.sourceIP, forDomain: domain)

                    func appendRecord(withProblem problem: String) {
                        isAllGood = false
                        builder.append(html: "<tr><td><a href='https://mxtoolbox.com/SuperTool.aspx?action=ptr%3a\(record.sourceIP)&run=toolpage'>\(record.sourceIP)</a></td><td>\(isApproved ? "Yes" : "No")</td><td>\(problem)</td></tr>")
                    }

                    switch (record.passedSPF, record.passedDKIM) {
                    case (true, true):
                        if !isApproved {
                            appendRecord(withProblem: "This unapproved server is passing fully.")
                        }
                        else {
                            // Full pass of approved server (expected)
                        }
                    case (false, true):
                        if isApproved {
                            appendRecord(withProblem: "Not included in the SPF record.")
                        }
                        else {
                            // Forwarded email (ok)
                        }
                    case (true, false):
                        if isApproved {
                            appendRecord(withProblem: "Not signed with DKIM properly.")
                        }
                        else {
                            appendRecord(withProblem: "Spam server included in SPF record.")
                        }
                    case (false, false):
                        if isApproved {
                            appendRecord(withProblem: "Approved server is failing both verifications.")
                        }
                        else {
                            appendRecord(withProblem: "SPAM (fully failed)")
                        }
                    }
                }

                builder.append(html: "</table>")
            }
        )

        if !isAllGood {
            email.send()
        }
    }
}

fileprivate extension DMARCAnalysisOptions {
    func approves(ip: String, forDomain domain: String) -> Bool {
        let approvedIps = self.approvedServers + (self.domainSpecificServers?[domain] ?? [])
        for approved in approvedIps {
            if self.ip(approved, matches: ip) {
                return true
            }
        }
        return false
    }

    enum IPVersion {
        case v4(String, String, String, String)
        case v6(String, String, String, String, String, String, String, String)
        case unknown

        init(_ ip: String) {
            let dotComponents = ip.components(separatedBy: ".")
            guard dotComponents.count != 4 else {
                self = .v4(dotComponents[0], dotComponents[1], dotComponents[2], dotComponents[3])
                return
            }

            let colonComponents = ip.components(separatedBy: ":")
            guard colonComponents.count != 8 else {
                self = .v6(colonComponents[0], colonComponents[1], colonComponents[2], colonComponents[3], colonComponents[4], colonComponents[5], colonComponents[6], colonComponents[7])
                return
            }
            self = .unknown
        }
    }

    func ip(_ lhs: String, matches rhs: String) -> Bool {
        switch IPVersion(lhs) {
        case .unknown:
            return false
        case let .v4(lOne, lTwo, lThree, lFour):
            switch IPVersion(rhs) {
            case let .v4(rOne, rTwo, rThree, rFour):
                return self.components(
                    [lOne, lTwo, lThree, lFour],
                    match: [rOne, rTwo, rThree, rFour]
                )
            default:
                return false
            }
        case let .v6(lOne, lTwo, lThree, lFour, lFive, lSix, lSeven, lEight):
            switch IPVersion(rhs) {
            case let .v6(rOne, rTwo, rThree, rFour, rFive, rSix, rSeven, rEight):
                return self.components(
                    [lOne, lTwo, lThree, lFour, lFive, lSix, lSeven, lEight],
                    match: [rOne, rTwo, rThree, rFour, rFive, rSix, rSeven, rEight]
                )
            default:
                return false
            }
        }
    }

    // Assumes two sides have same count
    private func components(_ lhs: [String], match rhs: [String]) -> Bool {
        for index in 0 ..< lhs.count {
            if lhs[index].lowercased() == "x" || rhs[index].lowercased() == "x" {
                return true
            }
            guard lhs[index].lowercased() == rhs[index].lowercased() else {
                return false
            }
        }
        return true
    }
}

fileprivate extension XML {
    struct DMARCRecord {
        let sourceIP: String
        let passedDKIM: Bool
        let passedSPF: Bool
    }

    func parseDMARC() throws -> (orgName: String, records: [DMARCRecord]) {
        guard let feedback = self["feedback"] else {
            throw GenericSwiftlierError("parsing DMARC", because: "no feedback element was found in the xml")
        }

        var output = [DMARCRecord]()
        for record in feedback["record"]?.array ?? [] {
            guard let row = record["row"]
                , let sourceIP = row["source_ip"]?.string
                , let evaluated = row["policy_evaluated"]
                , let dkim = evaluated["dkim"]?.string
                , let spf = evaluated["spf"]?.string
                else
            {
                continue
            }

            output.append(DMARCRecord(sourceIP: sourceIP, passedDKIM: (dkim == "pass"), passedSPF: (spf == "pass")))
        }
        if let row = feedback["record"]?.dictionary?["row"]
            , let sourceIP = row["source_ip"]?.string
            , let evaluated = row["policy_evaluated"]
            , let dkim = evaluated["dkim"]?.string
            , let spf = evaluated["spf"]?.string
        {
            output.append(DMARCRecord(sourceIP: sourceIP, passedDKIM: (dkim == "pass"), passedSPF: (spf == "pass")))
        }
        return (orgName: feedback["report_metadata"]?["org_name"]?.string ?? "Unknown", records: output)
    }
}

private extension EmailMessage {
    func xmlData() throws -> Data? {
        guard let part = self.part.part(ofType: .zip(name: nil))
            ?? self.part.part(ofType: .gzip(name: nil))
            else
        {
            return nil
        }

        switch part.content {
        case .gzip(let data):
            return try GzipArchive.unarchive(archive: data)
        case .zip(let data):
            guard let xmlEntry = (try? ZipContainer.open(container: data).first(where: {$0.info.name.hasSuffix(".xml")})) ?? nil else {
                throw GenericSwiftlierError("analyzing", because: "no xml found in zip")
            }
            guard let xmlData = xmlEntry.data else {
                throw GenericSwiftlierError("analyzing", because: "problem unzipping xml")
            }
            return xmlData
        default:
            return nil
        }
    }
}

extension DMARCAnalysisOptions: Decodable {
    enum CodingKeys: String, CodingKey {
        case sourceEmail, problemEmail, approvedServers, domainSpecificServers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.sourceEmail = try EmailAddress(userString: container.decode(String.self, forKey: .sourceEmail), for: "analyzing")
        self.problemEmail = try EmailAddress(userString: container.decode(String.self, forKey: .problemEmail), for: "analyzing")
        self.approvedServers = try container.decode([String].self, forKey: .approvedServers)
        self.domainSpecificServers = try container.decodeIfPresent([String:[String]].self, forKey: .domainSpecificServers)
    }
}
