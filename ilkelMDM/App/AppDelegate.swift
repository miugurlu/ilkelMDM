//
//  AppDelegate.swift
//  ilkelMDM
//
//  Created by İbrahim Uğurlu on 26.02.2026.
//
//  Sadece uygulama yaşam döngüsü ve sistem olaylarını alır; APNs token ve push
//  işlemleri APNsNotificationService'e devredilir.
//

import Foundation
import UIKit

public class AppDelegate: NSObject, UIApplicationDelegate {

    private let apnsService = APNsNotificationService()

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        apnsService.sendToken(deviceToken)
    }

    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[APNs] Token alınamadı: \(error.localizedDescription)")
    }

    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        apnsService.sendInventoryForPush(completion: completionHandler)
    }
}
