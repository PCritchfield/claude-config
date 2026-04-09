# SDD Workflow (Spec-Driven Development)

The project uses the [Spec-Driven Development workflow](https://github.com/liatrio-labs/spec-driven-workflow). Rincewind and all Watch Council agents should suggest the appropriate stage when the work calls for it.

## Stage Commands

| Stage | Command | When to use |
|-------|---------|-------------|
| 1 — Spec | `/SDD-1-generate-spec` | New feature or change with no spec yet |
| 2 — Tasks | `/SDD-2-generate-task-list-from-spec` | Spec exists, no task list yet |
| 3 — Execute | `/SDD-3-manage-tasks` | Spec + tasks exist, ready to implement |
| 4 — Validate | `/SDD-4-validate-spec-implementation` | Implementation complete, needs sign-off |

## Promotion within SDD
Invoking `/SDD-3-manage-tasks` is treated as Phil granting **IMPLEMENT (NARROW)** for the scope of that session. No additional promotion phrases needed. All other charter rules (output gates, rollback, scope control, veto authority) remain in full effect — SDD-3 grants write permission, not write impunity.

## Agent Responsibilities within SDD
- **Before `/SDD-1-generate-spec`**: Rincewind may suggest relevant agents review if it touches security, architecture, or data — advisory, not mandatory.
- **During spec review**: Granny, Angua, or Vimes may validate the spec doesn't embed bad decisions.
- **During `/SDD-3-manage-tasks`**: Carrot, Magrat, Moist, Adorabelle, Drumknott handle implementation. Granny, Angua, Vimes, Havelock remain review-only unless Phil promotes them by name.
- **During `/SDD-4-validate-spec-implementation`**: Angua, Vimes, and Havelock are the natural reviewers.

## SDD Prompting Behaviour
- Suggest the next SDD stage when obvious from context (spec exists but no tasks, implementation looks complete).
- Reference SDD artifact paths in output when applicable (`docs/specs/NN-spec-<feature>/`).
- Do not re-ask questions already answered in an existing spec.
- During SDD-3, all implementation tasks follow **TDD (red-green-refactor)** unless the task is explicitly non-code. Flag and correct if an agent writes production code before a failing test.
