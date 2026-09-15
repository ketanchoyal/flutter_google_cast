//
//  DiscoveryManagerMethodChannel.swift
//  google_cast
//
//  Created by LUIZ FELIPE ALVES LIMA on 30/06/22.
//

import Flutter
import Foundation
import GoogleCast

/// Flutter method channel for Google Cast device discovery operations
/// 
/// This class manages the discovery of Google Cast devices on the local network.
/// It implements the Google Cast discovery manager listener protocol to receive
/// updates about Cast device availability and communicates these updates back
/// to the Flutter side via method channels.
///
/// Key features:
/// - Automatic device discovery management
/// - Real-time device list updates to Flutter
/// - Device indexing for Flutter-side device selection
/// - Singleton pattern for consistent state management
///
/// The class maintains a dictionary of discovered devices indexed by their
/// discovery position, enabling Flutter to reference devices by index when
/// initiating Cast sessions.
///
/// - Author: LUIZ FELIPE ALVES LIMA
/// - Since: iOS 10.0+
class FGCDiscoveryManagerMethodChannel : UIResponder, GCKDiscoveryManagerListener, FlutterPlugin{
    
    // MARK: - Singleton Implementation
    
    /// Private initializer to enforce singleton pattern
    private override init() {
        
    }
    
    /// Shared singleton instance
    static private let _instance = FGCDiscoveryManagerMethodChannel.init()
    
    /// Public accessor for the singleton instance
    /// - Returns: The shared FGCDiscoveryManagerMethodChannel instance
    static var instance : FGCDiscoveryManagerMethodChannel {
        _instance
    }
    
    // MARK: - Properties
    
    /// Returns the discovery manager only after the Cast context has been initialized.
    ///
    /// Accessing `GCKCastContext.sharedInstance()` before initialization throws,
    /// so callers must guard through this helper when handling Flutter method calls.
    private func withDiscoveryManager(result: @escaping FlutterResult, _ body: (GCKDiscoveryManager) -> Void) {
        guard GCKCastContext.isSharedInstanceInitialized() else {
            result(FlutterError(
                code: "cast_context_not_initialized",
                message: "Google Cast context is not initialized. Call setSharedInstanceWithOptions before using discovery APIs.",
                details: nil
            ))
            return
        }

        body(GCKCastContext.sharedInstance().discoveryManager)
    }
    
    /// Dictionary storing discovered Cast devices indexed by their discovery position
    /// The key represents the device index in the discovery list, and the value
    /// is the corresponding GCKDevice object
    var devices : [UInt : GCKDevice] = [:]
    
    /// Flutter method channel for communicating device discovery events
    /// Used to send device list updates back to the Flutter side
    var channel : FlutterMethodChannel?
    
    // MARK: - Flutter Plugin Registration
    
    /// Registers the discovery manager method channel with Flutter
    /// 
    /// Sets up the Flutter method channel for device discovery communication.
    /// The channel name is "google_cast.discovery_manager" and handles
    /// device discovery related method calls from Flutter.
    ///
    /// - Parameter registrar: The Flutter plugin registrar for method channel setup
    static func register(with registrar: FlutterPluginRegistrar) {
        
        instance.channel = FlutterMethodChannel.init(name: "google_cast.discovery_manager", binaryMessenger: registrar.messenger())
        
        registrar.addMethodCallDelegate(instance, channel: instance.channel!)
        
    }
    
    // MARK: - Flutter Method Call Handling
    
    /// Handles method calls from the Flutter side
    /// 
    /// Processes incoming method calls for device discovery operations.
    ///
    /// Supported methods:
    /// - `startDiscovery`: Starts or restarts active device scanning
    /// - `stopDiscovery`: Stops active device scanning
    /// - `isDiscoveryActiveForDeviceCategory`: Checks if discovery is active for a device category
    ///
    private var pollTimer: Timer?

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if GCKCastContext.isSharedInstanceInitialized() {
                let dm = GCKCastContext.sharedInstance().discoveryManager
                if dm.deviceCount != self.devices.count {
                    CastLogger.shared.log("Poll timer mismatch: dm.deviceCount=\(dm.deviceCount), cached=\(self.devices.count). Updating...")
                    self.didUpdateDeviceList()
                }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Handles method calls from the Flutter side
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        withDiscoveryManager(result: result) { discoveryManager in
            switch call.method {
            case "startDiscovery":
                SwiftGoogleCastPlugin.instance?.shouldResumeDiscoveryOnForeground = true
                discoveryManager.passiveScan = false
                CastLogger.shared.log("startDiscovery requested. Current state=\(discoveryManager.discoveryState.rawValue), passive=\(discoveryManager.passiveScan)")
                if discoveryManager.discoveryState != .running {
                    CastLogger.shared.log("startDiscovery: not running -> starting discovery")
                    discoveryManager.startDiscovery()
                } else {
                    CastLogger.shared.log("startDiscovery: already running -> maintaining active scan without reset")
                }
                // Re-send current device list so Flutter gets immediate state
                didUpdateDeviceList()
                startPolling()
                result(true)
            case "stopDiscovery":
                SwiftGoogleCastPlugin.instance?.shouldResumeDiscoveryOnForeground = false
                stopPolling()
                CastLogger.shared.log("stopDiscovery requested")
                if discoveryManager.discoveryState == .running {
                    discoveryManager.stopDiscovery()
                }
                // Clear cached devices and notify Flutter with an empty list
                devices.removeAll()
                didUpdateDeviceList()
                result(true)
            case "getDevices":
                let count = discoveryManager.deviceCount
                devices.removeAll()
                for i in 0..<count {
                    let dev = discoveryManager.device(at: i)
                    devices[UInt(i)] = dev
                }
                let deviceList = devices.sorted {
                    a, b in a.key < b.key
                }.map { device -> [String : Any] in
                    var dict = device.value.toDict()
                    dict["index"] = device.key
                    return dict
                }
                CastLogger.shared.log("getDevices called from Flutter, returning \(deviceList.count) device(s)")
                result(deviceList)
            case "getDiscoveryStatus":
                let count = discoveryManager.deviceCount
                var deviceNames: [String] = []
                for i in 0..<count {
                    let d = discoveryManager.device(at: i)
                    deviceNames.append(d.friendlyName ?? d.deviceID)
                }
                result([
                    "initialized": true,
                    "state": discoveryManager.discoveryState == .running ? "running" : "stopped",
                    "passive": discoveryManager.passiveScan,
                    "count": count,
                    "devices": deviceNames,
                    "recentLogs": CastLogger.shared.getRecentLogs(),
                ])
            case "getRecentLogs":
                result(CastLogger.shared.getRecentLogs())
            case "isDiscoveryActiveForDeviceCategory":
                if let args = call.arguments as? Dictionary<String, Any>,
                   let deviceCategory = args["deviceCategory"] as? String {
                    let isActive = discoveryManager.isDiscoveryActive(forDeviceCategory: deviceCategory)
                    result(isActive)
                } else {
                    result(false)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - Google Cast Discovery Manager Listener
    
    /// Called when discovery starts for a device category
    public func didStartDiscovery(forDeviceCategory deviceCategory: String) {
        CastLogger.shared.log("didStartDiscovery for category: \(deviceCategory)")
    }

    /// Called when there are discovered devices available at the start of discovery
    public func didHaveDiscoveredDeviceWhenStartingDiscovery() {
        CastLogger.shared.log("didHaveDiscoveredDeviceWhenStartingDiscovery")
        didUpdateDeviceList()
    }

    /// Called when a Cast device is updated in the discovery list
    public func didUpdate(_ device: GCKDevice, at index: UInt) {
        CastLogger.shared.log("didUpdate device: \(device.friendlyName ?? device.deviceID) at index: \(index)")
        didUpdateDeviceList()
    }

    /// Called when a Cast device is updated and moved to a new index
    public func didUpdate(_ device: GCKDevice, at index: UInt, andMoveTo newIndex: UInt) {
        CastLogger.shared.log("didUpdate andMoveTo device: \(device.friendlyName ?? device.deviceID) to index: \(newIndex)")
        didUpdateDeviceList()
    }
    
    /// Called when a new Cast device is discovered
    public func didInsert(_ device: GCKDevice, at index: UInt) {
        CastLogger.shared.log("didInsert device: \(device.friendlyName ?? device.deviceID) (\(device.modelName ?? "Cast")) [ip: \(device.networkAddress.ipAddress)] at index: \(index)")
        didUpdateDeviceList()
    }
    
    /// Called when a Cast device is removed from discovery
    public func didRemove(_ device: GCKDevice, at index: UInt) {
        CastLogger.shared.log("didRemove device at index: \(index)")
        didUpdateDeviceList()
    }

    /// Called when a Cast device index is removed from discovery
    public func didRemoveDevice(at index: UInt) {
        CastLogger.shared.log("didRemoveDevice at index: \(index)")
        didUpdateDeviceList()
    }
    
    /// Called when the device list changes
    public func didUpdateDeviceList() {
        if GCKCastContext.isSharedInstanceInitialized() {
            let dm = GCKCastContext.sharedInstance().discoveryManager
            let count = dm.deviceCount
            devices.removeAll()
            for i in 0..<count {
                let dev = dm.device(at: i)
                devices[UInt(i)] = dev
            }
            CastLogger.shared.log("didUpdateDeviceList: dm has \(count) devices")
        }
        
        let deviceList = devices.sorted {
            a, b in a.key < b.key
        }.map { device -> [String : Any] in
            var dict = device.value.toDict()
            dict["index"] = device.key
            return dict
        }
        
        CastLogger.shared.log("notifying Flutter channel on main thread with \(deviceList.count) device(s)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let ch = self.channel else {
                CastLogger.shared.log("ERROR: channel is nil when notifying onDevicesChanged")
                return
            }
            ch.invokeMethod("onDevicesChanged", arguments: deviceList)
        }
    }
    
}
