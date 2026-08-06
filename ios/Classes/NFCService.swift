import UIKit
import CommonCrypto
import CryptoKit
import Flutter
import Network
import NFCPassportReader
import CoreNFC
import Foundation


// MARK: - NFC Service
class NFCService {

    static let shared = NFCService()
    private var passportReader: PassportReader?
    var lastPassportData: [String: Any]?

    private init() {}

    // Setup method channel - call this from AppDelegate
    func setupMethodChannel(with binaryMessenger: FlutterBinaryMessenger) {
        let passportChannel = FlutterMethodChannel(
            name: "passport_nfc",
            binaryMessenger: binaryMessenger
        )

        passportChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else { return }

            if call.method == "readPassport" {
                guard let args = call.arguments as? [String: String],
                      let passportNumber = args["passportNumber"],
                      let dateOfBirth = args["dateOfBirth"],
                      let dateOfExpiry = args["dateOfExpiry"] else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing MRZ fields", details: nil))
                    return
                }
                self.readPassport(
                    passportNumber: passportNumber,
                    dateOfBirth: dateOfBirth,
                    dateOfExpiry: dateOfExpiry,
                    result: result
                )
            } else if call.method == "checkNFCSupport" {
                self.checkNFCSupport(result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // Check if device supports NFC
    private func checkNFCSupport(result: @escaping FlutterResult) {
        if #available(iOS 13.0, *) {
            let isSupported = NFCNDEFReaderSession.readingAvailable
            result(["supported": isSupported])
        } else {
            result(["supported": false, "error": "iOS 13+ required for NFC"])
        }
    }

    @available(iOS 13, *)
    func readPassport(
        passportNumber: String,
        dateOfBirth: String,
        dateOfExpiry: String,
        result: @escaping FlutterResult
    ) {
        let bacKey = MRZUtils.computeMRZKey(
            passportNumber: passportNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )

        self.passportReader = PassportReader()

        Task { @MainActor in
            do {
                print("📡 Attempting to read passport with NFC...")

                let passportModel = try await self.passportReader!.readPassport(
                    mrzKey: bacKey,
                    tags: [.DG1, .DG2, .DG3, .DG4, .DG5, .DG6, .DG7, .DG11, .DG12, .DG13, .DG14, .DG15, .DG16, .COM, .SOD],
                    skipSecureElements: true,
                    skipCA: true,
                    skipPACE: true,
                    useExtendedMode: false,
                    customDisplayMessage: { displayMessage in
                        return displayMessage.description
                    }
                )

                var data: [String: Any] = [:]
                                data["firstName"] = passportModel.firstName
                                data["lastName"] = passportModel.lastName
                                data["documentNumber"] = passportModel.documentNumber
                                data["documentType"] = passportModel.documentType
                                data["documentSubType"] = passportModel.documentSubType
                                data["birthDate"] = passportModel.dateOfBirth
                                data["expiryDate"] = passportModel.documentExpiryDate
                                data["nationality"] = passportModel.nationality
                                data["sex"] = passportModel.gender
                                data["issuingState"] = passportModel.issuingAuthority
                                data["NIN"] = passportModel.personalNumber
                                data["mrz"] = passportModel.passportMRZ

                                data["placeOfBirth"] = passportModel.placeOfBirth
                                data["residenceAddress"] = passportModel.residenceAddress
                                data["telephone"] = passportModel.phoneNumber

                                // COM
                                data["ldsVersion"] = passportModel.LDSVersion
                                data["dataGroupsPresent"] = passportModel.dataGroupsPresent
                                data["dataGroupsAvailable"] = passportModel.dataGroupsAvailable.map { $0.getName() }

                                // Images
                                var photoStr: String? = nil
                                var sigStr: String? = nil
                                if let image = passportModel.passportImage,
                                   let imageData = image.jpegData(compressionQuality: 0.8) {
                                    photoStr = imageData.base64EncodedString()
                                    data["photoBase64"] = photoStr
                                }
                                if let image = passportModel.signatureImage,
                                   let imageData = image.jpegData(compressionQuality: 0.8) {
                                    sigStr = imageData.base64EncodedString()
                                    data["signatureBase64"] = sigStr
                                }

                                // Face image metadata (DG2)
//                                if let faceInfo = passportModel.faceImageInfo {
//                                    data["faceImageInfo"] = [
//                                        "gender": faceInfo.gender ?? "",
//                                        "eyeColor": faceInfo.eyeColor ?? "",
//                                        "hairColor": faceInfo.hairColor ?? "",
//                                        "expression": faceInfo.expression ?? "",
//                                        "imageDataType": faceInfo.imageDataType ?? ""
//                                    ]
//                                }

                                // Auth / verification status
                                data["BACStatus"] = String(describing: passportModel.BACStatus)
                                data["PACEStatus"] = String(describing: passportModel.PACEStatus)
                                data["chipAuthenticationStatus"] = String(describing: passportModel.chipAuthenticationStatus)
                                data["isPACESupported"] = passportModel.isPACESupported
                                data["isChipAuthenticationSupported"] = passportModel.isChipAuthenticationSupported
                                data["activeAuthenticationSupported"] = passportModel.activeAuthenticationSupported
                                data["activeAuthenticationPassed"] = passportModel.activeAuthenticationPassed
                                data["passportCorrectlySigned"] = passportModel.passportCorrectlySigned
                                data["documentSigningCertificateVerified"] = passportModel.documentSigningCertificateVerified
                                data["passportDataNotTampered"] = passportModel.passportDataNotTampered
                                data["verified"] = passportModel.documentSigningCertificateVerified
                                data["notTampered"] = passportModel.passportDataNotTampered
                                data["verificationErrors"] = passportModel.verificationErrors.map { "\($0)" }

                                // DG-mapped structure (mirrors your Android/jmrtd shape)
                                data["dg1"] = [
                                    "firstName": passportModel.firstName,
                                    "lastName": passportModel.lastName,
                                    "documentNumber": passportModel.documentNumber,
                                    "documentType": passportModel.documentType,
                                    "documentSubType": passportModel.documentSubType,
                                    "issuingState": passportModel.issuingAuthority,
                                    "nationality": passportModel.nationality,
                                    "dateOfBirth": passportModel.dateOfBirth,
                                    "dateOfExpiry": passportModel.documentExpiryDate,
                                    "gender": passportModel.gender,
                                    "mrz": passportModel.passportMRZ
                                ]
                                data["dg2"] = [
                                    "photo": photoStr as Any,
                                    "isJpeg": true
                                ]
                                data["dg7"] = [
                                    "images": [sigStr].compactMap { $0 }
                                ]
                                data["dg11"] = [
                                    "fullDateOfBirth": passportModel.dateOfBirth,
                                    "placeOfBirth": passportModel.placeOfBirth as Any,
                                    "personalNumber": passportModel.personalNumber as Any,
                                    "permanentAddress": passportModel.residenceAddress as Any,
                                    "telephone": passportModel.phoneNumber as Any
                                ]
                                data["dg14"] = [
                                    "chipAuthenticationSupported": passportModel.isChipAuthenticationSupported,
                                    "paceSupported": passportModel.isPACESupported
                                ]
                                data["dg15"] = [
                                    "activeAuthenticationSupported": passportModel.activeAuthenticationSupported
                                ]
                                data["sod"] = [
                                    "correctlySigned": passportModel.passportCorrectlySigned,
                                    "documentSigningCertVerified": passportModel.documentSigningCertificateVerified,
                                    "dataNotTampered": passportModel.passportDataNotTampered
                                ]

                                self.lastPassportData = data
                                result(data)

            } catch let error as NFCPassportReaderError {
                print("❌ NFC Passport Reader Error: \(error)")
                let errorMessage = self.getReadableError(error)
                result(FlutterError(
                    code: "NFC_PASSPORT_ERROR",
                    message: errorMessage,
                    details: error.localizedDescription
                ))
            } catch {
                print("❌ General Error: \(error)")
                result(FlutterError(
                    code: "NFC_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
            }
        }
    }

    func getReadableError(_ error: NFCPassportReaderError) -> String {
        switch error {
        case .TagNotValid:
            return "Invalid NFC tag. Make sure you're scanning an ePassport."
        case .MoreThanOneTagFound:
            return "Multiple NFC tags detected. Please scan one passport at a time."
        case .ConnectionError:
            return "Connection failed. Hold the passport steady near the NFC reader."
        case .InvalidMRZKey:
            return "Invalid MRZ data. Please check passport number, date of birth, and expiry date."
        case .ResponseError(let description, let sw1, let sw2):
            return "Passport communication error: \(description) (SW1: \(sw1), SW2: \(sw2))"
        case .InvalidResponseChecksum:
            return "Data integrity error. Please try scanning again."
        case .MissingMandatoryFields:
            return "Required passport data is missing."
        case .CannotDecodeASN1Length:
            return "Data format error. This passport may not be supported."
        case .InvalidHashAlgorithmSpecified:
            return "Unsupported security algorithm."
        case .UnsupportedCipherAlgorithm:
            return "Unsupported encryption method."
        case .UnsupportedMappingType:
            return "Unsupported passport format."
        case .NFCNotSupported:
            return "NFC is not supported on this device."
        case .NoConnectedTag:
            return "No NFC tag detected. Hold passport closer to device."
        case .D087Malformed:
            return "Passport security data is malformed."
        case .UnexpectedError:
            return "An unexpected error occurred during scanning."
        default:
            return "Unknown error occurred: \(error.localizedDescription)"
        }
    }
}

// MARK: - Data Extension
extension Data {
    func sha256() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
