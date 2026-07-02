---
name: project-workflow
description: Use when working in any software project with this generic OpenCode template; covers repository discovery, safe edits, verification, review handoffs, and secret handling.
---

# Project Workflow

Use this skill for normal software work in repositories that use the generic OpenCode project template.

## Startup

Before changing code:

- Identify the project type, package manager, build system, test framework, and local conventions from files already in the repo.
- Read project docs such as `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, package manifests, build files, and nearby code.
- Check whether the worktree already has user changes before editing files that may overlap.
- Avoid reading secret-bearing files unless the user explicitly authorizes that exact action.

## Editing Discipline

- Prefer the smallest correct change.
- Match existing style, naming, formatting, and error-handling patterns.
- Keep new helpers local until there is a clear reuse need.
- Do not add backward compatibility unless required by persisted data, shipped APIs, external consumers, or an explicit user requirement.
- Do not change unrelated files while fixing a focused issue.

## Verification

Choose verification from the repository's existing tooling:

- Run targeted tests for the changed area first.
- Run lint, typecheck, formatting checks, or build commands when they are relevant and reasonably available.
- If a verification step is skipped, state why and what risk remains.
- If a failure is unrelated to the change, record the command and the observed failure without hiding it.

## Review Handoffs

Use focused agents when they improve quality:

- `@code-reviewer` for correctness, regressions, edge cases, and maintainability.
- `@repo-architect` for design tradeoffs, migrations, module boundaries, and rollout plans.
- `@test-writer` for reproduction, fixtures, and meaningful coverage.
- `@security-reviewer` for defensive auth, secret handling, injection, unsafe IO, dependencies, and deployment risks.

Send reviewers a compact handoff with the files changed, intended behavior, assumptions, verification run, and exact concerns.

## Safety

- Do not print secrets, tokens, private keys, endpoint lists, or credential files.
- Ask before publishing packages, pushing git branches, deploying, touching production systems, running migrations, or destructive cleanup.
- Keep security analysis defensive and scoped to authorized repositories and systems.
