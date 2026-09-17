<!--
The four sections below are this repo's charter output gates
(claude/.claude/rules/council-charter.md). They were prose an agent might
follow; here they are a form a human fills in. Delete none of them — write
"n/a" with a reason instead.
-->

## What and why

<!-- What changed, and what problem it solves. Link the issue or session note. -->

## Verification

<!--
Commands to run and expected results. If verification did not complete, say so
plainly and state what remains — an honest "not proven" is worth more than an
implied pass.
-->

```bash
scripts/validate-config.py     # expect: 0 errors
./verify-drift.sh              # local only; expect: no drift, or the drift named
```

## Rollback

<!--
How to revert safely.

Note for anything touching claude/.claude/: ~/.claude/* are stow symlinks into
the working tree, so switching branches changes live agent behaviour. Reverting
a config change means checking out a branch without it, not just reverting a
commit in place.
-->

## Risks and assumptions

<!-- Brief and explicit. Include anything you could not verify. -->

## Scope control

<!-- Smallest viable change? What was deliberately left out, and why? -->

---

### Merge readiness

- [ ] `scripts/validate-config.py` passes (CI `validate / config schema`)
- [ ] No new entries added to `scripts/validate-config-baseline.json`
- [ ] All automated reviewers have completed — `gh pr checks`
- [ ] Tech debt noticed but not fixed here is captured as an issue
