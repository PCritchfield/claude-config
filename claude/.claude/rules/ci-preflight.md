# CI Pre-flight

Before pushing any branch, run the project's local validation suite. Detect and run what's available:

- **Python**: `ruff check .`, `ruff format --check .`, `pyright` (or `mypy`)
- **TypeScript/JavaScript**: `npx prettier --check .`, `npx eslint .`, `npx tsc --noEmit`
- **Java**: `mvn checkstyle:check`, `mvn compile`
- **General**: run pre-commit hooks if `.pre-commit-config.yaml` exists (`pre-commit run --all-files`)

If any check fails, fix it before pushing. Do not push known-broken code.

The post-edit hook (`settings.json`) catches most formatting issues at edit time. This pre-flight covers what the hook does not: type checking (`pyright`, `tsc`), linting rules beyond formatting (`eslint`), and tools not in the hook. Both layers are intentional (defense in depth).
