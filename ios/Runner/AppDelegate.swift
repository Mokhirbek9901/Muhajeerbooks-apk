import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pendingTokenReply: FlutterResult?
  private var apnsToken: String?
  private var pushChannel: FlutterMethodChannel?
  private var pendingCustomerOrder: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "muhajeerbooks/admin_apns",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    pushChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "getPendingCustomerOrder" {
        result(self?.pendingCustomerOrder); self?.pendingCustomerOrder = nil; return
      }
      guard call.method == "getToken" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.registerAdminDevice(result)
    }
  }

  private func registerAdminDevice(_ result: @escaping FlutterResult) {
    if let token = apnsToken {
      result(token)
      return
    }
    guard pendingTokenReply == nil else {
      result(FlutterError(code: "busy", message: "APNs registration already in progress", details: nil))
      return
    }
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
      [weak self] granted, error in
      DispatchQueue.main.async {
        guard let self = self else { return }
        if let error = error {
          result(FlutterError(code: "permission", message: error.localizedDescription, details: nil))
        } else if !granted {
          result(FlutterError(code: "denied", message: "Bildirishnoma ruxsati berilmagan", details: nil))
        } else {
          self.pendingTokenReply = result
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    apnsToken = deviceToken.map { String(format: "%02x", $0) }.joined()
    pushChannel?.invokeMethod("tokenUpdated", arguments: nil)
    pendingTokenReply?(apnsToken)
    pendingTokenReply = nil
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    pendingTokenReply?(FlutterError(
      code: "apns_registration",
      message: error.localizedDescription,
      details: nil
    ))
    pendingTokenReply = nil
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let info = response.notification.request.content.userInfo
    if info["kind"] as? String == "customer_order",
       let orderId = info["order_id"] as? String {
      pendingCustomerOrder = orderId
      pushChannel?.invokeMethod("customerOrderTapped", arguments: orderId)
      completionHandler()
      return
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}
