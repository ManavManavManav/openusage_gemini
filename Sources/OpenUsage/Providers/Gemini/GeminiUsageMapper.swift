import Foundation

enum GeminiUsageMapper {
    enum Error: LocalizedError, CategorizedError { case noRecognizedBuckets
        var errorDescription: String? { "Gemini returned no recognized personal quota windows." }
        var errorCategory: ErrorCategory { .decoding }
    }
    static func map(_ data: Data) throws -> [MetricLine] {
        if let summary = AntigravityUsageMapper.parseQuotaSummary(data), !summary.isEmpty { return summary.map { line in
            switch line { case let .progress(label, used, limit, format, reset, _, color): return .progress(label: label, used: used, limit: limit, format: format, resetsAt: reset, periodDurationMs: nil, colorHex: color); default: return line }
        } }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let buckets = root["buckets"] as? [[String: Any]] else { throw Error.noRecognizedBuckets }
        let lines = buckets.compactMap { bucket -> MetricLine? in
            let id = ((bucket["bucketId"] as? String) ?? "").lowercased()
            guard id == "gemini-5h" || id == "gemini-weekly" else { return nil }
            guard let fraction = bucket["remainingFraction"] as? NSNumber else { return nil }
            let reset = (bucket["resetTime"] as? String).flatMap { OpenUsageISO8601.date(from: $0) }
            return .progress(label: id == "gemini-weekly" ? "Weekly" : "Session", used: (1 - max(0, min(1, fraction.doubleValue))) * 100, limit: 100, format: .percent, resetsAt: reset, periodDurationMs: nil)
        }
        guard !lines.isEmpty else { AppLog.warn(LogTag.plugin("gemini"), "quota response skipped all bucket identifiers"); throw Error.noRecognizedBuckets }
        return lines
    }
}
