//
//  SampleHomeViewController.swift
//  SampleHomeViewController
//
//  Created by Servando Cordova on 7/29/21.
//

import EGCardScanner
import UIKit

class SampleHomeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        let button = UIButton(type: .system)
        button.setTitle("scan", for: .normal)
        button.addTarget(self,
                         action: #selector(didTouchButton),
                         for: .touchUpInside)
        button.sizeToFit()
        view.addSubview(button)
        button.center = view.center
    }
    
    @objc private func didTouchButton() {
        let scannerVC = CardScannerViewController(delegate: self)
        present(scannerVC, animated: true)
    }
    
}

extension SampleHomeViewController: CardScannerDelegate {
    func scanner(didFinishWith results: Result<CreditCard, Error>) {
        print("🏁🏁🏁🏁")
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            
            switch results {
            case .success(let creditCard):
                let vc = ResultsViewController(creditCard: creditCard)
                self.present(vc, animated: true)

            case .failure(_):
                fatalError()
            }
                     
        }
    }
}
