//
//  File.swift
//  
//
//  Created by Dhaval Sanjay Adhav on 7/30/21.
//

import Foundation

// Enum enlisting all types of errors
public enum CreditCardScannerError: Error {

    case authorizationDenied
    case captureError
    case cameraSetup
    case rectDetectError
}
