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

MODEL_KEYS=(primary balanced)
MODEL_TITLES=(
  "Primary and deep reasoning"
  "Fast and balanced work"
)
MODEL_DESCRIPTIONS=(
  "Planning, fixing, Oracle, architecture, and high-stakes specialist work."
  "Routine orchestration, general work, exploration, docs, design, titles, summaries, and compaction."
)
MODEL_DEFAULTS=(
  "openai/gpt-5.6-sol"
  "openai/gpt-5.6-terra"
)

JSON_RUNTIME=""
JSON_RUNTIME_BIN=""
if command -v node >/dev/null 2>&1; then
  JSON_RUNTIME="node"
  JSON_RUNTIME_BIN="$(command -v node)"
elif command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; sys.exit(0 if sys.version_info.major == 3 else 1)' >/dev/null 2>&1; then
  JSON_RUNTIME="python3"
  JSON_RUNTIME_BIN="$(command -v python3)"
elif command -v python >/dev/null 2>&1 && python -c 'import sys; sys.exit(0 if sys.version_info.major == 3 else 1)' >/dev/null 2>&1; then
  JSON_RUNTIME="python3"
  JSON_RUNTIME_BIN="$(command -v python)"
else
  echo "Installation requires Node.js or Python 3 to generate model routing; no supported runtime was found." >&2
  exit 1
fi

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

  if [[ "$JSON_RUNTIME" == "node" ]]; then
    "$JSON_RUNTIME_BIN" - "$opencode_config" "$slim_config" "$PRIMARY_MODEL" "$BALANCED_MODEL" <<'NODE'
const fs = require('fs');
const [
  opencodePath,
  slimPath,
  primary,
  balanced,
] = process.argv.slice(2);

function readJson(path) {
  return JSON.parse(fs.readFileSync(path, 'utf8'));
}

function writeJson(path, value) {
  fs.writeFileSync(path, JSON.stringify(value, null, 2) + '\n');
}

const opencode = readJson(opencodePath);
opencode.model = primary;
opencode.small_model = balanced;
opencode.agent.build.model = primary;
opencode.agent.build.variant = 'medium';
opencode.agent.plan.model = primary;
opencode.agent.plan.variant = 'high';
opencode.agent.general.model = balanced;
opencode.agent.general.variant = 'medium';
opencode.agent.explore.model = balanced;
opencode.agent.explore.variant = 'low';
opencode.agent.title.model = balanced;
opencode.agent.title.variant = 'low';
opencode.agent.summary.model = balanced;
opencode.agent.summary.variant = 'medium';
opencode.agent.compaction.model = balanced;
opencode.agent.compaction.variant = 'medium';
writeJson(opencodePath, opencode);

const slim = readJson(slimPath);
const preset = slim.presets['generic-openai'];
preset.orchestrator.model = [
  { id: primary, variant: 'medium' },
  { id: balanced, variant: 'medium' },
];
preset.oracle.model = [
  { id: primary, variant: 'xhigh' },
  { id: balanced, variant: 'high' },
];
preset.council.model = [
  { id: primary, variant: 'high' },
  { id: balanced, variant: 'high' },
];
preset.explorer.model = [
  { id: balanced, variant: 'low' },
  { id: primary, variant: 'low' },
];
preset.librarian.model = [
  { id: balanced, variant: 'low' },
  { id: primary, variant: 'low' },
];
preset.fixer.model = [
  { id: primary, variant: 'high' },
  { id: balanced, variant: 'high' },
];
preset.designer.model = [
  { id: balanced, variant: 'medium' },
  { id: primary, variant: 'high' },
];
slim.agents['code-reviewer'].model = balanced;
slim.agents['code-reviewer'].variant = 'high';
slim.agents['repo-architect'].model = primary;
slim.agents['repo-architect'].variant = 'xhigh';
slim.agents['test-writer'].model = balanced;
slim.agents['test-writer'].variant = 'medium';
slim.agents['security-reviewer'].model = primary;
slim.agents['security-reviewer'].variant = 'xhigh';
const councilPreset = slim.council.presets['generic-review-board'];
slim.council.councillor_retries = 1;
councilPreset['deep-review'].model = primary;
councilPreset['deep-review'].variant = 'xhigh';
councilPreset['fast-sanity'].model = balanced;
councilPreset['fast-sanity'].variant = 'low';
councilPreset['security-sanity'].model = balanced;
councilPreset['security-sanity'].variant = 'high';
writeJson(slimPath, slim);
NODE
    return 0
  fi

  if [[ "$JSON_RUNTIME" == "python3" ]]; then
    "$JSON_RUNTIME_BIN" - "$opencode_config" "$slim_config" "$PRIMARY_MODEL" "$BALANCED_MODEL" <<'PY'
import json
import sys

(
    opencode_path,
    slim_path,
    primary,
    balanced,
) = sys.argv[1:]

def read_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)

def write_json(path, value):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")

opencode = read_json(opencode_path)
opencode["model"] = primary
opencode["small_model"] = balanced
opencode["agent"]["build"].update(model=primary, variant="medium")
opencode["agent"]["plan"].update(model=primary, variant="high")
opencode["agent"]["general"].update(model=balanced, variant="medium")
opencode["agent"]["explore"].update(model=balanced, variant="low")
opencode["agent"]["title"].update(model=balanced, variant="low")
opencode["agent"]["summary"].update(model=balanced, variant="medium")
opencode["agent"]["compaction"].update(model=balanced, variant="medium")
write_json(opencode_path, opencode)

slim = read_json(slim_path)
preset = slim["presets"]["generic-openai"]
preset["orchestrator"]["model"] = [
    {"id": primary, "variant": "medium"},
    {"id": balanced, "variant": "medium"},
]
preset["oracle"]["model"] = [
    {"id": primary, "variant": "xhigh"},
    {"id": balanced, "variant": "high"},
]
preset["council"]["model"] = [
    {"id": primary, "variant": "high"},
    {"id": balanced, "variant": "high"},
]
preset["explorer"]["model"] = [
    {"id": balanced, "variant": "low"},
    {"id": primary, "variant": "low"},
]
preset["librarian"]["model"] = [
    {"id": balanced, "variant": "low"},
    {"id": primary, "variant": "low"},
]
preset["fixer"]["model"] = [
    {"id": primary, "variant": "high"},
    {"id": balanced, "variant": "high"},
]
preset["designer"]["model"] = [
    {"id": balanced, "variant": "medium"},
    {"id": primary, "variant": "high"},
]
slim["agents"]["code-reviewer"].update(model=balanced, variant="high")
slim["agents"]["repo-architect"].update(model=primary, variant="xhigh")
slim["agents"]["test-writer"].update(model=balanced, variant="medium")
slim["agents"]["security-reviewer"].update(model=primary, variant="xhigh")
council_preset = slim["council"]["presets"]["generic-review-board"]
slim["council"]["councillor_retries"] = 1
council_preset["deep-review"].update(model=primary, variant="xhigh")
council_preset["fast-sanity"].update(model=balanced, variant="low")
council_preset["security-sanity"].update(model=balanced, variant="high")
write_json(slim_path, slim)
PY
    return 0
  fi

  echo "Internal error: unsupported JSON runtime '$JSON_RUNTIME'." >&2
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

PRIMARY_MODEL=""
BALANCED_MODEL=""

SELECTED_MODELS=()
for index in "${!MODEL_KEYS[@]}"; do
  selected="$(select_model "${MODEL_KEYS[$index]}" "${MODEL_TITLES[$index]}" "${MODEL_DESCRIPTIONS[$index]}" "${MODEL_DEFAULTS[$index]}")"
  SELECTED_MODELS+=("$selected")
done

PRIMARY_MODEL="${SELECTED_MODELS[0]}"
BALANCED_MODEL="${SELECTED_MODELS[1]}"

apply_model_choices

echo "Installed generic OpenCode config to $DEST_DIR"
echo ""
echo "Selected model routing:"
for index in "${!MODEL_KEYS[@]}"; do
  echo "  ${MODEL_KEYS[$index]}: ${SELECTED_MODELS[$index]}"
done
echo ""
echo "Restart OpenCode in the target project so it loads the new config."
