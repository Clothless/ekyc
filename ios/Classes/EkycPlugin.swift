import Flutter
import UIKit
import CoreNFC

public class EkycPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ekyc", binaryMessenger: registrar.messenger())
    let instance = EkycPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
      
    case "checkNfc":
      if #available(iOS 11.0, *) {
        let isSupported = NFCNDEFReaderSession.readingAvailable
        result([
          "supported": isSupported,
          "enabled": isSupported
        ])
      } else {
        result([
          "supported": false,
          "enabled": false
        ])
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
} 