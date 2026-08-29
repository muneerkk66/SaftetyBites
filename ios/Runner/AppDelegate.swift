import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let badgeChannelName = "com.necsca.safebitesapp/badge"
  private var pendingRecallNotification: [String: String]?
  private var badgeChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let badgeChannel = FlutterMethodChannel(
      name: badgeChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    self.badgeChannel = badgeChannel
    badgeChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "hasUnread":
        result(UIApplication.shared.applicationIconBadgeNumber > 0)
      case "markUnread":
        self.setBadgeCount(1)
        result(nil)
      case "clearUnread":
        self.setBadgeCount(0)
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        result(nil)
      case "consumePendingNotification":
        let notification = self.pendingRecallNotification
        self.pendingRecallNotification = nil
        result(notification)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    pendingRecallNotification = recallNotificationData(
      from: response.notification
    )
    setBadgeCount(1)
    badgeChannel?.invokeMethod(
      "notificationReceived",
      arguments: pendingRecallNotification
    )
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    pendingRecallNotification = recallNotificationData(from: notification)
    setBadgeCount(1)
    badgeChannel?.invokeMethod(
      "notificationReceived",
      arguments: pendingRecallNotification
    )
    super.userNotificationCenter(
      center,
      willPresent: notification,
      withCompletionHandler: { options in
        completionHandler(
          options.union([.banner, .list, .sound, .badge])
        )
      }
    )
  }

  private func recallNotificationData(
    from notification: UNNotification
  ) -> [String: String] {
    let content = notification.request.content
    let userInfo = content.userInfo
    var data = [
      "title": content.title,
      "body": content.body,
    ]
    if let alertID = userInfo["alertId"] as? String {
      data["alertId"] = alertID
    }
    if let route = userInfo["route"] as? String {
      data["route"] = route
    }
    return data
  }

  private func setBadgeCount(_ count: Int) {
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(count)
    } else {
      UIApplication.shared.applicationIconBadgeNumber = count
    }
  }
}
