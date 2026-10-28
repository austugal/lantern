import Flutter
import UIKit
import MultipeerConnectivity
import AVFoundation
import UserNotifications
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var nearby: LanternNearby?
  private var device: LanternDevice?
  private var compass: LanternCompass?
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      nearby = LanternNearby(messenger: controller.binaryMessenger)
      device = LanternDevice(messenger: controller.binaryMessenger)
      compass = LanternCompass(messenger: controller.binaryMessenger, window: window)
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  override func applicationWillResignActive(_ application: UIApplication) {
    compass?.stop()
    super.applicationWillResignActive(application)
  }
  override func applicationDidEnterBackground(_ application: UIApplication) {
    compass?.stop()
    nearby?.stop()
    device?.background()
    super.applicationDidEnterBackground(application)
  }
  override func applicationWillEnterForeground(_ application: UIApplication) {
    device?.foreground = true
    super.applicationWillEnterForeground(application)
  }
  override func applicationWillTerminate(_ application: UIApplication) {
    compass?.stop()
    device?.background()
    super.applicationWillTerminate(application)
  }
  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if notification.request.identifier == "lantern-message" {
      completionHandler([.alert, .sound])
    } else {
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }
}

/// Local magnetic heading only. This manager never starts location updates or asks for authorization.
final class LanternCompass: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private weak var appWindow: UIWindow?
  private var running = false
  private var startedAt: Date?
  private var heading: Double?
  private var accuracy = "unreliable"
  private var sampleUptime: TimeInterval?

  init(messenger: FlutterBinaryMessenger, window: UIWindow?) {
    appWindow = window
    super.init()
    manager.delegate = self
    // Keep static headings fresh; Dart polls the latest sample at no more than 4 Hz.
    manager.headingFilter = kCLHeadingFilterNone
    FlutterMethodChannel(name: "org.austugal.lantern/compass", binaryMessenger: messenger).setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(FlutterError(code: "unavailable", message: "Compass unavailable", details: nil)); return }
      switch call.method {
      case "start": self.start(result)
      case "stop": self.stop(); result(nil)
      case "read": result(self.read())
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
  private func start(_ result: FlutterResult) {
    guard UIApplication.shared.applicationState == .active else {
      result(FlutterError(code: "state", message: "Keep Lantern open to use the compass", details: nil)); return
    }
    guard CLLocationManager.headingAvailable() else {
      result(FlutterError(code: "unsupported", message: "A magnetic compass sensor is unavailable on this device", details: nil)); return
    }
    if !running {
      running = true
      startedAt = Date()
      updateOrientation()
      manager.startUpdatingHeading()
    }
    result(nil)
  }
  /// Core Location device orientations and interface orientations use opposite landscape names.
  private func updateOrientation() {
    let orientation = appWindow?.windowScene?.interfaceOrientation ?? .portrait
    let next: CLDeviceOrientation
    switch orientation {
    case .portraitUpsideDown: next = .portraitUpsideDown
    case .landscapeLeft: next = .landscapeRight
    case .landscapeRight: next = .landscapeLeft
    default: next = .portrait
    }
    if manager.headingOrientation != next {
      manager.headingOrientation = next
      // Do not present a sample computed for the previous top-of-screen orientation.
      startedAt = Date()
      clearSample()
    }
  }
  private func clearSample() {
    heading = nil
    accuracy = "unreliable"
    sampleUptime = nil
  }
  private func read() -> [String: Any] {
    if UIApplication.shared.applicationState != .active { stop() }
    if running { updateOrientation() }
    let elapsed = sampleUptime.map { ProcessInfo.processInfo.systemUptime - $0 }
    let ageMillis = elapsed.map { Int(max(0, $0 * 1000)) } ?? -1
    let fresh = running && elapsed != nil && elapsed! >= 0 && elapsed! <= 2
    return ["heading": fresh ? (heading.map { $0 as Any } ?? NSNull()) : NSNull(),
            "accuracy": accuracy, "ageMillis": ageMillis]
  }
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    guard running, UIApplication.shared.applicationState == .active,
          let startedAt = startedAt, newHeading.timestamp >= startedAt else { return }
    let age = Date().timeIntervalSince(newHeading.timestamp)
    guard age >= 0, age <= 2, newHeading.magneticHeading.isFinite,
          newHeading.magneticHeading >= 0, newHeading.magneticHeading < 360,
          newHeading.headingAccuracy.isFinite, newHeading.headingAccuracy >= 0 else {
      clearSample(); return
    }
    heading = newHeading.magneticHeading
    accuracy = newHeading.headingAccuracy <= 15 ? "high" : newHeading.headingAccuracy <= 30 ? "medium" : "low"
    sampleUptime = ProcessInfo.processInfo.systemUptime - age
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { clearSample() }
  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { false }
  func stop() {
    running = false
    startedAt = nil
    manager.stopUpdatingHeading()
    manager.dismissHeadingCalibrationDisplay()
    clearSample()
  }
  deinit { manager.stopUpdatingHeading(); manager.delegate = nil }
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
  private var invitationTimeout: DispatchWorkItem?
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
      scheduleInvitationTimeout(id, session: session)
      browser?.invitePeer(peer, to: session, withContext: Data("lantern-v1".utf8), timeout: 30)
      result(nil)
    case "accept":
      guard pending == id, let handler = invitation, let session = session else { failure(result, "This invitation has expired"); return }
      invitation = nil
      handler(true, session)
      result(nil)
    case "reject":
      if pending == id { invitationTimeout?.cancel(); invitationTimeout = nil; invitation?(false, nil); invitation = nil; pending = nil }
      result(nil)
    case "disconnect":
      invitationTimeout?.cancel()
      invitationTimeout = nil
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
  private func scheduleInvitationTimeout(_ id: String, session: MCSession) {
    invitationTimeout?.cancel()
    let task = DispatchWorkItem { [weak self, weak session] in
      guard let self = self, let session = session, session === self.session, self.pending == id else { return }
      self.invitation?(false, nil)
      self.invitation = nil
      self.pending = nil
      let replacement = MCSession(peer: session.myPeerID, securityIdentity: nil, encryptionPreference: .required)
      replacement.delegate = self
      self.session = replacement
      session.disconnect()
      self.invitationTimeout = nil
      self.emit("disconnected", id)
      self.emit("error", id, ["message": "Invitation expired. Ask the other person to try again."])
    }
    invitationTimeout = task
    DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: task)
  }
  func stop(emitEvent: Bool = true) {
    invitationTimeout?.cancel()
    invitationTimeout = nil
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
    DispatchQueue.main.async { [self] in
      guard browser === self.browser, peers.count < 100, info?["v"] == "1" else { return }
      emit("found", key(peerID), ["name": peerID.displayName])
    }
  }
  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    DispatchQueue.main.async { [self] in
      guard browser === self.browser, let id = peers.first(where: { $0.value == peerID })?.key else { return }
      emit("lost", id)
      if id != pending && id != connected { peers.removeValue(forKey: id) }
    }
  }
  func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    DispatchQueue.main.async { [self] in
      guard browser === self.browser else { return }
      emit("error", "", ["message": "Discovery failed. Check Local Network permission in Settings. \(error.localizedDescription)"])
      stop()
    }
  }
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
    DispatchQueue.main.async { [self] in
      guard advertiser === self.advertiser else { return }
      emit("error", "", ["message": "Visibility failed. Check Local Network permission in Settings. \(error.localizedDescription)"])
      stop()
    }
  }
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    DispatchQueue.main.async { [self] in
      guard advertiser === self.advertiser, session != nil, pending == nil, connected == nil,
            context == Data("lantern-v1".utf8), peers.count < 100 else { invitationHandler(false, nil); return }
      let id = key(peerID)
      pending = id
      invitation = invitationHandler
      if let session = session { scheduleInvitationTimeout(id, session: session) }
      emit("invitation", id, ["name": peerID.displayName, "code": ""])
    }
  }
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, session === self.session else { return }
      let id = self.key(peerID)
      if state == .connected {
        guard self.pending == id, self.connected == nil else { session.cancelConnectPeer(peerID); return }
        self.invitationTimeout?.cancel()
        self.invitationTimeout = nil
        self.pending = nil
        self.connected = id
        self.emit("connected", id, ["name": peerID.displayName])
      } else if state == .notConnected {
        if self.pending == id { self.invitationTimeout?.cancel(); self.invitationTimeout = nil; self.pending = nil; self.invitation = nil }
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


/// Device helpers are independent of nearby transport and never request permission at launch.
final class LanternDevice {
  var foreground = true
  private var torchDevice: AVCaptureDevice?
  private var torchEpoch = 0
  private var requestingCamera = false
  private var requestingNotifications = false

  init(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "org.austugal.lantern/device", binaryMessenger: messenger).setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(FlutterError(code: "unavailable", message: "Device channel closed", details: nil)); return }
      self.handle(call, result: result)
    }
  }
  private func failure(_ result: FlutterResult, _ code: String, _ message: String) {
    result(FlutterError(code: code, message: message, details: nil))
  }
  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "setTorch":
      let enabled = args["enabled"] as? Bool ?? false
      if !enabled {
        if let error = turnOff() { failure(result, "unavailable", "Could not switch off torch: \(error.localizedDescription)") }
        else { result(nil) }
        return
      }
      guard foreground else { failure(result, "state", "Keep Lantern open to use the torch"); return }
      guard !requestingCamera else { failure(result, "busy", "Camera permission request already open"); return }
      guard let camera = AVCaptureDevice.default(for: .video), camera.hasTorch else { failure(result, "unavailable", "This device has no torch"); return }
      if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
        requestingCamera = true
        let epoch = torchEpoch
        AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
          DispatchQueue.main.async {
            guard let self = self else { result(FlutterError(code: "cancelled", message: "Torch request cancelled", details: nil)); return }
            self.requestingCamera = false
            guard self.foreground, epoch == self.torchEpoch else { self.failure(result, "cancelled", "Torch request cancelled"); return }
            if allowed { self.enableTorch(camera, result: result) }
            else { self.failure(result, "permission", "Camera permission is required for the torch. Enable it in app settings.") }
          }
        }
      } else if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
        enableTorch(camera, result: result)
      } else { failure(result, "permission", "Camera permission is required for the torch. Enable it in app settings.") }
    case "requestNotifications":
      guard !requestingNotifications else { failure(result, "busy", "Notification permission request already open"); return }
      requestingNotifications = true
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
        DispatchQueue.main.async {
          self?.requestingNotifications = false
          if let error = error { result(FlutterError(code: "notifications", message: error.localizedDescription, details: nil)) }
          else { result(granted) }
        }
      }
    case "notifyMessage":
      let center = UNUserNotificationCenter.current()
      center.getNotificationSettings { settings in
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { DispatchQueue.main.async { result(false) }; return }
        let content = UNMutableNotificationContent()
        content.title = "New Lantern message"
        content.body = "Open Lantern to view it."
        content.sound = .default
        center.add(UNNotificationRequest(identifier: "lantern-message", content: content, trigger: nil)) { error in
          DispatchQueue.main.async {
            if let error = error { result(FlutterError(code: "notifications", message: error.localizedDescription, details: nil)) }
            else { result(true) }
          }
        }
      }
    case "clearNotifications":
      let center = UNUserNotificationCenter.current()
      center.removePendingNotificationRequests(withIdentifiers: ["lantern-message"])
      center.removeDeliveredNotifications(withIdentifiers: ["lantern-message"])
      result(nil)
    case "openAppSettings":
      guard let url = URL(string: UIApplication.openSettingsURLString) else { failure(result, "unavailable", "App settings unavailable"); return }
      UIApplication.shared.open(url) { success in
        if success { result(nil) }
        else { result(FlutterError(code: "unavailable", message: "App settings could not be opened", details: nil)) }
      }
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func enableTorch(_ camera: AVCaptureDevice, result: FlutterResult) {
    guard camera.isTorchAvailable else { failure(result, "unavailable", "Torch is busy or unavailable"); return }
    do {
      try camera.lockForConfiguration()
      defer { camera.unlockForConfiguration() }
      try camera.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
      torchDevice = camera
      result(nil)
    } catch { failure(result, "unavailable", "Torch unavailable: \(error.localizedDescription)") }
  }
  @discardableResult
  private func turnOff() -> Error? {
    torchEpoch += 1
    guard let camera = torchDevice else { return nil }
    do {
      try camera.lockForConfiguration()
      defer { camera.unlockForConfiguration() }
      camera.torchMode = .off
    } catch { return error }
    torchDevice = nil
    return nil
  }
  func background() { foreground = false; turnOff() }
  deinit { turnOff() }
}
