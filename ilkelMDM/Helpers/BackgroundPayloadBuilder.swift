//
//  BackgroundPayloadBuilder.swift
//  ilkelMDM
//
//  Arka plan görevinde (BGTaskScheduler) ViewModel olmadan DeviceInventoryPayload üretir.
//

import Foundation
import Network
import UIKit

enum BackgroundPayloadBuilder {

    static func build() -> DeviceInventoryPayload {
        let device = UIDevice.current
        let processInfo = ProcessInfo.processInfo
        let fileManager = FileManager.default

        device.isBatteryMonitoringEnabled = true

        let (totalDisk, freeDisk) = diskSpace(fileManager: fileManager)
        let connectionType = currentConnectionType()

        return DeviceInventoryPayload(
            identity: .init(
                deviceName: device.name,
                systemName: device.systemName,
                systemVersion: device.systemVersion,
                model: device.model,
                localizedModel: device.localizedModel,
                userInterfaceIdiom: userInterfaceIdiomString(device.userInterfaceIdiom),
                identifierForVendor: device.identifierForVendor?.uuidString ?? "—",
                machineIdentifier: getMachineIdentifier(),
                isMultiTaskingSupported: device.isMultitaskingSupported
            ),
            resources: .init(
                physicalMemoryGB: formatBytes(Int64(processInfo.physicalMemory)),
                processorCountActive: processInfo.activeProcessorCount,
                processorCountTotal: processInfo.processorCount,
                systemUptime: formatUptime(processInfo.systemUptime),
                totalDiskSpaceGB: totalDisk,
                freeDiskSpaceGB: freeDisk
            ),
            power: .init(
                batteryLevel: batteryLevelString(device.batteryLevel),
                batteryState: batteryStateString(device.batteryState),
                thermalState: thermalStateString(processInfo.thermalState),
                orientation: orientationString(device.orientation)
            ),
            network: .init(connectionType: connectionType),
            location: nil
        )
    }

    private static func batteryLevelString(_ level: Float) -> String {
        return String(format: "%.0f%%", level * 100)
    }

    private static func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }

    private static func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private static func orientationString(_ orientation: UIDeviceOrientation) -> String {
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

    private static func userInterfaceIdiomString(_ idiom: UIUserInterfaceIdiom) -> String {
        switch idiom {
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

    private static func currentConnectionType() -> String {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.ilkelMDM.background.path")
        monitor.start(queue: queue)
        defer { monitor.cancel() }
        let path = monitor.currentPath
        guard path.status == .satisfied else { return "No Connection" }
        if path.usesInterfaceType(.wifi) { return "WiFi" }
        if path.usesInterfaceType(.cellular) { return "Cellular" }
        if path.usesInterfaceType(.wiredEthernet) { return "Ethernet" }
        return "Connected"
    }
}
