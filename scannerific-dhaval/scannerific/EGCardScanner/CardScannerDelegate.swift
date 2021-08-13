//
//  CardScannerDelegate.swift
//  
//
//  Created by Tyler Poland on 7/29/21.
//

import Foundation

///
public protocol CardScannerDelegate: AnyObject {
    ///
    func scanner(didFinishWith results: Result<CreditCard, Error>)
}
