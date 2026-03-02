//
//  TokenRegistrationPayload.swift
//  ilkelMDM
//
//  Created by İbrahim Uğurlu on 2.03.2026.
//

import Foundation

struct TokenRegistrationPayload: Codable {
    let type: String
    let deviceId: String
    let deviceToken: String

    static func registerToken(deviceId: String, deviceToken: String) -> TokenRegistrationPayload {
        TokenRegistrationPayload(
            type: "register_token",
            deviceId: deviceId,
            deviceToken: deviceToken
        )
    }
}
