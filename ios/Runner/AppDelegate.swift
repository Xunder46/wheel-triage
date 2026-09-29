import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The app side of `RevenueCatPurchaseGateway.showManageSubscriptions()`.
  ///
  /// The purchases SDK exposes the store's subscription-management URL
  /// (`CustomerInfo.managementURL`) but has no method that opens it, and this
  /// app deliberately carries no URL-opening dependency (D-37), so the page is
  /// opened here with `UIApplication`. The Dart side swallows a missing
  /// handler, so a platform without this channel degrades to a no-op.
  private static let storePageChannel = "wheel_triage/store_page"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerStorePageChannel(with: engineBridge.pluginRegistry)
  }

  private func registerStorePageChannel(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "StorePageChannel") else { return }
    let channel = FlutterMethodChannel(
      name: AppDelegate.storePageChannel,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "open",
            let urlString = call.arguments as? String,
            let url = URL(string: urlString)
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened ? nil : FlutterError(code: "open_failed", message: nil, details: nil))
      }
    }
  }
}
