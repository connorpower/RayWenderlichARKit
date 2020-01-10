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
import SpriteKit
import AVFoundation
import ARKit

class VideoCell: UICollectionViewCell {

    // MARK: - IBOutlets
    @IBOutlet private weak var playButton: UIButton!
    @IBOutlet private weak var playerContainer: UIView!

    // MARK: - Functions

    func configure(videoUrl: String, sceneView: ARSCNView, billboard: BillboardContainer) {

    }

    // MARK: - IBActions

    @IBAction private func play() {

    }

}

//extension VideoCell: VideoNodeHandler {
//  func createNode() -> SCNNode? {
//    guard let billboard = billboard else { return nil }
//
//    let frameSize = CGSize(width: 1024, height: 1024)
//    let url = URL(string: videoUrl)!
//
//    let player = AVPlayer(url: url)
//    videoNode = SKVideoNode(avPlayer: player)
//    videoNode.size = frameSize
//    videoNode.position = CGPoint(x: frameSize.width / 2, y: frameSize.height / 2)
//    videoNode.yScale = -1.0
//
//    spriteScene = SKScene(size: frameSize)
//    spriteScene.scaleMode = .aspectFit
//    spriteScene.backgroundColor = UIColor(white: 33/255, alpha: 1.0)
//    spriteScene.addChild(videoNode)
//
//    let billboardSize = CGSize(width: billboard.plane.width, height: billboard.plane.height / 2)
//    let plane = SCNPlane(width: billboardSize.width, height: billboardSize.height)
//    plane.firstMaterial!.isDoubleSided = true
//    plane.firstMaterial!.diffuse.contents = spriteScene
//    let node = SCNNode(geometry: plane)
//
//    billboard.videoNode = node
//
//    billboard.videoNodeHandler = self
//
//    videoNode.play()
//    return node
//  }
//
//  func removeNode() {
//    videoNode?.pause()
//
//    spriteScene?.removeAllChildren()
//    spriteScene = nil
//
//    if let videoAnchor = billboard?.videoAnchor {
//      sceneView?.session.remove(anchor: videoAnchor)
//    }
//
//    billboard?.videoPlayerDelegate?.didEndPlay()
//
//    billboard?.videoNode?.removeFromParentNode()
//    billboard?.videoAnchor = nil
//    billboard?.videoNode = nil
//
//    playButton.isEnabled = true
//  }
//}
