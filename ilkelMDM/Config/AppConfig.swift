//
//  AppConfig.swift
//  ilkelMDM
//
//  Application configuration constants.
//

import Foundation

enum MQTTConfig {
    static let host = "broker.hivemq.com"
    static let port: UInt16 = 1883
    static let topic = "ilkelMDM/device/inventory"
}
