//
//  ViewController.swift
//  ARPokerDice
//
//  Created by Connor Power on 31/12/2019.
//  Copyright © 2019 Connor Power. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    // MARK: - Constants

    private struct Nodes {
        static let earth = "earth"
        static let moonOrbitContiner = "moonOrbitContainer"
        static let moon = "moon"
    }

    private struct Constants {
        static let earthRotationDuration = 20.0
        static let moonOrbitDuration = 60.0
    }

    // MARK: - Properties

    @IBOutlet private var sceneView: ARSCNView!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var styleButton: UIButton!
    @IBOutlet private weak var resetButton: UIButton!

    lazy private var scene: SCNScene! = SCNScene(named: "EarthOrbit.scnassets/SimpleScene.scn")!

    override var prefersStatusBarHidden: Bool { return true }

    // MARK: - View Controller Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.scene = scene

        configureEarthRotation()
        configureMoonOrbit()

        statusLabel.text = "Greetings! :]"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    // MARK: - Private Functions

    private func configureEarthRotation() {
        let earthRotateAction = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0.0,
                               y: 2 * .pi,
                               z: 0.0,
                               duration: Constants.earthRotationDuration))
        let earth = scene.rootNode.childNode(withName: Nodes.earth, recursively: true)
        earth?.runAction(earthRotateAction)
    }

    private func configureMoonOrbit() {
        let tilt = SCNAction.sequence([
            SCNAction.moveBy(x: 0.0, y: -(2 * 0.08), z: 0, duration: Constants.moonOrbitDuration / 2.0),
            SCNAction.moveBy(x: 0.0, y: +(2 * 0.08), z: 0, duration: Constants.moonOrbitDuration / 2.0),
        ])

        let orbit = SCNAction.rotateBy(x: 0.0,
                                       y: 2 * .pi,
                                       z: 0.0,
                                       duration: Constants.moonOrbitDuration)

        let moonOrbitAction = SCNAction.repeatForever(orbit)
        let moonTiltAction = SCNAction.repeatForever(tilt)

        let moonContainer = scene.rootNode.childNode(withName: Nodes.moonOrbitContiner, recursively: true)
        let moon = scene.rootNode.childNode(withName: Nodes.moon, recursively: true)
        moonContainer?.runAction(moonOrbitAction)
        moon?.runAction(moonTiltAction)
    }

    // MARK: - IBActions

    @IBAction private func styleButtonPressed(_ sender: Any) {

    }

    @IBAction private func resetButtonPressed(_ sender: Any) {

    }

}

// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {

/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
