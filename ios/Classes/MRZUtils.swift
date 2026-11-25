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

    static func formatMRZDate(_ dateString: String, isExpiry: Bool = false) -> String {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "N/A" {
            return dateString
        }

        // If already formatted as YYYY/MM/DD or YYYY-MM-DD
        let formattedPattern = "^(\\d{4})[/\\-](\\d{2})[/\\-](\\d{2})$"
        if let regex = try? NSRegularExpression(pattern: formattedPattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            if let r1 = Range(match.range(at: 1), in: trimmed),
               let r2 = Range(match.range(at: 2), in: trimmed),
               let r3 = Range(match.range(at: 3), in: trimmed) {
                return "\(trimmed[r1])/\(trimmed[r2])/\(trimmed[r3])"
            }
        }

        let digits = trimmed.filter { $0.isNumber }
        if digits.count == 8 {
            let prefix = String(digits.prefix(2))
            if prefix == "19" || prefix == "20" {
                let y = digits.prefix(4)
                let m = digits.dropFirst(4).prefix(2)
                let d = digits.dropFirst(6).prefix(2)
                return "\(y)/\(m)/\(d)"
            }
        }

        guard digits.count >= 6 else { return dateString }

        let yearTwoDigitsStr = String(digits.prefix(2))
        guard let yearTwoDigits = Int(yearTwoDigitsStr) else { return dateString }

        let currentYear = Calendar.current.component(.year, from: Date()) % 100
        let century: Int
        if isExpiry {
            century = (yearTwoDigits <= currentYear + 50) ? 2000 : 1900
        } else {
            century = (yearTwoDigits <= currentYear) ? 2000 : 1900
        }

        let fullYear = century + yearTwoDigits
        let month = digits.dropFirst(2).prefix(2)
        let day = digits.dropFirst(4).prefix(2)

        return "\(fullYear)/\(month)/\(day)"
    }
}