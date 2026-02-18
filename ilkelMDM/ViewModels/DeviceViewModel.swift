//
//  DeviceViewModel.swift
//  ilkelMDM
//
//  MVVM ViewModel: fetches and holds all device inventory data and live monitoring.
//

import Combine
import CoreLocation
import Foundation
import Network
import UIKit
import SwiftUI

@MainActor
final class DeviceViewModel: ObservableObject {

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

    // MARK: - Dependencies

    private let device: UIDevice
    private let processInfo: ProcessInfo
    private let fileManager: FileManager
    private var pathMonitor: NWPathMonitor?
    private var monitorQueue: DispatchQueue?
    private let tcpService = TCPService()
    private let authService = AuthService()
    private let locationService = LocationService()
    private var hasSentToServer = false
    private let locationWaitTimeoutSeconds: UInt64 = 10

    init(
        device: UIDevice = .current,
        processInfo: ProcessInfo = .processInfo,
        fileManager: FileManager = .default
    ) {
        self.device = device
        self.processInfo = processInfo
        self.fileManager = fileManager

        self.deviceName = device.name
        self.systemName = device.systemName
        self.systemVersion = device.systemVersion
        self.model = device.model
        self.localizedModel = device.localizedModel
        self.userInterfaceIdiom = device.userInterfaceIdiom
        self.identifierForVendor = device.identifierForVendor?.uuidString ?? "—"
        self.machineIdentifier = getMachineIdentifier()
        self.isMultiTaskingSupported = device.isMultitaskingSupported

        let physicalMemoryBytes = Int64(processInfo.physicalMemory)
        self.physicalMemoryGB = formatBytes(physicalMemoryBytes)
        self.processorCountActive = processInfo.activeProcessorCount
        self.processorCountTotal = processInfo.processorCount
        self.systemUptimeFormatted = formatUptime(processInfo.systemUptime)
        let (total, free) = diskSpace(fileManager: fileManager)
        self.totalDiskSpaceGB = total
        self.freeDiskSpaceGB = free

        self.batteryLevel = device.batteryLevel
        self.batteryState = device.batteryState
        self.thermalState = processInfo.thermalState
        self.orientation = device.orientation
    }

    func startMonitoring() {
        device.isBatteryMonitoringEnabled = true
        updateBatteryFromDevice()
        updateThermalFromProcessInfo()

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryFromDevice()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryFromDevice()
            }
        }

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
        scheduleSendWithLocationTimeout()

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

    func stopMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
        monitorQueue = nil
        device.endGeneratingDeviceOrientationNotifications()
        locationService.stop()
        tcpService.disconnect()
    }

    func authenticate() {
        authService.authenticate { [weak self] success in
            self?.isUnlocked = success
        }
    }

    // MARK: - Location

    private func startLocationUpdates() {
        locationService.onLocationUpdate = { [weak self] location in
            guard let self = self else { return }
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            altitude = location.altitude
            locationTimestamp = location.timestamp
            if !hasSentToServer {
                hasSentToServer = true
                sendToServer()
            }
        }
        locationService.start()
    }

    /// Konum gelene kadar bekler; gelmezse timeout (10 sn) sonunda konum olmadan gönderir.
    private func scheduleSendWithLocationTimeout() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: locationWaitTimeoutSeconds * 1_000_000_000)
            if !hasSentToServer {
                hasSentToServer = true
                sendToServer()
            }
        }
    }

    // MARK: - TCP Send

    private func sendToServer() {
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
            deviceId: identifierForVendor,
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
            network: .init(connectionType: connectionType),
            location: loc
        )
        tcpService.send(payload)
    }

    // MARK: - Battery & thermal

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
        connectionType = Self.connectionType(from: monitor.currentPath)
    }

    // MARK: - Network Connection

    private static func connectionType(from path: NWPath) -> String {
        guard path.status == .satisfied else { return "No Connection" }
        if path.usesInterfaceType(.wifi) { return "WiFi" }
        if path.usesInterfaceType(.cellular) { return "Cellular" }
        if path.usesInterfaceType(.wiredEthernet) { return "Ethernet" }
        return "Connected"
    }

    // MARK: - Display helpers

    var batteryLevelText: String {
        if batteryLevel < 0 { return "Unknown" }
        return String(format: "%.0f%%", batteryLevel * 100)
    }

    var batteryStateText: String {
        switch batteryState {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }

    var thermalStateText: String {
        switch thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    var isThermalWarning: Bool {
        switch thermalState {
        case .serious, .critical: return true
        default: return false
        }
    }

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

    var locationText: String {
        guard let lat = latitude, let lon = longitude else { return "—" }
        return String(format: "%.6f, %.6f", lat, lon)
    }
}
