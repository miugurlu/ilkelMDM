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
    static func buildForForeground(
        deviceMonitor: DeviceMonitorService,
        latitude: Double?,
        longitude: Double?,
        altitude: Double?,
        locationTimestamp: Date?
    ) -> DeviceInventoryPayload {
        let loc: DeviceInventoryPayload.Location? = makeLocation(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            locationTimestamp: locationTimestamp
        )

        return DeviceInventoryPayload(
            type: "device_inventory",
            identity: makeIdentity(
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
            resources: makeResources(
                physicalMemoryGB: deviceMonitor.physicalMemoryGB,
                processorCountActive: deviceMonitor.processorCountActive,
                processorCountTotal: deviceMonitor.processorCountTotal,
                systemUptime: deviceMonitor.systemUptimeFormatted,
                totalDiskSpaceGB: deviceMonitor.totalDiskSpaceGB,
                freeDiskSpaceGB: deviceMonitor.freeDiskSpaceGB
            ),
            power: makePower(
                batteryLevel: DeviceDisplayFormatting.batteryLevel(deviceMonitor.batteryLevel),
                batteryState: DeviceDisplayFormatting.batteryState(deviceMonitor.batteryState),
                thermalState: DeviceDisplayFormatting.thermalState(deviceMonitor.thermalState),
                orientation: DeviceDisplayFormatting.orientation(deviceMonitor.orientation)
            ),
            network: makeNetwork(connectionType: deviceMonitor.connectionType),
            location: loc
        )
    }

    /// Arka plan görevinde (BGTaskScheduler) ViewModel/servis olmadan payload üretir.
    static func buildForBackground() -> DeviceInventoryPayload {
        let device = UIDevice.current
        let processInfo = ProcessInfo.processInfo
        let fileManager = FileManager.default

        device.isBatteryMonitoringEnabled = true

        let (totalDisk, freeDisk) = DeviceHelpers.diskSpace(fileManager: fileManager)
        let connectionTypeStr = currentConnectionType()

        return DeviceInventoryPayload(
            type: "device_inventory",
            identity: makeIdentity(
                deviceName: device.name,
                systemName: device.systemName,
                systemVersion: device.systemVersion,
                model: device.model,
                localizedModel: device.localizedModel,
                userInterfaceIdiom: DeviceDisplayFormatting.userInterfaceIdiom(device.userInterfaceIdiom),
                identifierForVendor: device.identifierForVendor?.uuidString ?? "—",
                machineIdentifier: DeviceHelpers.getMachineIdentifier(),
                isMultiTaskingSupported: device.isMultitaskingSupported
            ),
            resources: makeResources(
                physicalMemoryGB: DeviceHelpers.formatBytes(Int64(processInfo.physicalMemory)),
                processorCountActive: processInfo.activeProcessorCount,
                processorCountTotal: processInfo.processorCount,
                systemUptime: DeviceHelpers.formatUptime(processInfo.systemUptime),
                totalDiskSpaceGB: totalDisk,
                freeDiskSpaceGB: freeDisk
            ),
            power: makePower(
                batteryLevel: DeviceDisplayFormatting.batteryLevel(device.batteryLevel),
                batteryState: DeviceDisplayFormatting.batteryState(device.batteryState),
                thermalState: DeviceDisplayFormatting.thermalState(processInfo.thermalState),
                orientation: DeviceDisplayFormatting.orientation(device.orientation)
            ),
            network: makeNetwork(connectionType: connectionTypeStr),
            location: nil
        )
    }

    private static func currentConnectionType() -> String {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.ilkelMDM.background.path")
        monitor.start(queue: queue)
        defer { monitor.cancel() }
        return DeviceHelpers.connectionTypeString(from: monitor.currentPath)
    }

    // MARK: - Payload parçaları (build + buildForBackground tek kaynak)

    private static func makeIdentity(
        deviceName: String,
        systemName: String,
        systemVersion: String,
        model: String,
        localizedModel: String,
        userInterfaceIdiom: String,
        identifierForVendor: String,
        machineIdentifier: String,
        isMultiTaskingSupported: Bool
    ) -> DeviceInventoryPayload.Identity {
        .init(
            deviceName: deviceName,
            systemName: systemName,
            systemVersion: systemVersion,
            model: model,
            localizedModel: localizedModel,
            userInterfaceIdiom: userInterfaceIdiom,
            identifierForVendor: identifierForVendor,
            machineIdentifier: machineIdentifier,
            isMultiTaskingSupported: isMultiTaskingSupported
        )
    }

    private static func makeResources(
        physicalMemoryGB: String,
        processorCountActive: Int,
        processorCountTotal: Int,
        systemUptime: String,
        totalDiskSpaceGB: String,
        freeDiskSpaceGB: String
    ) -> DeviceInventoryPayload.Resources {
        .init(
            physicalMemoryGB: physicalMemoryGB,
            processorCountActive: processorCountActive,
            processorCountTotal: processorCountTotal,
            systemUptime: systemUptime,
            totalDiskSpaceGB: totalDiskSpaceGB,
            freeDiskSpaceGB: freeDiskSpaceGB
        )
    }

    private static func makePower(
        batteryLevel: String,
        batteryState: String,
        thermalState: String,
        orientation: String
    ) -> DeviceInventoryPayload.Power {
        .init(
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            thermalState: thermalState,
            orientation: orientation
        )
    }

    private static func makeNetwork(connectionType: String) -> DeviceInventoryPayload.Network {
        .init(connectionType: connectionType)
    }

    private static func makeLocation(
        latitude: Double?,
        longitude: Double?,
        altitude: Double?,
        locationTimestamp: Date?
    ) -> DeviceInventoryPayload.Location? {
        guard let lat = latitude, let lon = longitude else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return .init(
            latitude: lat,
            longitude: lon,
            altitude: altitude,
            timestamp: formatter.string(from: locationTimestamp ?? Date())
        )
    }
}
