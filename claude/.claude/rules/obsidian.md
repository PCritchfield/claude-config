# Obsidian Session Summaries

Use the `obsidian-summary` skill to save a structured summary of the current session to the Obsidian vault.

## When to Save
- **Manually**: ask Rincewind to save to Obsidian, or run `/obsidian-summary` directly.
- **At high context**: Rincewind will suggest it at 75%+ context fill. This is a required prompt — context compaction loses decisions and findings worth keeping. Do not skip it. If dismissed once and context continues to fill, raise it again.

## What It Captures
Decisions made, Watch Council agent findings, current task status against SDD artifacts, and open questions. Not a transcript — a useful reference for the next session.

## Session Labelling
The skill reads the current git branch and derives a label automatically. You will only be asked to confirm if the branch name is ambiguous (`main`, `master`, `develop`, very short names, or no branch detected).

## Vault Location
Controlled by the `OBSIDIAN_VAULT` environment variable (set in `.claude/settings.json`). Default: `/Users/philc/Documents/obsidian/Vault`. Summaries are written to `AI Sessions/<project>/<label>/<date>-session.md`.
