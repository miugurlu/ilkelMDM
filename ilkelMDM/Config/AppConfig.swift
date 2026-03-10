//
//  AppConfig.swift
//  ilkelMDM
//
//  Application configuration constants.
//

import Foundation

enum TCPConfig {
    /// Hedef – Simülatör: localhost, fiziksel cihaz: ngrok tüneli
    #if targetEnvironment(simulator)
    static let host = "localhost"
    static let port: UInt16 = 8080
    #else
    static let host = "2.tcp.eu.ngrok.io" //ngrok tcp 8080
    static let port: UInt16 = 19708
    #endif
}
