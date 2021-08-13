//
//  CardScannerViewController.swift
//
//
//  Created by Tyler Poland on 7/29/21.
//
import AVKit
import Combine
import UIKit
import Vision

public class CardScannerViewController: UIViewController {

    private let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private lazy var subscribers = Set<AnyCancellable>()
    private lazy var device = AVCaptureDevice.default(.builtInDualCamera,
                                                      for: .video,
                                                      position: .back)!
    private lazy var rectDetector: RectDetector = RectDetector(device: device)

    private var done = false
    // delegate to send back results
    public weak var delegate: CardScannerDelegate?

    // do not auto rotate this VC
    public override var shouldAutorotate: Bool {
        return false
    }

    /// Initialize this VC with a nil delegate
    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    /// Initialize this VC with a `CardScannerDelegate`
    public init(delegate: CardScannerDelegate? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.delegate = delegate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // check if the app has access to the camera
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
            doInitialSetup()
            print("access granted")
        case .notDetermined: // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    // initial setup does work on UI so execute on main thread
                    DispatchQueue.main.async {
                        self?.doInitialSetup()
                    }
                    print("access granted")
                } else {
                    print("access denied")
                    self?.delegate?.scanner(didFinishWith: .failure(CreditCardScannerError.authorizationDenied))
                }
            }

        case .denied, .restricted: // The user has previously denied access.
            print("access denied")
            delegate?.scanner(didFinishWith: .failure(CreditCardScannerError.authorizationDenied))

        default:
            print("access denied")
            delegate?.scanner(didFinishWith: .failure(CreditCardScannerError.authorizationDenied))
        }
    }



    // Sets up the camera for capture session
    private func doInitialSetup() {
        setupCameraInput()
        showCameraFeed()
        setCameraOutput()
        addOverlay()

        // Start
        captureSession.startRunning()
        rectDetector.configureDevice(torchMode: AVCaptureDevice.TorchMode.on)

        rectDetector.processor.subject.receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                if case let .failure(error) = completion {
                    self.delegate?.scanner(didFinishWith: .failure(error))
                }
            }, receiveValue: { [weak self] creditCard in
                guard let self = self else { return }
                self.onReceived(creditCard: creditCard)
            })
            .store(in: &subscribers)
    }

    private func onReceived(creditCard: CreditCard) {
        print("🔴: \(creditCard)")
        guard !done else { return }
        done = true
        captureSession.stopRunning()
        print("🟢")
        delegate?.scanner(didFinishWith: .success(creditCard))
    }

    private func setupCameraInput() {

        guard let cameraInput = try? AVCaptureDeviceInput(device: device) else {
            delegate?.scanner(didFinishWith: .failure(CreditCardScannerError.cameraSetup))
            return
        }

        self.captureSession.addInput(cameraInput)
    }

    private func showCameraFeed() {
        previewLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.frame
    }

    private func setCameraOutput() {
        self.videoDataOutput.videoSettings = [
            (kCVPixelBufferPixelFormatTypeKey as NSString): NSNumber(value: kCVPixelFormatType_32BGRA)
        ] as [String: Any]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self,
                                                queue: DispatchQueue(label: "camera_frame_processing_queue"))

        captureSession.addOutput(videoDataOutput)
        guard let connection = videoDataOutput.connection(with: .video),
              connection.isVideoOrientationSupported else { return }

        connection.videoOrientation = .portrait
    }
}

extension CardScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            delegate?.scanner(didFinishWith: .failure(CreditCardScannerError.captureError))
            dismiss(animated: true, completion: nil)
            return
        }

        rectDetector.detectRectangle(in: frame, completionHandler: { [weak self] (request: VNRequest, error: Error?) in

            guard let self = self else { return }

            DispatchQueue.main.async { [weak self] in
                guard let results = request.results as? [VNRectangleObservation],
                      let rect = results.first else {
                    return
                }

                self?.drawBoundingBox(rect: rect)
                // asynchronously test the frame
                self?.rectDetector.testForValidObservation(rect, buff: frame)
            }
        })
    }

    private func drawBoundingBox(rect: VNRectangleObservation) {
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.previewLayer.frame.height)
        let scale = CGAffineTransform.identity.scaledBy(x: previewLayer.frame.width, y: previewLayer.frame.height)
        let bounds = rect.boundingBox.applying(scale).applying(transform)
        createLayer(in: bounds)
    }

    private func createLayer(in rect: CGRect){

        let old = previewLayer.sublayers?
            .filter { $0.name == "overlay" }
            .compactMap { $0 }
        old?.forEach { $0.removeFromSuperlayer() }

        let maskLayer = CAShapeLayer()
        maskLayer.frame = rect
        maskLayer.cornerRadius = 10
        maskLayer.opacity = 0.75
        maskLayer.borderColor = UIColor.green.cgColor
        maskLayer.borderWidth = 3
        maskLayer.name = "overlay"
        previewLayer.insertSublayer(maskLayer, at: 1)
    }

    private func addOverlay() {
        // gray overlay with cut-out
        let bigPath = UIBezierPath(rect: view.bounds)
        let cornerRadius: CGFloat = 10
        let width = view.bounds.width
        let ccRatio: CGFloat = 1.58 // estimate rectangle size
        let boxWidth = width - (20 * 2) // subtract edge buffer
        let boxHeight = width / ccRatio
        // region of interest
        let roi = CGRect(x: 20, y: view.bounds.height/2 - boxHeight/2, width: boxWidth, height: boxHeight)
        let roiPath = UIBezierPath(roundedRect: roi, cornerRadius: cornerRadius)
        bigPath.append(roiPath)

        let fillLayer = CAShapeLayer()
        fillLayer.path = bigPath.cgPath
        fillLayer.fillRule = .evenOdd
        fillLayer.fillColor = view.backgroundColor?.cgColor
        fillLayer.opacity = 0.4
        view.layer.addSublayer(fillLayer)

        let border = CAShapeLayer()
        border.path = UIBezierPath(roundedRect: roi, cornerRadius: cornerRadius).cgPath
        border.fillColor = UIColor.clear.cgColor
        border.lineWidth = 3.5
        border.strokeColor = UIColor.white.cgColor
        view.layer.addSublayer(border)

        let label = UILabel()
        label.text = "Align your credit card to scan"
        label.sizeToFit()
        label.textAlignment = .center
        label.center = CGPoint(x: view.bounds.width/2,
                               y: view.bounds.height/2 + boxHeight/2 + 40)
        view.addSubview(label)
        view.bringSubviewToFront(label)
    }
}

extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        return CGPoint(x: self.x * size.width,
                       y: self.y * size.height)
    }
}
