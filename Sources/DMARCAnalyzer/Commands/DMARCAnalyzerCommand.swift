//
//  DMARCAnalyzerCommand.swift
//  DMARCAnalyzer
//
//  Created by Andrew J Wagner on 2/22/18.
//

import Foundation
import Swiftlier
import SWCompression
import CommandLineParser

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

        let domain = emailMessage.to?.first?.email.domain ?? ""
        let analyzer = try DMARCAnalyzer(domain: domain, report: xmlData, options: try optionsFile.contents())
        switch try analyzer.analyze() {
        case .good:
            break
        case let .bad(orgName, failures):
            Email(
                to: analyzer.options.problemEmail.string,
                subject: "Problematic \(domain) DMARC Report",
                from: analyzer.options.sourceEmail.string,
                build: { builder in
                    builder.appendAttachment(withContent: .email(raw: rawEmail), named: "original-report.eml")

                    builder.append(html: "<h1>Problems with \(domain) from \(orgName):</h1><table>")
                    builder.append(html: "<tr><th>IP Address</th><th>Is Approved Server</th><th>Problem</th></tr>")

                    for failure in failures {
                        func appendRecord(withProblem problem: String, isApproved: Bool) {
                            builder.append(html: "<tr><td><a href='https://mxtoolbox.com/SuperTool.aspx?action=ptr%3a\(failure.sourceIp)&run=toolpage'>\(failure.sourceIp)</a></td><td>\(isApproved ? "Yes" : "No")</td><td>\(problem)</td></tr>")
                        }

                        switch failure.reason {
                        case .approvedServerFailedFully:
                            appendRecord(withProblem: "Approved server is failing both verifications.", isApproved: true)
                        case .approvedServerFailedSPF:
                            appendRecord(withProblem: "Not included in the SPF record.", isApproved: true)
                        case .approvedServerFailedDKIM:
                            appendRecord(withProblem: "Not signed with DKIM properly.", isApproved: true)
                        case .unapprovedServerPassedFully:
                            appendRecord(withProblem: "This unapproved server is passing fully.", isApproved: false)
                        case .unapprovedServerPassedSPF:
                            appendRecord(withProblem:  "Spam server included in SPF record.", isApproved: false)
                        }
                    }

                    builder.append(html: "</table>")
                }
            ).send()
        }
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
