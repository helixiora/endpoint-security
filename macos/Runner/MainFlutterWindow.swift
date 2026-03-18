import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let windowTitleChannelName = "helixiora/window_title"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let channel = FlutterMethodChannel(
      name: windowTitleChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setWindowTitle" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let title = call.arguments as? String else {
        result(
          FlutterError(
            code: "invalid-args",
            message: "Expected a string title.",
            details: nil
          )
        )
        return
      }

      self?.title = title
      result(nil)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
