import Foundation

/// Converts Hangul syllables to Revised Romanization.
///
/// Apple's `toLatin` transform uses a different scheme (사랑 → salang,
/// 한국 → hangug) and mishandles syllable boundaries. This converter applies
/// the standard rules, including liaison of a final consonant into a following
/// vowel-initial syllable (사랑 → sa-rang).
enum KoreanRomanizer {
    private static let initials = [
        "g", "kk", "n", "d", "tt", "r", "m", "b", "pp",
        "s", "ss", "", "j", "jj", "ch", "k", "t", "p", "h"
    ]

    private static let medials = [
        "a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae",
        "oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i"
    ]

    private static let finals = [
        "",     // 0  none
        "k",    // 1  ㄱ
        "k",    // 2  ㄲ
        "k",    // 3  ㄳ
        "n",    // 4  ㄴ
        "n",    // 5  ㄵ
        "n",    // 6  ㄶ
        "t",    // 7  ㄷ
        "l",    // 8  ㄹ
        "k",    // 9  ㄺ
        "m",    // 10 ㄻ
        "l",    // 11 ㄼ
        "l",    // 12 ㄽ
        "l",    // 13 ㄾ
        "l",    // 14 ㄿ
        "l",    // 15 ㅀ
        "m",    // 16 ㅁ
        "p",    // 17 ㅂ
        "p",    // 18 ㅄ
        "t",    // 19 ㅅ
        "t",    // 20 ㅆ
        "ng",   // 21 ㅇ
        "t",    // 22 ㅈ
        "t",    // 23 ㅊ
        "k",    // 24 ㅋ
        "t",    // 25 ㅌ
        "p",    // 26 ㅍ
        "t"     // 27 ㅎ
    ]

    /// Finals that move to the next syllable when it begins with a vowel.
    private static let liaisonInitials: [Int: String] = [
        1: "g",   // ㄱ
        4: "n",   // ㄴ
        7: "d",   // ㄷ
        8: "r",   // ㄹ
        17: "b",  // ㅂ
        19: "s",  // ㅅ
        20: "s",  // ㅆ
        22: "j",  // ㅈ
        23: "ch", // ㅊ
        24: "k",  // ㅋ
        25: "t",  // ㅌ
        26: "p",  // ㅍ
        27: ""    // ㅎ is silent before a vowel
    ]

    static func romanize(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var result = ""
        var index = 0

        while index < scalars.count {
            let value = scalars[index].value
            guard (0xAC00...0xD7A3).contains(value) else {
                result.unicodeScalars.append(scalars[index])
                index += 1
                continue
            }

            let syllableIndex = Int(value - 0xAC00)
            var initial = syllableIndex / 588
            let medial = (syllableIndex % 588) / 28
            var final = syllableIndex % 28

            // Liaison: a final consonant is carried into a following syllable
            // that starts with silent ㅇ (a vowel).
            if final != 0,
               let carried = liaisonInitials[final],
               index + 1 < scalars.count,
               let next = Int(exactly: scalars[index + 1].value),
               (0xAC00...0xD7A3).contains(scalars[index + 1].value),
               (next - 0xAC00) / 588 == 11 {
                result += initials[initial]
                result += medials[medial]
                result += carried
                final = 0
                initial = 0
                index += 1
                guard index < scalars.count else { break }
                let carriedSyllable = Int(scalars[index].value - 0xAC00)
                initial = (carriedSyllable / 588) == 11 ? 0 : carriedSyllable / 588
                let carriedMedial = (carriedSyllable % 588) / 28
                let carriedFinal = carriedSyllable % 28
                result += medials[carriedMedial]
                result += finals[carriedFinal]
                index += 1
                continue
            }

            result += initials[initial]
            result += medials[medial]
            result += finals[final]
            index += 1
        }

        return result
    }
}
