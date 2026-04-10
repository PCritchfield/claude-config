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

## Vault Search (Obsidian MCP Server)

The Obsidian MCP Server provides read access to the vault. Use it to search for prior sessions, decisions, and findings before proposing changes. Available tools:

- **`obsidian_global_search`** — Search vault content by text/regex. Supports `searchInPath` to scope to a directory (e.g., `AI Sessions/<project>/`), `modified_since`/`modified_until` for date filtering.
- **`obsidian_read_note`** — Read a specific note by vault-relative path.
- **`obsidian_list_notes`** — List files in a vault directory.
- **`obsidian_manage_frontmatter`** — Read frontmatter properties from a specific note.

### When to Search the Vault
- **Before proposing architecture changes**: search for prior Granny findings on the same topic.
- **Before security reviews**: search for prior Angua findings to avoid re-discovering known issues.
- **Before schema changes**: search for prior Vimes findings on the same tables or migrations.
- **When resuming work on a branch**: search for session notes matching the branch label.
- **When context about a prior decision is needed**: search for decision notes or session notes mentioning the topic.

### Search Patterns
```
# Find prior sessions for this project
obsidian_global_search(query="<topic>", searchInPath="AI Sessions/<project>/")

# Find recent sessions
obsidian_global_search(query="<topic>", modified_since="2 weeks ago")

# Read a specific session note
obsidian_read_note(filePath="AI Sessions/<project>/<label>/<date>-session.md")

# Browse a project's session history
obsidian_list_notes(dirPath="AI Sessions/<project>/")
```

### Limitations
- Requires Obsidian desktop to be running (the MCP server talks to the Local REST API plugin).
- No Dataview query support — cannot filter across files by frontmatter properties. Use `obsidian_global_search` with text matching as a workaround.
- The SessionStart hook already loads the most recent session note automatically. Use MCP search when you need to go deeper than the most recent session.
