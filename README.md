# claude-config

Version-controlled backup of the hand-maintained files that live in `~/.claude/`. This repository exists so those files are not lost when a machine changes, and so there is a clear record of what changed and why.

Rincewind, the specialist agents, and the review and polish workflow are not here. They come from the [crew plugin](https://github.com/PCritchfield/claude-crew), which replaced the Watch Council this repository used to hold. [Superpowers](https://github.com/obra/superpowers) supplies the process skills.

---

## What lives here

```
claude/.claude/
├── settings.json       # Claude Code settings: permissions, env vars, hooks, plugins, spinners
├── statusline.sh       # Discworld-themed status line
├── rules/              # Always-available rule files
│   ├── obsidian.md            # Session summaries, vault search via MCP
│   ├── ci-preflight.md        # CI validation before pushing
│   └── agent-preflight.md     # Parallel agent dispatch checklist
├── hooks/              # Lifecycle hooks
│   ├── session-start-context.sh  # Loads prior Obsidian session as context
│   ├── precompact-checkpoint.sh  # Saves checkpoint before context compaction
│   └── sync-settings.py          # Keeps settings.json in step with this repo
└── skills/             # Custom skills (community skills installed separately, gitignored)
    ├── obsidian-digest/
    └── obsidian-summary/
```

The files are stored under `claude/.claude/` rather than directly at the repo root so the repository can hold other things (this README, for instance) without polluting the Claude config directory.

---

## Installing

Each step is independent. Run what you need.

### Step 1: Stow symlinks

```bash
./install.sh
```

Creates symlinks from `~/.claude/` pointing into the repo using [GNU Stow](https://www.gnu.org/software/stow/). Requires `stow`. The script backs up any pre-existing real files before replacing them with symlinks, seeds `settings.json` on a fresh machine, and installs the git hook that applies pulled settings.

On machines stowed before the crew replaced the council, it also removes the retired `CLAUDE.md`, `agents` and `commands` links, and names any leftover domain-skill links in `skills/` for you to delete.

### Step 2: Plugins

In Claude Code, `/plugin install crew@crew`. `settings.json` already declares the crew marketplace and enables the plugin; the crew declares Superpowers as a dependency.

### Step 3: Community skills

```bash
./install_skills.sh
```

Installs the general-purpose skills listed in `skills.txt` via `npx skills add`. Domain skills are not listed; the crew bundles its own.

### Step 4: Obsidian MCP Server (optional)

If you use Obsidian for session notes:

1. Install the [Local REST API plugin](https://github.com/coddingtonbear/obsidian-local-rest-api) in Obsidian (Community Plugins → Browse → "Local REST API")
2. Enable it and copy the API key from its settings
3. Add the MCP server:
   ```bash
   claude mcp add obsidian --scope user -- npx -y obsidian-mcp-server
   ```
4. Set the environment variables in `~/.claude.json`:
   ```json
   "obsidian": {
     "env": {
       "OBSIDIAN_API_KEY": "<your-key>",
       "OBSIDIAN_BASE_URL": "https://127.0.0.1:27124",
       "OBSIDIAN_VERIFY_SSL": "false"
     }
   }
   ```

### settings.json is synced, not stowed

Claude Code's tools replace a symlinked `settings.json` with a regular file the
first time they save it, so it is kept in step by git instead: captured into the
repo at every session end, applied from the repo after every `git pull`. On a
fresh machine, `install.sh` seeds it from the repo. See
[CONTRIBUTING.md](CONTRIBUTING.md#read-this-first-the-repo-is-your-live-config).

Some keys belong to one machine and never sync:

- `autoMode`, always. It describes this machine's hosts and network for auto mode's classifier, and this repository is public.
- Any path listed in `~/.claude/sync-settings.exclude`, one per line, segments separated by `/` (for example `hooks` or `enabledPlugins/vercel@claude-plugins-official`). Use it for hooks and plugins that only exist on one machine.

Set `OBSIDIAN_VAULT` to the vault location on each machine.

---

## rules/

- **obsidian.md**: when and how to save session summaries, and vault search patterns via MCP
- **ci-preflight.md**: run the project's local checks (ruff, prettier, eslint, tsc, pre-commit) before pushing
- **agent-preflight.md**: checklist before dispatching parallel agents or worktrees

## Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `session-start-context.sh` | SessionStart | Loads the most recent Obsidian session note for the current project/branch as `additionalContext`. Ends cold starts. |
| `precompact-checkpoint.sh` | PreCompact | Saves a lightweight checkpoint marker to the Obsidian vault before context compression. Non-blocking, best-effort. |
| `sync-settings.py capture` | SessionEnd | Copies live `settings.json` into the repo working tree. Never commits. |
| PostToolUse (inline) | Write/Edit | Auto-formats with ruff (Python) and prettier (JS/TS/CSS/JSON) on changed files. |

---

## skills/

Two hand-maintained skills. Community skills are installed separately via `install_skills.sh` and gitignored. They are symlinks into `~/.agents/skills/` and are not tracked in this repo.

### obsidian-summary

Saves a structured session summary to an Obsidian vault. Supports four note types: `session`, `document`, `decision`, and `investigation`. Produces Obsidian-flavoured markdown with YAML frontmatter, wikilinks, and Dataview-compatible properties. Session notes record which crew agents were consulted and their verdicts.

The vault path is read from the `OBSIDIAN_VAULT` environment variable set in `settings.json`. There is no default.

Files:
- `SKILL.md`: full skill definition
- `write-to-vault.sh`: writes the generated note to the correct vault path

### obsidian-digest

Synthesises multiple session notes into a structured digest and optional Marp slide deck. Scopes by project, feature, topic, or date range. Output tone and depth adapts to the intended audience (personal, team, leadership, or client-facing). Leadership and client-facing digests strip agent findings and commit refs; team and personal digests keep full technical depth.

Uses `obsidian-summary`'s `write-to-vault.sh` for writing to the vault. Marp slide generation is optional and checks for CLI availability before attempting.

Files:
- `SKILL.md`: full skill definition

---

## settings.json

Contains no secrets, and no machine's `autoMode`. Does contain:

- `OBSIDIAN_VAULT`: absolute path to the Obsidian vault
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`: enables the agent teams feature
- `permissions.deny`: blocks Claude from reading `.env*` files and `~/.ssh/**`
- `hooks`: see the Hooks section
- `enabledPlugins` / `extraKnownMarketplaces`: Superpowers and the crew
- `autoMemoryEnabled` / `autoDreamEnabled`: automatic memory and consolidation
- `spinnerVerbs`: a large set of Discworld-themed loading messages, because why not

The Obsidian MCP Server configuration (including the API key) lives in `~/.claude.json` at user scope, not in this file. It is machine-specific and not tracked in git.

## Checks

```bash
python3 scripts/validate-config.py      # config schema; CI runs it
python3 -m unittest discover -s tests   # unit tests; CI runs them
./verify-drift.sh                       # local only: this repo against ~/.claude
```
