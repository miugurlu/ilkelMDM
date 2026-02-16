//
//  MQTTService.swift
//  ilkelMDM
//
//  MQTT client: publishes device inventory to broker.
//

import CocoaMQTT
import Foundation

final class MQTTService {
    private var client: CocoaMQTT?
    private var pendingPayload: String?

    init() {
        let clientID = "ilkelMDM-\(UUID().uuidString.prefix(8))"
        let mqtt = CocoaMQTT(
            clientID: clientID,
            host: MQTTConfig.host,
            port: MQTTConfig.port
        )
        mqtt.keepAlive = 60
        mqtt.autoReconnect = true
        mqtt.delegateQueue = .main

        mqtt.didConnectAck = { [weak self] mqttClient, ack in
            guard ack == .accept, let self = self else { return }
            if let payload = self.pendingPayload {
                self.pendingPayload = nil
                mqttClient.publish(MQTTConfig.topic, withString: payload, qos: .qos1)
            }
        }

        self.client = mqtt
        _ = mqtt.connect()
    }

    func publish(_ payload: DeviceInventoryPayload) {
        guard let jsonData = try? JSONEncoder().encode(payload),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let mqtt = client else { return }

        if mqtt.connState == .connected {
            mqtt.publish(MQTTConfig.topic, withString: jsonString, qos: .qos1)
        } else {
            pendingPayload = jsonString
        }
    }

    func disconnect() {
        client?.disconnect()
    }
}
