//
//  PeerSession.swift
//  ARSketch
//
//  Created by Connor Power on 9/08/20.
//

import Foundation
import MultipeerConnectivity

class PeerSession: NSObject, MCAdvertiserAssistantDelegate {

    // MARK: - Constants

    static let serviceType = "arsketchsession"

    // MARK: - Properties

    private(set) var mcSession: MCSession!

    var connectedPeers: [MCPeerID] { return mcSession.connectedPeers }

    // MARK: - Private Properties

    private var advertiserAssistant: MCAdvertiserAssistant!
    private let receivedDataHandler: (Data, MCPeerID) -> Void
    private let peerID = MCPeerID(displayName: UIDevice.current.name)

    // MARK: - Initializer

    init(receivedDataHandler: @escaping (Data, MCPeerID) -> Void) {
        self.receivedDataHandler = receivedDataHandler
        super.init()

        mcSession = MCSession(peer: peerID,
                              securityIdentity: nil,
                              encryptionPreference: .required)
        mcSession.delegate = self

        advertiserAssistant =
            MCAdvertiserAssistant(serviceType: PeerSession.serviceType,
                                  discoveryInfo: nil, session: self.mcSession)
        advertiserAssistant.delegate = self
        advertiserAssistant.start()
    }

    func sendToAllPeers(_ data: Data) {
        do {
            try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
        } catch {
            print("error sending data to peers: \(error.localizedDescription)")
        }
    }

}

extension PeerSession: MCSessionDelegate {

    func session(_ session: MCSession,
                 peer peerID: MCPeerID,
                 didChange state: MCSessionState) {}

    func session(_ session: MCSession,
                 didReceive data: Data,
                 fromPeer peerID: MCPeerID) {
        receivedDataHandler(data, peerID)
    }

    func session(_ session: MCSession,
                 didReceive stream: InputStream,
                 withName streamName: String,
                 fromPeer peerID: MCPeerID) {
        fatalError("This service does not send/receive streams.")
    }

    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) {
        fatalError("This service does not send/receive resources.")
    }

    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) {
        fatalError("This service does not send/receive resources.")
    }
}
