//
//  DeviceViewModel.swift
//  ilkelMDM
//
//
//

import Combine
import CoreLocation
import Foundation
import SwiftUI
import UIKit

@MainActor
final class DeviceViewModel: ObservableObject {

    // MARK: - Device data (DeviceMonitorService üzerinden)

    var deviceName: String { deviceMonitor.deviceName }
    var systemName: String { deviceMonitor.systemName }
    var systemVersion: String { deviceMonitor.systemVersion }
    var model: String { deviceMonitor.model }
    var localizedModel: String { deviceMonitor.localizedModel }
    var userInterfaceIdiom: UIUserInterfaceIdiom { deviceMonitor.userInterfaceIdiom }
    var identifierForVendor: String { deviceMonitor.identifierForVendor }
    var machineIdentifier: String { deviceMonitor.machineIdentifier }
    var isMultiTaskingSupported: Bool { deviceMonitor.isMultiTaskingSupported }

    var physicalMemoryGB: String { deviceMonitor.physicalMemoryGB }
    var processorCountActive: Int { deviceMonitor.processorCountActive }
    var processorCountTotal: Int { deviceMonitor.processorCountTotal }
    var systemUptimeFormatted: String { deviceMonitor.systemUptimeFormatted }
    var totalDiskSpaceGB: String { deviceMonitor.totalDiskSpaceGB }
    var freeDiskSpaceGB: String { deviceMonitor.freeDiskSpaceGB }

    var batteryLevel: Float { deviceMonitor.batteryLevel }
    var batteryState: UIDevice.BatteryState { deviceMonitor.batteryState }
    var thermalState: ProcessInfo.ThermalState { deviceMonitor.thermalState }
    var connectionType: String { deviceMonitor.connectionType }
    var orientation: UIDeviceOrientation { deviceMonitor.orientation }

    // MARK: - View state (ViewModel’e özel)

    @Published var isUnlocked = false
    @Published private(set) var latitude: Double?
    @Published private(set) var longitude: Double?
    @Published private(set) var altitude: Double?
    @Published private(set) var locationTimestamp: Date?

    // MARK: - Dependencies

    private let deviceMonitor: DeviceMonitorService
    private let locationService: LocationService
    private let tcpService: TCPService
    private var cancellables = Set<AnyCancellable>()
    private var hasSentToServer = false
    private let locationWaitTimeoutSeconds: UInt64 = 10

    // MARK: - Init

    init(
        deviceMonitor: DeviceMonitorService? = nil,
        locationService: LocationService? = nil,
        tcpService: TCPService? = nil
    ) {
        self.deviceMonitor = deviceMonitor ?? DeviceMonitorService()
        self.locationService = locationService ?? LocationService()
        self.tcpService = tcpService ?? TCPService()

        self.deviceMonitor.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        deviceMonitor.startMonitoring()
        startLocationUpdates()
        scheduleSendWithLocationTimeout()
    }

    func stopMonitoring() {
        deviceMonitor.stopMonitoring()
        locationService.stop()
        tcpService.disconnect()
    }

    // MARK: - Location

    private func startLocationUpdates() {
        locationService.onLocationUpdate = { [weak self] location in
            guard let self = self else { return }
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.altitude = location.altitude
            self.locationTimestamp = location.timestamp
            if !self.hasSentToServer {
                self.hasSentToServer = true
                self.sendToServer()
            }
        }
        locationService.start()
    }

    /// Konum gelene kadar bekler; gelmezse timeout (10 sn) sonunda konum olmadan gönderir.
    private func scheduleSendWithLocationTimeout() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: locationWaitTimeoutSeconds * 1_000_000_000)
            if !hasSentToServer {
                hasSentToServer = true
                sendToServer()
            }
        }
    }

    // MARK: - TCP Send

    private func sendToServer() {
        let payload = DeviceInventoryPayloadBuilder.build(
            deviceMonitor: deviceMonitor,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            locationTimestamp: locationTimestamp
        )
        tcpService.send(payload)
    }

    // MARK: - Display helpers (DeviceDisplayFormatting’e yönlendirme)

    var batteryLevelText: String { DeviceDisplayFormatting.batteryLevel(batteryLevel) }
    var batteryStateText: String { DeviceDisplayFormatting.batteryState(batteryState) }
    var thermalStateText: String { DeviceDisplayFormatting.thermalState(thermalState) }
    var isThermalWarning: Bool { DeviceDisplayFormatting.isThermalWarning(thermalState) }
    var userInterfaceIdiomText: String { DeviceDisplayFormatting.userInterfaceIdiom(userInterfaceIdiom) }
    var orientationText: String { DeviceDisplayFormatting.orientation(orientation) }
    var locationText: String { DeviceDisplayFormatting.location(latitude: latitude, longitude: longitude) }
}
