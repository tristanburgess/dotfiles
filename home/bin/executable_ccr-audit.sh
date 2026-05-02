#!/bin/bash
set -euo pipefail

# ccr-audit — summarize claude-code-router routing decisions from journalctl.
#
# Reads [router] log lines from the claude-code-router user service and
# prints histograms: destination breakdown, class/reason mix, reasoning
# verbs, subagents, override usage, and ctx averages.
#
# Usage:
#   ccr-audit              # last 24h
#   ccr-audit 1h           # last hour
#   ccr-audit 7d           # last week
#   ccr-audit --since "2026-05-02 08:00"   # explicit window

since="24 hours ago"
case "${1:-}" in
    "")
        ;;
    --since)
        shift
        since="$1"
        ;;
    -h|--help)
        sed -n '1,/^$/p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        # Bare arg like 1h, 7d, 30m — convert to journalctl --since string.
        n="${1%[smhdw]}"
        unit="${1#$n}"
        case "$unit" in
            s) since="$n seconds ago" ;;
            m) since="$n minutes ago" ;;
            h) since="$n hours ago" ;;
            d) since="$n days ago" ;;
            w) since="$n weeks ago" ;;
            *)
                printf "Unrecognized window: %s\n" "$1" >&2
                exit 1
                ;;
        esac
        ;;
esac

raw=$(journalctl --user -u claude-code-router -g '\[router\]' \
    --since "$since" --no-pager --output=cat 2>/dev/null || true)

if [ -z "$raw" ]; then
    printf "No router decisions logged since: %s\n" "$since"
    exit 0
fi

total=$(printf '%s\n' "$raw" | wc -l)
printf "ccr-audit — %d requests since %s\n" "$total" "$since"
printf "%s\n" "════════════════════════════════════════════════════════════════"

# Destinations.
printf "\nDestinations\n"
printf '%s\n' "$raw" | awk -F'→ ' 'NF>1 {gsub(/^ +| +$/,"",$2); print $2}' \
    | sort | uniq -c | sort -rn \
    | awk -v t="$total" '{
        pct = 100 * $1 / t
        printf "  %5d  %5.1f%%  %s\n", $1, pct, $2
    }'

# Class × reason mix.
printf "\nClass × reason\n"
printf '%s\n' "$raw" \
    | grep -oE 'class=[^ ]+( reason=[^ ]+)?' \
    | sort | uniq -c | sort -rn \
    | awk '{ printf "  %5d  %s %s\n", $1, $2, ($3 ? $3 : "") }'

# Reasoning verbs.
printf "\nReasoning verbs (when matched)\n"
verbs=$(printf '%s\n' "$raw" | grep -oE ' verb=[^ ]+' | awk -F= '{print $2}' \
    | sort | uniq -c | sort -rn || true)
if [ -n "$verbs" ]; then
    printf '%s\n' "$verbs" | awk '{ printf "  %5d  %s\n", $1, $2 }'
else
    printf "  (none)\n"
fi

# Subagents.
printf "\nSubagents (when detected)\n"
subs=$(printf '%s\n' "$raw" | grep -oE ' subagent=[^ ]+' | awk -F= '{print $2}' \
    | sort | uniq -c | sort -rn || true)
if [ -n "$subs" ]; then
    printf '%s\n' "$subs" | awk '{ printf "  %5d  %s\n", $1, $2 }'
else
    printf "  (none)\n"
fi

# Lane signals — what triggered the prose/code split.
printf "\nLane signals\n"
sigs=$(printf '%s\n' "$raw" | grep -oE ' laneSignal=[^ ]+' | awk -F= '{print $2}' \
    | sort | uniq -c | sort -rn || true)
if [ -n "$sigs" ]; then
    printf '%s\n' "$sigs" | awk '{ printf "  %5d  %s\n", $1, $2 }'
else
    printf "  (none)\n"
fi

# Override usage.
printf "\nManual @overrides\n"
overrides=$(printf '%s\n' "$raw" | grep -E 'class=override' \
    | grep -oE ' reason=[^ ]+' | awk -F= '{print $2}' \
    | sort | uniq -c | sort -rn || true)
if [ -n "$overrides" ]; then
    printf '%s\n' "$overrides" | awk '{ printf "  %5d  %s\n", $1, $2 }'
else
    printf "  (none)\n"
fi

# Average ctx by destination tier (cloud vs local). Dest is the last
# whitespace token on the line; ctx field may be absent (overrides).
printf "\nAverage ctx by tier\n"
printf '%s\n' "$raw" | awk '
    {
        ctx = 0
        if (match($0, /ctx=[0-9]+/)) ctx = substr($0, RSTART+4, RLENGTH-4) + 0
        dest = $NF
        tier = (dest ~ /^anthropic,/) ? "cloud" : "local"
        sum[tier] += ctx
        n[tier]++
    }
    END {
        for (t in sum) printf "  %-6s %6d req   avg=%6d tokens\n", t, n[t], (n[t] ? sum[t]/n[t] : 0)
    }
'

# Perf-ctx escalations — requests pushed cloud because local would be too
# slow. The localPerfCtx field on these lines reports the active ceiling.
# Tune the chezmoi flag down if escalations are rare (most local traffic
# already fits), or up if they dominate (local barely gets used).
printf "\nPerf-ctx escalations (soft cloud push, see chezmoi flag localPerfCtx)\n"
escalations=$(printf '%s\n' "$raw" | grep -E 'reason=perf-ctx-ceiling' || true)
if [ -n "$escalations" ]; then
    printf '%s\n' "$escalations" | awk '
        match($0, /class=[^ ]+/)        { cls = substr($0, RSTART+6, RLENGTH-6) }
        match($0, /ctx=[0-9]+/)         { ctx = substr($0, RSTART+4, RLENGTH-4) + 0 }
        match($0, /localPerfCtx=[0-9]+/){ ceil = substr($0, RSTART+13, RLENGTH-13) + 0 }
        {
            n[cls]++; sum[cls] += ctx; if (ctx > max[cls]) max[cls] = ctx
            ceiling = ceil
        }
        END {
            for (c in n) printf "  %5d  %-18s avg=%6d max=%6d (ceiling=%d)\n",
                n[c], c, sum[c]/n[c], max[c], ceiling
        }
    '
else
    printf "  (none — either no traffic above ceiling, or localPerfCtx=-1)\n"
fi

# Optional: last N prompt snippets when CCR_LOG_PROMPT was on.
prompts=$(printf '%s\n' "$raw" | grep -oE 'prompt="[^"]*"' | tail -10 || true)
if [ -n "$prompts" ]; then
    printf "\nRecent prompt snippets (last 10, requires CCR_LOG_PROMPT=1)\n"
    printf '%s\n' "$prompts" | sed 's/^/  /'
fi
