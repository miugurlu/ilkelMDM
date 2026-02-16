//
//  DeviceViewModel.swift
//  ilkelMDM
//
//  MVVM ViewModel: fetches and holds all device inventory data and live monitoring.
//

import Combine
import CoreLocation
import CoreTelephony
import Foundation
import Network
import UIKit
import LocalAuthentication
import SwiftUI

// MARK: - Device ViewModel

@MainActor
final class DeviceViewModel: NSObject, ObservableObject {

    // MARK: - Published (dynamic / live data)

    @Published private(set) var batteryLevel: Float = 0
    @Published private(set) var batteryState: UIDevice.BatteryState = .unknown
    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published private(set) var connectionType: String = "—"
    @Published private(set) var orientation: UIDeviceOrientation = .unknown
    @Published var isUnlocked = false
    @Published private(set) var latitude: Double?
    @Published private(set) var longitude: Double?
    @Published private(set) var altitude: Double?
    @Published private(set) var locationTimestamp: Date?

    // MARK: - Identity & Hardware (UIDevice + machine id)

    let deviceName: String
    let systemName: String
    let systemVersion: String
    let model: String
    let localizedModel: String
    let userInterfaceIdiom: UIUserInterfaceIdiom
    let identifierForVendor: String
    let machineIdentifier: String
    let isMultiTaskingSupported: Bool

    // MARK: - Resources (ProcessInfo & FileManager)

    let physicalMemoryGB: String
    let processorCountActive: Int
    let processorCountTotal: Int
    let systemUptimeFormatted: String
    let totalDiskSpaceGB: String
    let freeDiskSpaceGB: String

    // MARK: - Dependencies (injectable for tests)

    private let device: UIDevice
    private let processInfo: ProcessInfo
    private let fileManager: FileManager
    private var pathMonitor: NWPathMonitor?
    private var monitorQueue: DispatchQueue?
    private let mqttService = MQTTService()
    private let locationManager = CLLocationManager()
    private var hasPublishedWithLocation = false

    init(
        device: UIDevice = .current,
        processInfo: ProcessInfo = .processInfo,
        fileManager: FileManager = .default
    ) {
        self.device = device
        self.processInfo = processInfo
        self.fileManager = fileManager

        // Identity & Hardware (name: iOS 16+ gives generic name; real name needs entitlement)
        self.deviceName = device.name
        self.systemName = device.systemName
        self.systemVersion = device.systemVersion
        self.model = device.model
        self.localizedModel = device.localizedModel
        self.userInterfaceIdiom = device.userInterfaceIdiom
        self.identifierForVendor = device.identifierForVendor?.uuidString ?? "—"
        self.machineIdentifier = getMachineIdentifier()
        self.isMultiTaskingSupported = device.isMultitaskingSupported

        // Resources
        let physicalMemoryBytes = Int64(processInfo.physicalMemory)
        self.physicalMemoryGB = formatBytes(physicalMemoryBytes)
        self.processorCountActive = processInfo.activeProcessorCount
        self.processorCountTotal = processInfo.processorCount
        self.systemUptimeFormatted = Self.formatUptime(processInfo.systemUptime)
        let (total, free) = Self.diskSpace(fileManager: fileManager)
        self.totalDiskSpaceGB = total
        self.freeDiskSpaceGB = free

        // Live values will be set in startMonitoring()
        self.batteryLevel = device.batteryLevel
        self.batteryState = device.batteryState
        self.thermalState = processInfo.thermalState
        self.orientation = device.orientation

        super.init()
    }

    /// Enables battery monitoring and subscribes to battery, thermal, and network updates.
    /// Call once when the dashboard appears (e.g. in .onAppear).
    func startMonitoring() {
        device.isBatteryMonitoringEnabled = true
        updateBatteryFromDevice()
        updateThermalFromProcessInfo()

        // Battery level
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryFromDevice()
            }
        }

        // Battery state
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryFromDevice()
            }
        }

        // Thermal state
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateThermalFromProcessInfo()
            }
        }

        startNetworkMonitoring()
        startLocationUpdates()

        // Carrier info loads asynchronously; retry after delay (SIM detection can be delayed)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            publishToMQTT()
        }

        publishToMQTT()

        // Orientation (must begin generating to receive updates)
        device.beginGeneratingDeviceOrientationNotifications()
        orientation = device.orientation
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.orientation = self?.device.orientation ?? .unknown
            }
        }
    }

    /// Stops network monitoring and orientation updates. Call on disappear if desired.
    func stopMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
        monitorQueue = nil
        device.endGeneratingDeviceOrientationNotifications()
        locationManager.stopUpdatingLocation()
        mqttService.disconnect()
    }

    // MARK: - Location

    private func startLocationUpdates() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - MQTT

    private func publishToMQTT() {
        let loc: DeviceInventoryPayload.Location? = {
            guard let lat = latitude, let lon = longitude else { return nil }
            let formatter = ISO8601DateFormatter()
            return .init(
                latitude: lat,
                longitude: lon,
                altitude: altitude,
                timestamp: formatter.string(from: locationTimestamp ?? Date())
            )
        }()

        let payload = DeviceInventoryPayload(
            identity: .init(
                deviceName: deviceName,
                systemName: systemName,
                systemVersion: systemVersion,
                model: model,
                localizedModel: localizedModel,
                userInterfaceIdiom: userInterfaceIdiomText,
                identifierForVendor: identifierForVendor,
                machineIdentifier: machineIdentifier,
                isMultiTaskingSupported: isMultiTaskingSupported
            ),
            resources: .init(
                physicalMemoryGB: physicalMemoryGB,
                processorCountActive: processorCountActive,
                processorCountTotal: processorCountTotal,
                systemUptime: systemUptimeFormatted,
                totalDiskSpaceGB: totalDiskSpaceGB,
                freeDiskSpaceGB: freeDiskSpaceGB
            ),
            power: .init(
                batteryLevel: batteryLevelText,
                batteryState: batteryStateText,
                thermalState: thermalStateText,
                orientation: orientationText
            ),
            network: .init(
                connectionType: connectionType
            ),
            location: loc
        )
        mqttService.publish(payload)
    }

    // MARK: - Battery & thermal (main queue)

    private func updateBatteryFromDevice() {
        batteryLevel = device.batteryLevel
        batteryState = device.batteryState
    }

    private func updateThermalFromProcessInfo() {
        thermalState = processInfo.thermalState
    }

    // MARK: - Network (NWPathMonitor)

    private func startNetworkMonitoring() {
        let queue = DispatchQueue(label: "com.ilkelMDM.network")
        monitorQueue = queue
        let monitor = NWPathMonitor()
        pathMonitor = monitor

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.connectionType = Self.connectionType(from: path)
            }
        }
        monitor.start(queue: queue)

        // Initial value
        connectionType = Self.connectionType(from: monitor.currentPath)
    }

    private static func connectionType(from path: NWPath) -> String {
        guard path.status == .satisfied else { return "No Connection" }
        if path.usesInterfaceType(.wifi) { return "WiFi" }
        if path.usesInterfaceType(.cellular) { return "Cellular" }
        if path.usesInterfaceType(.wiredEthernet) { return "Ethernet" }
        return "Connected"
    }

    // MARK: - Helpers

    private static func formatUptime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return String(format: "%d h %d min", hours, minutes)
    }

    private static func diskSpace(fileManager: FileManager) -> (total: String, free: String) {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? homeURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
              let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacityForImportantUsage else {
            // Fallback: attributesOfFileSystem (may report different values on some configurations)
            guard let attrs = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory() as String),
                  let total = attrs[.systemSize] as? Int64,
                  let free = attrs[.systemFreeSize] as? Int64 else {
                return ("—", "—")
            }
            return (formatBytes(Int64(total)), formatBytes(free))
        }
        return (formatBytes(Int64(total)), formatBytes(free))
    }

    // MARK: - Display helpers for UI

    /// Battery level string; handles -1.0 (unknown) gracefully.
    var batteryLevelText: String {
        if batteryLevel < 0 { return "Unknown" }
        return String(format: "%.0f%%", batteryLevel * 100)
    }

    /// Human-readable battery state.
    var batteryStateText: String {
        switch batteryState {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }

    /// Human-readable thermal state.
    var thermalStateText: String {
        switch thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    /// True when thermal state is serious or critical (for warning badge).
    var isThermalWarning: Bool {
        switch thermalState {
        case .serious, .critical: return true
        default: return false
        }
    }

    /// Human-readable interface idiom.
    var userInterfaceIdiomText: String {
        switch userInterfaceIdiom {
        case .unspecified: return "Unspecified"
        case .phone: return "Phone"
        case .pad: return "Pad"
        case .tv: return "TV"
        case .carPlay: return "CarPlay"
        case .mac: return "Mac"
        case .vision: return "Vision"
        @unknown default: return "Unknown"
        }
    }

    /// Human-readable orientation.
    var orientationText: String {
        switch orientation {
        case .unknown: return "Unknown"
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .faceUp: return "Face Up"
        case .faceDown: return "Face Down"
        @unknown default: return "Unknown"
        }
    }
    
    /// Human-readable location (for UI display).
    var locationText: String {
        guard let lat = latitude, let lon = longitude else { return "—" }
        return String(format: "%.6f, %.6f", lat, lon)
    }

    func authenticate() {
        let context = LAContext()
        var error: NSError?

        let reason = "Device Inventory'e erişmek için kimliğinizi doğrulayın"

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, _ in
                Task { @MainActor in
                    self?.isUnlocked = success
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            // Biyometri yok; cihaz şifresi ile dene
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, _ in
                Task { @MainActor in
                    self?.isUnlocked = success
                }
            }
        } else {
            // Simülatör veya kimlik doğrulama yok; erişime izin ver
            isUnlocked = true
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension DeviceViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            altitude = location.altitude
            locationTimestamp = location.timestamp
            if !hasPublishedWithLocation {
                hasPublishedWithLocation = true
                publishToMQTT()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // İzin reddedildi veya konum alınamadı; latitude/longitude nil kalır
    }
}
