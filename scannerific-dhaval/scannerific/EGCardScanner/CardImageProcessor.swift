//
//  CardImageProcessor.swift
//
//
//  Created by Tyler Poland on 7/29/21.
//
import Combine
import UIKit
import Vision

@available(iOS 13.0, *)
internal class CardImageProcessor {
    
    public var subject = PassthroughSubject<CreditCard, Error>()
    
    private let processingWorkQueue = DispatchQueue(label: "ProcessImageQueue",
                                            qos: .userInitiated,
                                            attributes: [],
                                            autoreleaseFrequency: .workItem,
                                            target: nil)
    
    // Ignore dashes and spaces. The only validation is that there
    // are between 13 and 16 digits.
    private let creditCardRegexString = "\\b(?:\\d[ -]*?){13,16}\\b"
    
    // Matches 06/21, 06/2021, etc.
    private let expirationDateRegex = "(0[1-9]|1[0-2]|[1-9])/(1[4-9]|[2-9][0-9]|20[1-9][1-9])$"

    // Matches alphabetical strings with at least one space between them.
    // Takes into account some punctuation.
    private let nameRegex = "^[a-zA-Z\\.\\'\\-]{2,50}(?: [a-zA-Z\\.\\'\\-]{2,50})+$"

    // skip words which are not needed
    let wordsToSkip = ["mastercard", "jcb", "visa", "express", "bank", "card", "discover"]

    // MARK: - init
    public init() {}
    
    // MARK: - methods
    
    public func process(image: UIImage) {
        
        guard let cgImage = image.cgImage else {
            // TO DO: handle error case
            return
        }
        
        // build the request handler
        let vnImageRequestHandler = VNImageRequestHandler(cgImage: cgImage)
        
        processingWorkQueue.async { [weak self] in
            do {
                
                // configure the request
                let request = VNRecognizeTextRequest(){ [weak self] (request, error) in
                    guard let self = self,
                          let results = request.results,
                          !results.isEmpty,
                          let vnRecognizedTextOservations = results as? [VNRecognizedTextObservation] else {
                              return
                          }
                    
                    let typeOfCard = self.getTypeofCard(from: vnRecognizedTextOservations)
                    
                    if var info = self.getCreditCardInfo(from: vnRecognizedTextOservations,
                                                         cardType: typeOfCard) {
                        info.image = image
                        self.subject.send(info)
                    }
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.customWords = ["GOOD", "THRU", "EXPIRY", "DATE", "REWARDS"]

                try vnImageRequestHandler.perform([request])

            } catch {
                print(error)
                self?.subject.send(completion: .failure(CreditCardScannerError.captureError))
            }
        }
    }

    private func getCreditCardInfo(from observations: [VNRecognizedTextObservation], cardType: CardType? = nil) -> CreditCard? {

        var cardNumber: String?
        var expirationMonth: String?
        var expirationYear: String?
        var firstName: String?
        var lastName: String?

        for observation in observations {
            guard let firstTopCandidate = observation.topCandidates(1).first else {
                continue
            }

            let stringValue = firstTopCandidate.string

            // if the stringValue is of the skipped words then continue to next observation
            if wordsToSkip.contains(stringValue) {
                continue
            }

            // check if the extracted value is important to us
            
            
            // if we have cardType then use that regex otherwise default to regular Card Regex
            let cardRegex = cardType?.regex ?? (try? NSRegularExpression(pattern: creditCardRegexString, options: []))
            
            // check if the extracted text is a credit card number
            if let cardRegex = cardRegex,
                   cardRegex.firstMatch(in: stringValue, options: [], range: NSRange(location: 0, length: stringValue.count)) != nil {
                cardNumber = stringValue
            } else if let expiration = try? NSRegularExpression(
                        pattern: expirationDateRegex,
                        options: []),
                      let _ = expiration.firstMatch(in: stringValue,
                                                    options: [],
                                                    range: NSRange(location: 0,
                                                                   length: stringValue.count)) {
                // expiry date is often prefixed by text like "good thru" or "expiry date"
                // we need to remove that text
                let truncatedExpiryDateText = getExpiryDate(from: stringValue)

                let components = truncatedExpiryDateText.components(separatedBy: "/")

                // assuming first component is a month
                if let month = components.first {
                    expirationMonth = month
                }

                // assuming last component is a year
                if let year = components.last {
                    expirationYear = year
                }
            }
            // Matches name
            else if let name = try? NSRegularExpression(
                        pattern: nameRegex,
                        options: []),
                      let _ = name.firstMatch(in: stringValue,
                                              options: [],
                                              range: NSRange(location: 0,
                                                             length: stringValue.count)) {

                let components = stringValue.components(separatedBy: " ")

                if let first = components.first {
                    firstName = String(first)
                }

                //combine the rest of the components into one
                if components.count > 1 {
                    lastName = components[(components.startIndex
                                            + 1)..<components.endIndex]
                        .joined(separator: " ")
                }
            }
        }

        // If any field is empty, return nil
        guard cardNumber != nil
                || expirationMonth != nil
                || expirationYear != nil
                || firstName != nil
                || lastName != nil else {
            return nil
        }

        return CreditCard(image: nil,
                          cardNumber: cardNumber,
                          expirationMonth: expirationMonth,
                          expirationYear: expirationYear,
                          firstName: firstName,
                          lastName: lastName)


    }
    
    // get type of card
    private func getTypeofCard(from observations: [VNRecognizedTextObservation]) -> CardType? {
        
        var typeOfCard: CardType = .unknown
        
        // 1) find the type of card
        // and continue if we know what type it is.
        // otherwise return nil.
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }
            
            let stringValue = topCandidate.string.lowercased()
            
            if stringValue.contains("visa") {
                typeOfCard = .visa
            } else if stringValue.contains("discover") {
                typeOfCard = .discover
            } else if stringValue.contains("mastercard") {
                typeOfCard = .mastercard
            } else if stringValue.contains("american express") || stringValue.contains("amex") {
                typeOfCard = .amex
            }
            
        }
        
        return typeOfCard
    }

    // input: "good thru 06/22"
    // output: "06/22"
    func getExpiryDate(from text: String) -> String {
        var expiryDate = ""
        for char in text {
            if char.isNumber || char == "/" {
                expiryDate.append(char)
            }
        }

        return expiryDate
    }
}
