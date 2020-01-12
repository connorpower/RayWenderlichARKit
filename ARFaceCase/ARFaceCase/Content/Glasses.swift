//
//  Glasses.swift
//  ARFaceCase
//
//  Created by Connor Power on 12/01/2020.
//

import Foundation
import ARKit

class Glasses: SCNNode {

    // MARK: - Propertie

    private let occlusionNode: SCNNode

    // MARK: - Initialization

    init(geometry: ARSCNFaceGeometry) {
        geometry.firstMaterial?.colorBufferWriteMask = []
        occlusionNode = SCNNode(geometry: geometry)
        occlusionNode.renderingOrder = -1

        super.init()

        addChildNode(occlusionNode)

        guard let url = Bundle.main.url(forResource: "glasses",
                                        withExtension: "scn",
                                        subdirectory: "Models.scnassets") else {
            fatalError("Missing resource")
        }
        let node = SCNReferenceNode(url: url)!
        node.load()
        addChildNode(node)
    }

    required init?(coder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }

    // MARK: - Functions

    func update(withFaceAnchor faceAnchor: ARFaceAnchor) {
        let faceGeometry = occlusionNode.geometry as! ARSCNFaceGeometry
        faceGeometry.update(from: faceAnchor.geometry)
    }

}
