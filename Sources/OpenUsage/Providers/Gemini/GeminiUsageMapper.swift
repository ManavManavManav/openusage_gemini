import Foundation

enum GeminiUsageMapper {
    static func map(_ data: Data) -> [MetricLine] { AntigravityUsageMapper.parseQuotaBuckets(data).enumerated().map { i, c in .progress(label: i == 0 ? "Session" : "Weekly", used: (1 - max(0, min(1, c.remainingFraction))) * 100, limit: 100, format: .percent, resetsAt: c.resetTime, periodDurationMs: i == 0 ? MetricPeriod.sessionMs : MetricPeriod.weekMs) } }
}
