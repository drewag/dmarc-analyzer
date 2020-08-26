//
//  File.swift
//  
//
//  Created by Andrew J Wagner on 8/25/20.
//

import Foundation

enum ServerSpec {
    typealias RawValue = String

    case ipv4(UInt8, UInt8, UInt8, UInt8, UInt8?)
    case ipv6(IPV6Address)
    case unknown

    init(raw: String) {
        let dotComponents = raw.components(separatedBy: ".")
        guard dotComponents.count != 4 else {
            guard let first = UInt8(dotComponents[0]) else {
                self = .unknown
                return
            }
            guard let second = UInt8(dotComponents[1]) else {
                self = .unknown
                return
            }
            guard let third = UInt8(dotComponents[2]) else {
                self = .unknown
                return
            }
            let slashComponents = dotComponents[3].components(separatedBy: "/")
            guard let fourth = UInt8(slashComponents[0]) else {
                self = .unknown
                return
            }

            let mask: UInt8?
            switch slashComponents.count {
            case 1:
                mask = nil
            case 2:
                guard let possibleMask = UInt8(slashComponents[1]) else {
                    self = .unknown
                    return
                }
                mask = possibleMask
            default:
                self = .unknown
                return
            }

            self = .ipv4(first, second, third, fourth, mask)
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
        case let .ipv4(lOne, lTwo, lThree, lFour, lMask):
            switch ServerSpec(raw: ip) {
            case let .ipv4(rOne, rTwo, rThree, rFour, rMask):
                if let lMask = lMask {
                    if let rMask = rMask {
                        // Both have masks
                        return lOne == rOne && lTwo == rTwo && lThree == rThree && lFour == rFour && lMask == rMask
                    }
                    else {
                        return self.ipv4Range(lOne, lTwo, lThree, lFour, lMask, contains: rOne, ipSecond: rTwo, rThree, rFour)
                    }
                }
                else {
                    if let rMask = rMask {
                        return self.ipv4Range(rOne, rTwo, rThree, rFour, rMask, contains: lOne, ipSecond: lTwo, lThree, lFour)
                    }
                    else {
                        // Neither have masks
                        return lOne == rOne && lTwo == rTwo && lThree == rThree && lFour == rFour
                    }
                }
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
    func ipv4Range(
        _ rFirst: UInt8, _ rSecond: UInt8, _ rThird: UInt8, _ rFourth: UInt8, _ rMask: UInt8,
        contains ipFirst: UInt8, ipSecond: UInt8, _ ipThird: UInt8, _ ipFourth: UInt8
        ) -> Bool
    {
        let maskBits = rFirst.bits + rSecond.bits + rThird.bits + rFourth.bits
        let ipBits = ipFirst.bits + ipSecond.bits + ipThird.bits + ipFourth.bits
        guard rMask < maskBits.count else {
            return false
        }
        for i in 0 ..< Int(rMask) {
            if maskBits[i] != ipBits[i] {
                return false
            }
        }
        return true
    }
}

private extension UInt8 {
    var bits: [Bool] {
        return [
            128 & self != 0,
            64 & self != 0,
            32 & self != 0,
            16 & self != 0,
            8 & self != 0,
            4 & self != 0,
            2 & self != 0,
            1 & self != 0,
        ]
    }
}
