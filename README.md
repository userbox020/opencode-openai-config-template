# OpenCode OpenAI Project Config

Reusable OpenCode configuration for general software projects. It is OpenAI-specific, project-agnostic, and designed for ChatGPT OAuth usage while remaining compatible with OpenAI API-key authentication.

## What This Includes

- `template/.opencode/opencode.jsonc`: OpenCode project config and balanced core defaults.
- `template/.opencode/routing-profile.js`: synchronized `balanced` and `quality` profile selection.
- `template/.opencode/oh-my-opencode-slim.jsonc`: matching Slim agents, fallbacks, specialists, and council routes.
- `template/.opencode/oh-my-opencode-slim/project-instructions.md`: project-wide working rules.
- `template/.opencode/skills/project-workflow/SKILL.md`: reusable workflow skill for any codebase.
- `scripts/install.ps1`: Windows installer with interactive model selection.
- `scripts/install.sh`: macOS/Linux installer with interactive model selection.

No API keys, OAuth tokens, RPC endpoints, private keys, or project-specific paths are included.

## Routing Profiles

The default `balanced` profile uses Terra as the everyday workhorse, Luna for clear high-volume work, and Sol for difficult or high-value work. The optional `quality` profile promotes more work to Sol and raises reasoning effort.

| Work | Balanced default | Quality |
| --- | --- | --- |
| Orchestration and build | Terra medium | Sol medium |
| Planning and fixing | Sol high | Sol xhigh |
| General work | Terra medium | Sol medium |
| Exploration | Luna low | Terra low |
| Titles | Luna none | Luna none |
| Summaries | Luna low | Terra medium |
| Compaction | Terra medium | Sol medium |
| Oracle | Sol xhigh | Sol max |
| Council synthesis | Sol high | Sol xhigh |
| Librarian | Terra low | Sol medium |
| Design | Terra medium | Sol medium |
| Code review | Terra high | Sol xhigh |
| Architecture and security | Sol high | Sol xhigh |
| Test writing | Terra medium | Sol high |
| Deep council review | Sol xhigh | Sol max |
| Fast sanity | Luna low | Terra low |
| Security sanity | Terra high | Sol high |

The balanced profile sets `openai/gpt-5.6-terra` as OpenCode's default model and `openai/gpt-5.6-luna` as its small model. The quality profile changes those to Sol and Terra respectively.

### Switch Profiles

Balanced is used when no profile is specified. Select quality before starting OpenCode:

```powershell
$env:OPENCODE_ROUTING_PROFILE = "quality"
opencode.cmd
```

```bash
OPENCODE_ROUTING_PROFILE=quality opencode
```

Set the value to `balanced` to switch back. The accepted values are `balanced` and `quality`; an unknown value logs a warning and safely uses balanced. Restart OpenCode after changing the profile because configuration is loaded at startup.

Do not use Slim's `/preset` command to switch these profiles. It changes only Slim-managed agents and can temporarily desynchronize them from OpenCode's core routes. Use `OPENCODE_ROUTING_PROFILE` and start a fresh OpenCode process.

Do not put this variable in `.opencode/opencode.env`; OpenCode does not automatically source that file. Set it in the launching shell, shell profile, IDE launch configuration, or process manager.

## Pricing And Usage

Rates below were verified against official OpenAI documentation on 2026-07-31. Check the [Codex pricing page](https://developers.openai.com/codex/pricing) and [API pricing page](https://developers.openai.com/api/docs/pricing) for current values.

### ChatGPT OAuth

ChatGPT OAuth usage follows the shared Codex and ChatGPT agentic allowance. It is measured in credits after included plan usage, not billed as ordinary API traffic.

| Model | Input credits | Cached input credits | Output credits |
| --- | ---: | ---: | ---: |
| Sol | 125 | 12.5 | 750 |
| Terra | 50 | 5 | 300 |
| Luna | 5 | 0.5 | 30 |

Values are credits per 1M tokens. Codex does not charge for cache writes. Reasoning tokens are included in output usage, so higher efforts can consume substantially more credits even when visible answers stay short.

Approximate local-message limits for ChatGPT Plus and Business are 10-100 Sol, 25-200 Terra, or 250-2,000 Luna messages per shared five-hour window. Pro 5x and Pro 20x increase those ranges proportionally. Task size, context, reasoning, tools, caching, other agentic features, and additional weekly limits affect actual availability.

This cost and allowance ratio is why balanced routing uses Terra for ordinary coding and Luna for repeatable volume work instead of routing every task through Sol.

### API Key

Standard short-context USD API pricing per 1M tokens:

| Model | Input | Cache read | Cache write | Output |
| --- | ---: | ---: | ---: | ---: |
| Sol | $5.00 | $0.50 | $6.25 | $30.00 |
| Terra | $2.00 | $0.20 | $2.50 | $12.00 |
| Luna | $0.20 | $0.02 | $0.25 | $1.20 |

API requests above 272K input tokens use long-context rates for the full request: 2x input/cache rates and 1.5x output rates. API models advertise a 1.05M context window, 922K maximum input, and 128K maximum output. OpenCode 1.18.10 caps ChatGPT OAuth routes at 500K context, 372K input, and 128K output; effective workspace or server limits may be lower.

### Effort, Pro, And Fast

OpenCode 1.18.10 maps GPT-5.6 efforts `none`, `low`, `medium`, `high`, `xhigh`, and `max`. Use the lowest effort that meets the task's quality target. The template reserves `max` for the quality profile's hardest bounded work.

OpenCode's ChatGPT OAuth integration filters generated Pro-mode model IDs, including `openai/gpt-5.6-sol-pro`. This template therefore uses standard `openai/gpt-5.6-sol` with xhigh or max instead of pretending a Pro route is available.

Fast mode is intentionally excluded from active routing. With ChatGPT OAuth it provides roughly 1.5x speed for 2.5x credit consumption on GPT-5.6. API Fast processing has separate rates, currently 2x standard GPT-5.6 token prices.

## Fallback Behavior

Slim 2.0.5 does not preserve a secondary model entry's configured variant when foreground fallback replays a request. The fallback model receives its default effort, currently medium.

To avoid silent effort changes, this template configures automatic fallback only for medium-effort routes:

- Balanced orchestrator and designer: Terra medium to Sol medium.
- Quality orchestrator and designer: Sol medium to Terra medium.

High, xhigh, max, low, and none routes use one model and surface failures instead of silently changing effort or cost class. In Slim 2.0.5, foreground fallback is primarily triggered by recognized rate-limit, quota, usage, and overload errors. The plugin's `timeoutMs`, `retryDelayMs`, and `retry_on_empty` schema fields do not control ordinary foreground fallback, so this template does not configure them.

## Requirements

- OpenCode 1.18.10 or newer, available as `opencode` or `opencode.cmd`.
- ChatGPT OAuth access to Sol, Terra, and Luna, or an OpenAI API key with access to those models.
- The `oh-my-opencode-slim` plugin, pinned to tested version 2.0.5 for runtime and schema.
- Node.js or Python 3 for the macOS/Linux installer.

OpenCode 1.18.10 is required for GPT-5.6 max effort, current OAuth model filtering, cache-write usage accounting, and current OpenAI request options. Slim remains pinned to 2.0.5 because 2.2.8 changes council execution semantics and still does not preserve fallback variants.

## Install Into A Project

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ProjectPath C:\path\to\your-project
```

macOS/Linux:

```bash
bash ./scripts/install.sh /path/to/your-project
```

If the target project already has `.opencode`, the installer stops unless force mode is explicitly selected.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ProjectPath C:\path\to\your-project -Force
```

```bash
FORCE=1 bash ./scripts/install.sh /path/to/your-project
```

Both installers generate configuration in a temporary staging directory before changing the target. Force mode merges and overwrites matching template files but does not delete extra files from the target `.opencode` directory.

### Model Slots

Interactive installation selects three distinct OpenAI models and applies them to both routing profiles:

- `primary`: Sol by default; must support medium, high, xhigh, and max.
- `balanced`: Terra by default; must support low, medium, and high.
- `utility`: Luna by default; must support none and low.

When `opencode models openai` returns a catalog, typed IDs must appear in it. Pro-mode IDs ending in `-pro` are excluded because OpenCode's ChatGPT OAuth integration does not expose them. The three slots must be distinct so fallback and profile semantics do not collapse. Catalog presence does not prove that the active ChatGPT workspace or API key can execute every model or effort.

Skip prompts and keep defaults for automation:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ProjectPath C:\path\to\your-project -NonInteractive
```

```bash
bash ./scripts/install.sh /path/to/your-project --non-interactive
```

Set `OPENCODE_BIN` for either installer if the OpenCode executable has a custom name. Unix CI can set `OPENCODE_INSTALL_JSON_RUNTIME=node` or `OPENCODE_INSTALL_JSON_RUNTIME=python3` to exercise a specific installed JSON runtime.

## Validate After Install

Run the repository's dependency-free routing checks before installation:

```bash
node ./scripts/test-routing.js
node ./scripts/test-installers.js
bash -n ./scripts/install.sh
```

Run these from the target project with no profile variable to inspect balanced routing:

```bash
opencode debug config
opencode debug agent orchestrator
opencode debug agent build
opencode debug skill
```

Inspect quality routing in a fresh process:

```powershell
$env:OPENCODE_ROUTING_PROFILE = "quality"
opencode.cmd debug config
opencode.cmd debug agent orchestrator
opencode.cmd debug agent build
```

```bash
OPENCODE_ROUTING_PROFILE=quality opencode debug config
OPENCODE_ROUTING_PROFILE=quality opencode debug agent orchestrator
OPENCODE_ROUTING_PROFILE=quality opencode debug agent build
```

A routing smoke test should not pass `-m`, because `-m` overrides the route being tested:

```bash
opencode run --agent build "Respond with exactly: BALANCED_ROUTING_OK"
OPENCODE_ROUTING_PROFILE=quality opencode run --agent build "Respond with exactly: QUALITY_ROUTING_OK"
```

Direct `-m openai/...` calls are useful only for checking model availability. They do not verify configured routing.

## Included Agents

- `orchestrator`: primary project coordinator.
- `oracle`: focused clarification and independent deep reasoning.
- `code-reviewer`: correctness, maintainability, regression, and diff review.
- `repo-architect`: architecture, module boundaries, migration planning, and tradeoffs.
- `test-writer`: test strategy, fixtures, edge cases, and regression coverage.
- `security-reviewer`: defensive review for auth, secrets, injection, unsafe IO, dependencies, and deployment risk.

## Safety Rules

The template provides best-effort guardrails for common dangerous surfaces:

- Ask before reading common secret-bearing files and deny edits to them.
- Ask before publishing packages, pushing branches, deploying infrastructure, touching Kubernetes, running production migrations, or broadcasting transactions.
- Keep security work defensive and scoped to repositories, systems, and targets the user is authorized to review.

Permission patterns cannot recognize every possible secret filename or shell-command spelling. Project instructions remain part of the safety boundary, and users should review the permission rules for their environment.

## Upload To GitHub

If this folder is not already a Git repository:

```bash
git init
git add .
git commit -m "Add generic OpenCode project config"
```

Create and push a private GitHub repository with GitHub CLI:

```bash
gh repo create opencode-openai-config-template --private --source . --remote origin --push
```

Change `--private` to `--public` only after confirming the repository contains no private notes or project-specific details.
