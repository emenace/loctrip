import Foundation

public enum TranscriptCleaner {
    // Matches any Whisper special tokens e.g. <|startoftranscript|>, <|id|>, <|0.00|>, </1.50|>, <|endoftext|>
    private static let whisperTokenRegex = try? NSRegularExpression(
        pattern: "<\\/?[\\|]?[^>]+[\\|]?>|<[^>]+>",
        options: [.caseInsensitive]
    )

    // Matches any raw timestamp artifacts e.g. [00:00 - 00:03] or [00:00]
    private static let timestampArtifactRegex = try? NSRegularExpression(
        pattern: "\\[[0-9]{1,2}:[0-9]{2}(?:\\s*-\\s*[0-9]{1,2}:[0-9]{2})?\\]",
        options: []
    )

    /// Cleans raw Whisper output text, removing all special tokens, inline timestamps, and formatting artifacts.
    public static func clean(_ raw: String) -> String {
        var text = raw

        // 1. Remove all Whisper token tags: <|...|>, </...|>, <...>
        if let regex = whisperTokenRegex {
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }

        // 2. Remove any bracket timestamp artifacts: [00:00 - 00:03]
        if let regex = timestampArtifactRegex {
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }

        // 3. Remove lingering stray delimiters like "|>", "<|", "</"
        text = text.replacingOccurrences(of: "|>", with: "")
        text = text.replacingOccurrences(of: "<|", with: "")
        text = text.replacingOccurrences(of: "</", with: "")

        // 4. Normalize multiple spaces into single space and trim
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 5. Clean leading punctuation artifacts (e.g. leading commas, hyphens, dots)
        while let first = text.first, [",", "-", ".", ":", ";", ">", "<"].contains(first) {
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespaces)
        }

        // 6. Ensure first letter is capitalized for readability
        if let first = text.first, first.isLetter {
            text = first.uppercased() + text.dropFirst()
        }

        return text
    }

    /// Smart-merges a new live segment into the existing transcript list,
    /// avoiding duplicates caused by sliding window overlap.
    public static func appendOrMerge(
        newSegment: TranscriptSegment,
        into currentSegments: inout [TranscriptSegment]
    ) {
        let cleanedText = clean(newSegment.text)
        guard !cleanedText.isEmpty else { return }

        // If list is empty, simply append
        guard let last = currentSegments.last else {
            let cleanedSegment = TranscriptSegment(
                id: newSegment.id,
                start: newSegment.start,
                end: newSegment.end,
                text: cleanedText,
                language: newSegment.language
            )
            currentSegments.append(cleanedSegment)
            return
        }

        let lastText = last.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastLower = lastText.lowercased()
        let newLower = cleanedText.lowercased()

        // 1. Exact duplicate: skip
        if lastLower == newLower {
            return
        }

        // 2. Substring containment:
        // If the new text is already completely contained in the last segment, skip
        if lastLower.contains(newLower) && newLower.count < lastLower.count {
            return
        }

        // If the new text expands and contains the previous segment (e.g. "Halo semuanya" -> "Halo semuanya, selamat pagi"),
        // update the last segment in place!
        if newLower.hasPrefix(lastLower) || (newLower.contains(lastLower) && lastLower.count > 6) {
            currentSegments[currentSegments.count - 1] = TranscriptSegment(
                id: last.id,
                start: last.start,
                end: newSegment.end,
                text: cleanedText,
                language: newSegment.language ?? last.language
            )
            return
        }

        // 3. Word-level overlap check:
        // Check if the end of `last` overlaps with the start of `new`
        let lastWords = lastText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let newWords = cleanedText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        var maxOverlap = 0
        let checkCount = min(5, min(lastWords.count, newWords.count))

        for k in stride(from: checkCount, through: 1, by: -1) {
            let lastSuffix = lastWords.suffix(k).joined(separator: " ").lowercased()
            let newPrefix = newWords.prefix(k).joined(separator: " ").lowercased()

            if lastSuffix == newPrefix {
                maxOverlap = k
                break
            }
        }

        if maxOverlap > 0 && maxOverlap < newWords.count {
            // Strip the overlapping words from the start of new
            let nonOverlappingWords = newWords.dropFirst(maxOverlap).joined(separator: " ")
            let sanitizedContinuation = clean(nonOverlappingWords)

            if !sanitizedContinuation.isEmpty {
                let stitchedSegment = TranscriptSegment(
                    id: newSegment.id,
                    start: newSegment.start,
                    end: newSegment.end,
                    text: sanitizedContinuation,
                    language: newSegment.language
                )
                currentSegments.append(stitchedSegment)
            }
            return
        }

        // 4. No overlap: append new clean segment
        let cleanSegment = TranscriptSegment(
            id: newSegment.id,
            start: newSegment.start,
            end: newSegment.end,
            text: cleanedText,
            language: newSegment.language
        )
        currentSegments.append(cleanSegment)
    }
}
