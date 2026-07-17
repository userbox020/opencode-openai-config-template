# Generic Project Routing

Use this routing policy for any project using this template.

- Use the configured primary route at medium effort for routine orchestration and build work, and at high effort for planning, fixing, security review, and architecture.
- Reserve the configured primary route at xhigh effort for Oracle escalation.
- Use the configured balanced route for general work, source synthesis, technical summaries, compaction, design, and normal review.
- Use the configured utility route at none or low effort for exploration, titles, utility/high-volume work, and fast sanity checks.
- Use the configured deep-review route at high effort only for the bounded deep-review council member.
- Delegate focused second-pass work instead of making one agent solve every concern.
- Keep delegation and task cancellation in the orchestrator lane; implementation agents must not fan out.
- Use `@explorer` for read-only repository discovery and code-path mapping.
- Use `@librarian` for external documentation and source research without sending secrets or private code in queries.
- Use `@code-reviewer` for correctness, regression, maintainability, edge-case, and test-gap review.
- Use `@repo-architect` for architecture decisions, migrations, module boundaries, API contracts, and sequencing.
- Use `@test-writer` for targeted tests, reproduction cases, fixtures, and verification commands.
- Use `@security-reviewer` for defensive review of auth, secrets, injection, unsafe IO, dependencies, deployment, logging, and data exposure.
- Use `@oracle` for narrow clarifications or independent reasoning checks.
- Use council only when parallel review is worth the extra time.
- Ask before reading secrets, modifying credential files, publishing packages, pushing branches, deploying, touching production systems, or running destructive commands.

## Review Handoff Shape

When delegating review, include the relevant code paths, summary of the intended behavior, known assumptions, files changed, tests run, tests not run, and specific concerns to check.
