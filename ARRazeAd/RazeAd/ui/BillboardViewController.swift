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

// MARK: - Enums

private enum Section: Int {
    case video = 0
    case images = 1
}

private enum Cell: String {
    case cellVideo
    case cellImage
}

// MARK: - BillboardViewController

class BillboardViewController: UICollectionViewController {

    // MARK: - Properties

    var sceneView: ARSCNView!
    var billboard: BillboardContainer!

    // MARK: - Private Properties

    private let doubleTapGesture = UITapGestureRecognizer()

    private weak var mainViewController: UIViewController?
    private weak var mainView: UIView?

    // MARK: - View Controller Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.addTarget(self, action: #selector(didDoubleTap))
        view.addGestureRecognizer(doubleTapGesture)
    }

    // MARK: - Gesture Recognizers

    @objc private func didDoubleTap() {
        guard let billboard = billboard else { return }

        if billboard.isFullScreen {
            restoreFromFullScreen()
        } else {
            showFullScreen()
        }
    }

    // MARK: - Private Functions

    private func showFullScreen() {
        guard let billboard = billboard, !billboard.isFullScreen else { return }
        guard let mainViewController = parent as? AdViewController else { return }

        self.mainViewController = mainViewController
        self.mainView = view.superview

        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()

        willMove(toParent: mainViewController)
        mainViewController.view.addSubview(view)
        mainViewController.addChild(self)
        didMove(toParent: mainViewController)

        billboard.isFullScreen = true
    }

    private func restoreFromFullScreen() {
        guard let billboard = billboard, billboard.isFullScreen else { return }
        guard let mainViewController = mainViewController, let mainView = mainView else { return }

        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()

        willMove(toParent: mainViewController)
        mainView.addSubview(view)
        mainViewController.addChild(self)
        didMove(toParent: mainViewController)

        billboard.isFullScreen = false
        self.mainViewController = nil
        self.mainView = nil
    }

}

// MARK: - UICollectionViewDataSource

extension BillboardViewController {

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }

        switch section {
            case .images:
                return billboard?.data.images.count ?? 0
            case .video:
                return 1
        }
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            fatalError("Unexpected section")
        }

        let cellType: Cell
        switch section {
            case .images:
                cellType = .cellImage
            case .video:
                cellType = .cellVideo
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellType.rawValue, for: indexPath)

        switch cell {
            case let imageCell as ImageCell:
                let image = UIImage(named: billboard.data.images[indexPath.item])!
                imageCell.show(image: image)
            case let videoCell as VideoCell:
                let videoURL = billboard.data.videoUrl
                videoCell.configure(videoUrl: videoURL, sceneView: sceneView, billboard: billboard)
            default:
                fatalError("Unrecognized cell")
        }

        return cell
    }

}

// MARK: - UICollectionViewDelegateFlowLayout

extension BillboardViewController : UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }

}
