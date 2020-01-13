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

    fileprivate var previousPoint: SCNVector3?
    private let lineColor = UIColor.white

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

    // MARK: - View Life Cycle

    // Lock the orientation of the app to the orientation in which it is launched
    override var shouldAutorotate: Bool { return false }

    override func viewDidLoad() {
        super.viewDidLoad()

        let viewBounds = self.view.bounds
        viewCenter = CGPoint(x: viewBounds.width / 2.0, y: viewBounds.height / 2.0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        sceneView.delegate = self

        sceneView.session.delegate = self
        sceneView.session.run(defaultConfiguration)

        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true

        //hide buttons
        saveExperienceButton.isHidden = true
        loadExperienceButton.isHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - Place AR content

    private var currentLineAnchorName = ""
    private var lineObjectAnchors =  [ARAnchor]()

    private func addLineAnchorForObject(sourcePoint: SCNVector3?, destinationPoint: SCNVector3?) {
        guard let hitTestResult = sceneView
            .hitTest(self.viewCenter!, types: [.existingPlaneUsingGeometry, .estimatedHorizontalPlane])
            .first
            else { return }

        currentLineAnchorName = "virtualObject\(lineObjectAnchors.count)"

        let lineAnchor = ARLineAnchor(name: currentLineAnchorName,
                                      transform: hitTestResult.worldTransform,
                                      sourcePoint: sourcePoint,
                                      destinationPoint: destinationPoint)

        lineObjectAnchors.append(lineAnchor)
        sceneView.session.add(anchor: lineAnchor)
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

    }

    @IBAction func saveExperience(_ sender: UIButton) {
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

    @IBAction func loadExperience(_ sender: Any) {

    }

    @IBAction func shareWorldMap(_ sender: Any) {

    }

}
