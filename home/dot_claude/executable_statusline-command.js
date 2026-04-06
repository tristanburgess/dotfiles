#!/usr/bin/env bun
// Claude Code status line — Bun rewrite of statusline-command.sh
// Adapted from https://github.com/andrewburgess/dotfiles

import { spawnSync } from "bun"
import { readFileSync, writeFileSync } from "fs"
import { basename } from "path"

// ─── ANSI helpers ────────────────────────────────────────────────────────────

const RESET = "\x1b[0m"
const BOLD = "\x1b[1m"

const rgb = (r, g, b) => `\x1b[38;2;${r};${g};${b}m`
const BLUE = rgb(88, 166, 255)
const GREEN = rgb(31, 136, 61)
const SEP = rgb(88, 166, 255)
const STATS = rgb(180, 190, 200)
const DKGRAY = rgb(45, 50, 55)
const RED = rgb(255, 80, 80)
const LTGRN = rgb(80, 220, 80)

/** Interpolate between blue (88,166,255) and red (255,80,80) at t in [0,1]. */
function blueToRed(t) {
    const r = Math.round(88 + (255 - 88) * t)
    const g = Math.round(166 + (80 - 166) * t)
    const b = Math.round(255 + (80 - 255) * t)
    return rgb(r, g, b)
}

// ─── Plan detection ──────────────────────────────────────────────────────────

function detectPlanType() {
    try {
        const credsPath = `${process.env.HOME}/.claude/.credentials.json`
        const creds = JSON.parse(readFileSync(credsPath, "utf8"))
        const sub = creds?.claudeAiOauth?.subscriptionType
        if (sub && sub !== "api") return "rate"
        if (!creds?.claudeAiOauth) return "api"
        return "rate"
    } catch {
        return null
    }
}

const credentialsPlanType = detectPlanType()

// ─── Input ───────────────────────────────────────────────────────────────────

const raw = await Bun.stdin.text()
const input = JSON.parse(raw || "{}")

const cwd = input?.workspace?.current_dir ?? input?.cwd ?? ""
const model = input?.model?.display_name ?? ""
const usedPct = input?.context_window?.used_percentage ?? null
const inputTokens = input?.context_window?.total_input_tokens ?? null
const outputTokens = input?.context_window?.total_output_tokens ?? null
const fivePct = input?.rate_limits?.five_hour?.used_percentage ?? null
const sevenPct = input?.rate_limits?.seven_day?.used_percentage ?? null
const sessionCost = input?.cost?.total_cost_usd ?? null
const sessionId = input?.session_id ?? null

// ─── VCS helpers ──────────────────────────────────────────────────────────────

function run(cmd, ...args) {
    const result = spawnSync([cmd, ...args], {
        stdout: "pipe",
        stderr: "pipe",
    })
    return result.exitCode === 0 ? result.stdout.toString().trim() : null
}

function git(...args) {
    return run("git", "-C", cwd, "--no-optional-locks", ...args)
}

function jj(...args) {
    return run("jj", "-R", cwd, "--no-pager", ...args)
}

// ─── Jujutsu info ─────────────────────────────────────────────────────────────

function buildJjSection() {
    if (!cwd) return null

    const isRepo = spawnSync(["jj", "root", "--quiet", "-R", cwd], {
        stdout: "pipe",
        stderr: "pipe",
    }).exitCode === 0
    if (!isRepo) return null

    const changeId = jj("log", "-r", "@", "--no-graph", "-T", "change_id.shortest()")
    if (!changeId) return null

    const bookmarks = jj("log", "-r", "@", "--no-graph", "-T", 'bookmarks.join(", ")')
    const ancestorBookmark = jj(
        "log",
        "-r",
        "latest(ancestors(@-) & bookmarks())",
        "--no-graph",
        "-T",
        'bookmarks.join(", ")'
    )

    let branch = changeId
    if (bookmarks) branch += ` (${bookmarks})`
    if (ancestorBookmark) branch += ` on ${ancestorBookmark}`

    // Check if working copy has changes (--summary is empty when clean)
    const diffSummary = jj("diff", "--summary")
    const indicators = diffSummary ? ` ${BOLD}${RED}[!]${RESET}` : ""

    return { branch, indicators }
}

// ─── Git info ─────────────────────────────────────────────────────────────────

function buildGitSection() {
    if (!cwd) return null

    const isRepo =
        spawnSync(["git", "-C", cwd, "rev-parse", "--is-inside-work-tree"], {
            stdout: "pipe",
            stderr: "pipe",
        }).exitCode === 0
    if (!isRepo) return null

    const branch =
        git("symbolic-ref", "--short", "HEAD") ??
        git("rev-parse", "--short", "HEAD")
    if (!branch) return null

    // ── Staged / unstaged / untracked ─────────────────────────────────────────
    const porcelain = git("status", "--porcelain") ?? ""
    let hasUnstaged = false,
        hasStaged = false,
        hasUntracked = false

    for (const line of porcelain.split("\n")) {
        if (!line) continue
        const x = line[0]
        const y = line[1]
        if (x === "?" && y === "?") {
            hasUntracked = true
            continue
        }
        if (x !== " " && x !== "?") hasStaged = true
        if (y !== " " && y !== "?") hasUnstaged = true
    }

    let bracket = ""
    if (hasUnstaged) bracket += "!"
    if (hasStaged) bracket += "+"
    if (hasUntracked) bracket += "?"
    const bracketStr = bracket ? ` ${BOLD}${RED}[${bracket}]${RESET}` : ""

    // ── Diff line counts ──────────────────────────────────────────────────────
    function parseDiffStat(raw) {
        let added = 0,
            deleted = 0
        for (const line of (raw ?? "").split("\n")) {
            const [a, d] = line.split("\t")
            if (a && a !== "-") added += parseInt(a, 10) || 0
            if (d && d !== "-") deleted += parseInt(d, 10) || 0
        }
        return { added, deleted }
    }

    const unstaged = parseDiffStat(git("diff", "--numstat"))
    const staged = parseDiffStat(git("diff", "--cached", "--numstat"))
    const totalAdded = unstaged.added + staged.added
    const totalDeleted = unstaged.deleted + staged.deleted

    const addStr =
        totalAdded > 0 ? ` ${BOLD}${LTGRN}+${totalAdded}${RESET}` : ""
    const delStr =
        totalDeleted > 0 ? ` ${BOLD}${RED}-${totalDeleted}${RESET}` : ""

    // ── Stashes ───────────────────────────────────────────────────────────────
    const stashCount = (git("stash", "list") ?? "")
        .split("\n")
        .filter(Boolean).length
    const stashStr = stashCount > 0 ? ` *${stashCount}` : ""

    // ── Ahead / behind ────────────────────────────────────────────────────────
    let aheadStr = "",
        behindStr = ""
    const upstream = git("rev-parse", "--abbrev-ref", "@{upstream}")
    if (upstream) {
        const ahead = parseInt(
            git("rev-list", "@{upstream}..HEAD", "--count") ?? "0",
            10
        )
        const behind = parseInt(
            git("rev-list", "HEAD..@{upstream}", "--count") ?? "0",
            10
        )
        if (ahead > 0) aheadStr = ` ⇡${ahead}`
        if (behind > 0) behindStr = ` ⇣${behind}`
    }

    const indicators =
        bracketStr + addStr + delStr + stashStr + aheadStr + behindStr
    return { branch, indicators }
}

// ─── VCS dispatch (jj first, then git) ────────────────────────────────────────

function buildVcsSection() {
    return buildJjSection() ?? buildGitSection()
}

// ─── Context window bar ───────────────────────────────────────────────────────

function buildContextBar(pct, totalInputTokens, totalOutputTokens) {
    if (pct === null) return null

    const BLOCKS = 30
    const filled = Math.min(BLOCKS, Math.round((pct * BLOCKS) / 100))
    const empty = BLOCKS - filled

    let bar = ""
    for (let i = 0; i < filled; i++) {
        const t = ((i * 100) / BLOCKS + 100 / BLOCKS / 2) / 100
        bar += `${blueToRed(t)}█${RESET}`
    }
    bar += `${DKGRAY}${"░".repeat(empty)}${RESET}`

    const tokenInfo =
        totalInputTokens !== null
            ? ` (↑${fmtTokens(totalInputTokens)} ↓${fmtTokens(totalOutputTokens ?? 0)})`
            : ""

    return `${bar} ${Math.round(pct)}%${tokenInfo}`
}

function fmtTokens(n) {
    n = Number(n) || 0
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`
    return String(n)
}

// ─── Session cost ─────────────────────────────────────────────────────────────

function buildSessionCost(cost) {
    if (!cost) return null
    const rounded = parseFloat(cost.toFixed(2))
    return `$${rounded}`
}

// ─── Rate-limit indicators ────────────────────────────────────────────────────

function rateIndicator(pct, label) {
    if (pct >= 50) {
        const color = blueToRed(pct / 100)
        return `${color}● ${label}${RESET}`
    }
    return `${DKGRAY}○ ${label}${RESET}`
}

function buildRateIcons(fivePct, sevenPct) {
    if (fivePct === null && sevenPct === null) return null
    const parts = []
    if (fivePct !== null) parts.push(rateIndicator(fivePct, "5h"))
    if (sevenPct !== null) parts.push(rateIndicator(sevenPct, "7d"))
    return parts.join(`${SEP} | ${RESET}`)
}

// ─── Budget tracker (API / dollar-based plan) ─────────────────────────────────

const MONTHLY_BUDGET = 1000
const BUDGET_FILE = `${process.env.HOME}/.claude/budget-tracker.json`

function buildBudgetIndicator(sessionCost, sessionId) {
    if (sessionCost === null) return null

    const currentMonth = new Date().toISOString().slice(0, 7)

    let budget
    try {
        budget = JSON.parse(readFileSync(BUDGET_FILE, "utf8"))
        if (budget.month !== currentMonth) throw new Error("new month")
    } catch {
        budget = { month: currentMonth, sessions: {}, total_spent: 0 }
    }

    const lastCost = budget.sessions[sessionId] ?? 0
    let delta = sessionCost - lastCost
    if (delta < 0) delta = sessionCost
    budget.sessions[sessionId] = sessionCost
    budget.total_spent = (budget.total_spent ?? 0) + delta

    writeFileSync(BUDGET_FILE, JSON.stringify(budget))

    const spent = budget.total_spent
    const remaining = Math.max(0, MONTHLY_BUDGET - spent)
    const spentPct = Math.min(100, (spent * 100) / MONTHLY_BUDGET)
    const remainPct = 100 - spentPct

    const BLOCKS = 30
    const filled = Math.max(
        0,
        Math.min(BLOCKS, Math.round((remainPct * BLOCKS) / 100))
    )
    const empty = BLOCKS - filled
    const t = spentPct / 100
    const color = blueToRed(t)

    let bar = `${color}${"█".repeat(filled)}${RESET}`
    bar += `${DKGRAY}${"░".repeat(empty)}${RESET}`

    const fmt = (n) => `$${n.toFixed(2)}`
    return `${bar} ${fmt(remaining)} left (${fmt(spent)} spent)`
}

// ─── Assemble output ──────────────────────────────────────────────────────────

const parentFolder = basename(cwd) || cwd
const vcsSection = buildVcsSection()
const ctxBar = buildContextBar(usedPct, inputTokens, outputTokens)
const currentSessionCost = buildSessionCost(sessionCost)

const hasLiveRateData = fivePct !== null || sevenPct !== null
const isRatePlan = hasLiveRateData || credentialsPlanType === "rate"
const isApiPlan = !hasLiveRateData && credentialsPlanType === "api"

const rateIcons = isRatePlan ? buildRateIcons(fivePct, sevenPct) : null
const budgetIndicator = isApiPlan
    ? buildBudgetIndicator(sessionCost, sessionId)
    : null

// Line 1: folder | branch <indicators> | model
let line1 = `${BLUE}${BOLD}${parentFolder}${RESET}`

if (vcsSection) {
    line1 += `${SEP} | ${RESET}${GREEN}${vcsSection.branch}${RESET}`
    if (vcsSection.indicators) line1 += vcsSection.indicators
}

line1 += `${SEP} | ${RESET}${STATS}${model}${RESET}`

// Line 2: context bar | session cost | rate icons
const line2Parts = [ctxBar, currentSessionCost, rateIcons].filter(Boolean)
const line2 = line2Parts.length ? line2Parts.join(`${SEP} | ${RESET}`) : null

process.stdout.write(line1)
if (line2) process.stdout.write(`\n${STATS}${line2}${RESET}`)
if (budgetIndicator)
    process.stdout.write(`\n${STATS}${budgetIndicator}${RESET}`)
process.stdout.write("\n\n")
