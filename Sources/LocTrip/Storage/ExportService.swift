import Foundation
import AppKit
import UniformTypeIdentifiers

public enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown = "Markdown (.md)"
    case plainText = "Plain Text (.txt)"
    case srt = "Subtitles (.srt)"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .srt: return "srt"
        }
    }
}

public final class ExportService: @unchecked Sendable {
    public static let shared = ExportService()

    private init() {}

    /// Formats a meeting session as clean GitHub-flavored Markdown
    public func generateMarkdown(session: MeetingSession) -> String {
        var md = "# 🎙️ \(session.title)\n\n"
        md += "- **Tanggal / Date**: \(session.formattedDate)\n"
        md += "- **Durasi / Duration**: \(session.formattedDuration)\n"
        md += "- **Aplikasi Sumber / Audio Source**: \(session.targetAppName)\n"
        md += "- **Mode Bahasa / Language**: \(session.languageMode.uppercased())\n"
        md += "- **Total Kata / Word Count**: \(session.totalWordCount) kata\n"
        md += "- **Total Segmen / Segments**: \(session.segments.count)\n\n"

        if let summary = session.summary {
            md += "## 📋 Ringkasan Eksekutif / Executive Summary\n"
            md += "\(summary.executiveSummary)\n\n"

            if !summary.keyPoints.isEmpty {
                md += "### 🎯 Poin-Poin Penting / Key Discussion Points\n"
                for point in summary.keyPoints {
                    md += "- \(point)\n"
                }
                md += "\n"
            }

            if !summary.actionItems.isEmpty {
                md += "### ✅ Tindak Lanjut & Action Items\n"
                for item in summary.actionItems {
                    md += "- [ ] \(item)\n"
                }
                md += "\n"
            }

            md += "---\n\n"
        }

        md += "## 💬 Transkrip Lengkap / Full Transcript\n\n"
        if session.segments.isEmpty {
            md += "*(Tidak ada percakapan yang terekam / No speech recorded)*\n"
        } else {
            for segment in session.segments {
                md += "**\(segment.timestampFormatted)** \(segment.text)\n\n"
            }
        }

        md += "\n---\n*Dihasilkan secara lokal oleh LocTrip (100% On-Device AI • Apple Silicon M2)*\n"
        return md
    }

    /// Formats a meeting session as readable Plain Text
    public func generatePlainText(session: MeetingSession) -> String {
        var text = "\(session.title.uppercased())\n"
        text += String(repeating: "=", count: session.title.count) + "\n"
        text += "Date: \(session.formattedDate) | Duration: \(session.formattedDuration)\n"
        text += "Source: \(session.targetAppName) | Words: \(session.totalWordCount)\n\n"

        if let summary = session.summary {
            text += "[EXECUTIVE SUMMARY]\n"
            text += "\(summary.executiveSummary)\n\n"

            if !summary.keyPoints.isEmpty {
                text += "[KEY POINTS]\n"
                for point in summary.keyPoints {
                    text += "• \(point)\n"
                }
                text += "\n"
            }

            if !summary.actionItems.isEmpty {
                text += "[ACTION ITEMS]\n"
                for item in summary.actionItems {
                    text += "[ ] \(item)\n"
                }
                text += "\n"
            }

            text += String(repeating: "-", count: 40) + "\n\n"
        }

        text += "[TRANSCRIPT]\n"
        for segment in session.segments {
            text += "\(segment.timestampFormatted) \(segment.text)\n"
        }

        return text
    }

    /// Formats a meeting session into standard SubRip Subtitle format (.srt)
    public func generateSRT(session: MeetingSession) -> String {
        var srt = ""
        for (index, segment) in session.segments.enumerated() {
            let itemIndex = index + 1
            let startTime = formatSRTTime(seconds: Double(segment.start))
            let endTime = formatSRTTime(seconds: Double(max(segment.end, segment.start + 1.0)))

            srt += "\(itemIndex)\n"
            srt += "\(startTime) --> \(endTime)\n"
            srt += "\(segment.text)\n\n"
        }
        return srt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Helper to format seconds to SRT timestamp: 00:00:00,000
    private func formatSRTTime(seconds: Double) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1.0)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hrs, mins, secs, millis)
    }

    /// Copies text content to macOS clipboard
    @MainActor
    public func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Shows native macOS Save Panel to export content to user's desired file location
    @MainActor
    public func exportToFile(content: String, defaultFilename: String, fileExtension: String) -> URL? {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = "\(defaultFilename).\(fileExtension)"

        if let utType = UTType(filenameExtension: fileExtension) {
            savePanel.allowedContentTypes = [utType]
        }

        let response = savePanel.runModal()
        guard response == .OK, let targetURL = savePanel.url else {
            return nil
        }

        do {
            try content.write(to: targetURL, atomically: true, encoding: .utf8)
            return targetURL
        } catch {
            print("[ExportService] Error saving file to \(targetURL): \(error)")
            return nil
        }
    }
}
