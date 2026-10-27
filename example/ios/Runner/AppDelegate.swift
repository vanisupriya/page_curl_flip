import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var phoneSoundChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The phone-sound channel: iOS has no public API for the silent switch, so only a zero volume is reported.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PhoneSound") {
      let channel = FlutterMethodChannel(
        name: "page_curl_flip_example/phone_sound", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "read" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(["silent": false, "volumeOff": AVAudioSession.sharedInstance().outputVolume == 0])
      }
      phoneSoundChannel = channel
    }
  }
}
