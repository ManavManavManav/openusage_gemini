# Gemini

OpenUsage monitors Gemini CLI Google login Code Assist quotas. It reads the CLI OAuth file locally and calls Google's `loadCodeAssist` and `retrieveUserQuota` endpoints using a refreshed Google token when needed. API-key and Vertex configurations are detected for provider enablement, but do not produce invented personal caps.

OpenUsage never writes to Gemini CLI credentials and does not currently estimate local Gemini CLI history because no stable session schema is available.
