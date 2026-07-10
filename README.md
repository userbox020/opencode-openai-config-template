# OpenCode Generic Project Config

Reusable OpenCode configuration for general software projects. It is OpenAI-first, project-agnostic, and conservative around secrets, destructive commands, publishing, deployments, and production access.

## What This Includes

- `template/.opencode/opencode.jsonc`: OpenCode project config.
- `template/.opencode/oh-my-opencode-slim.jsonc`: generic multi-agent routing for `oh-my-opencode-slim`.
- `template/.opencode/oh-my-opencode-slim/project-instructions.md`: project-wide working rules.
- `template/.opencode/oh-my-opencode-slim/orchestrator_append.md`: generic routing guidance.
- `template/.opencode/skills/project-workflow/SKILL.md`: reusable workflow skill for any codebase.
- `scripts/install.ps1`: Windows installer with interactive model selection.
- `scripts/install.sh`: macOS/Linux installer with interactive model selection.

No API keys, RPC endpoints, private keys, or project-specific paths are included.

## Defaults

- Runtime-verified OpenAI models only: `openai/gpt-5.6-sol` for primary/deep work and `openai/gpt-5.6-terra` for fast/balanced work. Luna is intentionally excluded because it may be catalog-listed but unavailable at runtime; the generic `openai/gpt-5.6` alias is not used.
- Core routing: Sol default; Terra small model; build Sol medium; plan Sol high; general Terra medium; explore/title Terra low; summary/compaction Terra medium. Compaction retains 6 tail turns.
- Built-in fallback routing: orchestrator Sol medium → Terra medium; Oracle Sol xhigh → Terra high; council Sol high → Terra high; explorer/librarian Terra low → Sol low; fixer Sol high → Terra high; designer Terra medium → Sol high.
- Council retries once. Deep review uses Sol xhigh, fast sanity uses Terra low, and balanced security review uses Terra high.
- Generic specialists route code review to Terra high, architecture to Sol xhigh, test writing to Terra medium, and high-stakes security review to Sol xhigh.
- These are template defaults. Customized installations substitute the selected primary and balanced models while retaining the documented effort variants and fallback order.
- Secret-like files are read-gated and edit-denied by default.
- Risky shell operations such as `git push`, package publish, production deploy, `kubectl`, `terraform apply`, live transaction broadcasts, and destructive cleanup ask first.

## Requirements

- OpenCode installed and available as `opencode` or `opencode.cmd`.
- The `oh-my-opencode-slim` OpenCode plugin available to OpenCode.
- OpenAI credentials or a compatible provider setup for the configured `openai/...` model IDs.
- The macOS/Linux installer requires Node.js or Python 3 and verifies the runtime before copying or overwriting destination files.

The installer queries `opencode models openai` for interactive customization. Catalog presence does not guarantee runtime availability; the defaults are the runtime-verified Sol and Terra IDs above. If your setup uses different model names, select them during install or edit both:

- `template/.opencode/opencode.jsonc`
- `template/.opencode/oh-my-opencode-slim.jsonc`

## Install Into A Project

From this repo on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ProjectPath C:\path\to\your-project
```

The installer asks whether to customize model routing. If you choose yes, it shows each routing slot, a short description, the default model, and the numbered models returned by OpenCode.

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

## Interactive Model Routing

The installer prompts for two model slots while preserving all role-specific effort variants and fallback order:

- `primary`: defaults to Sol for planning, fixing, Oracle, architecture, and high-stakes specialist work.
- `balanced`: defaults to Terra for routine orchestration, general work, exploration, docs, design, titles, summaries, and compaction.

Use a different provider model list:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ProjectPath C:\path\to\your-project -Provider anthropic
```

```bash
bash ./scripts/install.sh /path/to/your-project --provider anthropic
```

Skip prompts and keep defaults for automation:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ProjectPath C:\path\to\your-project -NonInteractive
```

```bash
bash ./scripts/install.sh /path/to/your-project --non-interactive
```

You can also set `OPENCODE_MODEL_PROVIDER` for the Unix installer, or `OPENCODE_BIN` if your OpenCode binary has a custom name.

## Validate After Install

Run these from the target project:

```bash
opencode debug config
opencode debug agent orchestrator
opencode debug skill
```

Run a live model smoke test if desired:

```bash
opencode run --agent build -m openai/gpt-5.6-sol "Respond with exactly: ROUTING_OK_SOL"
opencode run --agent build -m openai/gpt-5.6-terra "Respond with exactly: ROUTING_OK_TERRA"
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
