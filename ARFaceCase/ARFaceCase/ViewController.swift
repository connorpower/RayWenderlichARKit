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

    @IBOutlet private var sceneView: ARSCNView!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var recordButton: UIButton!

    // MARK: - Properties

    private var session: ARSession { return sceneView.session }

    // MARK: - View Controller Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
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
        resetTracking()
    }

    @IBAction private func didTapMask(_ sender: Any) {
        print("didTapMask")
    }

    @IBAction private func didTapGlasses(_ sender: Any) {
        print("didTapGlasses")
    }

    @IBAction private func didTapPig(_ sender: Any) {
        print("didTapPig")
    }

    @IBAction private func didTapRecord(_ sender: Any) {
        print("didTapRecord")
    }

    // MARK: - Private Functions

    private func setupScene() {
        sceneView.delegate = self
        sceneView.showsStatistics = true
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

    // Tag: CreateARSCNFaceGeometry

    // Tag: Setup Face Content Nodes

    private func updateMessage(text: String) {
        DispatchQueue.main.async {
            self.messageLabel.text = text
        }
    }

}

// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {

    // Tag: SceneKit Renderer

    // Tag: ARNodeTracking

    // Tag: ARFaceGeometryUpdate

    // Tag: ARSession Handling

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
