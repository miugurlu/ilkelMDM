//
//  MQTTService.swift
//  ilkelMDM
//
//  MQTT client: publishes device inventory to broker.hivemq.com:1883
//

import CocoaMQTT
import Foundation

// MARK: - Device Inventory Payload (JSON)

struct DeviceInventoryPayload: Codable {
    let identity: Identity
    let resources: Resources
    let power: Power
    let network: Network

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
        let carrierName: String
        let isoCountryCode: String
    }
}

// MARK: - MQTT Service

final class MQTTService {
    private let host = "broker.hivemq.com"
    private let port: UInt16 = 1883
    private let topic = "ilkelMDM/device/inventory"

    private var client: CocoaMQTT?
    private var pendingPayload: String?

    init() {
        let clientID = "ilkelMDM-\(UUID().uuidString.prefix(8))"
        let mqtt = CocoaMQTT(clientID: clientID, host: host, port: port)
        mqtt.keepAlive = 60
        mqtt.autoReconnect = true
        mqtt.delegateQueue = .main

        mqtt.didConnectAck = { [weak self] mqttClient, ack in
            guard ack == .accept, let self = self else { return }
            if let payload = self.pendingPayload {
                self.pendingPayload = nil
                mqttClient.publish(self.topic, withString: payload, qos: .qos1)
            }
        }

        self.client = mqtt
        _ = mqtt.connect()
    }

    /// Publishes device inventory JSON. Queues if not yet connected.
    func publish(_ payload: DeviceInventoryPayload) {
        guard let jsonData = try? JSONEncoder().encode(payload),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let mqtt = client else { return }

        if mqtt.connState == .connected {
            mqtt.publish(topic, withString: jsonString, qos: .qos1)
        } else {
            pendingPayload = jsonString
        }
    }

    func disconnect() {
        client?.disconnect()
    }
}
