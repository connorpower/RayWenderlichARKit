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

    private var neutralMouthY: Float = 0

    private var neutralRightPupilX: Float = 0
    private var neutralRightPupilY: Float = 0

    private var neutralLeftPupilX: Float = 0
    private var neutralLeftPupilY: Float = 0

    private lazy var browNode = childNode(withName: "brow", recursively: true)!

    private lazy var mouthNode = childNode(withName: "mouth", recursively: true)!

    private lazy var eyeRightNode = childNode(withName: "eyeRight", recursively: true)!
    private lazy var pupilRightNode = childNode(withName: "pupilRight", recursively: true)!

    private lazy var eyeLeftNode = childNode(withName: "eyeLeft", recursively: true)!
    private lazy var pupilLeftNode = childNode(withName: "pupilLeft", recursively: true)!

    // MARK: - Private Computed Properties

    private lazy var browHeight: Float = {
        let (min, max) = browNode.boundingBox
        return max.y - min.y
    }()

    private lazy var mouthHeight: Float = {
        let (min, max) = mouthNode.boundingBox
        return max.y - min.y
    }()

    private lazy var pupilWidth: Float = {
        let (min, max) = pupilRightNode.boundingBox
        return max.x - min.x
    }()

    private lazy var pupilHeight: Float = {
        let (min, max) = pupilRightNode.boundingBox
        return max.y - min.y
    }()

    private lazy var maxPupilTravel: Float = { (pupilWidth + pupilHeight) * 0.5 }()

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
        neutralMouthY = mouthNode.position.y
        neutralLeftPupilX = pupilLeftNode.position.x
        neutralLeftPupilY = pupilLeftNode.position.y
        neutralRightPupilX = pupilRightNode.position.x
        neutralRightPupilY = pupilRightNode.position.y
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
            guard let browUp = blendShapes[.browInnerUp] as? Float,
                let mouthOpen = blendShapes[.jawOpen] as? Float,

                let eyeLookInLeft = blendShapes[.eyeLookInLeft] as? Float,
                let eyeLookOutLeft = blendShapes[.eyeLookOutLeft] as? Float,
                let eyeLookUpLeft = blendShapes[.eyeLookUpLeft] as? Float,
                let eyeLookDownLeft = blendShapes[.eyeLookDownLeft] as? Float,

                let eyeBlinkLeft = blendShapes[.eyeBlinkLeft] as? Float,
                let eyeLookInRight = blendShapes[.eyeLookInRight] as? Float,
                let eyeLookOutRight = blendShapes[.eyeLookOutRight] as? Float,
                let eyeLookUpRight = blendShapes[.eyeLookUpRight] as? Float,
                let eyeLookDownRight = blendShapes[.eyeLookDownRight] as? Float,
                let eyeBlinkRight = blendShapes[.eyeBlinkRight] as? Float else { return }

            browNode.position.y = neutralBrowY + browUp * browHeight

            mouthNode.position.y = neutralMouthY - mouthOpen * mouthHeight

            pupilLeftNode.position = SCNVector3(
                neutralLeftPupilX - maxPupilTravel * (eyeLookInLeft - eyeLookOutLeft),
                neutralLeftPupilY - maxPupilTravel * (eyeLookDownLeft - eyeLookUpLeft),
                pupilLeftNode.position.z)

            pupilRightNode.position = SCNVector3(
                neutralRightPupilX + maxPupilTravel * (eyeLookInRight - eyeLookOutRight),
                neutralRightPupilY - maxPupilTravel * (eyeLookDownRight - eyeLookUpRight),
                pupilLeftNode.position.z)

            eyeLeftNode.scale.y = 1.0 - eyeBlinkLeft
            eyeRightNode.scale.y = 1.0 - eyeBlinkRight
        }
    }

}
