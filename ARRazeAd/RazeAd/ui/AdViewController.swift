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
import Vision

class AdViewController: UIViewController {

    // MARK: - IBOutlets

    @IBOutlet private var sceneView: ARSCNView!

    // MARK: - Properties

    private weak var targetView: TargetView!

    private var billboard: BillboardContainer?

    // MARK: - View Controller Lifecyle

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.showsStatistics = true

        let scene = SCNScene()
        sceneView.scene = scene

        let targetView = TargetView(frame: view.bounds)
        view.addSubview(targetView)
        self.targetView = targetView
        targetView.show()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let config = ARWorldTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.worldAlignment = .camera

        var detectionImages = ARReferenceImage.referenceImages(inGroupNamed: "RMK-ARKit-triggers", bundle: .main)!
        let runtimeImage = ARReferenceImage(UIImage(named: "logo_2")!.cgImage!, orientation: .up, physicalWidth: 0.2)
        detectionImages.insert(runtimeImage)
        config.detectionImages = detectionImages

        sceneView.session.run(config)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

}

// MARK: - Touch Handling

extension AdViewController {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let currentFrame = sceneView.session.currentFrame else { return }

        if billboard?.videoNode != nil {
            billboard?.billboardNode?.isHidden = false
            billboard?.videoNodeHandler?.removeNode()

            billboard?.videoNodeHandler = nil
            billboard?.videoNode = nil
            return
        }

        if billboard?.billboardNode != nil {
            removeBillboard()
            return
        }

        DispatchQueue.global(qos: .background).async {
            do {
                let request = VNDetectBarcodesRequest { (request, error) in
                    guard let result = request.results?.compactMap({ $0 as? VNBarcodeObservation }).first else {
                        print("[VISION] VNRequest produced no results")
                        return
                    }

                    guard let payload = result.payloadStringValue, let payloadData = payload.data(using: .utf8) else {
                        print("[VISION] VNBarcodeObservation contained no payload string")
                        return
                    }

                    guard let barcodeData = try? JSONDecoder().decode(BillboardData.self, from: payloadData) else {
                        print("[VISION] VNBarcodeObservation contained invalid payload data")
                        return
                    }

                    let coordinates: [matrix_float4x4] = [
                        result.topLeft,
                        result.topRight,
                        result.bottomRight,
                        result.bottomLeft].compactMap {
                            return currentFrame.hitTest($0, types: [.featurePoint]).first?.worldTransform
                    }

                    guard coordinates.count == 4 else { return }

                    DispatchQueue.main.async {
                        self.removeBillboard()

                        let (topLeft, topRight, bottomRight, bottomLeft) =
                            (coordinates[0], coordinates[1], coordinates[2], coordinates[3])

                        self.createBillboard(data: barcodeData,
                                             topLeft: topLeft,
                                             topRight: topRight,
                                             bottomRight: bottomRight,
                                             bottomLeft: bottomLeft)
                    }
                }

                let handler = VNImageRequestHandler(cvPixelBuffer: currentFrame.capturedImage)
                try handler.perform([request])
            } catch(let error) {
                print("[VISION] An error occured during detection: \(error)")
            }
        }
    }

}

// MARK: - Private Functions

private extension AdViewController {

    private func createBillboard(data: BillboardData,
                                 topLeft: matrix_float4x4,
                                 topRight: matrix_float4x4,
                                 bottomRight: matrix_float4x4,
                                 bottomLeft: matrix_float4x4) {
        let plane = RectangularPlane(topLeft: topLeft,
                                     topRight: topRight,
                                     bottomLeft: bottomLeft,
                                     bottomRight: bottomRight)

        let rotation = SCNMatrix4MakeRotation(.pi / 2.0, 0.0, 0.0, 1.0)
        let rotatedCenter = matrix_multiply(plane.center, matrix_float4x4(rotation))
        let anchor = ARAnchor(name: "billboard_anchor", transform: rotatedCenter)

        billboard = BillboardContainer(data: data, billboardAnchor: anchor, plane: plane)
        billboard?.videoPlayerDelegate = self

        sceneView.session.add(anchor: anchor)
        print("New billboard created")
    }

    private func createBillboard(center: matrix_float4x4,
                                 size: CGSize) {
        let data = BillboardData(link: "https://www.raywenderlich.com",
                                 images: ["logo_1", "logo_2", "logo_3", "logo_4", "logo_5"],
                                 videoUrl: "https://wolverine.raywenderlich.com/books/" +
                                           "ark/sample_videos/beginning_arkit_intro.mp4")

        let plane = RectangularPlane(center: center, size: size)
        let rotation = SCNMatrix4MakeRotation(.pi / 2.0, -1.0, 0.0, 0.0)
        let rotatedCenter = matrix_multiply(center, matrix_float4x4(rotation))
        let anchor = ARAnchor(name: "billboard_anchor", transform: rotatedCenter)

        billboard = BillboardContainer(data: data,
                                       billboardAnchor: anchor,
                                       plane: plane)
        billboard?.videoPlayerDelegate = self
        sceneView.session.add(anchor: anchor)
        print("New billboard created")
    }

    private func createBillboardController() {
        let navController = UIStoryboard(name: "Billboard",
                                         bundle: .main).instantiateInitialViewController() as! UINavigationController

        let billboardVC = navController.visibleViewController as! BillboardViewController

        billboardVC.sceneView = sceneView
        billboardVC.billboard = billboard

        billboardVC.willMove(toParent: self)
        addChild(billboardVC)
        view.addSubview(billboardVC.view)
        billboardVC.didMove(toParent: self)

        show(viewController: billboardVC)
    }

    private func show(viewController: BillboardViewController) {
        let material = SCNMaterial()
        material.isDoubleSided = true
        material.cullMode = .front

        material.diffuse.contents = viewController.view

        billboard?.viewController = viewController
        billboard?.billboardNode?.geometry?.materials = [material]
    }

    private func removeBillboard() {
        if let anchor = billboard?.billboardAnchor {
            sceneView.session.remove(anchor: anchor)
            billboard?.billboardNode?.removeFromParentNode()
            billboard = nil
        }
    }

    private func addBillboardNode() -> SCNNode? {
        guard let billboard = self.billboard else { return nil }

        let rectangle = SCNPlane(width: billboard.plane.width, height: billboard.plane.height)
        let node = SCNNode(geometry: rectangle)
        node.name = "billboard"
        self.billboard?.billboardNode = node

        return node
    }

}

// MARK: - VideoPlayerDelegate

extension AdViewController: VideoPlayerDelegate {

    func didStartPlay() {
        billboard?.billboardNode?.isHidden = true
    }

    func didEndPlay() {
        billboard?.billboardNode?.isHidden = false
    }

}

// MARK: - ARSCNViewDelegate

extension AdViewController: ARSCNViewDelegate {

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        if let imageAnchor = anchors.compactMap({ $0 as? ARImageAnchor }).first {
            createBillboard(center: imageAnchor.transform,
                            size: imageAnchor.referenceImage.physicalSize)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let billboard = self.billboard else { return nil }

        var node: SCNNode?

        switch anchor {
            case (let billboardAnchor) where billboardAnchor == billboard.billboardAnchor:
                DispatchQueue.main.sync {
                    node = addBillboardNode()
                    self.createBillboardController()
                }
            case (let videoAnchor) where videoAnchor == billboard.videoAnchor:
                DispatchQueue.main.sync {
                    node = billboard.videoNodeHandler?.createNode()
                }
            default:
                break
        }

        return node
    }

}

// MARK: - ARSessionDelegate

extension AdViewController: ARSessionDelegate {

    func session(_ session: ARSession, didFailWithError error: Error) {

    }

    func sessionWasInterrupted(_ session: ARSession) {

    }

    func sessionInterruptionEnded(_ session: ARSession) {
        removeBillboard()
    }

}
