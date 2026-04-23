---
name: sources
description: Citation rules for all claims. Load before making any factual claim, assumption, or inference.
---

# Sources

Every claim needs a verifiable source. No exceptions.

- **Code**: Full GitHub URL with line anchors (`https://github.com/org/repo/blob/main/path/file.ts#L10-L20`). Get org/repo from `jj git remote list` or repo remote.
- **Tool/platform behavior** (GHA, Docker, AWS, Go, etc.): **Use WebSearch to find official docs** and link them. Do not rely on training knowledge for how a tool works — find the doc page that says it. Example: "GHA composite inputs are strings" needs a link to the GHA metadata syntax docs.
- **Docs/external**: Link official docs, RFCs, or authoritative sources. Prefer primary over secondary.
- **Inference**: If a claim is your own reasoning (not directly from a source), label it as such — e.g., "Based on [linked code], I infer X because Y."
- **No source available**: Say so explicitly — never state as fact without a link or caveat.
