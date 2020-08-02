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
import CoreMotion

// MARK: - Game State

enum GameState: Int16 {
    case detectSurface
    case hitStartToPlay
    case playGame
}

class ViewController: UIViewController {

    // MARK: - Constants

    private struct WheelPhysics {
        static let wheelRadius: CGFloat = 0.04
        static let wheelFrictionSlip: CGFloat = 0.9
        static let suspensionMaxTravel: CGFloat = 4.0
        static let suspensionMaxForce: CGFloat = 100
        static let suspensionRestLength: CGFloat = 0.08
        static let suspensionDamping: CGFloat = 2.0
        static let suspensionStiffness: CGFloat = 2.0
        static let suspensionCompression: CGFloat = 4.0
    }

    private struct SpeedConstants {
        static let defaultEngineForce: CGFloat = 10.0
        static let defaultBrakingForce: CGFloat = 0.1
        static let maximumSpeed: CGFloat = 2.0
        static let steeringClamp: CGFloat = 0.6

    }

    // MARK: - Properties

    override var prefersStatusBarHidden: Bool { return true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .landscapeRight }

    private var trackingStatus: String = ""
    private var statusMessage: String = ""
    private var gameState: GameState = .detectSurface
    private var focusPoint:CGPoint!
    private var focusNode: SCNNode!

    private var truckNode: SCNNode!
    private var wheelFLNode: SCNNode!
    private var wheelFRNode: SCNNode!
    private var wheelRLNode: SCNNode!
    private var wheelRRNode: SCNNode!

    private var physicsVehicle: SCNPhysicsVehicle!

    private var groundNode: SCNNode!

    private var isThrottling = false
    private var engineForce: CGFloat = 0.0
    private var brakingForce: CGFloat = 0.0

    private var motionManager = CMMotionManager()
    private var steeringAngle: CGFloat = 0.0

    // MARK: Outlets

    @IBOutlet private var sceneView: ARSCNView!
    @IBOutlet private var statusLabel: UILabel!
    @IBOutlet private var startButton: UIButton!
    @IBOutlet private var resetButton: UIButton!

    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.initSceneView()
        self.initScene()
        self.initARSession()
        self.loadModels()
    }

    // MARK: Init Functions

    func initSceneView() {
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = false
        //sceneView.showsStatistics = true
        //sceneView.preferredFramesPerSecond = 60
        //sceneView.antialiasingMode = .multisampling2X
        sceneView.debugOptions = [
            //ARSCNDebugOptions.showFeaturePoints,
            //ARSCNDebugOptions.showWorldOrigin,
            //SCNDebugOptions.showPhysicsShapes,
            //SCNDebugOptions.showBoundingBoxes
        ]

        focusPoint = CGPoint(x: view.center.x, y: view.center.y + view.center.y * 0.25)
    }

    func initScene() {
        let scene = SCNScene()
        scene.lightingEnvironment.contents = "MonsterTruck.scnassets/Textures/Environment_CUBE.jpg"
        scene.lightingEnvironment.intensity = 4
        scene.physicsWorld.speed = 1
        //scene.physicsWorld.timeStep = 1.0 / 60.0 // Physics Precision
        scene.isPaused = false
        sceneView.scene = scene
    }

    func initARSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            print("*** ARConfig: AR World Tracking Not Supported")
            return
        }

        let config = ARWorldTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.planeDetection = .horizontal
        config.worldAlignment = .gravity
        config.providesAudioData = false
        sceneView.session.run(config)
    }

    // MARK: Actions

    @IBAction private func startButtonPressed(_ sender: Any) {
        self.startGame()
    }

    @IBAction private func resetButtonPressed(_ sender: Any) {
        self.resetGame()
    }

    private func resetARSession() {
        let config = sceneView.session.configuration as! ARWorldTrackingConfiguration
        config.planeDetection = .horizontal
        sceneView.session.run(config,
                              options: [.resetTracking,
                                        .removeExistingAnchors])
    }

    // MARK: Private Helper Functions

    private func suspendARPlaneDetection() {
        let config = sceneView.session.configuration as! ARWorldTrackingConfiguration
        config.planeDetection = []
        sceneView.session.run(config)
    }

    private func createARPlaneNode(planeAnchor: ARPlaneAnchor, color: UIColor) -> SCNNode {
        let planeGeometry = SCNPlane(width: CGFloat(planeAnchor.extent.x),
                                     height: CGFloat(planeAnchor.extent.z))

        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = color
        planeGeometry.materials = [planeMaterial]

        let planeNode = SCNNode(geometry: planeGeometry)
        planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)

        return planeNode
    }

    private func updateARPlaneNode(planeNode: SCNNode, planeAchor: ARPlaneAnchor) {

        // 1 - Update plane geometry with planeAnchor details
        let planeGeometry = planeNode.geometry as! SCNPlane
        planeGeometry.width = CGFloat(planeAchor.extent.x)
        planeGeometry.height = CGFloat(planeAchor.extent.z)

        // 2 - Update plane position
        planeNode.position = SCNVector3Make(planeAchor.center.x, 0, planeAchor.center.z)
    }

    private func removeARPlaneNode(node: SCNNode) {
        for childNode in node.childNodes {
            childNode.removeFromParentNode()
        }
    }

    private func createPhyscisVehicleWheel(wheelNode: SCNNode, postion: SCNVector3) -> SCNPhysicsVehicleWheel {
        let wheel = SCNPhysicsVehicleWheel(node: wheelNode)
        wheel.connectionPosition = postion
        wheel.axle = SCNVector3(x: -1.0, y: 0.0, z: 0.0)
        wheel.radius = WheelPhysics.wheelRadius
        wheel.frictionSlip = WheelPhysics.wheelFrictionSlip
        wheel.maximumSuspensionTravel = WheelPhysics.suspensionMaxTravel
        wheel.maximumSuspensionForce = WheelPhysics.suspensionMaxForce
        wheel.suspensionRestLength = WheelPhysics.suspensionRestLength
        wheel.suspensionDamping = WheelPhysics.suspensionDamping
        wheel.suspensionStiffness = WheelPhysics.suspensionStiffness
        wheel.suspensionCompression = WheelPhysics.suspensionCompression
        return wheel
    }

    private func createVehiclePhsics() {
        if physicsVehicle != nil {
            sceneView.scene.physicsWorld.removeBehavior(physicsVehicle)
        }

        let wheelFL = createPhyscisVehicleWheel(wheelNode: wheelFLNode!,
                                                postion: SCNVector3(x: -0.07, y: +0.04, z: +0.06))
        let wheelFR = createPhyscisVehicleWheel(wheelNode: wheelFRNode!,
                                                postion: SCNVector3(x: +0.07, y: +0.04, z: +0.06))
        let wheelRL = createPhyscisVehicleWheel(wheelNode: wheelRLNode!,
                                                postion: SCNVector3(x: -0.07, y: +0.04, z: -0.06))
        let wheelRR = createPhyscisVehicleWheel(wheelNode: wheelRRNode!,
                                                postion: SCNVector3(x: +0.07, y: +0.04, z: -0.06))

        physicsVehicle = SCNPhysicsVehicle(chassisBody: truckNode.physicsBody!,
                                           wheels: [wheelFL, wheelFR, wheelRL, wheelRR])
        sceneView.scene.physicsWorld.addBehavior(physicsVehicle)
    }

    private func createFloorNode() -> SCNNode {
        let floorGeometry = SCNFloor()
        floorGeometry.reflectivity = 0.0

        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = UIColor.white
        floorMaterial.blendMode = .multiply
        floorGeometry.materials = [floorMaterial]

        let floorNode = SCNNode(geometry: floorGeometry)
        floorNode.position = SCNVector3Zero
        floorNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        floorNode.physicsBody?.restitution = 0.5
        floorNode.physicsBody?.friction = 4.0
        floorNode.physicsBody?.rollingFriction = 0.0

        return floorNode
    }

    private func startAccelerometer() {
        guard motionManager.isAccelerometerAvailable else {
            return
        }

        motionManager.accelerometerUpdateInterval = 1.0/60.0
        motionManager.startAccelerometerUpdates(to: OperationQueue.main) { (accelerometerData, error) in
            self.updateSteeringAngle(acceleration: accelerometerData!.acceleration)
        }
    }

    private func stopAccelerometer() {
        motionManager.stopAccelerometerUpdates()
    }

    // MARK: Update Functions

    private func updateStatus() {
        switch gameState {
        case .detectSurface: statusMessage = "Detecting surfaces..."
        case .hitStartToPlay: statusMessage = "Hit START to play!"
        case .playGame: statusMessage = "Touch to Throttle, Tilt to Steer!"
        }

        self.statusLabel.text = trackingStatus != "" ?
            "\(trackingStatus)" : "\(statusMessage)"
    }

    private func updateFocusNode() {
        // Hide Focus Node
        if gameState == .playGame {
            self.focusNode.isHidden = true
            return
        }

        // Show Focus Node
        self.focusNode.isHidden = false

        let results = self.sceneView.hitTest(self.focusPoint, types: [.existingPlaneUsingExtent])

        if results.count >= 1 {
            if let match = results.first {
                let t = match.worldTransform
                self.focusNode.position = SCNVector3(x: t.columns.3.x, y: t.columns.3.y, z: t.columns.3.z)
                self.gameState = .hitStartToPlay
            }
        } else {
            self.gameState = .detectSurface
        }
    }

    private func updatePositions() {
        truckNode.position = focusNode.position
        truckNode.position.y += 0.20

        truckNode.physicsBody?.velocity = SCNVector3Zero
        truckNode.physicsBody?.angularVelocity = SCNVector4Zero

        truckNode.physicsBody?.resetTransform()

        groundNode.position = focusNode.position
        groundNode.physicsBody?.resetTransform()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isThrottling = true
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isThrottling = false
    }

    private func updateVehiclePhysics() {
        guard gameState == .playGame else {
            return
        }

        if isThrottling {
            engineForce = SpeedConstants.defaultEngineForce
            brakingForce = 0.0
        } else {
            engineForce = 0.0
            brakingForce = SpeedConstants.defaultBrakingForce
        }

        if physicsVehicle.speedInKilometersPerHour > SpeedConstants.maximumSpeed {
            engineForce = 0.0
        }

        physicsVehicle.applyEngineForce(engineForce, forWheelAt: 0)
        physicsVehicle.applyEngineForce(engineForce, forWheelAt: 1)
        physicsVehicle.applyEngineForce(engineForce, forWheelAt: 2)
        physicsVehicle.applyEngineForce(engineForce, forWheelAt: 3)

        physicsVehicle.applyBrakingForce(brakingForce, forWheelAt: 0)
        physicsVehicle.applyBrakingForce(brakingForce, forWheelAt: 1)
        physicsVehicle.applyBrakingForce(brakingForce, forWheelAt: 2)
        physicsVehicle.applyBrakingForce(brakingForce, forWheelAt: 3)

        physicsVehicle.setSteeringAngle(steeringAngle, forWheelAt: 0)
        physicsVehicle.setSteeringAngle(steeringAngle, forWheelAt: 1)
    }

    private func updateSteeringAngle(acceleration: CMAcceleration) {
        steeringAngle = (CGFloat)(acceleration.y)

        if steeringAngle < -SpeedConstants.steeringClamp {
            steeringAngle = -SpeedConstants.steeringClamp
        } else if steeringAngle > SpeedConstants.steeringClamp {
            steeringAngle = SpeedConstants.steeringClamp
        }
    }

    // MARK: Game Management

    private func startGame() {
        guard self.gameState == .hitStartToPlay else {
            return
        }

        DispatchQueue.main.async {
            self.createVehiclePhsics()
            self.updatePositions()
            self.startAccelerometer()
            self.truckNode.isHidden = false
            self.groundNode.isHidden = false
            self.gameState = .playGame
        }
    }

    private func resetGame(){
        guard gameState == .playGame else { return }

        DispatchQueue.main.async {
            self.truckNode.isHidden = true
            self.groundNode.isHidden = true
            self.stopAccelerometer()
            self.gameState = .detectSurface
        }
    }

    private func loadModels() {
        // Load Focus Node
        let focusScene = SCNScene(named: "MonsterTruck.scnassets/Models/Focus.scn")!
        focusNode = focusScene.rootNode.childNode(withName: "Focus", recursively: false)
        focusNode.isHidden = true
        sceneView.scene.rootNode.addChildNode(focusNode)

        // Load Truck
        let truckScene = SCNScene(named: "MonsterTruck.scnassets/Models/MonsterTruck.scn")!
        truckNode = truckScene.rootNode.childNode(withName: "Truck", recursively: true)
        wheelFLNode = truckScene.rootNode.childNode(withName: "Wheel_FL", recursively: true)
        wheelFRNode = truckScene.rootNode.childNode(withName: "Wheel_FR", recursively: true)
        wheelRLNode = truckScene.rootNode.childNode(withName: "Wheel_RL", recursively: true)
        wheelRRNode = truckScene.rootNode.childNode(withName: "Wheel_RR", recursively: true)

        truckNode.addChildNode(wheelFLNode!)
        truckNode.addChildNode(wheelFRNode!)
        truckNode.addChildNode(wheelRLNode!)
        truckNode.addChildNode(wheelRRNode!)

        truckNode.isHidden = true
        sceneView.scene.rootNode.addChildNode(truckNode)

        groundNode = createFloorNode()
        groundNode.isHidden = true
        sceneView.scene.rootNode.addChildNode(groundNode)
    }

}

// MARK: - ARSCNViewDelegate

extension ViewController : ARSCNViewDelegate {

    // MARK: - SceneKit Management

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.updateStatus()
            self.updateFocusNode()
            self.updateVehiclePhysics()
        }
    }

    // MARK: - AR Session State Management

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .notAvailable:
            self.trackingStatus = "Tacking:  Not available!"
            break
        case .normal:
            self.trackingStatus = "" // Tracking Normal
            break
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                self.trackingStatus = "Tracking: Limited due to excessive motion!"
                break
            case .insufficientFeatures:
                self.trackingStatus = "Tracking: Limited due to insufficient features!"
                break
            case .relocalizing:
                self.trackingStatus = "Tracking: Resuming..."
                break
            case .initializing:
                self.trackingStatus = "Tracking: Initializing..."
                break
            @unknown default:
                self.trackingStatus = "Tracking: Unknown..."
            }
        }
    }

    // MARK: - AR Session Error Managent

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        self.trackingStatus = "AR Session Failure: \(error)"
    }

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        self.trackingStatus = "AR Session Was Interrupted!"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        self.trackingStatus = "AR Session Interruption Ended"
        self.resetGame()
    }

    // MARK: - Plane Management

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        DispatchQueue.main.async {
            let planeNode = self.createARPlaneNode(
                planeAnchor: planeAnchor,
                color: UIColor.blue.withAlphaComponent(0))
            node.addChildNode(planeNode)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        DispatchQueue.main.async {
            self.updateARPlaneNode(
                planeNode: node.childNodes[0],
                planeAchor: planeAnchor)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor else { return }
        DispatchQueue.main.async {
            self.removeARPlaneNode(node: node)
        }
    }

}
