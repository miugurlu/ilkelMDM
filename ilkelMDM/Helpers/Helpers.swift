//
//  Helpers.swift
//  ilkelMDM
//
//  MDM Dashboard helper utilities.
//

import Foundation
import Darwin

// MARK: - Byte Formatting

/// Converts raw byte count to a human-readable string in GB (or MB when appropriate).
func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.allowedUnits = [.useGB, .useMB]
    formatter.includesUnit = true
    return formatter.string(fromByteCount: bytes)
}

// MARK: - Machine Identifier (Unix / sys/utsname.h)

/// Returns the exact machine / hardware identifier (e.g. "iPhone15,3") using `uname` and `sys/utsname.h`.
func getMachineIdentifier() -> String {
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

/// Formats system uptime (seconds) as "X h Y min".
func formatUptime(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    return String(format: "%d h %d min", hours, minutes)
}

// MARK: - Disk Space

/// Returns total and free disk space as formatted strings (GB/MB).
func diskSpace(fileManager: FileManager = .default) -> (total: String, free: String) {
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
