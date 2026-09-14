import Foundation

@MainActor final class GeminiProvider: ProviderRuntime {
 let provider = Provider(id: "gemini", displayName: "Gemini", icon: .providerMark("gemini"))
 let authStore: GeminiAuthStore; let usageClient: GeminiUsageClient
 init(authStore: GeminiAuthStore = GeminiAuthStore(), usageClient: GeminiUsageClient = GeminiUsageClient()) { self.authStore = authStore; self.usageClient = usageClient }
 var widgetDescriptors: [WidgetDescriptor] { [.percent(id: "gemini.session", provider: provider, title: "Session", metricLabel: "Session").exportingLimit("session", unit: "percent"), .percent(id: "gemini.weekly", provider: provider, title: "Weekly", metricLabel: "Weekly").exportingLimit("weekly", unit: "percent"), .usageTrend(provider: provider)] }
 func hasLocalCredentials() async -> Bool { await loadOffMainActor { [authStore] in authStore.hasLocalCredentials() } }
 func refresh() async -> ProviderSnapshot {
  do { guard let creds = try authStore.loadCredentials() else { throw GeminiUsageError.missingLogin }; let result = try await usageClient.fetch(accessToken: creds.accessToken); return .make(provider: provider, plan: result.plan, lines: result.lines, refreshedAt: Date()) }
  catch { return .error(provider: provider, error: error) }
 }
}
