# OpenCode OpenAI Generic Project Config

Reusable OpenCode configuration for general software projects. It is OpenAI-specific, project-agnostic, and conservative around secrets, destructive commands, publishing, deployments, and production access.

## What This Includes

- `template/.opencode/opencode.jsonc`: OpenCode project config.
- `template/.opencode/oh-my-opencode-slim.jsonc`: generic multi-agent routing for `oh-my-opencode-slim`.
- `template/.opencode/oh-my-opencode-slim/project-instructions.md`: project-wide working rules.
- `template/.opencode/oh-my-opencode-slim/orchestrator_append.md`: generic routing guidance.
- `template/.opencode/skills/project-workflow/SKILL.md`: reusable workflow skill for any codebase.
- `scripts/install.ps1`: Windows installer with interactive model selection.
- `scripts/install.sh`: macOS/Linux installer with interactive model selection.

No API keys, RPC endpoints, private keys, or project-specific paths are included.

## Balanced GPT-5.6 Defaults

- **Sol** (`openai/gpt-5.6-sol`) handles routine orchestration and build at medium effort, plus planning, fixing, security review, and architecture at high effort. Oracle escalation uses Sol xhigh.
- **Terra** (`openai/gpt-5.6-terra`) handles general work, source synthesis, technical summaries, compaction, design, and normal review.
- **Luna** (`openai/gpt-5.6-luna`) handles utility/high-volume work: exploration and fast sanity at low effort, and titles at none.
- **Sol-Pro** (`openai/gpt-5.6-sol-pro`) is reserved for one bounded deep-review council member at high effort. It maps to `reasoning.mode=pro`.
- Core routing uses Sol as the default model and Luna as the small model. Build is Sol medium; plan is Sol high; general is Terra medium; explore is Luna low; title is Luna none; and summary/compaction are Terra medium. Compaction retains 6 tail turns.
- Equal-effort fallbacks accommodate Slim 2.0.5 behavior: orchestrator Sol medium → Terra medium; Oracle Sol xhigh → Terra xhigh; council Sol high → Terra high; explorer Luna low → Terra low; librarian Terra low → Luna low; fixer Sol high → Terra high; designer Terra medium → Sol medium.
- Council configuration sets a 300-second timeout and requests one councillor retry. Deep review uses Sol-Pro high, fast sanity uses Luna low, and security sanity uses Terra high.
- Generic specialists route code review to Terra high, architecture to Sol high, test writing to Terra medium, and security review to Sol high.
- These are template defaults. Customized installations substitute four model slots while retaining the documented effort variants and fallback order.
- Secret-like files are read-gated and edit-denied by default.
- Risky shell operations such as `git push`, package publish, production deploy, `kubectl`, `terraform apply`, live transaction broadcasts, and destructive cleanup ask first.

## Models, Effort, And Pricing

Base USD API pricing per 1M tokens as of 2026-07-14 is shown below. Check the [official OpenAI API pricing](https://openai.com/api/pricing/) for current rates.

| Model | Input | Cache read | Output |
| --- | ---: | ---: | ---: |
| Sol | $5.00 | $0.50 | $30.00 |
| Terra | $2.50 | $0.25 | $15.00 |
| Luna | $1.00 | $0.10 | $6.00 |

Sol, Terra, and Luna all have about 1.05M tokens of context and a 128K maximum output. Higher-context rates apply above 272K input tokens. Sol-Pro pricing is not listed here; check current official pricing before running deep-review work.

OpenCode 1.17.12 effectively supports GPT-5.6 effort variants `none`, `low`, `medium`, `high`, and `xhigh`. The default template intentionally never configures `max`: OpenCode stores that value but does not map it to an OpenAI request option, so the defaults use xhigh instead. `-fast` models request the priority service tier; they do not guarantee lower latency or higher quality and are intentionally excluded from the default active routing. Sol-Pro is used only for bounded deep review rather than routine work.

## Requirements

- OpenCode installed and available as `opencode` or `opencode.cmd`. This template is tested with OpenCode 1.17.12.
- The `oh-my-opencode-slim` OpenCode plugin, pinned by this template to tested version 2.0.5 for both runtime loading and the editor schema.
- OpenAI credentials for the configured `openai/...` model IDs.
- The macOS/Linux installer requires Node.js or Python 3 and verifies the runtime before copying or overwriting destination files.

The installer queries `opencode models openai` for interactive customization. Catalog presence does not guarantee runtime availability; the defaults are the runtime-verified Sol, Terra, Luna, and Sol-Pro IDs above. If your setup uses different model names, select them during install or edit both:

- `template/.opencode/opencode.jsonc`
- `template/.opencode/oh-my-opencode-slim.jsonc`

## Install Into A Project

From this repo on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ProjectPath C:\path\to\your-project
```

The installer asks whether to customize model routing. If you choose yes, it shows each routing slot, a short description, the default model, and the numbered OpenAI models returned by OpenCode.

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

Both installers finish prompting and generate the customized configuration in a temporary staging directory before creating or changing the target `.opencode`. Staging is cleaned on success or error. Force mode then merges and overwrites matching template files; it does not delete extra files in the target `.opencode` directory.

## Interactive Model Routing

The installer prompts for four model slots while preserving all role-specific effort variants and fallback order:

- `primary`: Sol for orchestration, build, planning, fixing, Oracle, architecture, and security work.
- `balanced`: Terra for general work, synthesis, summaries, compaction, design, and normal review.
- `utility`: Luna for exploration, titles, high-volume utility work, and fast sanity checks.
- `deep`: Sol-Pro for the bounded deep-review council member only.

Customization accepts only model IDs of the form `openai/<model>` with no internal whitespace. A custom choice replaces a model slot but retains the template's fixed effort variants and fallback positions, so every selected OpenAI model must support the variants used by that slot.

Skip prompts and keep defaults for automation:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ProjectPath C:\path\to\your-project -NonInteractive
```

```bash
bash ./scripts/install.sh /path/to/your-project --non-interactive
```

You can set `OPENCODE_BIN` for the Unix installer if your OpenCode binary has a custom name. Both installers always query `opencode models openai`; provider customization is not supported.

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
opencode run --agent build -m openai/gpt-5.6-luna "Respond with exactly: ROUTING_OK_LUNA"
opencode run --agent build -m openai/gpt-5.6-sol-pro "Respond with exactly: ROUTING_OK_SOL_PRO"
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
gh repo create opencode-openai-config-template --private --source . --remote origin --push
```

Change `--private` to `--public` only if you are sure the repo contains no private notes or project-specific details.

Future repository links should use `https://github.com/<owner>/opencode-openai-config-template`.
