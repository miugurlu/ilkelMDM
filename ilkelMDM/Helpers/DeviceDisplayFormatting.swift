//
//  DeviceDisplayFormatting.swift
//  ilkelMDM
//
//  Cihaz verilerini ekranda gösterilecek metne çevirir (payload + UI için ortak).
//

import Foundation
import UIKit

enum DeviceDisplayFormatting {

    static func batteryLevel(_ level: Float) -> String {
        if level < 0 { return "Unknown" }
        return String(format: "%.0f%%", level * 100)
    }

    static func batteryState(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }

    static func thermalState(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    static func userInterfaceIdiom(_ idiom: UIUserInterfaceIdiom) -> String {
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

    static func orientation(_ orientation: UIDeviceOrientation) -> String {
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

    static func location(latitude: Double?, longitude: Double?) -> String {
        guard let lat = latitude, let lon = longitude else { return "—" }
        return String(format: "%.6f, %.6f", lat, lon)
    }
}
