//
//  File.swift
//  
//
//  Created by Andrew J Wagner on 8/25/20.
//

enum ServerSpec {
    typealias RawValue = String

    case ipv4(String, String, String, String)
    case ipv6(IPV6Address)
    case unknown

    init(raw: String) {
        let dotComponents = raw.components(separatedBy: ".")
        guard dotComponents.count != 4 else {
            self = .ipv4(dotComponents[0], dotComponents[1], dotComponents[2], dotComponents[3])
            return
        }

        do {
            let address = try IPV6Address(string: raw)
            self = .ipv6(address)
        }
        catch {
            self = .unknown
        }
    }

    func matches(ip: String) -> Bool {
        switch self {
        case .unknown:
            return false
        case let .ipv4(lOne, lTwo, lThree, lFour):
            switch ServerSpec(raw: ip) {
            case let .ipv4(rOne, rTwo, rThree, rFour):
                return self.components(
                    [lOne, lTwo, lThree, lFour],
                    match: [rOne, rTwo, rThree, rFour]
                )
            default:
                return false
            }
        case let .ipv6(lAddress):
            switch ServerSpec(raw: ip) {
            case let .ipv6(rAddress):
                return rAddress.normalized == lAddress.normalized
            default:
                return false
            }
        }
    }
}

extension ServerSpec: Decodable {
    init(from decoder: Decoder) throws {
        self.init(raw: try decoder.singleValueContainer().decode(String.self))
    }
}

private extension ServerSpec {
    // Assumes two sides have same count
    func components(_ lhs: [String], match rhs: [String]) -> Bool {
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
