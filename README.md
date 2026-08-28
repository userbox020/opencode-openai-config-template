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
- The orchestrator uses a goal-locked fast path: direct execution is the default, effort stays proportional to the request, optional findings do not become new objectives, and work stops after targeted verification establishes the requested result.
- Equal-effort fallbacks use Slim 2.2.17 model chains: orchestrator Sol medium → Terra medium; Oracle Sol xhigh → Terra xhigh; council Sol high → Terra high; explorer Luna low → Terra low; librarian Terra low → Luna low; fixer Sol high → Terra high; designer Terra medium → Sol medium.
- Council runs three dynamic councillor subagents in parallel. Deep review uses Sol-Pro high, fast sanity uses Luna low, and security sanity uses Terra high. Slim retries an empty councillor response once per model entry and handles council timing through its orchestrator prompt rather than obsolete timeout fields.
- Generic specialists route code review to Terra high, architecture to Sol high, test strategy to Terra medium, and security review to Sol high.
- These are template defaults. Customized installations substitute four model slots while retaining the documented effort variants and fallback order.
- The orchestrator is the only normal lane allowed to delegate, but does so only for a missing specialist capability, materially useful parallelism, or justified high-risk review. Fixer and designer can edit but cannot spawn agents; explorer, librarian, Oracle, and the project review specialists are enforced read-only.
- Librarian alone receives OpenCode's built-in web search plus the bundled Context7 and GitHub grep MCPs for external research. Other normal lanes are denied built-in web search and do not receive those MCPs.
- Slim's periodic orchestrator wake is explicitly disabled to avoid unplanned idle model calls. Background tasks, completion injection, and reconciliation remain enabled.
- Secret-like files are read-gated and edit-denied by default.
- Shell commands ask first by default, including `git push`, package publish, production deploy, `kubectl`, `terraform apply`, live transaction broadcasts, and destructive cleanup. Dedicated file tools remain available for normal repository inspection and edits.

## Models, Effort, Pricing, And Performance

Standard short-context USD API pricing per 1M tokens as of 2026-08-27 is shown below. Check the [official OpenAI API pricing](https://developers.openai.com/api/docs/pricing) for current rates.

| Model | Input | Cache read | Cache write | Output |
| --- | ---: | ---: | ---: | ---: |
| Sol | $4.00 | $0.40 | $5.00 | $20.00 |
| Terra | $2.00 | $0.20 | $2.50 | $12.00 |
| Luna | $0.20 | $0.02 | $0.25 | $1.20 |

All three models have a 1,050,000-token context window, a 922,000-token maximum input, and a 128,000-token provider output limit. Requests above 272,000 input tokens are billed at the following rates for the full request:

| Model | Input | Cache read | Cache write | Output |
| --- | ---: | ---: | ---: | ---: |
| Sol | $8.00 | $0.80 | $10.00 | $30.00 |
| Terra | $4.00 | $0.40 | $5.00 | $18.00 |
| Luna | $0.40 | $0.04 | $0.50 | $1.80 |

GPT-5.6 cache writes cost 1.25x uncached input and cache reads cost 0.1x. Sol's current Standard pricing is promotional through at least 2026-11-21 and should be reviewed again near that date.

OpenAI's published coding results support the current tiering. These are general benchmarks, not evaluations of this template's exact prompts or workloads:

| Published evaluation | Sol | Terra | Luna |
| --- | ---: | ---: | ---: |
| Artificial Analysis Coding Agent Index v1.1 | 80.0 | 77.4 | 74.6 |
| SWE-Bench Pro | 64.6% | 63.4% | 62.7% |
| Terminal-Bench 2.1 | 88.8% | 87.4% | 84.7% |

OpenCode 1.18.23 exposes GPT-5.6 effort variants `none`, `low`, `medium`, `high`, and `xhigh`. The OpenAI API also supports `max`, but OpenCode 1.18.23 does not expose it for GPT-5.6, so the template continues to use xhigh for its strongest normal route. OpenCode also defaults requests to 32,000 output tokens even though the provider supports 128,000. Set `OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=128000` before launch only when a workload genuinely needs larger single responses; the lower default limits latency and runaway output cost.

Generated `-fast` aliases request Fast mode, which costs 2x the Standard GPT-5.6 rates and can deliver up to 2.5x faster service. They remain excluded from default routing. `openai/gpt-5.6-sol-pro` is a generated Sol mode alias that sends `reasoning.mode=pro`, not a separate base model. Pro mode uses Sol's per-token rates but performs more aggregate model work, increasing billed tokens and latency, so it remains bounded to deep review.

## Requirements

- OpenCode installed and available as `opencode` or `opencode.cmd`. This template is tested with OpenCode 1.18.23.
- The `oh-my-opencode-slim` OpenCode plugin, pinned by this template to tested version 2.2.17 for both runtime loading and the editor schema.
- OpenAI credentials for the configured `openai/...` model IDs.
- The macOS/Linux installer requires Node.js or Python 3 and verifies the runtime before copying or overwriting destination files.

The installer queries `opencode models openai` for interactive customization. Catalog presence does not guarantee runtime availability; the defaults are the runtime-verified Sol, Terra, Luna, and Sol-Pro IDs above. If your setup uses different model names, select them during install or edit both:

- `template/.opencode/opencode.jsonc`
- `template/.opencode/oh-my-opencode-slim.jsonc`

## Required Runtime Environment

Launch OpenCode for this project with the two required feature flags and the project-scoped preset override:

```text
OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true
OPENCODE_ENABLE_EXA=1
OH_MY_OPENCODE_SLIM_PRESET=generic-openai
```

The preset variable prevents a user-level `OH_MY_OPENCODE_SLIM_PRESET` from overriding this project's custom `generic-openai` routing. The installed `.opencode/opencode.env` records the values but OpenCode does not load that file automatically. Use the one-shot launch commands below; only the two feature flags are suitable for cross-project shell profiles.

PowerShell one-shot launch:

```powershell
$env:OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true"
$env:OPENCODE_ENABLE_EXA = "1"
$env:OH_MY_OPENCODE_SLIM_PRESET = "generic-openai"
opencode
```

PowerShell persistent user environment for the two cross-project feature flags:

```powershell
[Environment]::SetEnvironmentVariable("OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS", "true", "User")
[Environment]::SetEnvironmentVariable("OPENCODE_ENABLE_EXA", "1", "User")
```

Open a new terminal after setting persistent variables. Keep `OH_MY_OPENCODE_SLIM_PRESET=generic-openai` in this project's one-shot launch command or a project-specific wrapper; setting it globally would override Slim routing in unrelated projects.

macOS/Linux one-shot launch:

```bash
OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true OPENCODE_ENABLE_EXA=1 OH_MY_OPENCODE_SLIM_PRESET=generic-openai opencode
```

For persistent setup, add the two feature flags to the startup file for your shell and open a new terminal:

```bash
export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true
export OPENCODE_ENABLE_EXA=1
```

Keep `OH_MY_OPENCODE_SLIM_PRESET=generic-openai` project-scoped in the one-shot command or a project-specific wrapper.

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

Both installers finish prompting and generate the customized configuration in a temporary staging directory before creating or changing the target `.opencode`. They copy a fixed allowlist of template files and directories, excluding OpenCode-generated `node_modules`, package manifests, lockfiles, and local `.gitignore` state. The shipped JSONC files intentionally remain valid strict JSON so PowerShell, Node.js, and Python can customize them without an extra parser dependency. Staging is cleaned on success or error. Force mode then merges and overwrites matching template files; it does not delete extra files in the target `.opencode` directory.

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

You can set `OPENCODE_BIN` for either installer if your OpenCode binary has a custom name. Both installers query that binary for `models openai`; provider customization is not supported.

## Validate After Install

Run the repository's dependency-free config and native-installer checks first:

```bash
node ./scripts/test.mjs
```

Run these from the target project:

```bash
opencode debug config
opencode debug agent orchestrator
opencode debug skill
npx --yes oh-my-opencode-slim@2.2.17 doctor
```

Run a paid live model smoke test if desired:

```bash
opencode run --agent build -m openai/gpt-5.6-sol "Respond with exactly: ROUTING_OK_SOL"
opencode run --agent build -m openai/gpt-5.6-terra "Respond with exactly: ROUTING_OK_TERRA"
opencode run --agent build -m openai/gpt-5.6-luna "Respond with exactly: ROUTING_OK_LUNA"
opencode run --agent build -m openai/gpt-5.6-sol-pro "Respond with exactly: ROUTING_OK_SOL_PRO"
```

Launch with the required environment variables and restart any already-running OpenCode session after copying or editing config files. OpenCode loads config at startup.

## Included Agents

- `orchestrator`: primary project coordinator.
- `oracle`: focused clarification and second-pass reasoning.
- `explorer`: read-only repository discovery and code-path mapping.
- `librarian`: read-only external documentation and source research.
- `fixer`: bounded implementation without subagent delegation.
- `designer`: UI/UX implementation and review without subagent delegation.
- `council`: explicit, higher-cost multi-model review.
- `code-reviewer`: correctness, maintainability, regression, and diff review.
- `repo-architect`: architecture, module boundaries, migration planning, and tradeoffs.
- `test-writer`: test strategy, fixtures, edge cases, and regression coverage.
- `security-reviewer`: defensive review for auth, secrets, injection, unsafe IO, dependencies, and deployment risk.

## Safety Rules

The template defaults to dedicated file tools for normal coding work and asks before shell execution to protect common dangerous surfaces:

- Do not read or summarize secrets unless explicitly authorized in the current turn.
- Do not edit secret-bearing files.
- Do not place secrets or private code in librarian queries because enabled research MCPs send queries to remote services.
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
