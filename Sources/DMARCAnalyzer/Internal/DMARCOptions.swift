//
//  File.swift
//  
//
//  Created by Andrew J Wagner on 8/25/20.
//

import Swiftlier

public struct DMARCAnalysisOptions: Decodable {
    public let sourceEmail: EmailAddress
    public let problemEmail: EmailAddress
    let approvedServers: [ServerSpec]
    let domainSpecificServers: [String:[ServerSpec]]?

    func approves(ip: String, forDomain domain: String) -> Bool {
        let approvedIps = self.approvedServers + (self.domainSpecificServers?[domain] ?? [])
        for approved in approvedIps {
            if approved.matches(ip: ip) {
                return true
            }
        }
        return false
    }
}
