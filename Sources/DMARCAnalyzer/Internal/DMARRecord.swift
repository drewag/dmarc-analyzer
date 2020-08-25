//
//  File.swift
//  
//
//  Created by Andrew J Wagner on 8/25/20.
//

struct DMARCRecord {
    let sourceIP: String
    let passedDKIM: Bool
    let passedSPF: Bool
}
