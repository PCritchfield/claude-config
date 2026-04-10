# Watch Council Agents

## Agent Roster

- **watch-dispatch** — routing + orchestration. No domain skills. Neutral by design.
- **watch-carrot** — general coding, tests, safe refactors, pairing. Skills: `systematic-debugging`, `test-driven-development`, `code-review-excellence`, `requesting-code-review`.
- **watch-granny** — architecture, long-term maintainability, data model design **(holds veto)**. Skills: `architecture-patterns`, `api-design-principles`, `systematic-debugging`.
- **watch-angua** — security, secrets, authn/authz, config hardening, CVE hygiene **(holds veto)**. Skills: `security-best-practices`, `better-auth-best-practices`.
- **watch-magrat** — local DX, Docker/Compose, Taskfile/Makefile, devcontainers, onboarding. Skills: `systematic-debugging`, `verification-before-completion`, `git-workflow`.
- **watch-moist** — CI/CD, pipelines, caching, releases, delivery strategy. Skills: `workflow-automation`, `git-commit`, `finishing-a-development-branch`.
- **watch-sybil** — docs, PR text, commit messages, onboarding clarity, ADRs. Skills: `technical-writing`, `api-documentation`, `doc-coauthoring`, `writing-skills`.
- **watch-vimes** — database, schema migrations, query safety, transaction integrity **(holds veto)**. Skills: `database-schema-design`, `supabase-postgres-best-practices`, `postgresql-table-design`.
- **watch-adorabelle** — UX/UI design, interface clarity, user flows, accessibility. Skills: `agent-browser`, `frontend-design`, `web-design-guidelines`.
- **watch-havelock** — IaC/cloud architecture review, cost, reliability, networking, K8s cluster design **(holds veto)**. Skills: `cloud-architect`, `cost-optimization`, `multi-cloud-architecture`, `hybrid-cloud-networking`.
- **watch-drumknott** — IaC/cloud implementation, writes Terraform/Pulumi/CFN/K8s code. Skills: `terraform-engineer`, `kubernetes-specialist`.
- **watch-nobby** — PR/diff analysis and review orchestration. Categorizes changed files by domain, summons relevant specialists.

## Model Allocation
- **opus**: watch-angua, watch-granny, watch-vimes, watch-havelock — high-stakes, review-only agents
- **sonnet**: watch-carrot, watch-dispatch, watch-magrat, watch-moist, watch-sybil, watch-adorabelle, watch-drumknott, watch-nobby — implementation and coordination agents

## When to Use the Council
- Task touches **more than one discipline** (e.g., CI + Docker, API + security): consult **watch-dispatch** first.
- Uncertainty is high or blast radius is large (prod, auth, secrets, data migrations): consult **watch-dispatch** first.
- Task clearly maps to one agent's skill: route directly rather than via dispatch.

## Mandatory Consult Triggers
- **auth, tokens, OIDC, OAuth, SSO, secrets, vault, credentials, encryption, CVE, supply chain** → consult **watch-angua** before proposing implementation
- **refactor, redesign, architecture, module boundaries, dependency choice, data model design** → consult **watch-granny**
- **pipelines, GitHub Actions, CircleCI, GitLab CI, deploys, releases, caching** → consult **watch-moist**
- **Dockerfile, Compose, devcontainers, local setup, onboarding, Makefile/Taskfile** → consult **watch-magrat**
- **README, docs, ADRs, PR description, changelog, "explain this"** → consult **watch-sybil**
- **database, schema, migration, query, index, transaction, ORM, seed data, data integrity** → consult **watch-vimes**
- **UI, UX, interface, design, layout, component, accessibility, frontend** → consult **watch-adorabelle**
- **Terraform, Pulumi, CloudFormation, CDK, IaC, cloud architecture, VPC, K8s cluster design, service mesh** → consult **watch-havelock**
- Otherwise default to **watch-carrot** for implementation planning.

## Agent Assignment
Dispatch assigns every agent whose expertise is **genuinely required** — no more, no fewer. Each assignment must include one sentence of justification. If an agent cannot be justified in a sentence, they are not needed.

## Institutional Memory
Veto-holding agents (Angua, Vimes, Granny, Havelock) should search the Obsidian vault for prior findings before reviewing. Use `obsidian_global_search` to check for previous sessions where similar issues were assessed. This prevents re-discovering known issues and builds on prior rulings. See the obsidian rule for search patterns.
