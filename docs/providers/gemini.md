# Gemini

OpenUsage monitors Gemini CLI Google login Code Assist quotas. It reads the CLI OAuth file locally and calls Google's `loadCodeAssist` and `retrieveUserQuota` endpoints using a refreshed Google token when needed. API-key and Vertex configurations are intentionally not enabled because they do not expose personal Code Assist limits.

OpenUsage never writes to Gemini CLI credentials and does not currently estimate local Gemini CLI history because no stable session schema is available.
