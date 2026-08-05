import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    let accepted = DocumentOpenBroker.shared.accept(paths: filenames)
    if accepted {
      sender.activate(ignoringOtherApps: true)
      sender.reply(toOpenOrPrint: .success)
    } else {
      sender.reply(toOpenOrPrint: .failure)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
