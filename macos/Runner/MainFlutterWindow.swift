import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var attachmentChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    attachmentChannel = FlutterMethodChannel(
      name: "city_companion/attachments",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    attachmentChannel?.setMethodCallHandler { call, result in
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

      let url = URL(fileURLWithPath: path)
      guard FileManager.default.fileExists(atPath: url.path) else {
        result(FlutterError(code: "file_missing", message: "The attachment is no longer on this device.", details: nil))
        return
      }
      guard NSWorkspace.shared.open(url) else {
        result(FlutterError(code: "viewer_unavailable", message: "No app can open this attachment type.", details: nil))
        return
      }
      result(nil)
    }

    super.awakeFromNib()
  }
}
