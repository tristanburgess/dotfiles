---
globs: "**"
description: Check existing solutions before writing new code
---

Before writing a new utility, abstraction, or helper:
1. Check if it already exists in this repo (grep for similar function names)
2. Check if a well-maintained package/module solves it (standard library first, then popular packages)
3. If an existing solution covers 80%+ of the need, extend or wrap it — don't rebuild from scratch
