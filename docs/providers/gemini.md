# Gemini

OpenUsage monitors Gemini CLI Google login Code Assist quotas. It reads the CLI OAuth file locally and calls Google's `loadCodeAssist` and `retrieveUserQuota` endpoints using a refreshed Google token when needed. API-key and Vertex configurations are intentionally not enabled because they do not expose personal Code Assist limits.

OpenUsage never writes to Gemini CLI credentials and does not currently estimate local Gemini CLI history because no stable session schema is available.

The quota UI follows Gemini CLI's per-model buckets: primary metrics are `gemini.pro` and `gemini.flash`, grouped by model tier with the lowest remaining fraction. This mirrors `ModelQuotaDisplay` in the installed `interactiveCli-RIVGDZH4.js` bundle. Summary pool IDs are only a secondary compatibility path.
