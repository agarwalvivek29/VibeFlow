import Foundation

struct FillerRemover {
    // Pre-compiled regex patterns for filler words and phrases.
    // Order matters: longer phrases before shorter words to avoid partial matches.
    private static let fillerPatterns: [NSRegularExpression] = {
        let rawPatterns = [
            #"\b[Yy]ou know\b[,]?\s*"#,
            #"\b[Ii] mean\b[,]?\s*"#,
            #"\b[Ss]ort of\b[,]?\s*"#,
            #"\b[Kk]ind of\b[,]?\s*"#,
            #"\b[Bb]asically\b[,]?\s*"#,
            #"\b[Aa]ctually\b[,]?\s*"#,
            #"\b[Ll]iterally\b[,]?\s*"#,
            #"\b[Ll]ike\b[,]?\s*"#,
            #"\b[Uu]mm?\b[,]?\s*"#,
            #"\b[Uu]hh?\b[,]?\s*"#,
        ]
        return rawPatterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private static let commaCleanupRegex: NSRegularExpression? = try? NSRegularExpression(pattern: #",\s*,"#)
    private static let doubleSpaceRegex: NSRegularExpression? = try? NSRegularExpression(pattern: #" {2,}"#)

    static func removeFiller(from text: String) -> String {
        var result = text

        for regex in fillerPatterns {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        if let commaCleanup = commaCleanupRegex {
            result = commaCleanup.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ","
            )
        }

        if let doubleSpace = doubleSpaceRegex {
            result = doubleSpace.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
        }

        return result.trimmingCharacters(in: .whitespaces)
    }
}
