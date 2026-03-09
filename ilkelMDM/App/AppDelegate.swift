//
//  AppDelegate.swift
//  ilkelMDM
//
//  Created by İbrahim Uğurlu on 26.02.2026.
//

import Foundation
import UIKit

public class AppDelegate: NSObject, UIApplicationDelegate{
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }
    
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(tokenString, forKey: "apns_device_token")
        print("[APNs] Device token alındı: \(tokenString.prefix(20))...")

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let payload = TokenRegistrationPayload.registerToken(deviceId: deviceId, deviceToken: tokenString)
        let tcp = TCPService()
        tcp.send(payload) { success in
            if success {
                print("[APNs] Token gönderildi.")
            } else {
                print("[APNs] Token gönderilemedi.")
            }
            tcp.disconnect()
        }
    }

    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[APNs] Token alınamadı: \(error.localizedDescription)")
    }

    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let payload = DeviceInventoryPayloadBuilder.buildForBackground()
        let tcp = TCPService()
        tcp.send(payload) { success in
            tcp.disconnect()
            completionHandler(success ? .newData : .failed)
        }
    }
    
    
}
