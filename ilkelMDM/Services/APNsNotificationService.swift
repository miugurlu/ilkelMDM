//
//  APNsNotificationService.swift
//  ilkelMDM
//
//  APNs token kaydı ve push sonrası envanter gönderimi. TCP gönderimini bu servis yönetir
//

import Foundation
import UIKit

final class APNsNotificationService {

    private let tcpServiceFactory: () -> TCPService
    private let tokenStorageKey = "apns_device_token"

    /// Test için TCP servisi inject edilebilir; yoksa her gönderimde yeni TCPService kullanılır.
    init(tcpServiceFactory: @escaping () -> TCPService = { TCPService() }) {
        self.tcpServiceFactory = tcpServiceFactory
    }

    /// Token'ı string'e çevirir, saklar ve sunucuya gönderir.
    func sendToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(tokenString, forKey: tokenStorageKey)
        print("[APNs] Device token alındı: \(tokenString.prefix(20))...")

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let payload = TokenRegistrationPayload.registerToken(deviceId: deviceId, deviceToken: tokenString)
        let tcp = tcpServiceFactory()
        tcp.send(payload) { success in
            if success {
                print("[APNs] Token gönderildi.")
            } else {
                print("[APNs] Token gönderilemedi.")
            }
            tcp.disconnect()
        }
    }

    /// Push bildirimi sonrası arka plan envanterini sunucuya gönderir.
    func sendInventoryForPush(completion: @escaping (UIBackgroundFetchResult) -> Void) {
        let payload = DeviceInventoryPayloadBuilder.buildForBackground()
        let tcp = tcpServiceFactory()
        tcp.send(payload) { success in
            tcp.disconnect()
            completion(success ? .newData : .failed)
        }
    }
}
