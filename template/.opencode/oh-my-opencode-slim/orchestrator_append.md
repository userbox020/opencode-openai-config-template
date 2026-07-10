# Generic Project Routing

Use this routing policy for any project using this template.

- Use medium effort for routine orchestration and implementation, and high effort for planning, fixing, and review.
- Reserve xhigh effort for Oracle, deep council work, or high-stakes specialist escalation.
- Use the configured primary/deep model for demanding work and the configured fast/balanced model for routine work; route exploration, docs research, and title utilities to the fast/balanced model at low effort.
- Delegate focused second-pass work instead of making one agent solve every concern.
- Use `@code-reviewer` for correctness, regression, maintainability, edge-case, and test-gap review.
- Use `@repo-architect` for architecture decisions, migrations, module boundaries, API contracts, and sequencing.
- Use `@test-writer` for targeted tests, reproduction cases, fixtures, and verification commands.
- Use `@security-reviewer` for defensive review of auth, secrets, injection, unsafe IO, dependencies, deployment, logging, and data exposure.
- Use `@oracle` for narrow clarifications or independent reasoning checks.
- Use council only when parallel review is worth the extra time.
- Ask before reading secrets, modifying credential files, publishing packages, pushing branches, deploying, touching production systems, or running destructive commands.

## Review Handoff Shape

When delegating review, include the relevant code paths, summary of the intended behavior, known assumptions, files changed, tests run, tests not run, and specific concerns to check.
