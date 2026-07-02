#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH=""
FORCE="${FORCE:-0}"
NON_INTERACTIVE="${NON_INTERACTIVE:-0}"
PROVIDER="${OPENCODE_MODEL_PROVIDER:-openai}"
OPENCODE_BIN="${OPENCODE_BIN:-opencode}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)
      FORCE="1"
      ;;
    --non-interactive)
      NON_INTERACTIVE="1"
      ;;
    --provider)
      shift
      if [[ $# -eq 0 ]]; then
        echo "--provider requires a value" >&2
        exit 1
      fi
      PROVIDER="$1"
      ;;
    -h|--help)
      echo "Usage: bash ./scripts/install.sh [project-path] [--force] [--non-interactive] [--provider openai]"
      exit 0
      ;;
    *)
      if [[ -n "$PROJECT_PATH" ]]; then
        echo "Unexpected argument: $1" >&2
        exit 1
      fi
      PROJECT_PATH="$1"
      ;;
  esac
  shift
done

PROJECT_PATH="${PROJECT_PATH:-$PWD}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/template/.opencode"
DEST_DIR="$PROJECT_PATH/.opencode"

MODEL_KEYS=(core explorer fixer designer title summary compaction librarian reviewer architect test security)
MODEL_TITLES=(
  "Core reasoning and orchestration"
  "Explorer and code search"
  "Fixer and bounded implementation"
  "Designer and UI/UX work"
  "Title generation"
  "Summary generation"
  "Context compaction"
  "Librarian and docs research"
  "Code reviewer"
  "Architecture reviewer"
  "Test writer"
  "Security reviewer"
)
MODEL_DESCRIPTIONS=(
  "Primary coordinator plus built-in build, plan, and general agents. Use your strongest reliable coding model."
  "Fast repo navigation, grep, file discovery, and context mapping. Use a fast inexpensive coding model."
  "Focused code edits after scope is clear. Use a fast coding model that is good at mechanical changes."
  "User-facing UI, responsive layout, visual polish, and interaction changes. Use a model that handles frontend design well."
  "Short session or conversation titles. Use a fast cheap model; this does not need deep reasoning."
  "Short session summaries and handoff summaries. Use a fast model with decent compression quality."
  "Compresses long conversations before continuing. Use a reliable model because bad compaction loses context."
  "External docs, library behavior, examples, and reference lookups. Use a reliable model; low variant is configured in the preset."
  "Correctness, regressions, maintainability, edge cases, and test-gap review. Use a strong reasoning model."
  "Module boundaries, API contracts, migrations, data flow, and technical tradeoffs. Use a strong reasoning model."
  "Test strategy, fixtures, regression coverage, and reproduction cases. Use a capable coding model."
  "Defensive auth, secrets, injection, unsafe IO, dependency, deployment, and data exposure review. Use a strong reasoning model."
)
MODEL_DEFAULTS=(
  "openai/gpt-5.5"
  "openai/gpt-5.3-codex-spark"
  "openai/gpt-5.3-codex-spark"
  "openai/gpt-5.3-codex-spark"
  "openai/gpt-5.3-codex-spark"
  "openai/gpt-5.3-codex-spark"
  "openai/gpt-5.5"
  "openai/gpt-5.5"
  "openai/gpt-5.5"
  "openai/gpt-5.5"
  "openai/gpt-5.3-codex-spark"
  "openai/gpt-5.5"
)

MODELS=()
if command -v "$OPENCODE_BIN" >/dev/null 2>&1; then
  while IFS= read -r model; do
    if [[ -n "$model" && "$model" == */* ]]; then
      MODELS+=("$model")
    fi
  done < <("$OPENCODE_BIN" models "$PROVIDER" </dev/null 2>/dev/null || true)
fi

select_model() {
  local key="$1"
  local title="$2"
  local description="$3"
  local default_model="$4"
  local answer=""
  local index=0
  local selected_index=0

  if [[ "$NON_INTERACTIVE" == "1" ]]; then
    printf '%s\n' "$default_model"
    return 0
  fi

  while true; do
    echo "" >&2
    echo "== $title ==" >&2
    echo "$description" >&2
    echo "Default: $default_model" >&2

    if [[ ${#MODELS[@]} -gt 0 ]]; then
      echo "" >&2
      echo "Available models:" >&2
      for index in "${!MODELS[@]}"; do
        if [[ "${MODELS[$index]}" == "$default_model" ]]; then
          echo "  $((index + 1)). ${MODELS[$index]} (default)" >&2
        else
          echo "  $((index + 1)). ${MODELS[$index]}" >&2
        fi
      done
    else
      echo "" >&2
      echo "No models were returned by opencode. You can still type a full provider/model id." >&2
    fi

    if ! read -r -p "Choose model number or provider/model for '$key' [Enter = default]: " answer; then
      answer=""
    fi
    answer="${answer//[$'\t\r\n ']}"

    if [[ -z "$answer" ]]; then
      printf '%s\n' "$default_model"
      return 0
    fi

    if [[ "$answer" =~ ^[0-9]+$ ]]; then
      selected_index=$((answer - 1))
      if [[ $selected_index -ge 0 && $selected_index -lt ${#MODELS[@]} ]]; then
        printf '%s\n' "${MODELS[$selected_index]}"
        return 0
      fi
    fi

    if [[ "$answer" == */* ]]; then
      printf '%s\n' "$answer"
      return 0
    fi

    echo "Invalid selection. Use a listed number, press Enter for default, or type provider/model." >&2
  done
}

apply_model_choices() {
  local opencode_config="$DEST_DIR/opencode.jsonc"
  local slim_config="$DEST_DIR/oh-my-opencode-slim.jsonc"

  if command -v node >/dev/null 2>&1; then
    node - "$opencode_config" "$slim_config" \
      "$CORE_MODEL" "$EXPLORER_MODEL" "$FIXER_MODEL" "$DESIGNER_MODEL" "$TITLE_MODEL" "$SUMMARY_MODEL" \
      "$COMPACTION_MODEL" "$LIBRARIAN_MODEL" "$REVIEWER_MODEL" "$ARCHITECT_MODEL" "$TEST_MODEL" "$SECURITY_MODEL" <<'NODE'
const fs = require('fs');
const [
  opencodePath,
  slimPath,
  core,
  explorer,
  fixer,
  designer,
  title,
  summary,
  compaction,
  librarian,
  reviewer,
  architect,
  test,
  security,
] = process.argv.slice(2);

function readJson(path) {
  return JSON.parse(fs.readFileSync(path, 'utf8'));
}

function writeJson(path, value) {
  fs.writeFileSync(path, JSON.stringify(value, null, 2) + '\n');
}

const opencode = readJson(opencodePath);
opencode.model = core;
opencode.small_model = explorer;
opencode.agent.build.model = core;
opencode.agent.plan.model = core;
opencode.agent.general.model = core;
opencode.agent.explore.model = explorer;
opencode.agent.title.model = title;
opencode.agent.summary.model = summary;
opencode.agent.compaction.model = compaction;
writeJson(opencodePath, opencode);

const slim = readJson(slimPath);
const preset = slim.presets['generic-openai'];
preset.orchestrator.model = core;
preset.oracle.model = core;
preset.council.model = core;
preset.explorer.model = explorer;
preset.librarian.model = librarian;
preset.fixer.model = fixer;
preset.designer.model = designer;
slim.agents['code-reviewer'].model = reviewer;
slim.agents['repo-architect'].model = architect;
slim.agents['test-writer'].model = test;
slim.agents['security-reviewer'].model = security;
const councilPreset = slim.council.presets['generic-review-board'];
councilPreset['deep-review'].model = reviewer;
councilPreset['fast-sanity'].model = explorer;
councilPreset['security-sanity'].model = security;
writeJson(slimPath, slim);
NODE
    return 0
  fi

  if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    local python_bin="python3"
    if ! command -v python3 >/dev/null 2>&1; then
      python_bin="python"
    fi
    "$python_bin" - "$opencode_config" "$slim_config" \
      "$CORE_MODEL" "$EXPLORER_MODEL" "$FIXER_MODEL" "$DESIGNER_MODEL" "$TITLE_MODEL" "$SUMMARY_MODEL" \
      "$COMPACTION_MODEL" "$LIBRARIAN_MODEL" "$REVIEWER_MODEL" "$ARCHITECT_MODEL" "$TEST_MODEL" "$SECURITY_MODEL" <<'PY'
import json
import sys

(
    opencode_path,
    slim_path,
    core,
    explorer,
    fixer,
    designer,
    title,
    summary,
    compaction,
    librarian,
    reviewer,
    architect,
    test,
    security,
) = sys.argv[1:]

def read_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)

def write_json(path, value):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")

opencode = read_json(opencode_path)
opencode["model"] = core
opencode["small_model"] = explorer
opencode["agent"]["build"]["model"] = core
opencode["agent"]["plan"]["model"] = core
opencode["agent"]["general"]["model"] = core
opencode["agent"]["explore"]["model"] = explorer
opencode["agent"]["title"]["model"] = title
opencode["agent"]["summary"]["model"] = summary
opencode["agent"]["compaction"]["model"] = compaction
write_json(opencode_path, opencode)

slim = read_json(slim_path)
preset = slim["presets"]["generic-openai"]
preset["orchestrator"]["model"] = core
preset["oracle"]["model"] = core
preset["council"]["model"] = core
preset["explorer"]["model"] = explorer
preset["librarian"]["model"] = librarian
preset["fixer"]["model"] = fixer
preset["designer"]["model"] = designer
slim["agents"]["code-reviewer"]["model"] = reviewer
slim["agents"]["repo-architect"]["model"] = architect
slim["agents"]["test-writer"]["model"] = test
slim["agents"]["security-reviewer"]["model"] = security
council_preset = slim["council"]["presets"]["generic-review-board"]
council_preset["deep-review"]["model"] = reviewer
council_preset["fast-sanity"]["model"] = explorer
council_preset["security-sanity"]["model"] = security
write_json(slim_path, slim)
PY
    return 0
  fi

  echo "Could not customize model routing: install node, python3, or python, then re-run installer." >&2
  return 1
}

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Project path does not exist or is not a directory: $PROJECT_PATH" >&2
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Template source not found: $SOURCE_DIR" >&2
  exit 1
fi

if [[ -e "$DEST_DIR" && "$FORCE" != "1" ]]; then
  echo "Target already has .opencode. Re-run with FORCE=1 to merge and overwrite matching template files." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
cp -R "$SOURCE_DIR"/. "$DEST_DIR"/

if [[ "$NON_INTERACTIVE" != "1" ]]; then
  echo ""
  echo "Interactive model routing"
  echo "Provider queried: $PROVIDER"
  if [[ ${#MODELS[@]} -gt 0 ]]; then
    echo "Found ${#MODELS[@]} model(s) via opencode models $PROVIDER."
  else
    echo "No model list was available from opencode models $PROVIDER. Defaults still work if your provider supports them."
  fi
  if ! read -r -p "Customize model routing now? [Y/n]: " customize_answer; then
    customize_answer=""
  fi
  case "$customize_answer" in
    n|N|no|NO|No)
      NON_INTERACTIVE="1"
      ;;
  esac
fi

CORE_MODEL=""
EXPLORER_MODEL=""
FIXER_MODEL=""
DESIGNER_MODEL=""
TITLE_MODEL=""
SUMMARY_MODEL=""
COMPACTION_MODEL=""
LIBRARIAN_MODEL=""
REVIEWER_MODEL=""
ARCHITECT_MODEL=""
TEST_MODEL=""
SECURITY_MODEL=""

SELECTED_MODELS=()
for index in "${!MODEL_KEYS[@]}"; do
  selected="$(select_model "${MODEL_KEYS[$index]}" "${MODEL_TITLES[$index]}" "${MODEL_DESCRIPTIONS[$index]}" "${MODEL_DEFAULTS[$index]}")"
  SELECTED_MODELS+=("$selected")
done

CORE_MODEL="${SELECTED_MODELS[0]}"
EXPLORER_MODEL="${SELECTED_MODELS[1]}"
FIXER_MODEL="${SELECTED_MODELS[2]}"
DESIGNER_MODEL="${SELECTED_MODELS[3]}"
TITLE_MODEL="${SELECTED_MODELS[4]}"
SUMMARY_MODEL="${SELECTED_MODELS[5]}"
COMPACTION_MODEL="${SELECTED_MODELS[6]}"
LIBRARIAN_MODEL="${SELECTED_MODELS[7]}"
REVIEWER_MODEL="${SELECTED_MODELS[8]}"
ARCHITECT_MODEL="${SELECTED_MODELS[9]}"
TEST_MODEL="${SELECTED_MODELS[10]}"
SECURITY_MODEL="${SELECTED_MODELS[11]}"

apply_model_choices

echo "Installed generic OpenCode config to $DEST_DIR"
echo ""
echo "Selected model routing:"
for index in "${!MODEL_KEYS[@]}"; do
  echo "  ${MODEL_KEYS[$index]}: ${SELECTED_MODELS[$index]}"
done
echo ""
echo "Restart OpenCode in the target project so it loads the new config."
