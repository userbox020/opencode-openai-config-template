# OpenCode Generic Project Config

Reusable OpenCode configuration for general software projects. It is OpenAI-first, project-agnostic, and conservative around secrets, destructive commands, publishing, deployments, and production access.

## What This Includes

- `template/.opencode/opencode.jsonc`: OpenCode project config.
- `template/.opencode/oh-my-opencode-slim.jsonc`: generic multi-agent routing for `oh-my-opencode-slim`.
- `template/.opencode/oh-my-opencode-slim/project-instructions.md`: project-wide working rules.
- `template/.opencode/oh-my-opencode-slim/orchestrator_append.md`: generic routing guidance.
- `template/.opencode/skills/project-workflow/SKILL.md`: reusable workflow skill for any codebase.
- `scripts/install.ps1`: Windows installer that copies the template into a project.
- `scripts/install.sh`: macOS/Linux installer that copies the template into a project.

No API keys, RPC endpoints, private keys, or project-specific paths are included.

## Defaults

- Core reasoning and orchestration: `openai/gpt-5.5` with `xhigh`.
- Fast exploration, fixing, design, titles, and summaries: `openai/gpt-5.3-codex-spark` with `xhigh`.
- Compaction: `openai/gpt-5.5` with `high`.
- Secret-like files are read-gated and edit-denied by default.
- Risky shell operations such as `git push`, package publish, production deploy, `kubectl`, `terraform apply`, live transaction broadcasts, and destructive cleanup ask first.

## Requirements

- OpenCode installed and available as `opencode` or `opencode.cmd`.
- The `oh-my-opencode-slim` OpenCode plugin available to OpenCode.
- OpenAI credentials or a compatible provider setup for the configured `openai/...` model IDs.

If your OpenCode setup uses different model names, edit both:

- `template/.opencode/opencode.jsonc`
- `template/.opencode/oh-my-opencode-slim.jsonc`

## Install Into A Project

From this repo on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ProjectPath C:\path\to\your-project
```

From this repo on macOS/Linux:

```bash
bash ./scripts/install.sh /path/to/your-project
```

If the target project already has `.opencode`, the installer stops unless you pass force mode.

Windows force mode:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ProjectPath C:\path\to\your-project -Force
```

macOS/Linux force mode:

```bash
FORCE=1 bash ./scripts/install.sh /path/to/your-project
```

Force mode merges and overwrites matching template files. It does not delete extra files in the target `.opencode` directory.

## Validate After Install

Run these from the target project:

```bash
opencode debug config
opencode debug agent orchestrator
opencode debug skill
```

Run a live model smoke test if desired:

```bash
opencode run --agent build "Respond with exactly: ROUTING_OK_CORE"
opencode run --agent build -m openai/gpt-5.3-codex-spark "Respond with exactly: ROUTING_OK_SPARK"
```

Restart any already-running OpenCode session after copying or editing config files. OpenCode loads config at startup.

## Included Agents

- `orchestrator`: primary project coordinator.
- `oracle`: focused clarification and second-pass reasoning.
- `code-reviewer`: correctness, maintainability, regression, and diff review.
- `repo-architect`: architecture, module boundaries, migration planning, and tradeoffs.
- `test-writer`: test strategy, fixtures, edge cases, and regression coverage.
- `security-reviewer`: defensive review for auth, secrets, injection, unsafe IO, dependencies, and deployment risk.

## Safety Rules

The template defaults to normal coding productivity while protecting common dangerous surfaces:

- Do not read or summarize secrets unless explicitly authorized in the current turn.
- Do not edit secret-bearing files.
- Ask before publishing packages, pushing git branches, deploying infrastructure, touching Kubernetes, running production migrations, or broadcasting transactions.
- Keep security work defensive and scoped to repositories, systems, and targets you are authorized to review.

## Upload To GitHub

If this folder is not already a git repo:

```bash
git init
git add .
git commit -m "Add generic OpenCode project config"
```

Create and push a private GitHub repo with GitHub CLI:

```bash
gh repo create opencode-generic-config-template --private --source . --remote origin --push
```

Change `--private` to `--public` only if you are sure the repo contains no private notes or project-specific details.
