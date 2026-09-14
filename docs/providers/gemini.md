# Gemini

OpenUsage monitors Gemini CLI Google login Code Assist quotas. It reads the CLI OAuth file locally and calls Google's `loadCodeAssist` and `retrieveUserQuota` endpoints using a refreshed Google token when needed. API-key and Vertex configurations are intentionally not enabled because they do not expose personal Code Assist limits.

OpenUsage never writes to Gemini CLI credentials and does not currently estimate local Gemini CLI history because no stable session schema is available.

The quota UI follows Gemini CLI's per-model buckets: primary metrics are `gemini.pro` and `gemini.flash`, grouped by model tier with the lowest remaining fraction. This mirrors `ModelQuotaDisplay` in the installed `interactiveCli-RIVGDZH4.js` bundle. Summary pool IDs are only a secondary compatibility path.

## Testing

1. Install the Gemini CLI, run `gemini` once, and sign in with Google. This finishes Code Assist setup and gives the account a quota project.
2. Quit any running OpenUsage instance.
3. From the repository, run `swift build`, then launch OpenUsage. The app needs a full rebuild and restart; it has no hot reload.
4. Confirm Gemini appears after Devin. Pro and Flash should be visible and pinned in the menu bar, and Trend should be visible. Percentages and reset times should roughly match the Gemini CLI quota display (for example, `/stats`).
5. Check negative cases: no `~/.gemini` login does not auto-enable Gemini; an un onboarded account shows the setup message; API-key-only and Vertex setups are not enabled; expired or revoked login shows the re-login message.
6. If an error occurs, inspect `~/Library/Logs/OpenUsage/OpenUsage.log` (see [Logging](../logging.md)).

For automated checks, run `swift test --filter GeminiProviderTests`, then the full `swift test`.
