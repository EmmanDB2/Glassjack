import Foundation
import MultipeerConnectivity

/// §6 over Apple's peer-to-peer stack rather than a server.
///
/// The host advertises with the room code in its discovery info; a guest browses
/// and only invites the peer whose advertised code matches what was typed. That is
/// how "join by six-character code" maps onto a transport with no directory: the
/// code is the filter, not an address.
///
/// Peers are exposed upward as opaque keys minted per connection, because
/// `MCPeerID.displayName` is whatever the player called themselves and two people
/// can easily pick the same one.
@MainActor
final class MultipeerTransport: NSObject, MultiplayerTransport {
    weak var delegate: MultiplayerTransportDelegate?

    /// Must be 1–15 characters of lowercase ASCII, digits and hyphens.
    private static let serviceType = "glassjack-mp"
    private static let codeKey = "code"

    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var wantedCode: String?
    private var keysByPeer: [MCPeerID: String] = [:]
    private var peersByKey: [String: MCPeerID] = [:]

    // MARK: Lifecycle

    func startHosting(roomCode: String, displayName: String) {
        stop()
        let peer = makePeer(displayName)
        let session = makeSession(for: peer)

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peer,
            discoveryInfo: [Self.codeKey: roomCode],
            serviceType: Self.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()

        self.peerID = peer
        self.session = session
        self.advertiser = advertiser
        wantedCode = roomCode
    }

    func startJoining(roomCode: String, displayName: String) {
        stop()
        let peer = makePeer(displayName)
        let session = makeSession(for: peer)

        let browser = MCNearbyServiceBrowser(peer: peer, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()

        self.peerID = peer
        self.session = session
        self.browser = browser
        wantedCode = roomCode.uppercased()
    }

    func send(_ message: MPMessage, to peer: String?) {
        guard let session else { return }

        let targets: [MCPeerID]
        if let peer {
            guard let single = peersByKey[peer] else { return }
            targets = [single]
        } else {
            targets = session.connectedPeers
        }
        guard !targets.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: targets, with: .reliable)
        } catch {
            delegate?.transportDidFail("Could not send: \(error.localizedDescription)")
        }
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        peerID = nil
        wantedCode = nil
        keysByPeer.removeAll()
        peersByKey.removeAll()
    }

    // MARK: Plumbing

    private func makePeer(_ displayName: String) -> MCPeerID {
        // MCPeerID rejects empty names and truncates past 63 bytes.
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.isEmpty ? "Player" : String(trimmed.prefix(30))
        return MCPeerID(displayName: safe)
    }

    private func makeSession(for peer: MCPeerID) -> MCSession {
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        return session
    }

    private func key(for peer: MCPeerID) -> String {
        if let existing = keysByPeer[peer] { return existing }
        let minted = UUID().uuidString
        keysByPeer[peer] = minted
        peersByKey[minted] = peer
        return minted
    }
}

/// MultipeerConnectivity predates `Sendable`, and its delegate callbacks arrive on
/// the framework's own queue. Peers and handlers are safe to carry across the hop to
/// the main actor; the compiler just cannot prove it.
private struct Unchecked<T>: @unchecked Sendable {
    let value: T
}

// MARK: - MCSessionDelegate

extension MultipeerTransport: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let boxed = Unchecked(value: peerID)
        Task { @MainActor in
            let peerID = boxed.value
            switch state {
            case .connected:
                delegate?.transportDidConnect(peer: key(for: peerID))
            case .notConnected:
                let existing = keysByPeer[peerID]
                if let existing {
                    keysByPeer.removeValue(forKey: peerID)
                    peersByKey.removeValue(forKey: existing)
                    delegate?.transportDidDisconnect(peer: existing)
                }
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let boxed = Unchecked(value: peerID)
        Task { @MainActor in
            guard let message = try? JSONDecoder().decode(MPMessage.self, from: data) else {
                delegate?.transportDidFail("Received something unreadable")
                return
            }
            delegate?.transportDidReceive(message, from: key(for: boxed.value))
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - Advertiser (host)

extension MultipeerTransport: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let boxed = Unchecked(value: invitationHandler)
        Task { @MainActor in
            // The guest already matched on our code before inviting, and the table
            // caps itself at four seats upstream, so accept and let the session
            // decide whether there is room.
            boxed.value(self.session != nil, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            delegate?.transportDidFail("Could not open the table: \(error.localizedDescription)")
        }
    }
}

// MARK: - Browser (guest)

extension MultipeerTransport: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        let boxed = Unchecked(value: peerID)
        Task { @MainActor in
            // The code is the filter — ignore every other table on the network.
            guard let wantedCode,
                  let advertised = info?[Self.codeKey],
                  advertised.uppercased() == wantedCode,
                  let session,
                  let browser = self.browser else { return }
            browser.invitePeer(boxed.value, to: session, withContext: nil, timeout: 20)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            delegate?.transportDidFail("Could not look for tables: \(error.localizedDescription)")
        }
    }
}
