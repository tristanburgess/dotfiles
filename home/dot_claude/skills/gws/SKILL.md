---
name: gws
description: Google Workspace CLI patterns — Docs editing, Drive exports, and common pitfalls. Load before any gws operation.
---

# Google Workspace (gws) CLI

## Core Commands

```
gws docs documents get --params '{"documentId": "ID", "includeTabsContent": true}'
gws docs documents batchUpdate --params '{"documentId": "ID"}' --json '{"requests": [...]}'
gws drive files export --params '{"fileId": "ID", "mimeType": "text/plain"}' -o file.txt
```

## Golden Rule: Always Read Before Writing

Never craft `replaceAllText` strings from a plain-text export. The export diverges from
the actual API text (smart quotes, em dashes, revised content). Always:

1. Fetch the live document via `documents get` with `includeTabsContent: true`
2. Extract the actual text from the JSON response
3. Use that exact text in `replaceAllText` search strings

```python
# Extract text from a specific tab
import json
doc = json.loads(raw_response)
for tab in doc['tabs']:
    if tab['tabProperties']['tabId'] == TARGET_TAB:
        for elem in tab['documentTab']['body']['content']:
            if 'paragraph' in elem:
                for pe in elem['paragraph']['elements']:
                    if 'textRun' in pe:
                        text = pe['textRun']['content']
```

## Tab Scoping

Google Docs can have multiple tabs. Always scope operations to a specific tab:

```python
# Find tab IDs
for tab in doc['tabs']:
    props = tab['tabProperties']
    print(f"{props['tabId']}: {props.get('title', '(untitled)')}")
    for child in tab.get('childTabs', []):
        # nested tabs exist

# Scope replaceAllText to a tab
{"replaceAllText": {
    "containsText": {"text": "old", "matchCase": True},
    "replaceText": "new",
    "tabsCriteria": {"tabIds": ["t.abc123"]},
}}

# Scope insertText to a tab
{"insertText": {
    "location": {"segmentId": "", "index": 1234, "tabId": "t.abc123"},
    "text": "new text",
}}
```

## Text Replacement Patterns

### replaceAllText

Replaces ALL occurrences of the search string in the scoped tab(s). Cannot do
"first occurrence only." If you need first-only (e.g., acronym expansion), ensure the
search string is unique in context.

**Ordering hazard:** If replacement A modifies text that replacement B needs to match,
B will fail silently (0 occurrences changed). Solutions:
- Use post-replacement-A text as B's search string
- Chain A and B in separate batchUpdate calls
- Check `occurrencesChanged` in the response for each replacement

**Unicode hazard:** Google Docs uses smart quotes (`\u2018`, `\u2019`), em dashes
(`\u2014`), and curly apostrophes. The API does exact matching. Always extract the
actual text from the API response rather than typing it manually.

### insertText

Inserts text at a character index. Does NOT carry formatting.

**Index shift rule:** When inserting at multiple positions in one batchUpdate, process
from bottom to top (highest index first). Earlier insertions shift all subsequent
indexes.

**Formatting after insert:** `insertText` creates NORMAL_TEXT paragraphs. To apply
heading styles, follow up with `updateParagraphStyle`:

```python
{"updateParagraphStyle": {
    "range": {"segmentId": "", "startIndex": N, "endIndex": M, "tabId": "t.abc123"},
    "paragraphStyle": {"namedStyleType": "HEADING_1"},
    "fields": "namedStyleType",
}}
```

### Structural Changes (Tables)

Table operations (`insertTableColumn`, `insertTableRow`, `deleteTableColumn`, etc.)
shift all indexes in the document. Always:

1. Apply structural changes first (add/remove rows/columns)
2. Re-fetch the document to get updated indexes
3. Then apply text insertions or style changes

```python
# Insert column before index 1
{"insertTableColumn": {
    "tableCellLocation": {
        "tableStartLocation": {"segmentId": "", "index": TABLE_START, "tabId": "t.abc123"},
        "rowIndex": 0, "columnIndex": 1,
    },
    "insertRight": False,
}}
# Then re-fetch, get new cell indexes, then insertText into each cell
```

## Drive Export CWD Constraint

`gws drive files export -o` resolves paths relative to CWD and rejects paths outside it.
Always export to `/tmp/`:

```bash
cd /tmp && gws drive files export --params '{"fileId": "ID", "mimeType": "text/plain"}' -o doc.txt
cd -  # return to previous dir
```

**Never export into a VCS-managed directory.** Exported files pollute the working copy.

## Batch Update Workflow

For non-trivial doc edits, follow this sequence:

```
1. GET document (includeTabsContent: true)
2. Identify target tab ID
3. Extract actual text from API response
4. Craft replacements against extracted text
5. Apply structural changes (table columns/rows) first
6. Re-fetch if structural changes were made
7. Apply text replacements (replaceAllText)
8. Apply text insertions (insertText, bottom-to-top order)
9. Apply style changes (updateParagraphStyle)
10. Verify: re-fetch and spot-check key sections
```

## Verification

After any batchUpdate, check the response:

```python
resp = json.loads(response_text)
for i, reply in enumerate(resp.get('replies', [])):
    rat = reply.get('replaceAllText', {})
    count = rat.get('occurrencesChanged', 0)
    if count == 0:
        print(f'WARNING: replacement {i} matched nothing')
    if count > 1:
        print(f'NOTE: replacement {i} matched {count} times (expected 1?)')
```

## Common Mistakes

| Mistake | Consequence | Fix |
|---------|-------------|-----|
| Using plain-text export for match strings | 0 matches (unicode mismatch) | Extract text from API JSON |
| Forgetting `tabsCriteria` | Changes apply to ALL tabs | Always scope to target tab |
| Inserting text top-to-bottom | Later indexes are wrong | Insert bottom-to-top |
| `insertText` expecting heading style | New text is NORMAL_TEXT | Follow up with `updateParagraphStyle` |
| Table column add then immediate text insert | Indexes shifted | Re-fetch after structural changes |
| Exporting to repo CWD | VCS snapshots the file | `cd /tmp` first |
| Chained replacements where A changes B's target | B matches 0 | Use post-A text or separate batches |
