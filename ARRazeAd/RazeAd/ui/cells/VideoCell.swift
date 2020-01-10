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

    // MARK: - Properties

    private var isPlaying = false
    private var videoUrl: String!
    private var player: AVPlayer?

    private weak var billboard: BillboardContainer?
    private weak var sceneView: ARSCNView?

    // MARK: - IBOutlets

    @IBOutlet private weak var playButton: UIButton! {
        didSet {
            playButton.imageView?.contentMode = .scaleAspectFit
        }
    }

    @IBOutlet private weak var playerContainer: UIView!

    // MARK: - Functions

    func configure(videoUrl: String, sceneView: ARSCNView, billboard: BillboardContainer) {
        self.videoUrl = videoUrl
        self.sceneView = sceneView
        self.billboard = billboard

        billboard.videoNodeHandler = self
    }

    // MARK: - IBActions

    @IBAction private func play() {
        guard let billboard = billboard else { return }

        if billboard.isFullScreen {
            if isPlaying {
                stopVideo()
                playButton.setImage(#imageLiteral(resourceName: "arKit-play"), for: .normal)
            } else {
                createVideoPlayerView()
                playButton.setImage(#imageLiteral(resourceName: "arKit-pause"), for: .normal)
            }
            isPlaying.toggle()
        } else {
            createVideoPlayerAnchor()
            billboard.videoPlayerDelegate?.didStartPlay()
            playButton.isEnabled = false
        }
    }

    // MARK: - Private Functions

    private func createVideoPlayerAnchor() {
        guard let billboard = billboard, let sceneView = sceneView else { return }

        let center = matrix_multiply(billboard.plane.center,
                                     matrix_float4x4(SCNMatrix4MakeRotation(.pi / 2.0, 0.0, 0.0, 1.0)))
        let anchor = ARAnchor(name: "video player anchor", transform: center)
        sceneView.session.add(anchor: anchor)

        billboard.videoAnchor = anchor
    }

    private func stopVideo() {
        player?.pause()
    }

    private func createVideoPlayerView() {
        if player == nil {
            guard let url = URL(string: videoUrl) else { return }

            player = AVPlayer(url: url)
            let layer = AVPlayerLayer(player: player)
            layer.frame = playerContainer.bounds
            playerContainer.layer.addSublayer(layer)
        }

        player?.play()
    }

}

// MARK: - VideoNodeHandler

extension VideoCell: VideoNodeHandler {

    func createNode() -> SCNNode? {
        guard let billboard = billboard else { return nil }

        let player = AVPlayer(url: URL(string: videoUrl)!)

        let billboardSize = CGSize(width: billboard.plane.width, height: billboard.plane.height / 2)
        let plane = SCNPlane(width: billboardSize.width, height: billboardSize.height)
        plane.firstMaterial!.isDoubleSided = true
        plane.firstMaterial!.diffuse.contents = player
        let node = SCNNode(geometry: plane)

        billboard.videoNode = node
        billboard.videoNodeHandler = self

        player.play()
        return node
    }

    func removeNode() {
        player?.pause()

        if let videoAnchor = billboard?.videoAnchor {
            sceneView?.session.remove(anchor: videoAnchor)
        }

        billboard?.videoPlayerDelegate?.didEndPlay()

        billboard?.videoNode?.removeFromParentNode()
        billboard?.videoAnchor = nil
        billboard?.videoNode = nil

        playButton.isEnabled = true
    }

}
