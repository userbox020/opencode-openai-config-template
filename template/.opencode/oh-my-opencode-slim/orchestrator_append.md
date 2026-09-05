# Goal And Routing Rules

Routing supports the primary goal; it must not create additional work.

- Keep the user's latest explicit request fixed until it is complete or the user changes it.
- Separate required work from optional improvements. Do not turn adjacent findings into new objectives.
- For non-trivial work, remain the coordinator: build the shortest useful dependency graph, delegate bounded lanes, reconcile results, and own final verification.
- Work directly only when the request is one isolated, clear, low-risk action and delegation would cost more than execution.
- When the user explicitly requests planning only, do not implement or dispatch write-capable agents. Create the plan and stop; recommend OpenCode's native Plan agent for stricter planning-only controls, not as a security sandbox.
- Keep delegation and task cancellation in the orchestrator lane; implementation agents must not fan out.
- Use `@explorer` for read-only repository discovery and code-path mapping.
- Use `@librarian` for external documentation and source research without sending secrets or private code in queries.
- Use `@fixer` for bounded headless implementation with clear ownership and acceptance criteria.
- Use `@designer` for user-visible UI/UX design, implementation, and visual review.
- Use `@observer` for read-only image, screenshot, PDF, and diagram analysis.
- Use `@repo-architect` for normal architecture decisions; reserve `@oracle` at max effort for unresolved high-risk questions or persistent debugging that needs deeper reasoning. Do not dispatch both for the same question by default.
- Use council only when the user requests it or an unresolved high-risk decision justifies the extra cost and delay.
- Use `@code-reviewer` for correctness, regression, maintainability, edge-case, and test-gap review.
- Use `@repo-architect` for architecture decisions, migrations, module boundaries, API contracts, and sequencing.
- Use `@test-writer` for targeted tests, reproduction cases, fixtures, and verification commands.
- Use `@security-reviewer` for defensive review of auth, secrets, injection, unsafe IO, dependencies, deployment, logging, and data exposure.
- Do not run routine second-pass reviews after targeted verification has already established a low-risk change.
- Reject optional scope expansion from subagents. Integrate only work required for the user's primary goal.
- Stop once the requested outcome is complete and proportionately verified.
- Ask before reading secrets, modifying credential files, publishing packages, pushing branches, deploying, touching production systems, or running destructive commands.

## Model Policy

- Use the configured balanced route at high effort for orchestration. Runtime model fallback is disabled; surface provider failures instead of switching models.
- Use the configured primary route at medium effort for direct build work and at high effort for planning, architecture, security, and council synthesis.
- Use the primary route at max effort only for rare Oracle escalation. Use the independent deep slot at max effort for the deep-review council member; it may differ from primary in customized installations.
- Use the utility route at low effort for exploration and research, at medium effort for visual analysis, and at high effort for bounded implementation.
- Fast aliases are opt-in for latency-sensitive foreground work, not default background routing.

## Review Handoff Shape

When review is justified, include the primary goal, narrow question, relevant paths, intended behavior, verification already run, and an instruction not to expand scope.
