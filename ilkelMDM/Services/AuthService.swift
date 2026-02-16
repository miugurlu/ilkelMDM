//
//  AuthService.swift
//  ilkelMDM
//
//  Biometric and device authentication (Face ID, Touch ID, passcode).
//

import Foundation
import LocalAuthentication
import UIKit

@MainActor
final class AuthService {
    private let reason = "Device Inventory'e erişmek için kimliğinizi doğrulayın"

    func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                Task { @MainActor in
                    completion(success)
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                Task { @MainActor in
                    completion(success)
                }
            }
        } else {
            completion(true)
        }
    }
}
