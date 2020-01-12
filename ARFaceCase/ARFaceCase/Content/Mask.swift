//
//  Mask.swift
//  ARFaceCase
//
//  Created by Connor Power on 12/01/2020.
//

import Foundation
import ARKit

class Mask: SCNNode {

    // MARK: - Data Types

    enum MaskType {
        case basic
        case painted
        case zombie

        func next() -> MaskType {
            switch self {
            case .basic:
                return .painted
            case .painted:
                return .zombie
            case .zombie:
                return .basic
            }
        }
    }

    // MARK: - Initialization

    init(geometry: SCNGeometry, maskType: MaskType) {
        super.init()

        self.geometry = geometry
        swapMaterials(maskType: maskType)
    }

    required init?(coder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }

    // MARK: - Functions

    func update(withFaceAnchor faceAnchor: ARFaceAnchor) {
        let faceGeometry = geometry as! ARSCNFaceGeometry

        faceGeometry.update(from: faceAnchor.geometry)
    }

    func swapMaterials(maskType: MaskType) {
        guard let material = geometry?.firstMaterial else { return }

        material.lightingModel = .physicallyBased
        material.diffuse.contents = nil
        material.normal.contents = nil
        material.transparent.contents = nil

        switch maskType {
        case .basic:
            material.lightingModel = .physicallyBased
            material.diffuse.contents = UIColor(red: 0.0, green: 0.68, blue: 0.37, alpha: 1.0)
        case .painted:
            material.diffuse.contents = "Models.scnassets/Masks/Painted/Diffuse.png"
            material.normal.contents = "Models.scnassets/Masks/Painted/Normal_v1.png"
            material.transparent.contents = "Models.scnassets/Masks/Painted/Transparency.png"
        case .zombie:
            material.diffuse.contents = "Models.scnassets/Masks/Zombie/Diffuse.png"
            material.normal.contents = "Models.scnassets/Masks/Zombie/Normal_v1.png"
        }
    }

}
