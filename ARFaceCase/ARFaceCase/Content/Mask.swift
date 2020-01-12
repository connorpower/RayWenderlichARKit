//
//  Mask.swift
//  ARFaceCase
//
//  Created by Connor Power on 12/01/2020.
//

import Foundation
import ARKit

class Mask: SCNNode {

    // MARK: - Initialization

    init(geometry: SCNGeometry) {
        super.init()

        let material = geometry.firstMaterial!
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(red: 0.0, green: 0.68, blue: 0.37, alpha: 1.0)

        self.geometry = geometry
    }

    required init?(coder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }

}
