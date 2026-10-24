# Evaluation dispatch record

Estimates use the PLAN.md rates; reservations include headroom and are retained after failures. No invoice verification.

```json
{
  "requests": [
    {
      "sequence": 1,
      "provider": "gemini",
      "model": "gemini-2.5-flash-lite",
      "profile": "beginner",
      "startedAt": "2026-10-22T14:21:17.132Z",
      "reservedInr": 0.5625,
      "status": "provider_rejected",
      "httpStatus": 404,
      "elapsedMs": 556
    },
    {
      "sequence": 2,
      "provider": "openai",
      "model": "gpt-6-luna",
      "profile": "beginner",
      "startedAt": "2026-10-22T14:21:33.293Z",
      "reservedInr": 0.6249999999999999,
      "status": "received",
      "httpStatus": 200,
      "usage": {
        "inputTokens": 749,
        "outputTokens": 3234
      },
      "estimatedInr": 0.1607305,
      "finishStatus": "completed",
      "jsonParsed": true,
      "artifact": "sample-2-openai-beginner.md",
      "elapsedMs": 27170
    },
    {
      "sequence": 3,
      "provider": "openai",
      "model": "gpt-6-luna",
      "profile": "advanced",
      "startedAt": "2026-10-22T14:22:38.328Z",
      "reservedInr": 0.6249999999999999,
      "status": "received",
      "httpStatus": 200,
      "usage": {
        "inputTokens": 753,
        "outputTokens": 3203
      },
      "estimatedInr": 0.159296,
      "finishStatus": "completed",
      "jsonParsed": true,
      "artifact": "sample-3-openai-advanced.md",
      "elapsedMs": 27525
    },
    {
      "sequence": 4,
      "provider": "gemini35",
      "model": "gemini-3.5-flash-lite",
      "profile": "beginner",
      "startedAt": "2026-10-22T14:29:09.676Z",
      "reservedInr": 2.4999999999999996,
      "status": "provider_rejected",
      "httpStatus": 400,
      "elapsedMs": 1416
    },
    {
      "sequence": 5,
      "provider": "gemini35",
      "model": "gemini-3.5-flash-lite",
      "profile": "advanced",
      "startedAt": "2026-10-22T14:34:33.259Z",
      "reservedInr": 2.4999999999999996,
      "status": "provider_rejected",
      "httpStatus": 400,
      "elapsedMs": 1459
    },
    {
      "sequence": 6,
      "provider": "openai",
      "model": "gpt-6-luna",
      "profile": "beginner",
      "promptRevision": "v2",
      "startedAt": "2026-10-22T14:35:51.310Z",
      "reservedInr": 0.6249999999999999,
      "status": "received",
      "httpStatus": 200,
      "usage": {
        "inputTokens": 1239,
        "outputTokens": 3277
      },
      "estimatedInr": 0.167428,
      "finishStatus": "completed",
      "jsonParsed": true,
      "artifact": "sample-6-openai-beginner.md",
      "elapsedMs": 26581
    }
  ]
}
```
