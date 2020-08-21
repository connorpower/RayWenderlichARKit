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
import ARKit

class DeckViewController : UIViewController, ARSessionDelegate {
    @IBOutlet var sceneView: ARSCNView!

    enum Card: String {
        case clubAce
        case club2
        case club3
        case club4
        case club5
        case club6
        case club7
        case club8
        case club9
        case club10
        case clubJack
        case clubQueen
        case clubKing
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.showsStatistics = true
        let scene = SCNScene()
        sceneView.scene = scene
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARImageTrackingConfiguration()
        configuration.maximumNumberOfTrackedImages = 1

        let triggerImages = ARReferenceImage.referenceImages(inGroupNamed: "deck", bundle: nil)!
        configuration.trackingImages = triggerImages

        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
}

extension DeckViewController {
    func createCardOverlayNode(for anchor: ARImageAnchor) -> SCNNode {
        let box = SCNBox(width: anchor.referenceImage.physicalSize.width,
                         height: 0.0001,
                         length: anchor.referenceImage.physicalSize.height,
                         chamferRadius: 0)

        if let material = box.firstMaterial {
            material.diffuse.contents = UIColor.red
            material.transparency = 0.3
        }

        return SCNNode(geometry: box)
    }

    func createInfoPanelNode(for anchor: ARImageAnchor) -> SCNNode {
        let cardName = anchor.referenceImage.name ?? "Unknown card"

        let plane = SCNPlane(width: anchor.referenceImage.physicalSize.width,
                             height: anchor.referenceImage.physicalSize.height / 12)
        plane.cornerRadius = 0.0015
        let labelSize = CGSize(width: 100, height: 100 * plane.height / plane.width)
        let labelVerticalOffset = plane.height / 2

        let material = SCNMaterial()

        DispatchQueue.main.sync {
            let label = UILabel()

            label.backgroundColor = UIColor.clear
            label.textColor = UIColor.darkGray
            label.text = cardName
            label.frame.size = labelSize
            label.textAlignment = .center

            material.diffuse.contents = label
        }

        material.transparency = 0.8
        plane.materials = [material]

        let node = SCNNode(geometry: plane)

        let translation = SCNMatrix4MakeTranslation(0,
                                                    Float(anchor.referenceImage.physicalSize.height / 2 + labelVerticalOffset + 0.001),
                                                    0)
        let rotation = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
        let transform = SCNMatrix4Mult(translation, rotation)
        node.transform = transform

        SCNTransaction.animationDuration = 2.0

        let height = plane.height
        let animation = CABasicAnimation(keyPath: "height")
        animation.fromValue = 0.0
        animation.toValue = height
        animation.duration = 1.0
        animation.autoreverses = false
        animation.repeatCount = 0
        plane.addAnimation(animation, forKey: "height")

        return node
    }
}

// MARK: - ARSCNViewDelegate

extension DeckViewController : ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        if let imageAnchor = anchor as? ARImageAnchor {
            let overlayNode = createCardOverlayNode(for: imageAnchor)

            let infoPanelNode = createInfoPanelNode(for: imageAnchor)
            overlayNode.addChildNode(infoPanelNode)

            return overlayNode
        }

        return nil
    }
}
