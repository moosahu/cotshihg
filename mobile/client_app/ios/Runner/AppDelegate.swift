import Flutter
import UIKit
import FirebaseAuth

/// Provides the top-most UIViewController to Firebase for reCAPTCHA presentation.
/// Needed because UIApplication.shared.keyWindow is nil in Flutter (UIWindowScene).
class FlutterAuthUIDelegate: NSObject, AuthUIDelegate {
  func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
    DispatchQueue.main.async {
      self.topViewController()?.present(viewControllerToPresent, animated: animated, completion: completion)
    }
  }

  func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
    DispatchQueue.main.async {
      self.topViewController()?.dismiss(animated: animated, completion: completion)
    }
  }

  private func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    return scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let uiDelegate = FlutterAuthUIDelegate()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    application.registerForRemoteNotifications()

    // Method channel so Flutter can trigger verifyPhoneNumber with proper UIDelegate
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "firebase_auth_ios_helper",
                                       binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if call.method == "verifyPhoneNumber",
         let args = call.arguments as? [String: Any],
         let phoneNumber = args["phoneNumber"] as? String {
        let provider = PhoneAuthProvider.provider(auth: Auth.auth())
        provider.verifyPhoneNumber(
          phoneNumber,
          uiDelegate: self.uiDelegate
        ) { verificationId, error in
          if let error = error {
            result(FlutterError(code: "FIREBASE_AUTH_ERROR",
                                message: error.localizedDescription,
                                details: nil))
          } else {
            result(verificationId)
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication,
                             didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(_ application: UIApplication,
                             didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                             fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }

  override func application(_ application: UIApplication,
                             open url: URL,
                             options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if Auth.auth().canHandle(url) {
      return true
    }
    return super.application(application, open: url, options: options)
  }
}
