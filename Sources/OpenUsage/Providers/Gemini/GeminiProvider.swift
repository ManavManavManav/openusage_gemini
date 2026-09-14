import Foundation

@MainActor final class GeminiProvider: ProviderRuntime {
 let provider = Provider(id: "gemini", displayName: "Gemini", icon: .providerMark("gemini"))
 let authStore: GeminiAuthStore; let usageClient: GeminiUsageClient
 init(authStore: GeminiAuthStore = GeminiAuthStore(), usageClient: GeminiUsageClient = GeminiUsageClient()) { self.authStore = authStore; self.usageClient = usageClient }
 var widgetDescriptors: [WidgetDescriptor] { [.percent(id: "gemini.session", provider: provider, title: "Session", metricLabel: "Session").exportingLimit("session", unit: "percent"), .percent(id: "gemini.weekly", provider: provider, title: "Weekly", metricLabel: "Weekly").exportingLimit("weekly", unit: "percent"), .usageTrend(provider: provider)] }
 func hasLocalCredentials() async -> Bool { await loadOffMainActor { [authStore] in authStore.hasLocalCredentials() } }
 func refresh() async -> ProviderSnapshot {
  do {
   guard let creds = try authStore.loadCredentials() else { throw authStore.settingsAuthType() == nil ? GeminiUsageError.missingLogin : GeminiUsageError.unsupportedAuthMode }
   var token = creds.accessToken
   if let expiry = creds.expiresAt, expiry.timeIntervalSinceNow < 60, let refresh = creds.refreshToken {
    if case let .refreshed(accessToken, _) = await usageClient.refreshToken(refresh) { token = accessToken } else { throw GeminiUsageError.expired }
   }
   let result = try await usageClient.fetch(accessToken: token)
   return .make(provider: provider, plan: result.plan, lines: result.lines, refreshedAt: Date())
  } catch { AppLog.error(LogTag.plugin("gemini"), "refresh failed (\((error as? GeminiUsageError)?.errorCategory.rawValue ?? "other"))"); return .error(provider: provider, error: error) }
 }
}
