//
//  PortalViewController.swift
//  Portal
//
//  Created by Connor Power on 03/01/2020.
//  Copyright © 2020 Namrata Bandekar. All rights reserved.
//

import UIKit
import ARKit

class PortalViewController: UIViewController {

    // MARK: - IBOutlets

    @IBOutlet private var sceneView: ARSCNView!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var sessionStateLabel: UILabel!
    @IBOutlet private weak var crosshair: UIView!

    // MARK: - Properties

    private var debugPlanes = [SCNNode]()
    private var portalNode: SCNNode?

    // MARK: - View Controller Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        resetLabels()
        runSession()
    }

    // MARK: - Setup

    private func runSession() {
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) else {
            fatalError("People occlusion is not supported on this device")
        }

        let config = ARWorldTrackingConfiguration()
        
        config.planeDetection = .horizontal
        config.isLightEstimationEnabled = true
        config.worldAlignment = .gravity
        config.frameSemantics.insert(.personSegmentationWithDepth)
        sceneView?.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        #if DEBUG
            sceneView?.debugOptions = [.showWireframe, .showFeaturePoints]
        #endif

        sceneView.delegate = self
    }

    // MARK: - Hit Testing

    private var viewCenter: CGPoint {
        let bounds = view.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let hit = sceneView.hitTest(viewCenter, types: [.existingPlaneUsingExtent]).first {
            sceneView.session.add(anchor: ARAnchor(transform: hit.worldTransform))
        }
    }

    // MARK: - Private Functions

    private func resetLabels() {
        messageLabel.alpha = 1.0
        messageLabel.text =
            "Move the phone around and allow the app to find a plane. You will see a yellow horizontal plane."
        sessionStateLabel.alpha = 0.0
        sessionStateLabel.text = ""
    }

    private func showMessage(_ message: String, label: UILabel, seconds: Double) {
        label.text = message
        label.alpha = 1.0

        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            label.text = ""
            label.alpha = 0.0
        }
    }

    private func removeAllNodes() {
        removeDebugPlaneNodes()
        portalNode?.removeFromParentNode()
        portalNode = nil
    }

    private func removeDebugPlaneNodes() {
        for node in debugPlanes {
            node.removeFromParentNode()
        }

        debugPlanes.removeAll()
    }

    // MARK: - Make Portal

    private func makePortal() -> SCNNode {
        let portal = SCNNode()
        portal.name = "portal"

        let floorNode = makeFloorNode()
        floorNode.name = "floor"
        floorNode.position = SCNVector3(0, 0, 0)
        portal.addChildNode(floorNode)

        let ceilingNode = makeCeilingNode()
        ceilingNode.position = SCNVector3( 0,
                                          +Constants.innerCubeLength + Constants.wallThickness,
                                           0)
        portal.addChildNode(ceilingNode)

        let farWallNode = makeWallNode()
        farWallNode.name = "wall (far)"
        farWallNode.eulerAngles = SCNVector3Make(0.0, .pi/2, 0.0)
        farWallNode.position = SCNVector3( 0,
                                          +Constants.innerCubeLength * 0.5 + Constants.wallThickness,
                                          -Constants.innerCubeLength * 0.5 - Constants.wallThickness * 0.5)
        portal.addChildNode(farWallNode)

        let leftSideWallNode = makeWallNode(maskLowerSide: false)
        leftSideWallNode.name = "wall (left)"
        leftSideWallNode.eulerAngles = SCNVector3(0.0, .pi, 0.0)
        leftSideWallNode.position = SCNVector3(-Constants.innerCubeLength * 0.5 - Constants.wallThickness * 0.5,
                                               +Constants.innerCubeLength * 0.5 + Constants.wallThickness,
                                                0)
        portal.addChildNode(leftSideWallNode)

        let rightSideWallNode = makeWallNode(maskLowerSide: true)
        rightSideWallNode.name = "wall (right)"
        rightSideWallNode.eulerAngles = SCNVector3(0.0, .pi, 0.0)
        rightSideWallNode.position = SCNVector3(+Constants.innerCubeLength * 0.5 + Constants.wallThickness * 0.5,
                                                +Constants.innerCubeLength * 0.5 + Constants.wallThickness,
                                                 0)
        portal.addChildNode(rightSideWallNode)

        let invisibleColumns = SCNNode()
        invisibleColumns.name = "invisible columns"
        portal.addChildNode(invisibleColumns)

        addInvisibleVerticalColumns(node: invisibleColumns)
        addInvisibleTopColumns(node: invisibleColumns)
        addInvisibleBottomColumns(node: invisibleColumns)

        addDoorway(node: portal)
        placeLightSources(node: portal)

        return portal
    }

    private func addDoorway(node: SCNNode) {
        let sidePanelLength = (Constants.innerCubeLength - Constants.doorWidth) * 0.5
        let aboveDoorHeight = Constants.innerCubeLength - Constants.doorHeight

        let wall = SCNNode()
        wall.name = "wall (front)"
        node.addChildNode(wall)

        let leftSideDoorNode = makeWallNode(length: sidePanelLength, height: Constants.innerCubeLength)
        leftSideDoorNode.name = "wall (left front)"
        leftSideDoorNode.eulerAngles = SCNVector3(0,
                                                  3.0/2.0 * .pi,
                                                  0)
        leftSideDoorNode.position = SCNVector3(-Constants.innerCubeLength * 0.5 + sidePanelLength * 0.5,
                                               +Constants.innerCubeLength * 0.5 + Constants.wallThickness,
                                               +Constants.innerCubeLength * 0.5 + Constants.wallThickness * 0.5)
        wall.addChildNode(leftSideDoorNode)

        let rightSideDoorNode = makeWallNode(length: sidePanelLength,
                                             height: Constants.innerCubeLength)
        rightSideDoorNode.name = "wall (right front)"
        rightSideDoorNode.eulerAngles = SCNVector3(0,
                                                   3.0/2.0 * .pi,
                                                   0)
        rightSideDoorNode.position = SCNVector3(+Constants.innerCubeLength * 0.5 - sidePanelLength * 0.5,
                                                +Constants.innerCubeLength * 0.5 + Constants.wallThickness,
                                                +Constants.innerCubeLength * 0.5 + Constants.wallThickness * 0.5)
        wall.addChildNode(rightSideDoorNode)

        let aboveDoorNode = makeWallNode(length: Constants.doorWidth,
                                         height: aboveDoorHeight)
        aboveDoorNode.name = "wall (top front)"
        aboveDoorNode.eulerAngles = SCNVector3(0,
                                               3.0/2.0 * .pi,
                                               0)
        aboveDoorNode.position = SCNVector3( 0,
                                            +Constants.innerCubeLength + Constants.wallThickness - aboveDoorHeight * 0.5,
                                            +Constants.innerCubeLength * 0.5 + Constants.wallThickness * 0.5)
        wall.addChildNode(aboveDoorNode)
    }

    private func placeLightSources(node: SCNNode) {
        let light = SCNLight()
        light.name = "internal light"
        light.intensity = Constants.lightIntensity
        light.type = .omni

        let lightingNode = SCNNode()
        lightingNode.name = "lights"
        node.addChildNode(lightingNode)

        let lightNode1 = SCNNode()
        lightNode1.name = "light"
        lightNode1.light = light
        lightNode1.position = SCNVector3(+Constants.innerCubeLength * 0.25,
                                         +Constants.innerCubeLength + Constants.wallThickness - Constants.lightOffset,
                                         +Constants.innerCubeLength * 0.25)
        lightingNode.addChildNode(lightNode1)

        let lightNode2 = SCNNode()
        lightNode2.name = "light"
        lightNode2.light = light
        lightNode2.position = SCNVector3(+Constants.innerCubeLength * 0.25,
                                         +Constants.innerCubeLength + Constants.wallThickness - Constants.lightOffset,
                                         -Constants.innerCubeLength * 0.25)
        lightingNode.addChildNode(lightNode2)

        let lightNode3 = SCNNode()
        lightNode3.name = "light"
        lightNode3.light = light
        lightNode3.position = SCNVector3(-Constants.innerCubeLength * 0.25,
                                         +Constants.innerCubeLength + Constants.wallThickness - Constants.lightOffset,
                                         +Constants.innerCubeLength * 0.25)
        lightingNode.addChildNode(lightNode3)

        let lightNode4 = SCNNode()
        lightNode4.name = "light"
        lightNode4.light = light
        lightNode4.position = SCNVector3(-Constants.innerCubeLength * 0.25,
                                         +Constants.innerCubeLength + Constants.wallThickness - Constants.lightOffset,
                                         -Constants.innerCubeLength * 0.25)
        lightingNode.addChildNode(lightNode4)
    }

    // MARK: - Invisible Columns

    private func addInvisibleVerticalColumns(node: SCNNode) {
        let frontLeft = makeInvisbleColumn()
        frontLeft.eulerAngles = SCNVector3(0,
                                           0,
                                           .pi/2.0)
        frontLeft.position = SCNVector3(-Constants.innerCubeLength * 0.5 - Constants.wallThickness * 0.5,
                                        +Constants.innerCubeLength * 0.5 + Constants.wallThickness,
                                        +Constants.innerCubeLength * 0.5 + Constants.wallThickness * 0.5)
        node.addChildNode(frontLeft)

        let frontRight = makeInvisbleColumn()
        frontRight.eulerAngles = SCNVector3(0,
                                            0,
                                            .pi/2.0)
        frontRight.position = SCNVector3(+Constants.innerCubeLength * 0.5 + Constants.wallThickness * 0.5,
                                         +Constants.innerCubeLength * 0.5 + Constants.wallThickness,
                                         +Constants.innerCubeLength * 0.5 + Constants.wallThickness * 0.5)
        node.addChildNode(frontRight)

        let backLeft = makeInvisbleColumn()
        backLeft.eulerAngles = SCNVector3(0,
                                          0,
                                          .pi/2.0)
        backLeft.position = SCNVector3(-Constants.innerCubeLength * 0.5 - Constants.wallThickness * 0.5,
                                       +Constants.innerCubeLength * 0.5 + Constants.wallThickness,
                                       -Constants.innerCubeLength * 0.5 - Constants.wallThickness * 0.5)
        node.addChildNode(backLeft)

        let backRight = makeInvisbleColumn()
        backRight.eulerAngles = SCNVector3(0,
                                           0,
                                           .pi/2.0)
        backRight.position = SCNVector3(+Constants.innerCubeLength * 0.5 + Constants.wallThickness * 0.5,
                                        +Constants.innerCubeLength * 0.5 + Constants.wallThickness,
                                        -Constants.innerCubeLength * 0.5 - Constants.wallThickness * 0.5)
        node.addChildNode(backRight)
    }

    private func addInvisibleTopColumns(node: SCNNode) {
        let topFront = makeInvisbleColumn()
        topFront.eulerAngles = SCNVector3(0,
                                          0,
                                          0)
        topFront.position = SCNVector3( 0,
                                       +Constants.innerCubeLength + Constants.wallThickness + Constants.wallThickness * 0.5,
                                       +Constants.innerCubeLength * 0.5 + Constants.wallThickness * 0.5)
        node.addChildNode(topFront)

        let topRear = makeInvisbleColumn()
        topRear.eulerAngles = SCNVector3(0,
                                         0,
                                         0)
        topRear.position = SCNVector3( 0,
                                       +Constants.innerCubeLength + Constants.wallThickness + Constants.wallThickness * 0.5,
                                       -Constants.innerCubeLength * 0.5 - Constants.wallThickness * 0.5)
        node.addChildNode(topRear)

        let topLeft = makeInvisbleColumn()
        topLeft.eulerAngles = SCNVector3(0,
                                         .pi/2.0,
                                         0)
        topLeft.position = SCNVector3(-Constants.innerCubeLength * 0.5 - Constants.wallThickness * 0.5,
                                      +Constants.innerCubeLength + Constants.wallThickness + Constants.wallThickness * 0.5,
                                      0)
        node.addChildNode(topLeft)

        let topRight = makeInvisbleColumn()
        topRight.eulerAngles = SCNVector3(0,
                                          .pi/2.0,
                                          0)
        topRight.position = SCNVector3(+Constants.innerCubeLength * 0.5 + Constants.wallThickness * 0.5,
                                       +Constants.innerCubeLength + Constants.wallThickness + Constants.wallThickness * 0.5,
                                       0)
        node.addChildNode(topRight)
    }

    private func addInvisibleBottomColumns(node: SCNNode) {
        let bottomFront = makeInvisbleColumn()
        bottomFront.eulerAngles = SCNVector3(0,
                                             0,
                                             0)
        bottomFront.position = SCNVector3(0,
                                          +Constants.wallThickness * 0.5,
                                          +Constants.innerCubeLength * 0.5 + Constants.wallThickness * 0.5)
        node.addChildNode(bottomFront)

        let bottomRear = makeInvisbleColumn()
        bottomRear.eulerAngles = SCNVector3(0,
                                            0,
                                            0)
        bottomRear.position = SCNVector3(0,
                                         +Constants.wallThickness * 0.5,
                                         -Constants.innerCubeLength * 0.5 - Constants.wallThickness * 0.5)
        node.addChildNode(bottomRear)

        let bottomLeft = makeInvisbleColumn()
        bottomLeft.eulerAngles = SCNVector3(0,
                                            .pi/2.0,
                                            0)
        bottomLeft.position = SCNVector3(-Constants.innerCubeLength * 0.5 - Constants.wallThickness * 0.5,
                                         +Constants.wallThickness * 0.5,
                                         0)
        node.addChildNode(bottomLeft)

        let bottomRight = makeInvisbleColumn()
        bottomRight.eulerAngles = SCNVector3(0,
                                             .pi/2.0,
                                             0)
        bottomRight.position = SCNVector3(+Constants.innerCubeLength * 0.5 + Constants.wallThickness * 0.5,
                                          +Constants.wallThickness * 0.5,
                                          0)
        node.addChildNode(bottomRight)
    }

}

// MARK: - ARSCNViewDelegate

extension PortalViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            if let _ = self.sceneView.hitTest(self.viewCenter, types: [.existingPlaneUsingExtent]).first {
                self.crosshair.backgroundColor = .green
            } else {
                self.crosshair.backgroundColor = .lightGray
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let planeAnchor = anchor as? ARPlaneAnchor {
            #if DEBUG
            let debugPlaneNode = createPlaneNode(center: planeAnchor.center, extent: planeAnchor.extent)
            node.addChildNode(debugPlaneNode)
            debugPlanes.append(node)
            #endif

            DispatchQueue.main.async {
                self.messageLabel.text = "Tap on the detected horizontal plane to place the portal"
            }
        } else if portalNode == nil {
            let portal = makePortal()

            // Point door at camera
            let rotation = SCNMatrix4MakeRotation(sceneView.session.currentFrame?.camera.eulerAngles.y ?? 0.0, 0, 1, 0)
            portal.transform = rotation
            portal.position = SCNVector3(0.0,
                                         -Constants.wallThickness,
                                         0.0)

            node.addChildNode(portal)
            node.name = "portal anchor"
            self.portalNode = portal

            removeDebugPlaneNodes()
            sceneView.debugOptions = []

            DispatchQueue.main.async {
                self.messageLabel.text = ""
                self.messageLabel.alpha = 0.0
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let plane = node.childNodes.first,
            portalNode == nil else { return }

        updatePlaneNode(plane: plane, center: planeAnchor.center, extent: planeAnchor.extent)
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor else { return }

        node.enumerateChildNodes { (node, _) in
            node.removeFromParentNode()
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.showMessage(error.localizedDescription, label: self.sessionStateLabel, seconds: 3.0)
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.showMessage("Session interrupted", label: self.sessionStateLabel, seconds: 3.0)
        }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        removeAllNodes()

        DispatchQueue.main.async {
            self.resetLabels()
            self.runSession()
        }
    }

}
