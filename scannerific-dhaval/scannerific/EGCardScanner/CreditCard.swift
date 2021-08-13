//
//  CreditCard.swift
//  
//
//  Created by Tyler Poland on 7/29/21.
//

import UIKit

public struct CreditCard {
    
    public var image: UIImage?
    public let cardNumber: String?
    public let expirationMonth: String?
    public let expirationYear: String?
    public let firstName: String?
    public let lastName: String?
    
    public var isValidCard: Bool {
        
        guard let cardNumber = cardNumber,
              expirationMonth != nil,
              expirationYear != nil,
              firstName != nil,
              lastName != nil else {
            return false
        }
        
        return isValidLuhn(cardNumber.filter("0123456789".contains))
    }
    
    public init(image: UIImage?,
                cardNumber: String?,
                expirationMonth: String?,
                expirationYear: String?,
                firstName: String?,
                lastName: String?) {
        self.image = image
        self.cardNumber = cardNumber
        self.expirationMonth = expirationMonth
        self.expirationYear = expirationYear
        self.firstName = firstName
        self.lastName = lastName
    }
    
    // ripped from the vrbo app
    private func isValidLuhn(_ number: String) -> Bool {
        var oddSum = 0, evenSum = 0
        for (i, s) in number.reversed().enumerated() {
            let digit = Int(String(s))!
            if i % 2 == 0 {
                evenSum += digit
            } else {
                oddSum += digit / 5 + (2 * digit) % 10
            }
        }
        guard (oddSum + evenSum) % 10 == 0 else {
            return false
        }
        return true
    }
}
