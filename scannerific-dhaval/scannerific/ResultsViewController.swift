//
//  ResultsViewController.swift
//  ResultsViewController
//
//  Created by Servando Cordova on 7/27/21.
//

import EGCardScanner
import UIKit

class ResultsViewController: UIViewController {

    private let creditCard: CreditCard
    
    init(creditCard: CreditCard) {
        self.creditCard = creditCard
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 20
        view.addSubview(stackView)

        let imageView = UIImageView(image: creditCard.image)
        imageView.contentMode = .scaleAspectFit
        stackView.addArrangedSubview(imageView)
        
        let label = UILabel()
        label.numberOfLines = 0
        label.text = """
        cardNumber:
        \(creditCard.cardNumber ?? "N/A")
        
        expirationMonth:
        \(creditCard.expirationMonth ?? "Not found")
        
        expirationYear:
        \(creditCard.expirationYear ?? "Not Found")

        name:
        \(creditCard.firstName ?? "Not Found") \(creditCard.lastName ?? "Not Found")
        """
        
        stackView.addArrangedSubview(label)
        
        [imageView.heightAnchor.constraint(equalToConstant: 200),
         stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
         stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
         stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
         stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor)]
            .forEach { $0.isActive = true }
    }
}
