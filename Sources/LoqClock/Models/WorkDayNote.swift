import Foundation

enum WorkDayNote {
    static let maxCountedCharacters = 140

    static func sanitized(_ rawValue: String?) -> String? {
        guard let rawValue else {
            return nil
        }

        let oneLineValue = rawValue
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        var sanitized = ""
        var countedCharacters = 0

        for character in oneLineValue {
            if countsTowardLimit(character) {
                guard countedCharacters < maxCountedCharacters else {
                    break
                }

                countedCharacters += 1
            }

            sanitized.append(character)
        }

        let trimmedValue = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func countsTowardLimit(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }
    }
}
