import Flutter
import UIKit
import MultipeerConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var nearby: LanternNearby?
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      nearby = LanternNearby(messenger: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  override func applicationDidEnterBackground(_ application: UIApplication) {
    nearby?.stop()
    super.applicationDidEnterBackground(application)
  }
}

/// iOS-only, encrypted Multipeer transport. Display names are NOT authenticated.
/// There is deliberately no auto-accept and no background mode.
final class LanternNearby: NSObject, FlutterStreamHandler, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
  private var sink: FlutterEventSink?
  private var session: MCSession?
  private var advertiser: MCNearbyServiceAdvertiser?
  private var browser: MCNearbyServiceBrowser?
  private var peers: [String: MCPeerID] = [:]
  private var pending: String?
  private var connected: String?
  private var invitation: ((Bool, MCSession?) -> Void)?
  private let service = "lantern-v1"

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterEventChannel(name: "org.austugal.lantern/events", binaryMessenger: messenger).setStreamHandler(self)
    FlutterMethodChannel(name: "org.austugal.lantern/nearby", binaryMessenger: messenger).setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { sink = events; return nil }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { stop(); sink = nil; return nil }
  private func emit(_ type: String, _ id: String = "", _ extras: [String: Any] = [:]) {
    var event: [String: Any] = ["type": type, "id": id]
    extras.forEach { event[$0.key] = $0.value }
    sink?(event)
  }
  private func key(_ peer: MCPeerID) -> String {
    if let existing = peers.first(where: { $0.value == peer }) { return existing.key }
    let id = UUID().uuidString
    peers[id] = peer
    return id
  }
  private func failure(_ result: FlutterResult, _ message: String) { result(FlutterError(code: "nearby", message: message, details: nil)) }
  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let id = args["id"] as? String ?? ""
    switch call.method {
    case "start":
      stop(emitEvent: false)
      var name = (args["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      while name.utf8.count > 63 { name.removeLast() }
      guard !name.isEmpty else { failure(result, "Choose a display name first"); return }
      let peer = MCPeerID(displayName: name)
      let newSession = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
      newSession.delegate = self
      session = newSession
      let ad = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: ["v": "1"], serviceType: service)
      advertiser = ad
      ad.delegate = self
      let discovery = MCNearbyServiceBrowser(peer: peer, serviceType: service)
      browser = discovery
      discovery.delegate = self
      ad.startAdvertisingPeer()
      discovery.startBrowsingForPeers()
      result(nil)
    case "stop": stop(emitEvent: false); result(nil)
    case "request":
      guard let peer = peers[id], let session = session, pending == nil, connected == nil else { failure(result, "This person is no longer available"); return }
      pending = id
      browser?.invitePeer(peer, to: session, withContext: Data("lantern-v1".utf8), timeout: 30)
      result(nil)
    case "accept":
      guard pending == id, let handler = invitation, let session = session else { failure(result, "This invitation has expired"); return }
      invitation = nil
      handler(true, session)
      result(nil)
    case "reject":
      if pending == id { invitation?(false, nil); invitation = nil; pending = nil }
      result(nil)
    case "disconnect":
      invitation?(false, nil)
      invitation = nil
      pending = nil
      connected = nil
      // Recreate the session so a cancelled, in-flight invitation cannot connect.
      if let old = session {
        old.disconnect()
        let replacement = MCSession(peer: old.myPeerID, securityIdentity: nil, encryptionPreference: .required)
        replacement.delegate = self
        session = replacement
      }
      result(nil)
    case "send":
      guard connected == id, let peer = peers[id], let session = session,
            let text = args["data"] as? String, let data = text.data(using: .utf8), data.count <= 8192 else { failure(result, "No active connection or message too large"); return }
      do { try session.send(data, toPeers: [peer], with: .reliable); result(nil) }
      catch { failure(result, error.localizedDescription) }
    default: result(FlutterMethodNotImplemented)
    }
  }
  func stop(emitEvent: Bool = true) {
    invitation?(false, nil)
    invitation = nil
    advertiser?.stopAdvertisingPeer()
    browser?.stopBrowsingForPeers()
    let old = session
    session = nil
    old?.disconnect()
    advertiser = nil
    browser = nil
    pending = nil
    connected = nil
    peers.removeAll()
    if emitEvent { emit("stopped") }
  }
  func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
    guard browser === self.browser, peers.count < 100, info?["v"] == "1" else { return }
    emit("found", key(peerID), ["name": peerID.displayName])
  }
  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    guard browser === self.browser, let id = peers.first(where: { $0.value == peerID })?.key else { return }
    emit("lost", id)
    if id != pending && id != connected { peers.removeValue(forKey: id) }
  }
  func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    guard browser === self.browser else { return }
    emit("error", "", ["message": "Discovery failed. Check Local Network permission in Settings. \(error.localizedDescription)"])
    stop()
  }
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
    guard advertiser === self.advertiser else { return }
    emit("error", "", ["message": "Visibility failed. Check Local Network permission in Settings. \(error.localizedDescription)"])
    stop()
  }
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    guard advertiser === self.advertiser, session != nil, pending == nil, connected == nil,
          context == Data("lantern-v1".utf8), peers.count < 100 else { invitationHandler(false, nil); return }
    let id = key(peerID)
    pending = id
    invitation = invitationHandler
    emit("invitation", id, ["name": peerID.displayName, "code": ""])
  }
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, session === self.session else { return }
      let id = self.key(peerID)
      if state == .connected {
        guard self.pending == id, self.connected == nil else { session.cancelConnectPeer(peerID); return }
        self.pending = nil
        self.connected = id
        self.emit("connected", id, ["name": peerID.displayName])
      } else if state == .notConnected {
        if self.pending == id { self.pending = nil; self.invitation = nil }
        if self.connected == id { self.connected = nil }
        self.emit("disconnected", id)
      }
    }
  }
  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    guard data.count <= 8192, let text = String(data: data, encoding: .utf8) else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self = self, session === self.session,
            let id = self.peers.first(where: { $0.value == peerID })?.key, self.connected == id else { return }
      self.emit("data", id, ["data": text])
    }
  }
  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { stream.close() }
  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { progress.cancel() }
  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
