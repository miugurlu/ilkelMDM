//
//  DeviceInventoryPayloadBuilder.swift
//  ilkelMDM
//
//
//

import Foundation
import Network
import UIKit

enum DeviceInventoryPayloadBuilder {

    /// Foreground: DeviceMonitorService + konum ile payload üretir (ViewModel kullanır).
    static func build(
        deviceMonitor: DeviceMonitorService,
        latitude: Double?,
        longitude: Double?,
        altitude: Double?,
        locationTimestamp: Date?
    ) -> DeviceInventoryPayload {
        let loc: DeviceInventoryPayload.Location? = {
            guard let lat = latitude, let lon = longitude else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return .init(
                latitude: lat,
                longitude: lon,
                altitude: altitude,
                timestamp: formatter.string(from: locationTimestamp ?? Date())
            )
        }()

        return DeviceInventoryPayload(
            type: "device_inventory",
            identity: .init(
                deviceName: deviceMonitor.deviceName,
                systemName: deviceMonitor.systemName,
                systemVersion: deviceMonitor.systemVersion,
                model: deviceMonitor.model,
                localizedModel: deviceMonitor.localizedModel,
                userInterfaceIdiom: DeviceDisplayFormatting.userInterfaceIdiom(deviceMonitor.userInterfaceIdiom),
                identifierForVendor: deviceMonitor.identifierForVendor,
                machineIdentifier: deviceMonitor.machineIdentifier,
                isMultiTaskingSupported: deviceMonitor.isMultiTaskingSupported
            ),
            resources: .init(
                physicalMemoryGB: deviceMonitor.physicalMemoryGB,
                processorCountActive: deviceMonitor.processorCountActive,
                processorCountTotal: deviceMonitor.processorCountTotal,
                systemUptime: deviceMonitor.systemUptimeFormatted,
                totalDiskSpaceGB: deviceMonitor.totalDiskSpaceGB,
                freeDiskSpaceGB: deviceMonitor.freeDiskSpaceGB
            ),
            power: .init(
                batteryLevel: DeviceDisplayFormatting.batteryLevel(deviceMonitor.batteryLevel),
                batteryState: DeviceDisplayFormatting.batteryState(deviceMonitor.batteryState),
                thermalState: DeviceDisplayFormatting.thermalState(deviceMonitor.thermalState),
                orientation: DeviceDisplayFormatting.orientation(deviceMonitor.orientation)
            ),
            network: .init(connectionType: deviceMonitor.connectionType),
            location: loc
        )
    }

    /// Arka plan görevinde (BGTaskScheduler) ViewModel/servis olmadan payload üretir.
    static func buildForBackground() -> DeviceInventoryPayload {
        let device = UIDevice.current
        let processInfo = ProcessInfo.processInfo
        let fileManager = FileManager.default

        device.isBatteryMonitoringEnabled = true

        let (totalDisk, freeDisk) = diskSpace(fileManager: fileManager)
        let connectionType = currentConnectionType()

        return DeviceInventoryPayload(
            type: "device_inventory",
            identity: .init(
                deviceName: device.name,
                systemName: device.systemName,
                systemVersion: device.systemVersion,
                model: device.model,
                localizedModel: device.localizedModel,
                userInterfaceIdiom: DeviceDisplayFormatting.userInterfaceIdiom(device.userInterfaceIdiom),
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
                batteryLevel: DeviceDisplayFormatting.batteryLevel(device.batteryLevel),
                batteryState: DeviceDisplayFormatting.batteryState(device.batteryState),
                thermalState: DeviceDisplayFormatting.thermalState(processInfo.thermalState),
                orientation: DeviceDisplayFormatting.orientation(device.orientation)
            ),
            network: .init(connectionType: connectionType),
            location: nil
        )
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
