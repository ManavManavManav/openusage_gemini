import Foundation

struct GeminiUsageResult: Sendable { let plan: String?; let lines: [MetricLine]; let token: String }

enum GeminiUsageError: LocalizedError, CategorizedError { case missingLogin, expired, unavailable
 var errorDescription: String? { switch self { case .missingLogin: "Sign in to Gemini CLI with Google to view Code Assist usage."; case .expired: "Gemini Google login has expired. Sign in again in Gemini CLI."; case .unavailable: "Gemini usage is temporarily unavailable." } }
 var errorCategory: ErrorCategory { switch self { case .missingLogin: .notLoggedIn; case .expired: .authExpired; case .unavailable: .network } }
}

struct GeminiUsageClient: Sendable {
    var http: HTTPClient = URLSessionHTTPClient()
    static let bases = ["https://daily-cloudcode-pa.googleapis.com", "https://cloudcode-pa.googleapis.com"]

    func refreshToken(_ refresh: String) async -> TokenRefreshOutcome { await AntigravityUsageClient(http: http).refreshGoogleToken(refresh) }

    func fetch(accessToken: String) async throws -> (plan: String?, lines: [MetricLine]) {
        let body = ["metadata": ["ideType": "GEMINI_CLI", "platform": "DARWIN"]]
        let payload = try JSONSerialization.data(withJSONObject: body)
        for base in Self.bases {
            guard let loadURL = URL(string: base + "/v1internal:loadCodeAssist") else { continue }
            let req = HTTPRequest(method: "POST", url: loadURL, headers: ["Authorization": "Bearer \(accessToken)", "Content-Type": "application/json", "Accept": "application/json"], body: payload, timeout: 15)
            guard let load = try? await http.send(req), (200..<300).contains(load.statusCode) else { continue }
            let plan = AntigravityUsageMapper.parseLoadCodeAssistPlan(load.body)
            guard let quotaURL = URL(string: base + "/v1internal:retrieveUserQuota") else { continue }
            let quotaReq = HTTPRequest(method: "POST", url: quotaURL, headers: req.headers, body: Data("{}".utf8), timeout: 15)
            guard let quota = try? await http.send(quotaReq), (200..<300).contains(quota.statusCode) else { continue }
            let configs = AntigravityUsageMapper.parseQuotaBuckets(quota.body)
            let lines = configs.enumerated().map { i, c in MetricLine.progress(label: i == 0 ? "Session" : "Weekly", used: (1 - max(0, min(1, c.remainingFraction))) * 100, limit: 100, format: .percent, resetsAt: c.resetTime, periodDurationMs: i == 0 ? MetricPeriod.sessionMs : MetricPeriod.weekMs) }
            return (plan, lines)
        }
        throw GeminiUsageError.unavailable
    }
}
