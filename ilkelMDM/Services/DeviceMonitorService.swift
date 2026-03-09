//
//  DeviceMonitorService.swift
//  ilkelMDM
//
//  Tek servis: cihaz kimliği, kaynaklar (bellek/CPU/disk/uptime), pil/termal, ağ, oryantasyon.
//

import Combine
import Foundation
import Network
import UIKit

@MainActor
final class DeviceMonitorService: ObservableObject {

    // MARK: - Identity & Hardware (read-only)

    let deviceName: String
    let systemName: String
    let systemVersion: String
    let model: String
    let localizedModel: String
    let userInterfaceIdiom: UIUserInterfaceIdiom
    let identifierForVendor: String
    let machineIdentifier: String
    let isMultiTaskingSupported: Bool

    // MARK: - Resources (read-only, uptime canlı güncellenir)

    let physicalMemoryGB: String
    let processorCountActive: Int
    let processorCountTotal: Int
    let totalDiskSpaceGB: String
    let freeDiskSpaceGB: String
    @Published private(set) var systemUptimeFormatted: String = ""

    // MARK: - Battery & Thermal (canlı)

    @Published private(set) var batteryLevel: Float = 0
    @Published private(set) var batteryState: UIDevice.BatteryState = .unknown
    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal

    // MARK: - Network (canlı)

    @Published private(set) var connectionType: String = "—"

    // MARK: - Orientation (canlı)

    @Published private(set) var orientation: UIDeviceOrientation = .unknown

    // MARK: - Dependencies

    private let device: UIDevice
    private let processInfo: ProcessInfo
    private let fileManager: FileManager
    private var pathMonitor: NWPathMonitor?
    private var monitorQueue: DispatchQueue?
    private var uptimeTimer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Init

    init(
        device: UIDevice = .current,
        processInfo: ProcessInfo = .processInfo,
        fileManager: FileManager = .default
    ) {
        self.device = device
        self.processInfo = processInfo
        self.fileManager = fileManager

        // Identity
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
        self.systemUptimeFormatted = formatUptime(processInfo.systemUptime)
        let (total, free) = diskSpace(fileManager: fileManager)
        self.totalDiskSpaceGB = total
        self.freeDiskSpaceGB = free

        // İlk değerler
        self.batteryLevel = device.batteryLevel
        self.batteryState = device.batteryState
        self.thermalState = processInfo.thermalState
        self.orientation = device.orientation
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        device.isBatteryMonitoringEnabled = true
        device.beginGeneratingDeviceOrientationNotifications()
        addDeviceObservers()
        setupNetworkMonitoring()
        setupUptimeTimer()
    }

    func stopMonitoring() {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
        uptimeTimer?.invalidate()
        uptimeTimer = nil
        pathMonitor?.cancel()
        pathMonitor = nil
        monitorQueue = nil
        device.endGeneratingDeviceOrientationNotifications()
    }
    
    // MARK: - Observers
    
    private func addDeviceObservers() {
        batteryLevel = device.batteryLevel
        observe(UIDevice.batteryLevelDidChangeNotification) { [weak self] in
            self?.batteryLevel = self?.device.batteryLevel ?? 0
        }

        batteryState = device.batteryState
        observe(UIDevice.batteryStateDidChangeNotification) { [weak self] in
            self?.batteryState = self?.device.batteryState ?? .unknown
        }

        thermalState = processInfo.thermalState
        observe(ProcessInfo.thermalStateDidChangeNotification) { [weak self] in
            self?.thermalState = self?.processInfo.thermalState ?? .nominal
        }

        orientation = device.orientation
        observe(UIDevice.orientationDidChangeNotification) { [weak self] in
            self?.orientation = self?.device.orientation ?? .unknown
        }
    }
    
    /// NotificationCenter observer ekler; handler main queue'da çalışır, token cleanup için saklanır.
    private func observe(_ name: Notification.Name, onMain: @escaping () -> Void) {
        let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
            onMain()
        }
        notificationObservers.append(token)
    }


    // MARK: - Network

    private func setupNetworkMonitoring() {
        let queue = DispatchQueue(label: "ilkelMDM.network")
        monitorQueue = queue
        let monitor = NWPathMonitor()
        pathMonitor = monitor

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let type = Self.connectionType(from: path)
            Task { @MainActor in
                self.connectionType = type
            }
        }
        monitor.start(queue: queue)
        connectionType = Self.connectionType(from: monitor.currentPath)
    }

    private nonisolated static func connectionType(from path: NWPath) -> String {
        guard path.status == .satisfied else { return "No Connection" }
        if path.usesInterfaceType(.wifi) { return "WiFi" }
        if path.usesInterfaceType(.cellular) { return "Cellular" }
        if path.usesInterfaceType(.wiredEthernet) { return "Ethernet" }
        return "Connected"
    }

    // MARK: - Uptime

    private func setupUptimeTimer() {
        uptimeTimer?.invalidate()
        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            let formatted = formatUptime(self.processInfo.systemUptime)
            Task { @MainActor in
                self.systemUptimeFormatted = formatted
            }
        }
        if let timer = uptimeTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
}
