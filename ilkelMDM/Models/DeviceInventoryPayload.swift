//
//  DeviceInventoryPayload.swift
//  ilkelMDM
//
//  Device inventory model - Java DeviceLog entity ile uyumlu JSON.
//

import Foundation

/// Java DeviceLog entity ile uyumlu TCP gönderim modeli.
struct DeviceInventoryPayload: Codable {
    let identity: Identity
    let resources: Resources
    let power: Power
    let network: Network
    let location: Location?

    struct Identity: Codable {
        let deviceName: String
        let systemName: String
        let systemVersion: String
        let model: String
        let localizedModel: String
        let userInterfaceIdiom: String
        let identifierForVendor: String
        let machineIdentifier: String
        let isMultiTaskingSupported: Bool
    }

    struct Resources: Codable {
        let physicalMemoryGB: String
        let processorCountActive: Int
        let processorCountTotal: Int
        let systemUptime: String
        let totalDiskSpaceGB: String
        let freeDiskSpaceGB: String
    }

    struct Power: Codable {
        let batteryLevel: String
        let batteryState: String
        let thermalState: String
        let orientation: String
    }

    struct Network: Codable {
        let connectionType: String
    }

    struct Location: Codable {
        let latitude: Double
        let longitude: Double
        let altitude: Double?
        let timestamp: String
    }
}
