---
name: project-workflow
description: Use when working in a software project with this generic OpenCode template; enforces goal lock, minimal edits, proportional verification, and safe execution.
---

# Project Workflow

Use this skill to complete the user's stated goal without turning it into a broader engineering program.

## Goal And Scope

- Identify the exact requested outcome and keep it as the primary goal.
- Separate required work from optional improvements.
- Do not adopt adjacent cleanup, refactors, modernization, extra features, or maintenance as new objectives.
- Ask before expanding scope. If no decision is needed, make the smallest reasonable assumption and proceed.
- Consider the task complete when the requested behavior works and proportionate verification passes.

## Fast Start

- Read only the files needed to locate and understand the relevant behavior.
- Infer project tooling and conventions from nearby code and manifests as needed; do not inventory the entire repository first.
- Check whether the worktree already has user changes before editing files that may overlap.
- Avoid reading secret-bearing files unless the user explicitly authorizes that exact action.
- Orchestrator routes non-trivial work once the dependency path is clear. Implementation agents start their assigned work directly. Do not write a formal plan or task list for one isolated action.

## Editing Discipline

- Prefer the smallest correct change.
- Match existing style, naming, formatting, and error-handling patterns.
- Keep new helpers local until there is a clear reuse need.
- Do not add backward compatibility unless required by persisted data, shipped APIs, external consumers, or an explicit user requirement.
- Do not change unrelated files while fixing a focused issue.
- Do not add infrastructure, abstractions, documentation, tests, or hardening unrelated to the acceptance condition.

## Verification

Use the cheapest decisive evidence from the repository's existing tooling:

- Run targeted tests for the changed area first.
- Run lint, typecheck, formatting checks, or builds only when relevant to the changed behavior or required by the repository.
- Do not create a new harness or broaden verification merely to increase confidence in unrelated areas.
- If a verification step is skipped, state why and what risk remains.
- If a failure is unrelated to the change, record the command and the observed failure without hiding it.
- Stop after the requested result is established. Do not continue with optional improvements.

## Delegation

Orchestrator only: direct execution is reserved for one isolated, clear, low-risk action where delegation would cost more than execution. For non-trivial work, focus on routing, reconciliation, and final verification. Build, Fixer, and Designer execute their assigned bounded work directly without spawning agents; read-only specialists inspect and report. Native Plan may delegate only read-only research to Explorer or Librarian.

The following routing choices are for Orchestrator, not instructions for specialists to delegate:

- `@explorer` for read-only repository discovery and code-path mapping.
- `@librarian` for external documentation, current APIs, and source research.
- `@fixer` for bounded headless implementation with clear ownership.
- `@designer` for user-visible UI/UX design and implementation.
- `@observer` for read-only visual and document analysis.
- `@oracle` for unresolved high-risk questions or persistent debugging; use `@repo-architect` for normal architecture work instead of duplicating both reviews.
- `@council` only when diverse model judgment is worth the extra cost.
- `@code-reviewer` for correctness, regressions, edge cases, and maintainability.
- `@repo-architect` for design tradeoffs, migrations, module boundaries, and rollout plans.
- `@test-writer` for reproduction, fixtures, and meaningful coverage.
- `@security-reviewer` for defensive auth, secret handling, injection, unsafe IO, dependencies, and deployment risks.

Give each writer a non-overlapping ownership boundary and each task a validation owner. Never use a specialist response to expand scope. When review is justified, send a compact handoff with the primary goal, exact concern, relevant files, and verification already run.

## Safety

- Do not print secrets, tokens, private keys, endpoint lists, or credential files.
- Ask before publishing packages, pushing git branches, deploying, touching production systems, running migrations, or destructive cleanup.
- Keep security analysis defensive and scoped to authorized repositories and systems.
