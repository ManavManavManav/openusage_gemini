import XCTest
@testable import OpenUsage

final class GeminiAuthStoreTests: XCTestCase {
    func testParsesOAuthCredentialsAndAuthType() throws {
        let files = FakeFiles([
            "~/.gemini/oauth_creds.json": #"{"access_token":"access","refresh_token":"refresh"}"#,
            "~/.gemini/settings.json": #"{"authType":"oauth-personal"}"#
        ])
        let credentials = try GeminiAuthStore(files: files, environment: [:]).loadCredentials()
        XCTAssertEqual(credentials, GeminiCredentials(accessToken: "access", refreshToken: "refresh", authType: "oauth-personal", expiresAt: nil))
    }

    func testHasLocalCredentialsRecognizesAPIKeyWithoutTreatingItAsOAuth() {
        let store = GeminiAuthStore(files: FakeFiles(), environment: ["GEMINI_API_KEY": "key"])
        XCTAssertFalse(store.hasLocalCredentials())
        XCTAssertNil(try? store.loadCredentials())
    }
}

final class GeminiUsageMapperTests: XCTestCase {
    func testMapsBucketsAndResetTimesAndAllowsMissingWeekly() {
        let json = #"{"response":{"groups":[{"buckets":[{"bucketId":"gemini-5h","remainingFraction":0.25,"resetTime":"2030-01-01T00:00:00Z"}]}]}}"#
        let lines = try! GeminiUsageMapper.map(Data(json.utf8))
        XCTAssertEqual(lines.count, 1)
        guard case let .progress(label, used, limit, _, reset, _, _) = lines[0] else { return XCTFail("expected progress") }
        XCTAssertEqual(label, "Session"); XCTAssertEqual(used, 75); XCTAssertEqual(limit, 100)
        XCTAssertNotNil(reset)
    }
}

final class GeminiUsageClientTests: XCTestCase {
    func testFallsBackToSecondBaseAfterFirstFailure() async throws {
        let http = GeminiRoutingHTTP { request in
            if request.url.host == "daily-cloudcode-pa.googleapis.com" { return HTTPResponse(statusCode: 503, headers: [:], body: Data()) }
            if request.url.path.contains("loadCodeAssist") { return HTTPResponse(statusCode: 200, headers: [:], body: Data(#"{"currentTier":{"name":"Free"}}"#.utf8)) }
            return HTTPResponse(statusCode: 200, headers: [:], body: Data(#"{"response":{"groups":[{"buckets":[{"bucketId":"gemini-5h","remainingFraction":0.5}]}]}}"#.utf8))
        }
        let result = try await GeminiUsageClient(http: http).fetch(accessToken: "token")
        XCTAssertEqual(result.plan, "Free")
        XCTAssertEqual(result.lines.count, 1)
        XCTAssertTrue(http.requests.contains { $0.url.host == "cloudcode-pa.googleapis.com" })
    }

    func testAuthResponsesProduceUnavailableWithoutLeakingToken() async {
        let http = GeminiRoutingHTTP { _ in HTTPResponse(statusCode: 401, headers: [:], body: Data()) }
        do { _ = try await GeminiUsageClient(http: http).fetch(accessToken: "secret") ; XCTFail("expected error") }
        catch let error as GeminiUsageError { XCTAssertEqual(error, .expired) }
        catch { XCTFail("unexpected error: \(error)") }
        XCTAssertFalse(http.requests.contains { String(decoding: $0.body ?? Data(), as: UTF8.self).contains("secret") })
    }
}

@MainActor final class GeminiLayoutTests: XCTestCase {
    func testGeminiDefaultsArePlacedVisibleAndPinned() {
        let provider = GeminiProvider()
        let store = LayoutStore(registry: .from([provider]), defaults: UserDefaults(suiteName: "GeminiLayout.\(UUID())")!, storageKey: "layout")
        XCTAssertEqual(store.placed.map(\.descriptorID), ["gemini.session", "gemini.weekly", "gemini.trend"])
        XCTAssertEqual(store.pinnedMetricIDs, ["gemini.session", "gemini.weekly"])
        XCTAssertFalse(store.expandedMetricIDs.contains("gemini.session")); XCTAssertFalse(store.expandedMetricIDs.contains("gemini.weekly")); XCTAssertFalse(store.expandedMetricIDs.contains("gemini.trend"))
    }
}

private final class GeminiRoutingHTTP: HTTPClient, @unchecked Sendable {
    let handler: @Sendable (HTTPRequest) -> HTTPResponse
    var requests: [HTTPRequest] = []
    init(handler: @escaping @Sendable (HTTPRequest) -> HTTPResponse) { self.handler = handler }
    func send(_ request: HTTPRequest) async throws -> HTTPResponse { requests.append(request); return handler(request) }
}
