import Flutter
import UIKit
import CoreNFC

@available(iOS 11.0, *)
public class EkycPlugin: NSObject, FlutterPlugin, NFCNDEFReaderSessionDelegate {
  private var nfcSession: NFCNDEFReaderSession?
  private var result: FlutterResult?
  
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
      
    case "readNfc":
      if #available(iOS 11.0, *) {
        if NFCNDEFReaderSession.readingAvailable {
          self.result = result
          nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
          nfcSession?.alertMessage = "Hold your iPhone near the NFC tag"
          nfcSession?.begin()
        } else {
          result(FlutterError(code: "NFC_NOT_SUPPORTED", message: "NFC is not supported on this device", details: nil))
        }
      } else {
        result(FlutterError(code: "NFC_NOT_SUPPORTED", message: "NFC requires iOS 11.0 or later", details: nil))
      }
      
    case "onNfcTagDetected":
      result(FlutterError(code: "NOT_IMPLEMENTED", message: "onNfcTagDetected is not implemented for iOS", details: nil))
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // MARK: - NFCNDEFReaderSessionDelegate
  
  @available(iOS 11.0, *)
  public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
    DispatchQueue.main.async {
      if let result = self.result {
        result(FlutterError(code: "NFC_ERROR", message: error.localizedDescription, details: nil))
        self.result = nil
      }
    }
  }
  
  @available(iOS 11.0, *)
  public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
    var nfcData: [String: Any] = [:]
    var messagesArray: [[String: Any]] = []
    
    for message in messages {
      var recordsArray: [[String: Any]] = []
      for record in message.records {
        let recordData: [String: Any] = [
          "type": String(data: record.type, encoding: .utf8) ?? "",
          "payload": String(data: record.payload, encoding: .utf8) ?? "",
          "identifier": String(data: record.identifier, encoding: .utf8) ?? ""
        ]
        recordsArray.append(recordData)
      }
      messagesArray.append(["records": recordsArray])
    }
    
    nfcData["ndefMessages"] = messagesArray
    
    DispatchQueue.main.async {
      if let result = self.result {
        result(nfcData)
        self.result = nil
      }
    }
  }
}
