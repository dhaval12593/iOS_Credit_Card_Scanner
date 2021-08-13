//
//  CardType.swift
//  scannerific
//
//  Created by Dhaval Sanjay Adhav on 7/31/21.
//

import Foundation

public enum CardType: String {
    
    case visa
    case mastercard
    case amex
    case discover
    case unknown
    
    internal var regex: NSRegularExpression? {
        switch self {
        case .amex:
            return try? NSRegularExpression(pattern: "^(\\d{4})\\s(\\d{6})\\s(\\d{5})$", options: [])
        case .visa:
            return try? NSRegularExpression(pattern: "^((\\d\\s?){13,19})$", options: [])
        case .mastercard:
            return try? NSRegularExpression(pattern: "^((\\d\\s?){16})$", options: [])
        case .discover:
            return try? NSRegularExpression(pattern: "^((\\d\\s?){16})$", options: [])
        default:
            return nil
        }
    }
}
