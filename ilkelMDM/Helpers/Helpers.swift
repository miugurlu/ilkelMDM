//
//  Helpers.swift
//  ilkelMDM
//
//  MDM Dashboard helper utilities.
//

import Darwin
import Foundation
import Network

enum DeviceHelpers {

    // MARK: - Connection Type

    /// NWPath'ten bağlantı tipi string'i (WiFi, Cellular, vb.). Payload ve DeviceMonitorService tek kaynak.
    nonisolated static func connectionTypeString(from path: NWPath) -> String {
        guard path.status == .satisfied else { return "No Connection" }
        if path.usesInterfaceType(.wifi) { return "WiFi" }
        if path.usesInterfaceType(.cellular) { return "Cellular" }
        if path.usesInterfaceType(.wiredEthernet) { return "Ethernet" }
        return "Connected"
    }

    // MARK: - Byte Formatting

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.includesUnit = true
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Machine Identifier (Unix / sys/utsname.h)

    /// machine / hardware identifier  `uname` `sys/utsname.h`.
    static func getMachineIdentifier() -> String {
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else {
            return "Unknown"
        }
        return withUnsafeBytes(of: &systemInfo.machine) { buffer -> String in
            let data = Data(buffer)
            guard let lastNonZero = data.lastIndex(where: { $0 != 0 }) else {
                return String(data: data, encoding: .isoLatin1) ?? "Unknown"
            }
            return String(data: data[0...lastNonZero], encoding: .isoLatin1) ?? "Unknown"
        }
    }

    // MARK: - Uptime Formatting

    static func formatUptime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return String(format: "%d h %d min", hours, minutes)
    }

    // MARK: - Disk Space

    static func diskSpace(fileManager: FileManager = .default) -> (total: String, free: String) {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? homeURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
              let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacityForImportantUsage else {
            guard let attrs = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory() as String),
                  let total = attrs[.systemSize] as? Int64,
                  let free = attrs[.systemFreeSize] as? Int64 else {
                return ("—", "—")
            }
            return (formatBytes(Int64(total)), formatBytes(free))
        }
        return (formatBytes(Int64(total)), formatBytes(free))
    }
}
