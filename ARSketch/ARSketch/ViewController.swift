/**
 * Copyright (c) 2019 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import SceneKit
import ARKit
import MultipeerConnectivity

class ViewController: UIViewController {

    // MARK: - IBOutlets

    @IBOutlet private weak var sceneView: ARSCNView!
    @IBOutlet private weak var sketchButton: UIButton!

    @IBOutlet private weak var mappingStatusLabel: UILabel!
    @IBOutlet private weak var sessionInfoView: UIVisualEffectView!
    @IBOutlet private weak var sessionInfoLabel: UILabel!

    @IBOutlet private weak var saveExperienceButton: StatusControlledButton!
    @IBOutlet private weak var loadExperienceButton: StatusControlledButton!

    @IBOutlet private weak var snapshotThumbnailImageView: UIImageView!
    @IBOutlet private weak var resetSceneButton: UIButton!
    @IBOutlet private weak var shareButton: UIButton!

    // MARK: - Properties

    private var peerSession: PeerSession!
    private var mapProvider: MCPeerID?

    private var previousPoint: SCNVector3?
    private let lineColor = UIColor.white

    private var lineObjectAnchors =  [ARAnchor]()

    private var isSketchButtonPressed = false
    private var viewCenter: CGPoint?

    private var defaultConfiguration: ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        return configuration
    }

    private lazy var mapSaveURL: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true).appendingPathComponent("mymap.arexperience")
        } catch {
            fatalError("Can't get URL to save map: \(error.localizedDescription)")
        }
    }()

    private var mapDataFromFile: Data? {
        return try? Data(contentsOf: mapSaveURL)
    }

    private var isRelocalizingMap = false

    // MARK: - View Life Cycle

    // Lock the orientation of the app to the orientation in which it is launched
    override var shouldAutorotate: Bool { return false }

    override func viewDidLoad() {
        super.viewDidLoad()

        let viewBounds = self.view.bounds
        viewCenter = CGPoint(x: viewBounds.width / 2.0, y: viewBounds.height / 2.0)
        loadExperienceButton.isEnabled = (mapDataFromFile != nil)

        peerSession = PeerSession(receivedDataHandler: handleReceivedData)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        sceneView.delegate = self

        sceneView.session.delegate = self
        sceneView.session.run(defaultConfiguration)

        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true

        saveExperienceButton.isHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - Place AR content

    private func addLineAnchorForObject(sourcePoint: SCNVector3?, destinationPoint: SCNVector3?) {
        guard let hitTestResult = sceneView
            .hitTest(self.viewCenter!, types: [.existingPlaneUsingGeometry, .estimatedHorizontalPlane])
            .first
            else { return }

        let lineAnchor = ARLineAnchor(name: "virtualObject\(lineObjectAnchors.count)",
                                      transform: hitTestResult.worldTransform,
                                      sourcePoint: sourcePoint,
                                      destinationPoint: destinationPoint)

        lineObjectAnchors.append(lineAnchor)
        sceneView.session.add(anchor: lineAnchor)

        if let data = try? NSKeyedArchiver.archivedData(withRootObject: lineAnchor, requiringSecureCoding: true) {
            self.peerSession.sendToAllPeers(data)
        }
    }

    // MARK: - Save & Load World Maps

    private func saveWorldMap() {
        sceneView.session.getCurrentWorldMap { map, error in
            guard let map = map else {
                self.showAlert(title: "Can't get current world map", message: error!.localizedDescription)
                return
            }

            guard let snapshotAnchor = SnapshotAnchor(capturing: self.sceneView) else {
                fatalError("Failed to take snapshot")
            }
            map.anchors.append(snapshotAnchor)

            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                try data.write(to: self.mapSaveURL, options: [.atomic])
            } catch {
                fatalError("Can't save map: \(error.localizedDescription)")
            }

            DispatchQueue.main.async {
                self.loadExperienceButton.isHidden = false
                self.loadExperienceButton.isEnabled = true
            }
        }
    }

    private func loadWorldMap() -> ARWorldMap {
        guard let data = mapDataFromFile else {
            fatalError("Saved map should already exist if this codepath was allowed")
        }

        do {
            guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                fatalError("No world map in archive data")
            }
            return map
        } catch {
            fatalError("Can't load map: \(error.localizedDescription)")
        }
    }

    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        let message: String
        snapshotThumbnailImageView.isHidden = true

        switch (trackingState, frame.worldMappingStatus) {
        case (.normal, .mapped), (.normal, .extending):
            if frame.anchors.contains(where: { $0.name == "virtualObject0" }) {
                message = "Tap 'Save Experience' to save the current map."
            } else {
                message = "Tap Sketch to draw on screen."
            }
        case (.normal, _) where (mapDataFromFile != nil && !isRelocalizingMap):
            message = """
            Move around to map the environment,
            or tap 'Load Experience' to load a saved experience.
            """
        case (.normal, _) where mapDataFromFile == nil || (frame.anchors.isEmpty && peerSession.connectedPeers.isEmpty):
            message = """
            Move around to map the environment,
            or wait to join a shared session.
            """
        case (.normal, _) where !peerSession.connectedPeers.isEmpty && mapProvider == nil:
            let peerNames = peerSession.connectedPeers.map({ $0.displayName }).joined(separator: ",")
            message = "Connected with \(peerNames)."
        case (.limited(.relocalizing), _) where isRelocalizingMap:
            message = "Move your device to the location shown in the image."
            snapshotThumbnailImageView.isHidden = false
        case (.limited(.initializing), _) where mapProvider != nil,
             (.limited(.relocalizing), _) where mapProvider != nil:
            message = "Received map from \(mapProvider!.displayName)."
        default:
            message = trackingState.localizedFeedback
        }

        sessionInfoLabel.text = message
        sessionInfoView.isHidden = message.isEmpty
    }

}

// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.isSketchButtonPressed = self.sketchButton.isHighlighted
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        guard let pointOfView = sceneView.pointOfView else { return }

        let transform = pointOfView.transform
        let direction = SCNVector3(-1 * transform.m31, -1 * transform.m32, -1 * transform.m33)
        let currentPoint = pointOfView.position + (direction * 0.1)

        if isSketchButtonPressed {
            if let previousPoint = previousPoint {
                addLineAnchorForObject(sourcePoint: previousPoint, destinationPoint: currentPoint)
            }
        }
        previousPoint = currentPoint
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let lineAnchor = anchor as? ARLineAnchor,
            let sourcePoint = lineAnchor.sourcePoint,
            let destinationPoint = lineAnchor.destinationPoint
            else { return }

        let lineNode = SCNLineNode(from: sourcePoint, to: destinationPoint, radius: 0.02, color: lineColor)
        node.addChildNode(lineNode)
    }

}

// MARK: - AR session management

extension ViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        switch frame.worldMappingStatus {
        case .extending, .mapped:
            if let lastAnchor = lineObjectAnchors.last, frame.anchors.contains(lastAnchor) {
                saveExperienceButton.isEnabled = true
                saveExperienceButton.isHidden = false
            } else {
                saveExperienceButton.isEnabled = false
            }
        case .notAvailable, .limited:
            saveExperienceButton.isEnabled = false
        @unknown default:
            print("Unknown ARSession worldMappingStatus encountered")
        }

        mappingStatusLabel.text = """
        Mapping: \(frame.worldMappingStatus.description)
        Tracking: \(frame.camera.trackingState.description)
        """
    }

    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard let frame = session.currentFrame
            else { return }

        updateSessionInfoLabel(for: frame, trackingState: camera.trackingState)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay.
        sessionInfoLabel.text = "Session was interrupted"
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required.
        sessionInfoLabel.text = "Session interruption ended"
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        sessionInfoLabel.text = "Session failed: \(error.localizedDescription)"
    }

}

// MARK: - Persistent AR

extension ViewController {

    @IBAction func resetTracking(_ sender: UIButton?) {
        sceneView.session.run(defaultConfiguration, options: [.resetTracking, .removeExistingAnchors])
        lineObjectAnchors.removeAll()
        isRelocalizingMap = false
    }

    @IBAction func saveExperience(_ sender: UIButton) {
        saveWorldMap()
    }

    @IBAction func loadExperience(_ sender: Any) {
        let map = loadWorldMap()
        displaySnapshotImage(from: map)
        configureARSession(for: map)
    }

    @IBAction func shareWorldMap(_ sender: Any) {
        let mcBrowserVC = MCBrowserViewController(serviceType: PeerSession.serviceType,
                                                  session: peerSession.mcSession)
        mcBrowserVC.delegate = self
        present(mcBrowserVC, animated: true, completion: nil)
    }

}

extension ViewController: MCBrowserViewControllerDelegate {

    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap else {
                print("Error: \(error!.localizedDescription)")
                return
            }
            guard let snapshotAnchor = SnapshotAnchor(capturing: self.sceneView) else {
                fatalError("Can't take snapshot")
            }
            map.anchors.append(snapshotAnchor)
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) else {
                fatalError("can't encode map")
            }
            self.peerSession.sendToAllPeers(data)
        }
        browserViewController.dismiss(animated: true, completion: nil)
    }

    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        browserViewController.dismiss(animated: true, completion: nil)
    }

}

extension ViewController {

    func handleReceivedData(_ data: Data, from peer: MCPeerID) {
        do {
            if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                DispatchQueue.main.async {
                    self.displaySnapshotImage(from: worldMap)
                }
                configureARSession(for: worldMap)
                mapProvider = peer
                return
            }
        } catch {
            print("can't decode data received from \(peer)")
        }

        if !isRelocalizingMap {
            do {
                if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARLineAnchor.self, from: data) {
                    sceneView.session.add(anchor: anchor)
                }
            } catch {
                print("unknown data received from \(peer)")
            }
        }
    }

    func displaySnapshotImage(from worldMap: ARWorldMap) {
        if let snapshotData = worldMap.snapshotAnchor?.imageData, let snapshot = UIImage(data: snapshotData) {
            self.snapshotThumbnailImageView.image = snapshot
        } else {
            print("No snapshot image in world map")
        }
        worldMap.anchors.removeAll(where: { $0 is SnapshotAnchor })
    }

    func configureARSession(for worldMap: ARWorldMap) {
        let configuration = self.defaultConfiguration
        configuration.initialWorldMap = worldMap
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isRelocalizingMap = true
        lineObjectAnchors.removeAll()
    }

}
