/*
 Copyright 2025 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import UIKit
import AEPConcierge

/// Simple UIKit screen showcasing the UIKit-based Concierge presentation API.
final class ConciergeUIKitDemoViewController: UIViewController {
    private let openButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Present Chat (UIKit)", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemRed
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let hideButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Hide Chat", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(.systemRed, for: .normal)
        button.backgroundColor = UIColor.secondarySystemBackground
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        view.addSubview(openButton)
        view.addSubview(hideButton)

        NSLayoutConstraint.activate([
            openButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -12),

            hideButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hideButton.topAnchor.constraint(equalTo: openButton.bottomAnchor, constant: 16)
        ])

        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)
        hideButton.addTarget(self, action: #selector(hideTapped), for: .touchUpInside)
    }

    @objc private func openTapped() {
        Concierge.present(on: self, title: "Concierge", subtitle: "Powered by Adobe")
    }

    @objc private func hideTapped() {
        Concierge.hide()
    }
}


