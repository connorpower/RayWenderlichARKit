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
import ReplayKit

class ViewController: UIViewController {

    // MARK: - Enums

    private enum ContentType {
        case none
        case mask
        case glasses
        case pig
    }

    // MARK: - IBOutlets

    @IBOutlet private var sceneView: ARSCNView!
    @IBOutlet private weak var messageLabel: UILabel!

    @IBOutlet private weak var recordButton: UIButton! {
        didSet {
            recordButton.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        }
    }

    // MARK: - Properties

    private var session: ARSession { return sceneView.session }

    private var anchorNode: SCNNode?
    private var mask: Mask?
    private var maskType = Mask.MaskType.basic
    private var glasses: Glasses?
    private var pig: Pig?

    private var contentType = ContentType.none

    private let sharedRecorder = RPScreenRecorder.shared()
    private var isRecording = false

    // MARK: - View Controller Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        createFaceGeometry()

        sharedRecorder.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        UIApplication.shared.isIdleTimerDisabled = true
        resetTracking()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        UIApplication.shared.isIdleTimerDisabled = false
        session.pause()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    // MARK: - IBActions

    @IBAction private func didTapReset(_ sender: Any) {
        print("didTapReset")

        contentType = .none
        resetTracking()
    }

    @IBAction private func didTapMask(_ sender: Any) {
        print("didTapMask")

        contentType = .mask
        maskType = maskType.next()
        mask?.swapMaterials(maskType: maskType)
        resetTracking()
    }

    @IBAction private func didTapGlasses(_ sender: Any) {
        print("didTapGlasses")

        contentType = .glasses
        resetTracking()
    }

    @IBAction private func didTapPig(_ sender: Any) {
        print("didTapPig")

        contentType = .pig
        resetTracking()
    }

    @IBAction private func didTapRecord(_ sender: Any) {
        print("didTapRecord")

        guard sharedRecorder.isAvailable else {
            print("Recording is not available")
            return
        }

        if !isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }

    // MARK: - Private Functions

    private func setupScene() {
        sceneView.delegate = self
        sceneView.showsStatistics = true

        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = false
        sceneView.scene.lightingEnvironment.intensity = 1.0

        sceneView.rendersCameraGrain = true
        sceneView.scene.rootNode.camera?.grainIntensity = 1.0
    }

    private func resetTracking() {
        guard ARFaceTrackingConfiguration.isSupported else {
            updateMessage(text: "Face tracking is not supported")
            return
        }

        updateMessage(text: "Looking for face...")

        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.providesAudioData = false
        config.isWorldTrackingEnabled = false
        config.maximumNumberOfTrackedFaces = 1

        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    private func createFaceGeometry() {
        updateMessage(text: "Creating face geometry...")

        let maskGeometry = ARSCNFaceGeometry(device: sceneView.device!)!
        mask = Mask(geometry: maskGeometry, maskType: maskType)

        let glassesGeometry = ARSCNFaceGeometry(device: sceneView.device!)!
        glasses = Glasses(geometry: glassesGeometry)

        let pigGeometry = ARSCNFaceGeometry(device: sceneView.device!)!
        pig = Pig(geometry: pigGeometry)
    }

    private func setupFaceNodeContent() {
        guard let node = anchorNode else { return }

        node.childNodes.forEach { $0.removeFromParentNode() }

        switch contentType {
        case .mask:
            if let mask = mask {
                node.addChildNode(mask)
            }
        case .glasses:
            if let glasses = glasses {
                node.addChildNode(glasses)
            }
        case .pig:
            if let pig = pig {
                node.addChildNode(pig)
            }
        case .none:
            break
        }
    }

    private func updateMessage(text: String) {
        DispatchQueue.main.async {
            self.messageLabel.text = text
        }
    }

}

// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        anchorNode = node
        setupFaceNodeContent()
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }

        updateMessage(text: "Tracking your face...")

        switch contentType {
            case .mask:
                mask?.update(withFaceAnchor: faceAnchor)
            case .glasses:
                glasses?.update(withFaceAnchor: faceAnchor)
        case .pig:
            pig?.update(withFaceAnchor: faceAnchor)
            case .none:
                break
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let estimate = session.currentFrame?.lightEstimate else { return }

        let intensity = estimate.ambientIntensity / 1000.0
        sceneView.scene.lightingEnvironment.intensity = intensity
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("** didFailWithError: \(error)")
        updateMessage(text: "AR session failed.")
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("** sessionInterrupted")
        updateMessage(text: "Session interrupted.")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("** sessionInterruptEnded")
        updateMessage(text: "Session interruption ended.")
    }

}

// MARK: - RPPreviewViewControllerDelegate (ReplayKit)

extension ViewController: RPPreviewViewControllerDelegate, RPScreenRecorderDelegate {

    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        print("RPPreviewViewController didFinish")
        dismiss(animated: true, completion: nil)
    }

    func screenRecorder(_ screenRecorder: RPScreenRecorder,
                        didStopRecordingWith previewViewController: RPPreviewViewController?,
                        error: Error?) {
        guard error == nil else {
            print("There was an error recording: \(String(describing: error?.localizedDescription))")
            self.isRecording = false
            return
        }
    }

    func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        DispatchQueue.main.async {
            self.recordButton.isEnabled = screenRecorder.isAvailable
        }
    }

    private func startRecording() {
        sharedRecorder.isMicrophoneEnabled = true

        sharedRecorder.startRecording { error in
            guard error == nil else {
                print("There was an error starting the recording: \(String(describing: error?.localizedDescription))")
                return
            }

            print("Started recording successfully")
            self.isRecording = true

            DispatchQueue.main.async {
                self.recordButton.setTitle("Stop Recording", for: .normal)
                self.recordButton.backgroundColor = .red
            }
        }
    }

    private func stopRecording() {
        sharedRecorder.isMicrophoneEnabled = false

        sharedRecorder.stopRecording { previewViewController, error in
            guard error == nil else {
                print("There was an error stopping the recording: \(String(describing: error?.localizedDescription))")
                return
            }

            print("Stopped recording successfully")
            self.isRecording = false

            if let preview = previewViewController {
                preview.previewControllerDelegate = self
                preview.view.tintColor = .systemGreen
                self.present(preview, animated: true, completion: nil)
            }

            DispatchQueue.main.async {
                self.recordButton.setTitle("Start Recording", for: .normal)
                self.recordButton.backgroundColor = UIColor(named: "ui-green")
            }
        }
    }

}
