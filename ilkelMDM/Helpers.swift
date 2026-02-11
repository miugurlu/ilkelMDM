//
//  Helpers.swift
//  ilkelMDM
//
//  MDM Dashboard helper utilities: byte formatting and machine identifier.
//

import Foundation
import Darwin

// MARK: - Byte Formatting

/// Converts raw byte count to a human-readable string in GB (or MB when appropriate).
/// - Parameter bytes: Raw byte count (e.g. from disk or memory attributes).
/// - Returns: Formatted string (e.g. "12.45 GB" or "512.00 MB").
func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.allowedUnits = [.useGB, .useMB]
    formatter.includesUnit = true
    return formatter.string(fromByteCount: bytes)
}

// MARK: - Machine Identifier (Unix / sys/utsname.h)

/// Returns the exact machine / hardware identifier (e.g. "iPhone15,3") using `uname` and `sys/utsname.h`.
/// Prefer this over `UIDevice.current.model`, which only returns a generic name like "iPhone".
/// - Returns: Machine string, or a fallback if unavailable.
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
