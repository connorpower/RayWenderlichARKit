//
//  Pig.swift
//  ARFaceCase
//
//  Created by Connor Power on 12/01/2020.
//

import Foundation
import ARKit

class Pig: SCNNode {

    // MARK: - Properties

    private let occlusionNode: SCNNode

    // MARK: - Initialization

    init(geometry: ARSCNFaceGeometry) {
        geometry.firstMaterial!.colorBufferWriteMask = []
        occlusionNode = SCNNode(geometry: geometry)
        occlusionNode.renderingOrder = -1

        super.init()
        self.geometry = geometry

        guard let url = Bundle.main.url(forResource: "pig",
                                        withExtension: "scn",
                                        subdirectory: "Models.scnassets") else {
            fatalError("Resource missing")
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
        let geometry = self.geometry as! ARSCNFaceGeometry
        geometry.update(from: faceAnchor.geometry)
    }

}
