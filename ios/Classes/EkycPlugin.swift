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
    case "initialize":
      result(true)
    case "isNfcAvailable":
      let isSupported = NFCTagReaderSession.readingAvailable
      result(isSupported)
    case "readPassport":
        guard let args = call.arguments as? [String: String],
                let passportNumber = args["documentNumber"] ?? args["passportNumber"],
                let dateOfBirth = args["dateOfBirth"],
                let dateOfExpiry = args["dateOfExpiry"] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing MRZ fields", details: nil))
            return
        }
        NFCService.shared.readPassport(
            passportNumber: passportNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry,
            result: result
        )
    case "checkNfc":
      #if targetEnvironment(simulator)
      result([
        "supported": false,
        "enabled": false,
        "error": "NFC is not supported on the iOS Simulator. Please test on a physical iPhone."
      ])
      #else
      let tagSupported = NFCTagReaderSession.readingAvailable
      let ndefSupported = NFCNDEFReaderSession.readingAvailable
      let isSupported = tagSupported || ndefSupported
      result([
        "supported": isSupported,
        "enabled": isSupported,
        "error": isSupported ? nil : "NFC is not available on this device."
      ])
      #endif
    case "readCOM":
      result(NFCService.shared.lastPassportData?["com"] ?? [:])
    case "readSOD":
      result(NFCService.shared.lastPassportData?["sod"] ?? [:])
    case "readDG1":
      result(NFCService.shared.lastPassportData?["dg1"] ?? [:])
    case "readDG2":
      result(NFCService.shared.lastPassportData?["dg2"] ?? [:])
    case "readDG7":
      result(NFCService.shared.lastPassportData?["dg7"] ?? [:])
    case "readDG11":
      result(NFCService.shared.lastPassportData?["dg11"] ?? [:])
    case "readDG12":
      result(NFCService.shared.lastPassportData?["dg12"] ?? [:])
    case "readDG15":
      result(NFCService.shared.lastPassportData?["dg15"] ?? [:])
    default:
      result(FlutterMethodNotImplemented)
    }
  }
} 