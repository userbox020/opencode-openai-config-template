# Model And Specialist Routing

Routing supports the primary goal; it must not create additional work.

- Use the configured primary route at medium effort for routine orchestration and build work, and at high effort for planning, fixing, security review, and architecture.
- Reserve the configured primary route at xhigh effort for Oracle escalation.
- Use the configured balanced route for general work, source synthesis, technical summaries, compaction, design, and normal review.
- Use the configured utility route at none or low effort for exploration, titles, utility/high-volume work, and fast sanity checks.
- Use the configured deep-review route at high effort only for the bounded deep-review council member.
- Direct execution is the default. Do not delegate solely because a task is non-trivial, multi-step, or touches multiple files.
- Delegate only a narrow lane that clearly needs specialized capability, materially useful parallelism, or independent high-risk review.
- Keep delegation and task cancellation in the orchestrator lane; implementation agents must not fan out.
- Use `@explorer` for read-only repository discovery and code-path mapping.
- Use `@librarian` for external documentation and source research without sending secrets or private code in queries.
- Use `@code-reviewer` for correctness, regression, maintainability, edge-case, and test-gap review.
- Use `@repo-architect` for architecture decisions, migrations, module boundaries, API contracts, and sequencing.
- Use `@test-writer` for targeted tests, reproduction cases, fixtures, and verification commands.
- Use `@security-reviewer` for defensive review of auth, secrets, injection, unsafe IO, dependencies, deployment, logging, and data exposure.
- Use `@oracle` for narrow clarifications or independent reasoning checks.
- Use council only when the user requests it or an unresolved high-risk decision justifies the extra cost and delay.
- Do not run routine second-pass reviews after targeted verification has already established a low-risk change.
- Reject optional scope expansion from subagents. Integrate only work required for the user's primary goal.
- Stop once the requested outcome is complete and proportionately verified.
- Ask before reading secrets, modifying credential files, publishing packages, pushing branches, deploying, touching production systems, or running destructive commands.

## Review Handoff Shape

When review is justified, include the primary goal, narrow question, relevant paths, intended behavior, verification already run, and an instruction not to expand scope.
