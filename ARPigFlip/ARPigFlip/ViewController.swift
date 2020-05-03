//
//  ViewController.swift
//  ARPigFlip
//
//  Created by Connor Power on 18/01/2020.
//  Copyright © 2020 Connor Power. All rights reserved.
//

import UIKit
import RealityKit

class ViewController: UIViewController {

    // MARK: - IBOutlets

    @IBOutlet private var arView: ARView!

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let pigAnchor = try! Experience.loadPig()
        arView.scene.anchors.append(pigAnchor)
    }

}
