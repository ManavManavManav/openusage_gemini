import Foundation

enum GeminiUsageMapper {
    enum Error: LocalizedError, CategorizedError { case noRecognizedBuckets
        var errorDescription: String? { "Gemini returned no recognized personal quota windows." }
        var errorCategory: ErrorCategory { .decoding }
    }
    // Mirrors the installed CLI bundle ModelQuotaDisplay in interactiveCli-RIVGDZH4.js: buckets are filtered by modelId/remainingFraction and grouped by model tier, retaining the lowest remaining fraction and resetTime.
    static func map(_ data: Data) throws -> [MetricLine] {
        if let summary = AntigravityUsageMapper.parseQuotaSummary(data), !summary.isEmpty { return summary }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let buckets = root["buckets"] as? [[String: Any]] else { throw Error.noRecognizedBuckets }
        var grouped: [String: (Double, Date?)] = [:]
        for bucket in buckets {
            guard let model = (bucket["modelId"] as? String)?.nilIfEmpty, let fraction = (bucket["remainingFraction"] as? NSNumber)?.doubleValue else { continue }
            let lower = model.lowercased(); let label = lower.contains("flash") ? "Flash" : (lower.contains("pro") ? "Pro" : model)
            let reset = (bucket["resetTime"] as? String).flatMap { OpenUsageISO8601.date(from: $0) }
            if grouped[label] == nil || fraction < grouped[label]!.0 { grouped[label] = (fraction, reset) }
        }
        guard !grouped.isEmpty else { AppLog.warn(LogTag.plugin("gemini"), "quota response skipped all bucket identifiers"); throw Error.noRecognizedBuckets }
        return grouped.sorted { $0.key < $1.key }.map { label, value in .progress(label: label, used: (1 - max(0, min(1, value.0))) * 100, limit: 100, format: .percent, resetsAt: value.1, periodDurationMs: nil) }
    }
}
