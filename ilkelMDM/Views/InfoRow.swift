//
//  InfoRow.swift
//  ilkelMDM
//
//  Reusable row component for the device inventory list.
//

import SwiftUI

/// A single key-value row for the dashboard list.
struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    List {
        InfoRow(title: "Device Name", value: "İbrahim's iPhone")
        InfoRow(title: "Model", value: "iPhone15,3")
    }
}
