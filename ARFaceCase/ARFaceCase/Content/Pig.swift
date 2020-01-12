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

    private var neutralBrowY: Float = 0
    private lazy var browNode = childNode(withName: "brow", recursively: true)!

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

        neutralBrowY = browNode.position.y
    }

    required init?(coder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }

    // MARK: - Functions

    func update(withFaceAnchor faceAnchor: ARFaceAnchor) {
        blendShapes = faceAnchor.blendShapes
    }

    // MARK: - Private Functions

    private var blendShapes: [ARFaceAnchor.BlendShapeLocation: Any] = [:] {
        didSet {
            guard let browUp = blendShapes[.browInnerUp] as? Float else { return }

            let browHeight = browNode.boundingBox.max.y - browNode.boundingBox.min.y
            browNode.position.y = neutralBrowY + browUp * browHeight
        }
    }

}
