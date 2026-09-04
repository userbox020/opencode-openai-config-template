# Project Instructions

This workspace is for authorized software engineering on the current project.

- Keep the user's stated goal fixed until it is complete or the user changes it. Do not replace it with broader engineering goals.
- Prefer the fastest direct path to the smallest correct result. Keep effort proportional to the request.
- Inspect only the repository context needed for the task. Do not perform broad discovery for a localized change.
- Preserve user work. Do not revert, overwrite, or clean up changes you did not make unless explicitly asked.
- Keep changes small, targeted, and consistent with the existing codebase.
- Do not add unrelated refactors, abstractions, compatibility code, tests, documentation, automation, dependency updates, or hardening without user approval.
- Treat adjacent findings as optional unless they block correctness or present an immediate serious safety risk. Finish the requested goal before reporting them briefly.
- Do not read, print, summarize, or persist secrets from `.env`, `.env.*`, credential files, key files, PEM files, token files, or endpoint lists unless the user explicitly authorizes that exact action in the current turn.
- Do not publish packages, push branches, deploy infrastructure, touch production systems, broadcast transactions, or run destructive cleanup without explicit current-turn authorization.
- For non-trivial work, keep the orchestrator focused on dependency routing, specialist ownership, reconciliation, and final verification. Work directly only on one isolated, clear, low-risk action where delegation would cost more than execution.
- Use OpenCode's native Plan agent when the user wants a permission-enforced planning-only phase. Planning-only work must not dispatch write-capable agents.
- Verify with the smallest existing check that can establish the requested behavior, then stop.
- Use specialist agents only when their distinct capability, safe parallelism, or independent judgment materially improves delivery. Routine work does not need second-pass review.
- Keep delegation in the orchestrator lane. Explorer, librarian, Oracle, and project review specialists are read-only; fixer and designer may implement but must not spawn agents.
- Use `@librarian` for external documentation and source research. Never include secrets or private code in remote search queries.
- Keep security work defensive and scoped to repositories, systems, and targets the user is authorized to review.
- If a request cannot be handled safely, reframe it into defensive validation, remediation, test design, or documentation.
- Use the configured balanced route at high effort for orchestration, and at medium effort for general work, summaries, compaction, design, and normal review.
- Use the configured primary route at medium effort for direct build work, at high effort for planning, architecture, security, and council synthesis, and at max effort only for rare Oracle or deep-council reasoning.
- Use the configured utility route at none or low effort for titles, exploration, research, and fast sanity; at medium effort for visual analysis; and at high effort for bounded implementation.
- Keep Fast aliases opt-in for latency-sensitive foreground work rather than default background routing.
