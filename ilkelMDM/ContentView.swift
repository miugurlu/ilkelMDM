//
//  ContentView.swift
//  ilkelMDM
//
//  Created by İbrahim Uğurlu on 10.02.2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DeviceViewModel()

    var body: some View {
        if viewModel.isUnlocked {
            dashboardView
        } else {
            lockScreenView
        }
    }

    private var lockScreenView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Device Inventory")
                .font(.title2.weight(.semibold))
            Text("Giriş yapmak için Face ID veya Touch ID kullanın")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .onAppear {
            viewModel.authenticate()
        }
    }

    private var dashboardView: some View {
        NavigationStack {
            List {
                identitySection
                resourcesSection
                powerAndEnvironmentSection
                locationSection
                networkSection
            }
            .navigationTitle("Device Inventory")
            .onAppear {
                viewModel.startMonitoring()
            }
            .onDisappear {
                viewModel.stopMonitoring()
            }
        }
    }

    // MARK: - Identity & Hardware

    private var identitySection: some View {
        Section("Identity & Hardware") {
            InfoRow(title: "Device Name", value: viewModel.deviceName)
            InfoRow(title: "System Name", value: viewModel.systemName)
            InfoRow(title: "System Version", value: viewModel.systemVersion)
            InfoRow(title: "Model", value: viewModel.model)
            InfoRow(title: "Localized Model", value: viewModel.localizedModel)
            InfoRow(title: "User Interface Idiom", value: viewModel.userInterfaceIdiomText)
            InfoRow(title: "Identifier For Vendor", value: viewModel.identifierForVendor)
            InfoRow(title: "Machine Identifier", value: viewModel.machineIdentifier)
            InfoRow(title: "Multitasking Supported", value: viewModel.isMultiTaskingSupported ? "Yes" : "No")
        }
    }

    // MARK: - Resources & Storage

    private var resourcesSection: some View {
        Section("Resources & Storage") {
            InfoRow(title: "Physical Memory (RAM)", value: viewModel.physicalMemoryGB)
            InfoRow(title: "Processors", value: "\(viewModel.processorCountActive) / \(viewModel.processorCountTotal)")
            InfoRow(title: "System Uptime", value: viewModel.systemUptimeFormatted)
            InfoRow(title: "Total Disk Space", value: viewModel.totalDiskSpaceGB)
            InfoRow(title: "Free Disk Space", value: viewModel.freeDiskSpaceGB)
        }
    }

    // MARK: - Live Power & Environment (with thermal warning)

    private var powerAndEnvironmentSection: some View {
        Section {
            InfoRow(title: "Battery Level", value: viewModel.batteryLevelText)
            InfoRow(title: "Battery State", value: viewModel.batteryStateText)
            InfoRow(title: "Orientation", value: viewModel.orientationText)
            HStack {
                Text("Thermal State")
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.isThermalWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .padding(.trailing, 4)
                }
                Text(viewModel.thermalStateText)
                    .foregroundColor(viewModel.isThermalWarning ? .orange : .primary)
            }
        } header: {
            Text("Power & Environment")
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        Section("Location") {
            InfoRow(title: "Coordinates", value: viewModel.locationText)
        }
    }

    // MARK: - Network & Connectivity

    private var networkSection: some View {
        Section("Network & Connectivity") {
            InfoRow(title: "Connection Type", value: viewModel.connectionType)
        }
    }
}

#Preview {
    ContentView()
}
