/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    // MARK: - Constants

    private enum GameState: Int16 {
        case detectSurface
        case pointToSurface
        case swipeToPlay
    }

    // MARK: - Properties

    private var gameState = GameState.detectSurface
    private var statusMessage = ""
    private var trackingStatus = ""

    private var focusPoint: CGPoint!

    private var focusNode: SCNNode!
    private var diceNodes = [SCNNode]()
    private var diceCount = 5
    private var diceStyle = 0
    private var diceOffset: [SCNVector3] = [.init( 0.00,  0.00,  0.00),
                                            .init(-0.15,  0.00,  0.00),
                                            .init(+0.15,  0.00,  0.00),
                                            .init(-0.15, +0.15, +0.12),
                                            .init(+0.15, +0.15, +0.12)]

    // MARK: - Outlets

    @IBOutlet private var sceneView: ARSCNView!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var styleButton: UIButton!
    @IBOutlet private weak var resetButton: UIButton!

    // MARK: - Actions

    @IBAction private func styleButtonPressed(_ sender: Any) {
        diceStyle = (diceStyle + 1) % 5
    }

    @IBAction private func resetButtonPressed(_ sender: Any) {
        resetGame()
    }

    @IBAction private func swipeUpGestureHandler(_ sender: Any) {
        guard gameState == .swipeToPlay else { return }
        guard let frame = sceneView.session.currentFrame else { return }

        _ = (0..<diceCount).map {
            throwDice(cameraTransform: SCNMatrix4(frame.camera.transform), offset: diceOffset[$0])
        }
    }

    // MARK: - View Management

    override func viewDidLoad() {
        super.viewDidLoad()
        initSceneView()
        initScene()
        initARSession()
        loadModels()
        initCoachingOverlayView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("*** ViewWillAppear()")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("*** ViewWillDisappear()")
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    // MARK: - Initialization

    func initSceneView() {
        sceneView.delegate = self
        sceneView.showsStatistics = true

//        sceneView.debugOptions = [.showWorldOrigin,
//                                  .showFeaturePoints,
//                                  .showBoundingBoxes,
//                                  .showPhysicsShapes,
//                                  .showPhysicsFields]
        orientationChanged()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(orientationChanged),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
    }

    func initScene() {
        let scene = SCNScene()
        scene.isPaused = false
        sceneView.scene = scene
        scene.physicsWorld.timeStep = 1.0 / 60.0
    }

    func initARSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("*** ARConfig: AR World Tracking Not Supported")
        }
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.providesAudioData = false
        config.environmentTexturing = .automatic
        config.planeDetection = .horizontal
        config.isLightEstimationEnabled = true
        sceneView.session.run(config)
    }

    func loadModels() {
        let diceScene = SCNScene(named: "PokerDice.scnassets/Models/DiceScene.scn")!
        diceNodes = (0..<5).map { diceScene.rootNode.childNode(withName: "dice\($0)", recursively: false)! }

        let focusScene = SCNScene(named: "PokerDice.scnassets/Models/FocusScene.scn")!
        focusNode = focusScene.rootNode.childNode(withName: "focus", recursively: false)!
        sceneView.scene.rootNode.addChildNode(focusNode)
    }

    func initCoachingOverlayView() {
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = sceneView.session
        coachingOverlay.activatesAutomatically = true
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.delegate = self
        sceneView.addSubview(coachingOverlay)

        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            coachingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            coachingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            coachingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            coachingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Hit Testing

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        DispatchQueue.main.async {
            guard let location = touches.first?.location(in: self.sceneView) else { return }

            if let dice = self.sceneView.hitTest(location, options: nil).filter({ $0.node.name == "dice" }).first {
                dice.node.removeFromParentNode()
                self.diceCount += 1
            }
        }
    }

    // MARK: - Helper Functions

    private func startGame() {
        DispatchQueue.main.async {
            self.hideARPlaneNodes()
            self.gameState = .pointToSurface
        }
    }

    private func resetGame() {
        let config = sceneView.session.configuration as! ARWorldTrackingConfiguration
        config.planeDetection = .horizontal
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    private func throwDice(cameraTransform: SCNMatrix4, offset: SCNVector3) {
        let position = SCNVector3(cameraTransform.m41 + offset.x,
                                  cameraTransform.m42 + offset.y,
                                  cameraTransform.m43 + offset.z)

        let diceNode = diceNodes[diceStyle].clone()
        diceNode.name = "dice"
        diceNode.position = position

        let rotation = SCNVector3(Double.random(min: 0.0, max: .pi),
                                  Double.random(min: 0.0, max: .pi),
                                  Double.random(min: 0.0, max: .pi))
        diceNode.eulerAngles = rotation

        let distance = simd_distance(focusNode.simdPosition,
                                     simd_make_float3(cameraTransform.m41, cameraTransform.m42, cameraTransform.m43))
        let direction = SCNVector3(-(distance * 2) * cameraTransform.m31,
                                   -(distance * 2) * (cameraTransform.m32 - .pi / 8.0),
                                   -(distance * 2) * cameraTransform.m33)
        diceNode.physicsBody?.resetTransform()
        diceNode.physicsBody?.applyForce(direction, asImpulse: true)

        sceneView.scene.rootNode.addChildNode(diceNode)
        diceCount -= 1
    }

    func updateDiceNodes() {
        _ = sceneView.scene.rootNode.childNodes.filter {
            $0.name == "dice"
        }.filter {
            $0.presentation.position.y <= -2
        }.map {
            $0.removeFromParentNode()
            diceCount += 1
        }
    }

    private func updateStatus() {
        switch gameState {
        case .detectSurface:
            statusMessage = "Scan entire table surface..."
        case .pointToSurface:
            statusMessage = "Point at the designated surface first!"
        case .swipeToPlay:
            statusMessage = "Swipe UP to throw.\nTap die to collect."
        }

        statusLabel.text = trackingStatus != "" ? trackingStatus : statusMessage
    }

    private func createARPlaneNode(planeAnchor: ARPlaneAnchor, color: UIColor) -> SCNNode {
        let planeGeometry = ARSCNPlaneGeometry(device: MTLCreateSystemDefaultDevice()!)!
        planeGeometry.update(from: planeAnchor.geometry)
        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = "PokerDice.scnassets/Textures/Surface_DIFFUSE.png"
        planeGeometry.materials = [planeMaterial]

        let planeNode = SCNNode(geometry: planeGeometry)
        planeNode.physicsBody = createARPlanePhysics(geometry: planeAnchor.geometry)

        return planeNode
    }

    private func createARPlanePhysics(geometry: ARPlaneGeometry) -> SCNPhysicsBody {
        let planeGeometry = ARSCNPlaneGeometry(device: MTLCreateSystemDefaultDevice()!)!
        planeGeometry.update(from: geometry)

        let shape = SCNPhysicsShape(geometry: planeGeometry, options: [.type: SCNPhysicsShape.ShapeType.boundingBox])
        let physicsBody = SCNPhysicsBody(type: .kinematic, shape: shape)
        physicsBody.restitution = 0.4
        physicsBody.friction = 0.6

        return physicsBody
    }

    private func updateARSurfaceNode(node: SCNNode, planeAnchor: ARPlaneAnchor) {
        if let planeGeometry = node.geometry as? ARSCNPlaneGeometry {
            planeGeometry.update(from: planeAnchor.geometry)
            node.physicsBody = nil
            node.physicsBody = createARPlanePhysics(geometry: planeAnchor.geometry)
        }

        node.position = SCNVector3(planeAnchor.center)
    }

    private func removeARPlaneNode(planeNode: SCNNode) {
        _ = planeNode.childNodes.map { $0.removeFromParentNode() }
    }

    private func suspendPlaneDetection() {
        let config = sceneView.session.configuration as! ARWorldTrackingConfiguration

        config.planeDetection = []
        sceneView.session.run(config)
    }

    private func hideARPlaneNodes() {
        _ = sceneView.session.currentFrame?.anchors.compactMap {
            self.sceneView.node(for: $0)
        }.flatMap { $0.childNodes }.map {
            $0.geometry?.materials.first?.colorBufferWriteMask = .init(rawValue: 0)
        }
    }

    @objc private func orientationChanged() {
        focusPoint = CGPoint(x: view.center.x, y: view.center.y + view.center.y * 0.25)
    }

    private func updateFocusNode() {
        let results = self.sceneView.hitTest(self.focusPoint, types: [.existingPlaneUsingExtent])

        if results.count == 1, let match = results.first {
            let t = match.worldTransform
            focusNode.position = SCNVector3(x: t.columns.3.x,
                                            y: t.columns.3.y,
                                            z: t.columns.3.z)
            gameState = .swipeToPlay
            focusNode.isHidden = false
        } else {
            gameState = .pointToSurface
            focusNode.isHidden = true
        }
    }

}

// MARK: - ARSCNViewDelegate

extension ViewController : ARSCNViewDelegate {

    // MARK: - SceneKit Management

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatus()
        }
        updateFocusNode()
        updateDiceNodes()
    }

    // MARK: - Session State Management

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .notAvailable:
            trackingStatus = "Tracking: Not Available"
        case .limited(let reason):
            switch reason {
            case .initializing:
                trackingStatus = "Tracking: Initializing..."
            case .excessiveMotion:
                trackingStatus = "Tracking: Limited Due To Excessive Motion"
            case .insufficientFeatures:
                trackingStatus = "Tracking: Limited Due To Insufficient Features"
            case .relocalizing:
                trackingStatus = "Tracking: Relocalizing..."
            @unknown default:
                trackingStatus = "Tracking: Unknown Status"
            }
        case .normal:
            trackingStatus = ""
        }
    }

    // MARK: - Session Error Managent

    func session(_ session: ARSession, didFailWithError error: Error) {
        trackingStatus = "AR Session Failure: \(error)"
    }

    func sessionWasInterrupted(_ session: ARSession) {
        trackingStatus = "AR Session Was Interrupted!"
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        trackingStatus = "AR Session Intteruption Ended"
    }

    // MARK: - Plane Management

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

        let planeNode = self.createARPlaneNode(planeAnchor: planeAnchor,
                                               color: UIColor.yellow.withAlphaComponent(0.5))
        node.addChildNode(planeNode)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

        updateARSurfaceNode(node: node.childNodes[0], planeAnchor: planeAnchor)
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor else { return }

        removeARPlaneNode(planeNode: node)
    }

}

// MARK: - ARCoachingOverlayViewDelegate

extension ViewController: ARCoachingOverlayViewDelegate {

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        resetGame()
    }

    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) { }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        startGame()
    }

}
