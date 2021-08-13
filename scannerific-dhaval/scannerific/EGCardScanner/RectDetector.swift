//
//  RectDetector.swift
//  
//
//  Created by Tyler Poland on 7/29/21.
//

import AVKit
import Vision

internal struct RectDetector {
    internal let processor = CardImageProcessor()
    internal var device: AVCaptureDevice
    
    internal init(device: AVCaptureDevice) {
        self.device = device
    }
    
    internal func detectRectangle(in image: CVPixelBuffer,
                                   completionHandler: @escaping (VNRequest, Error?) -> Void) {
                
        let requestCompletionHandler: VNRequestCompletionHandler = completionHandler
        
        let vnRequest: VNRequest
        
        if #available(iOS 15, *) {
            // this should compile on Xcode 13 with iOS 15
            // uncomment this to provide support for iOS 15
//            vnRequest = VNDetectDocumentSegmentationRequest(completionHandler: requestCompletionHandler)
            // Remove this. Adding to make compiler happy
            vnRequest = VNDetectRectanglesRequest()
        } else {
            vnRequest = VNDetectRectanglesRequest(completionHandler: requestCompletionHandler)
            // (most) CCs and biz cards fall within this aspect ratio range
            (vnRequest as! VNDetectRectanglesRequest).minimumAspectRatio = VNAspectRatio(1.3)
            (vnRequest as! VNDetectRectanglesRequest).maximumAspectRatio = VNAspectRatio(1.6)
            (vnRequest as! VNDetectRectanglesRequest).minimumSize = Float(0.5)
            (vnRequest as! VNDetectRectanglesRequest).maximumObservations = 1
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
        try? imageRequestHandler.perform([vnRequest])
    }
        
    internal func testForValidObservation(_ rect: VNRectangleObservation,
                                         buff: CVImageBuffer) {
        print("confidence: \(rect.confidence)")
        guard rect.confidence > 0.95,
              let image = getImage(rect, from: buff) else { return }
        
        processor.process(image: image)
    }
    
    private func getImage(_ observation: VNRectangleObservation, from buffer: CVImageBuffer) -> UIImage? {
        var ciImage = CIImage(cvImageBuffer: buffer)
        
        let topLeft = observation.topLeft.scaled(to: ciImage.extent.size)
        let topRight = observation.topRight.scaled(to: ciImage.extent.size)
        let bottomLeft = observation.bottomLeft.scaled(to: ciImage.extent.size)
        let bottomRight = observation.bottomRight.scaled(to: ciImage.extent.size)
        
        ciImage = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight": CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight)
        ])
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage,
                                                  from: ciImage.extent) else { return nil }
        let output = UIImage(cgImage: cgImage)
        return output
    }
    
    internal func configureDevice(torchMode: AVCaptureDevice.TorchMode) {
        guard device.hasTorch, device.torchMode != torchMode else {
            return
        }
        do {
            try device.lockForConfiguration()
            if torchMode == .on {
                try device.setTorchModeOn(level: 0.1)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            fatalError()
        }
    }
}
