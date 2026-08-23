import Flutter
import QuickLook
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  QLPreviewControllerDataSource
{
  private var attachmentChannel: FlutterMethodChannel?
  private var previewURL: URL?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    attachmentChannel = FlutterMethodChannel(
      name: "city_companion/attachments",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    attachmentChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "open" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(FlutterError(code: "invalid_path", message: "No attachment path was provided.", details: nil))
        return
      }
      self?.openAttachment(at: path, result: result)
    }
  }

  private func openAttachment(at path: String, result: @escaping FlutterResult) {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
      result(FlutterError(code: "file_missing", message: "The attachment is no longer on this device.", details: nil))
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      guard let presenter = self.activeViewController() else {
        result(FlutterError(code: "viewer_unavailable", message: "The attachment viewer is unavailable.", details: nil))
        return
      }

      self.previewURL = url
      let previewController = QLPreviewController()
      previewController.dataSource = self
      presenter.present(previewController, animated: true) {
        result(nil)
      }
    }
  }

  private func activeViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }?
      .rootViewController
    return topViewController(from: root)
  }

  private func topViewController(from controller: UIViewController?) -> UIViewController? {
    if let presented = controller?.presentedViewController {
      return topViewController(from: presented)
    }
    if let navigation = controller as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tabs = controller as? UITabBarController {
      return topViewController(from: tabs.selectedViewController)
    }
    return controller
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    previewURL == nil ? 0 : 1
  }

  func previewController(
    _ controller: QLPreviewController,
    previewItemAt index: Int
  ) -> QLPreviewItem {
    previewURL! as NSURL
  }
}
