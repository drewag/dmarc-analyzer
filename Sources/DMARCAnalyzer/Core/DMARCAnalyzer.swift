//
//  File.swift
//  
//
//  Created by Andrew J Wagner on 8/25/20.
//

import Foundation
import Swiftlier

public struct DMARCAnalyzer {
    private let domain: String
    private let xml: XML
    public let options: DMARCAnalysisOptions

    public enum Analysis {
        case good(orgName: String)
        case bad(orgName: String, [DMARCFailure])
    }

    public init(domain: String, report: Data, options: Data) throws {
        self.domain = domain
        self.xml = try XML(report)
        self.options = try JSONDecoder().decode(DMARCAnalysisOptions.self, from:  options)
    }

    func analyze() throws -> Analysis {
        let (orgName, records) = try xml.parseDMARC()
        var failures = [DMARCFailure]()
        for record in records {
            let isApprovedServer = self.options.approves(ip: record.sourceIP, forDomain: self.domain)
            switch (isApprovedServer, record.passedSPF, record.passedDKIM) {
            case (true, true, true):
                // Approved server fully passed
                continue
            case (true, false, false):
                failures.append(.init(
                    sourceIp: record.sourceIP,
                    reason: .approvedServerFailedFully
                ))
            case (true, false, true):
                failures.append(.init(
                    sourceIp: record.sourceIP,
                    reason: .approvedServerFailedSPF
                ))
            case (true, true, false):
                failures.append(.init(
                    sourceIp: record.sourceIP,
                    reason: .approvedServerFailedDKIM
                ))
            case (false, false, false):
                // Don't need to report if an unapproved server is failing fully
                continue
            case (false, true, false):
                failures.append(.init(
                    sourceIp: record.sourceIP,
                    reason: .unapprovedServerPassedSPF
                ))
            case (false, false, true):
                // Forwarded email (ok)
                continue
            case (false, true, true):
                failures.append(.init(
                    sourceIp: record.sourceIP,
                    reason: .unapprovedServerPassedFully
                ))
            }
        }
        if failures.isEmpty {
            return .good(orgName: orgName)
        }
        return .bad(orgName: orgName, failures)
    }
}

private extension XML {
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
