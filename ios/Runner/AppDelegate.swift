import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pendingTokenReply: FlutterResult?
  private var apnsToken: String?

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
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getToken":
        self?.registerAdminDevice(result)
      case "getExistingToken":
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
          DispatchQueue.main.async {
            let allowed = settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional
            if allowed { self?.registerAuthorizedDevice(result) }
            else { result("") }
          }
        }
      case "getPermissionStatus":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          DispatchQueue.main.async {
            switch settings.authorizationStatus {
            case .authorized, .provisional:
              result("authorized")
            case .denied:
              result("denied")
            default:
              result("default")
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerAuthorizedDevice(_ result: @escaping FlutterResult) {
    if let token = apnsToken {
      result(token)
      return
    }
    guard pendingTokenReply == nil else {
      result(FlutterError(code: "busy", message: "APNs registration in progress", details: nil))
      return
    }
    pendingTokenReply = result
    UIApplication.shared.registerForRemoteNotifications()
  }

  private func registerAdminDevice(_ result: @escaping FlutterResult) {
    // Always re-check OS permission; a user may revoke notifications
    // after the app cached its APNs token.
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
          self.registerAuthorizedDevice(result)
        }
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    apnsToken = deviceToken.map { String(format: "%02x", $0) }.joined()
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
