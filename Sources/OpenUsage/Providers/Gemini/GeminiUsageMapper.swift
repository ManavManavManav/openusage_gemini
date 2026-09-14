import Foundation

enum GeminiUsageMapper {
    static func map(_ data: Data) -> [MetricLine] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let buckets = root["buckets"] as? [[String: Any]] else { return [] }
        return buckets.compactMap { bucket in
            let id = ((bucket["bucketId"] as? String) ?? (bucket["modelId"] as? String) ?? "").lowercased()
            let window = ((bucket["window"] as? String) ?? (bucket["period"] as? String) ?? "").lowercased()
            let isWeekly = id.contains("weekly") || id.contains("7d") || window.contains("week") || window.contains("7d")
            let isSession = id.contains("session") || id.contains("5h") || window.contains("5h")
            guard isSession || isWeekly, let fraction = bucket["remainingFraction"] as? NSNumber else { return nil }
            let reset = (bucket["resetTime"] as? String).flatMap { OpenUsageISO8601.date(from: $0) }
            return MetricLine.progress(label: isWeekly ? "Weekly" : "Session", used: (1 - max(0, min(1, fraction.doubleValue))) * 100, limit: 100, format: .percent, resetsAt: reset, periodDurationMs: nil)
        }
    }
}
