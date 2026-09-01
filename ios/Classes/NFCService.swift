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
    var channel: FlutterMethodChannel?
    var lastPassportData: [String: Any]?

    private init() {}

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
                    skipPACE: false,
                    useExtendedMode: false,
                    customDisplayMessage: { displayMessage in
                        return displayMessage.description
                    }
                )

                var data: [String: Any] = [:]

                // Top-level fields (matches Android EkycPlugin)
                data["firstName"] = passportModel.firstName
                data["lastName"] = passportModel.lastName
                data["documentNumber"] = passportModel.documentNumber
                data["documentCode"] = passportModel.documentType
                data["documentType"] = passportModel.documentType
                data["documentSubType"] = passportModel.documentSubType
                data["birthDate"] = passportModel.dateOfBirth
                data["expiryDate"] = passportModel.documentExpiryDate
                data["nationality"] = passportModel.nationality
                data["sex"] = passportModel.gender
                data["gender"] = passportModel.gender
                data["issuingState"] = passportModel.issuingAuthority
                data["issuingCountry"] = passportModel.issuingAuthority
                data["NIN"] = passportModel.personalNumber
                data["personalNumber"] = passportModel.personalNumber
                data["placeOfBirth"] = passportModel.placeOfBirth
                data["residenceAddress"] = passportModel.residenceAddress
                data["telephone"] = passportModel.phoneNumber
                data["mrz"] = passportModel.passportMRZ
                data["fullMrz"] = passportModel.passportMRZ

                // Raw DG11 & DG12 helpers
                let dg11Raw = passportModel.dataGroupsRead[.DG11] as? DataGroup11
                let dg12Raw = passportModel.dataGroupsRead[.DG12] as? DataGroup12

                data["profession"] = dg11Raw?.profession
                data["title"] = dg11Raw?.title
                data["personalSummary"] = dg11Raw?.personalSummary
                data["custodyInformation"] = dg11Raw?.custodyInfo

                // COM
                data["ldsVersion"] = passportModel.LDSVersion
                data["unicodeVersion"] = passportModel.unicodeVersion
                data["dataGroupsPresent"] = passportModel.dataGroupsPresent
                data["dataGroupsAvailable"] = passportModel.dataGroupsAvailable.map { $0.getName() }

                // Images (Base64)
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
                data["frontImageBase64"] = nil
                data["rearImageBase64"] = nil

                // Auth / Verification status
                data["verified"] = passportModel.documentSigningCertificateVerified
                data["notTampered"] = passportModel.passportDataNotTampered
                data["passportCorrectlySigned"] = passportModel.passportCorrectlySigned
                data["documentSigningCertificateVerified"] = passportModel.documentSigningCertificateVerified
                data["activeAuthenticationPassed"] = passportModel.activeAuthenticationPassed
                data["activeAuthenticationSupported"] = passportModel.activeAuthenticationSupported
                data["chipAuthenticationSupported"] = passportModel.isChipAuthenticationSupported
                data["isPACESupported"] = passportModel.isPACESupported
                data["isChipAuthenticationSupported"] = passportModel.isChipAuthenticationSupported
                data["BACStatus"] = String(describing: passportModel.BACStatus)
                data["PACEStatus"] = String(describing: passportModel.PACEStatus)
                data["chipAuthenticationStatus"] = String(describing: passportModel.chipAuthenticationStatus)
                data["verificationErrors"] = passportModel.verificationErrors.map { "\($0)" }

                // DG-mapped structures (mirrors Android jmrtd format)
                data["com"] = [
                    "ldsVersion": passportModel.LDSVersion,
                    "unicodeVersion": passportModel.unicodeVersion,
                    "tagsList": passportModel.dataGroupsPresent,
                    "dataGroupsPresent": passportModel.dataGroupsPresent,
                    "dataGroupsAvailable": passportModel.dataGroupsAvailable.map { $0.getName() }
                ]

                data["sod"] = [
                    "correctlySigned": passportModel.passportCorrectlySigned,
                    "documentSigningCertVerified": passportModel.documentSigningCertificateVerified,
                    "dataNotTampered": passportModel.passportDataNotTampered,
                    "digestAlgorithm": "",
                    "digestAlgorithmSignerInfo": "",
                    "serialNumber": "",
                    "signature": "",
                    "Subject": "",
                    "issuer": "",
                    "Valid from": "",
                    "Valid until": "",
                    "Public Key": "",
                    "Signature algorithm": "",
                    "full": ""
                ]

                data["dg1"] = [
                    "firstName": passportModel.firstName,
                    "lastName": passportModel.lastName,
                    "documentNumber": passportModel.documentNumber,
                    "documentCode": passportModel.documentType,
                    "documentType": passportModel.documentType,
                    "documentSubType": passportModel.documentSubType,
                    "issuingState": passportModel.issuingAuthority,
                    "issuingCountry": passportModel.issuingAuthority,
                    "nationality": passportModel.nationality,
                    "dateOfBirth": passportModel.dateOfBirth,
                    "dateOfExpiry": passportModel.documentExpiryDate,
                    "gender": passportModel.gender,
                    "opt1": passportModel.personalNumber as Any,
                    "opt2": "",
                    "mrz": passportModel.passportMRZ,
                    "fullMrz": passportModel.passportMRZ
                ]

                data["dg2"] = [
                    "photo": photoStr as Any,
                    "isJpeg": true,
                    "rawBytes": nil
                ]

                data["dg7"] = [
                    "images": [sigStr].compactMap { $0 }
                ]

                let fullName = dg11Raw?.fullName ?? [passportModel.firstName, passportModel.lastName].filter { !$0.isEmpty }.joined(separator: " ")
                data["dg11"] = [
                    "nameOfHolder": dg11Raw?.fullName ?? passportModel.firstName + " " + passportModel.lastName,
                    // arabicName / fullNameArabic / nameOfHolderOriginal / otherInfo: this library's
                    // DataGroup11.parse() does not capture any tag that maps to these — if your Algerian
                    // ID cards carry an Arabic name in DG11, it's in a tag this parser currently drops.
                    // Needs a custom DataGroup11 subclass/patch to capture the unhandled tag(s) before
                    // these can be populated.
                    "fullDateOfBirth": dg11Raw?.dateOfBirth ?? passportModel.dateOfBirth,
                    "placeOfBirth": passportModel.placeOfBirth as Any,
                    "personalNumber": passportModel.personalNumber as Any,
                    "permanentAddress": passportModel.residenceAddress as Any,
                    "permanentAddress1": passportModel.residenceAddress as Any,
                    "telephone": passportModel.phoneNumber as Any,
                    "profession": dg11Raw?.profession as Any,
                    "title": dg11Raw?.title as Any,
                    "personalSummary": dg11Raw?.personalSummary as Any,
                    "custodyInformation": dg11Raw?.custodyInfo as Any
                ]

                data["dg12"] = [
                    "issuingAuthority": dg12Raw?.issuingAuthority as Any,
                    "dateOfIssue": dg12Raw?.dateOfIssue as Any,
                    "otherPersons": dg12Raw?.otherPersonsDetails as Any,
                    "endorsementsObservations": dg12Raw?.endorsementsOrObservations as Any,
                    "taxExitRequirements": dg12Raw?.taxOrExitRequirements as Any,
                    "personalizationTime": dg12Raw?.personalizationTime as Any,
                    "personalizationDeviceSerialNumber": dg12Raw?.personalizationDeviceSerialNr as Any,
                    "imageOfFront": nil,
                    "imageOfRear": nil
                ]

                data["dg14"] = [
                    "chipAuthenticationSupported": passportModel.isChipAuthenticationSupported,
                    "paceSupported": passportModel.isPACESupported
                ]

                data["dg15"] = [
                    "activeAuthenticationSupported": passportModel.activeAuthenticationSupported,
                    "algorithm": "",
                    "format": "",
                    "encoded": ""
                ]

                self.lastPassportData = data

                // Return via method channel Future
                result(data)

                // Also notify registered listener (exact same way as Android)
                self.channel?.invokeMethod("onPassportRead", arguments: data)

            } catch let error as NFCPassportReaderError {
                print("❌ NFC Passport Reader Error: \(error)")
                let errorMessage = self.getReadableError(error)
                result(FlutterError(
                    code: "NFC_PASSPORT_ERROR",
                    message: errorMessage,
                    details: error.localizedDescription
                ))
                self.channel?.invokeMethod("onPassportError", arguments: errorMessage)
            } catch {
                print("❌ General Error: \(error)")
                let errorMessage = error.localizedDescription
                result(FlutterError(
                    code: "NFC_ERROR",
                    message: errorMessage,
                    details: nil
                ))
                self.channel?.invokeMethod("onPassportError", arguments: errorMessage)
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
