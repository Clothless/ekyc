struct MRZUtils {
    static func computeMRZKey(passportNumber: String, dateOfBirth: String, dateOfExpiry: String) -> String {
        return buildBACKey(passportNumber: passportNumber, dateOfBirth: dateOfBirth, dateOfExpiry: dateOfExpiry)
    }

    static func buildBACKey(passportNumber: String, dateOfBirth: String, dateOfExpiry: String) -> String {
        let cleanPassportNumber = passportNumber.replacingOccurrences(of: " ", with: "").uppercased()
        let cleanDOB = formatDateForMRZ(dateOfBirth.replacingOccurrences(of: " ", with: ""))
        let cleanDOE = formatDateForMRZ(dateOfExpiry.replacingOccurrences(of: " ", with: ""))

        let paddedPassportNumber = padWithFillChars(cleanPassportNumber, targetLength: 9)

        let passportCheck = calculateMRZCheckDigit(for: paddedPassportNumber)
        let dobCheck = calculateMRZCheckDigit(for: cleanDOB)
        let doeCheck = calculateMRZCheckDigit(for: cleanDOE)

        let bacKey = paddedPassportNumber + passportCheck + cleanDOB + dobCheck + cleanDOE + doeCheck

        return bacKey
    }

    static func padWithFillChars(_ input: String, targetLength: Int) -> String {
        if input.count >= targetLength {
            return String(input.prefix(targetLength))
        }
        return input + String(repeating: "<", count: targetLength - input.count)
    }

    static func calculateMRZCheckDigit(for input: String) -> String {
        let weights = [7, 3, 1]
        var sum = 0

        for (index, char) in input.enumerated() {
            let weight = weights[index % 3]
            let value: Int

            if char.isNumber {
                value = Int(String(char))!
            } else if char.isLetter && char.isASCII {
                value = Int(char.asciiValue! - Character("A").asciiValue!) + 10
            } else {
                value = 0
            }

            sum += value * weight
        }

        return String(sum % 10)
    }

    static func formatDateForMRZ(_ dateString: String) -> String {
        let cleanDate = dateString.replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")

        if cleanDate.count == 6 {
            return cleanDate
        } else if cleanDate.count == 8 {
            let prefix2 = cleanDate.prefix(2)
            // If starts with 19 or 20, it's YYYYMMDD
            if prefix2 == "19" || prefix2 == "20" {
                let year = String(cleanDate.prefix(4).suffix(2))
                let month = String(cleanDate.dropFirst(4).prefix(2))
                let day = String(cleanDate.suffix(2))
                return year + month + day
            } else {
                // Assume DDMMYYYY
                let day = String(cleanDate.prefix(2))
                let month = String(cleanDate.dropFirst(2).prefix(2))
                let year = String(cleanDate.suffix(4).suffix(2))
                return year + month + day
            }
        }

        return cleanDate
    }
}