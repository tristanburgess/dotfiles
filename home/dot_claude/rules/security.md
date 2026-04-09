---
globs: "**"
description: Security baseline for all code
---

- Never hardcode secrets, tokens, passwords, or API keys — use environment variables or a secret manager
- Validate all external input at system boundaries (user input, API responses, file contents)
- Use parameterized queries for SQL — never string-concatenate user input into queries
- Sanitize output to prevent XSS — escape HTML/JS in any user-facing rendering
- Don't log secrets, tokens, or PII — redact sensitive fields in structured logging
- Prefer short-lived, scoped tokens over long-lived credentials
