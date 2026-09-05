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

## Scheduler-First GPT-5.6 Defaults

- **Terra** (`openai/gpt-5.6-terra`) handles high-effort orchestration and balanced general work, source synthesis, technical summaries, compaction, design, and normal review.
- **Sol** (`openai/gpt-5.6-sol`) handles direct build work at medium effort; planning, council synthesis, security review, and architecture at high effort; and rare Oracle or deep-council reasoning at max effort.
- **Luna** (`openai/gpt-5.6-luna`) handles high-volume specialist work: exploration and research at low effort, visual analysis at medium, bounded implementation at high, and titles at none.
- Core routing uses Terra as the default model and Luna as the small model. Build is Sol medium; native Plan is Sol high; general is Terra medium; Explore is Luna low; title is Luna none; and summary/compaction are Terra medium. Compaction retains 6 tail turns.
- The orchestrator retains OMOS 2.2.17's bundled scheduler-first prompt, with a goal-locking append: it builds the shortest useful dependency graph, delegates bounded non-trivial work, reconciles results, and owns final verification. It works directly only on one isolated, clear, low-risk action where delegation would cost more than execution.
- Runtime model fallback is disabled; provider errors do not trigger model-chain switches. Configured routes are: Orchestrator Terra high; Oracle Sol max; council Sol high; Explorer and Librarian Luna low; Fixer Luna high; Designer Terra medium; Observer Luna medium. OpenCode's same-model retries and explicit user model selection are separate behaviors.
- Council runs three dynamic councillor subagents in parallel. Deep review uses Sol max, fast sanity uses Luna low, and security sanity uses Terra high. Slim retries an empty councillor response once per model entry and handles council timing through its orchestrator prompt rather than obsolete timeout fields.
- Generic specialists route code review to Terra high, architecture to Sol high, test strategy to Terra medium, and security review to Sol high.
- These are template defaults. Customized installations substitute four model slots while retaining the documented role-specific effort variants.
- The orchestrator is the only implementation lane allowed to delegate. Native Plan may call only the read-only Explorer and Librarian. Fixer and Designer can edit but cannot spawn agents; Explorer, Librarian, Oracle, Observer, and the project review specialists are enforced read-only. `subagent_depth` is explicitly `1`.
- Librarian alone receives OpenCode's built-in web search plus the bundled Context7 and GitHub grep MCPs for external research. Other normal lanes are denied built-in web search and do not receive those MCPs.
- Observer is enabled with automatic image routing so screenshots, images, PDFs, and diagrams can be analyzed outside the orchestrator's main context.
- Slim's periodic orchestrator wake is explicitly disabled to avoid unplanned idle model calls. Background tasks, completion injection, and reconciliation remain enabled.
- Secret-like files are read-gated and edit-denied by default.
- Shell commands ask first by default, including `git push`, package publish, production deploy, `kubectl`, `terraform apply`, live transaction broadcasts, and destructive cleanup. Dedicated file tools remain available for normal repository inspection and edits.

## Models, Effort, Pricing, And Performance

Standard USD API pricing per 1M tokens, verified on **2026-09-04** against [official OpenAI API pricing](https://developers.openai.com/api/docs/pricing). These are direct API prices, not ChatGPT subscription credits or third-party hosting rates. Short-context rates apply through 272,000 input tokens:

| Model | Input | Cache read | Cache write | Output |
| --- | ---: | ---: | ---: | ---: |
| Astra (opt-in) | $10.00 | $1.00 | $12.50 | $50.00 |
| Sol | $4.00 | $0.40 | $5.00 | $20.00 |
| Terra | $2.00 | $0.20 | $2.50 | $12.00 |
| Luna | $0.20 | $0.02 | $0.25 | $1.20 |

OpenAI's current model pages document all four models with a 1,050,000-token context window, a 922,000-token maximum input, and a 128,000-token output limit. Requests above 272,000 input tokens are billed at the following rates for the **full request**, not just the excess:

| Model | Input | Cache read | Cache write | Output |
| --- | ---: | ---: | ---: | ---: |
| Astra (opt-in) | $20.00 | $2.00 | $25.00 | $75.00 |
| Sol | $8.00 | $0.80 | $10.00 | $30.00 |
| Terra | $4.00 | $0.40 | $5.00 | $18.00 |
| Luna | $0.40 | $0.04 | $0.50 | $1.80 |

Cache writes cost 1.25x uncached input and cache reads cost 0.1x for these models. The write rate is the total rate for write-classified tokens, not an extra 1.25x surcharge on top of ordinary input. Cache hits are not guaranteed. Reasoning tokens are billed as output, so `max` is neither a fixed token budget nor a fixed cost multiplier. Sol's current Standard pricing is promotional through at least 2026-11-21; that is not a confirmed end date or a published post-promotion price.

The reviewed OpenCode 1.18.29 catalog reports **400,000 context / 272,000 input / 128,000 output** for Sol/Terra/Luna, versus **1,050,000 / 922,000 / 128,000** for Astra. It also reports zero cost for all listed models in this environment; that does **not** mean inference is free. Use the effective host limits for context planning and official pricing/account billing for cost estimates. Do not raise context limits merely to match a provider headline.

OpenAI's [GPT-5.6 launch evaluations](https://openai.com/index/gpt-5-6/) support the current tiering. These are historical, versioned benchmarks, not evaluations of this template's exact prompts or workloads:

| Published evaluation | Sol | Terra | Luna |
| --- | ---: | ---: | ---: |
| Artificial Analysis Coding Agent Index v1.1 | 80.0 | 77.4 | 74.6 |
| SWE-Bench Pro | 64.6% | 63.4% | 62.7% |
| Terminal-Bench 2.1 | 88.8% | 87.4% | 84.7% |

OpenCode 1.18.29 exposes GPT-5.6 effort variants `none`, `low`, `medium`, `high`, `xhigh`, and `max`. This template reserves max for rare Oracle and deep-council reasoning rather than applying it globally.

Generated `-fast` aliases select the same underlying model with Fast service (`serviceTier: "priority"` in the reviewed host). [Fast pricing](https://developers.openai.com/api/docs/guides/fast-mode) is **2x every corresponding Standard rate** for all four models, including long-context rates. OpenAI advertises up to 2.5x faster service for Sol and up to 2x for Astra, not guaranteed end-to-end task speedups. Astra Fast is unavailable with EU data residency and has no latency SLA. Keep Fast opt-in for latency-sensitive work rather than paying the premium for every background task.

### GPT-6 Astra Assessment

[Astra's announcement](https://openai.com/index/gpt-6-astra/) describes a staged rollout. A host catalog entry does not guarantee that an API organization has access. At equal token usage and cache mix, Astra costs 2.5x Sol; actual cost per successful task can differ if Astra needs fewer steps or tokens.

| Current evaluation | Astra | Sol |
| --- | ---: | ---: |
| Terminal-Bench 4.0 | 57.9% | 37.3% |
| DeepSWE v1.1 | 74.1% | 72.7% |
| Artificial Analysis Coding Agent Index v1.4 | 67.0 | 65.1 |

These are OpenAI-reported maximum scores across efforts, not matched-budget measurements. Do not compare the v1.4 index with the older v1.1 table, or Terminal-Bench 4.0 with 2.1. They justify evaluating Astra for difficult work, not moving all agents to it.

Keep Terra for orchestration, Luna for frequent specialist work, and Sol for the shipped primary/deep slots. To evaluate Astra without changing routine routing, customize **only `deep`** to `openai/gpt-6-astra`. That seat remains at `max`, so keep the input focused and compare useful findings, billed tokens, and latency before changing defaults. No paid Astra benchmark was run for this review. Automatic model fallback remains disabled.

According to [Astra's migration guide](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra), tool calling requires the Responses API; Chat Completions does not support Astra tool calls. Keep effort explicit and do not add `temperature` or `top_p` overrides. Provider safety-monitoring blocks must be surfaced, not automatically retried or routed around.

Sources: [Astra model](https://developers.openai.com/api/docs/models/gpt-6-astra), [Sol model](https://developers.openai.com/api/docs/models/gpt-5.6-sol), [Terra model](https://developers.openai.com/api/docs/models/gpt-5.6-terra), [Luna model](https://developers.openai.com/api/docs/models/gpt-5.6-luna), [prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching), [reasoning](https://developers.openai.com/api/docs/guides/reasoning).

## Requirements

- OpenCode installed and available as `opencode` or `opencode.cmd`. Configuration resolution is checked with OpenCode 1.18.29.
- The `oh-my-opencode-slim` OpenCode plugin, pinned by this template to tested version 2.2.17 for both runtime loading and the editor schema.
- OpenAI credentials for the configured `openai/...` model IDs.
- The macOS/Linux installer requires Node.js or Python 3 and verifies the runtime before copying or overwriting destination files.

OMOS 2.2.18 was available at review time, but this update retains the verified 2.2.17 pin. New model IDs do not require changing that pin. Evaluate plugin upgrades separately with background-task and prompt-loading checks rather than bundling them into a pricing update.

The installer queries `opencode models openai` for interactive customization. Catalog presence does not guarantee runtime availability or account access. The 2026-09-04 review checked catalog capabilities and configuration resolution, not paid inference. Earlier GPT-5.6 runtime smoke checks are point-in-time evidence, not a guarantee of current provider health. If your setup uses different model names, select them during install or edit both:

- `template/.opencode/opencode.jsonc`
- `template/.opencode/oh-my-opencode-slim.jsonc`

## Required Runtime Environment

Launch OpenCode for this project with the two required feature flags and the project-scoped preset override:

```text
OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true
OPENCODE_ENABLE_EXA=1
OH_MY_OPENCODE_SLIM_PRESET=generic-openai
```

The preset variable selects this project's `generic-openai` preset instead of an inherited preset name. It does not override every other configuration layer. OMOS merges top-level `agents.<name>` over preset entries, including inherited user-level agent settings; core OpenCode `agent.<name>` fields can also override plugin-generated routing. Inspect effective configuration rather than assuming the preset wins. The installed `.opencode/opencode.env` records the values but OpenCode does not load that file automatically. Use the one-shot launch commands below; only the two feature flags are suitable for cross-project shell profiles.

PowerShell one-shot launch:

```powershell
$env:OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true"
$env:OPENCODE_ENABLE_EXA = "1"
$env:OH_MY_OPENCODE_SLIM_PRESET = "generic-openai"
opencode.cmd
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

The installer asks whether to customize model routing. Only if you choose yes does it query OpenCode, then show each routing slot, its description, default model, and numbered OpenAI models. Non-interactive installs and declining customization skip the catalog query.

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

Force installation stops before target changes if a full Orchestrator prompt exists at `.opencode/oh-my-opencode-slim/orchestrator.md` or `.opencode/oh-my-opencode-slim/generic-openai/orchestrator.md`. Older templates shipped the first path, and customized replacements have the same precedence. Review and back up/rename that replacement before retrying; use `orchestrator_append.md` for project-specific additions to the bundled scheduler prompt. The installer does not delete these user-owned files automatically. User-level and other preset-specific full prompt overrides can also supersede the bundled prompt and must be inspected separately.

## Interactive Model Routing

The installer prompts for four model slots while preserving all role-specific effort variants:

- `primary`: Sol for build, Plan, Oracle, architecture, security, and council synthesis.
- `balanced`: Terra for orchestration, general work, synthesis, summaries, compaction, design, and normal review.
- `utility`: Luna for exploration, research, bounded implementation, visual analysis, titles, and fast sanity checks.
- `deep`: Sol at max effort for the bounded deep-review council member only. It is a separate slot so customized installs can select another max-capable model.

Customization accepts only model IDs of the form `openai/<model>` with no internal whitespace. A custom choice replaces a model slot but retains the template's fixed effort variants, so every selected OpenAI model must support the variants used by that slot.

| Slot | Required efforts |
| --- | --- |
| `primary` | `medium`, `high`, `max` |
| `balanced` | `medium`, `high` |
| `utility` | `none`, `low`, `medium`, `high` |
| `deep` | `max` |

The newly catalogued `openai/gpt-6-astra` and `openai/gpt-6-astra-fast` support `low`, `medium`, `high`, `xhigh`, and `max` in OpenCode 1.18.29, but not `none`. They are compatible with the `primary`, `balanced`, and `deep` slot efforts, not the `utility` slot's title generation at `none`. Both installers reject these two Astra IDs for utility before changing target files, including in force mode. Keep Luna for utility work instead of silently changing the title effort or paying flagship rates for every small task. Other custom IDs still require checking `opencode models openai --verbose` against the table; the installer is not a general provider-capability validator.

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

To verify the template's **effective** model/effort assignments, including inherited overrides and host catalog support, run:

```bash
node ./scripts/test.mjs --opencode
```

This optional check requires `opencode` (`opencode.cmd` on Windows), loads the pinned plugin with the project preset, and makes no inference requests. It does not print the full resolved configuration. A routing mismatch identifies the affected agent; review inherited OMOS `agents` and core `agent` settings rather than changing user-level configuration blindly. Passing does not prove API account access or runtime tool behavior.

On Windows with Git Bash, use `node ./scripts/test.mjs --bash` to exercise the Bash installer as well. Set `BASH_BIN` to its executable path if `bash` is not on `PATH`. Bash selects Node when available, otherwise Python 3; exercising both JSON runtime paths still requires controlling the test environment's `PATH`.

Run these from the target project:

```bash
opencode debug config
opencode debug agent orchestrator
opencode debug skill
npx --yes oh-my-opencode-slim@2.2.17 doctor
```

In PowerShell, use `opencode.cmd` and `npx.cmd` for these commands if execution policy blocks the `.ps1` wrappers. Apply the project-scoped environment variables above before plugin-aware checks. Debug commands can expose merged user configuration; inspect locally and redact sensitive values before sharing output.

Run a paid live model smoke test if desired:

```bash
opencode run --agent build -m openai/gpt-5.6-sol "Respond with exactly: ROUTING_OK_SOL"
opencode run --agent build -m openai/gpt-5.6-terra "Respond with exactly: ROUTING_OK_TERRA"
opencode run --agent build -m openai/gpt-5.6-luna "Respond with exactly: ROUTING_OK_LUNA"
opencode run --agent build -m openai/gpt-5.6-sol --variant max "Respond with exactly: ROUTING_OK_SOL_MAX"
```

Launch with the required environment variables and restart any already-running OpenCode session after copying or editing config files. OpenCode loads config at startup.

## Included Agents

- `orchestrator`: primary project coordinator.
- `oracle`: focused clarification and second-pass reasoning.
- `explorer`: read-only repository discovery and code-path mapping.
- `librarian`: read-only external documentation and source research.
- `fixer`: bounded implementation without subagent delegation.
- `designer`: UI/UX implementation and review without subagent delegation.
- `observer`: read-only image, screenshot, PDF, and diagram analysis.
- `council`: explicit, higher-cost multi-model review.
- `code-reviewer`: correctness, maintainability, regression, and diff review.
- `repo-architect`: architecture, module boundaries, migration planning, and tradeoffs.
- `test-writer`: test strategy, fixtures, edge cases, and regression coverage.
- `security-reviewer`: defensive review for auth, secrets, injection, unsafe IO, dependencies, and deployment risk.

## Planning-Only Work

Use OpenCode's native Plan agent for a stricter planning-only workflow instead of asking the Orchestrator to plan and hoping it does not begin implementation. Plan may inspect the repository and delegate only to the read-only Explorer or Librarian; write-capable agents, OMOS mutators, and nested delegation remain blocked. Direct edits are restricted to OpenCode's native plan-file locations.

The template intentionally omits a global `edit: "allow"` rule. OpenCode already allows normal edits by default, while a later global allow can override the built-in Plan agent's edit denial. Secret-like file edits remain explicitly denied.

Treat Plan as a workflow guardrail, not a security sandbox. Native plan-file writes remain allowed, shell commands can still be approved, and permission enforcement depends on the installed host and plugins. Use OS-level read-only isolation when a strict filesystem boundary is required; configuration checks alone do not establish that boundary.

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
