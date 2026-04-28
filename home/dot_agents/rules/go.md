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

## Formatter enforcement

`gofmt` and `golangci-lint` run automatically after every `.go` file edit via a PostToolUse hook. Lint output is fed back as a system notification — address it before continuing.

- Never write unused imports: the formatter removes them and the compiler rejects them
- Never write unused variables: golangci-lint flags them immediately
- Don't add speculative imports hoping to use them later — only import what the current code uses
- Run `golangci-lint run ./...` from the module root before declaring Go work complete
- If golangci-lint output appears after an edit, fix all issues before moving on
