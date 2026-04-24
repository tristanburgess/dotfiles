---
globs: "*.go,go.mod,go.sum"
description: Go conventions
---

- Use table-driven tests with `t.Run` subtests
- Wrap errors with `fmt.Errorf("context: %w", err)` — never discard errors silently
- Use `errors.Is` / `errors.As` for error checking, not string matching
- Prefer `context.Context` as first parameter for functions that do I/O
- Run `go vet` and check for lint issues before considering code complete
- Use named return values only when they improve readability of the godoc
