//
//  File.swift
//  
//
//  Created by Andrew J Wagner on 8/25/20.
//

public struct DMARCFailure {
    public enum Reason {
        case approvedServerFailedDKIM
        case approvedServerFailedSPF
        case approvedServerFailedFully

        case unapprovedServerPassedSPF
        case unapprovedServerPassedFully
    }

    public let sourceIp: String
    public let reason: Reason

    init(sourceIp: String, reason: Reason) {
        self.sourceIp = sourceIp
        self.reason = reason
    }
}
