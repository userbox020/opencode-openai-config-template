#!/usr/bin/env bash
set -euo pipefail
shopt -s extglob

PROJECT_PATH=""
FORCE="${FORCE:-0}"
NON_INTERACTIVE="${NON_INTERACTIVE:-0}"
OPENCODE_BIN="${OPENCODE_BIN:-opencode}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)
      FORCE="1"
      ;;
    --non-interactive)
      NON_INTERACTIVE="1"
      ;;
    -h|--help)
      echo "Usage: bash ./scripts/install.sh [project-path] [--force] [--non-interactive]"
      exit 0
      ;;
    -*)
      echo "Unexpected option: $1" >&2
      exit 1
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
SOURCE_DIR="${OPENCODE_TEMPLATE_SOURCE:-$REPO_ROOT/template/.opencode}"
DEST_DIR="$PROJECT_PATH/.opencode"
STAGING_DIR=""
STAGED_CONFIG_DIR=""

cleanup_staging() {
  if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
    rm -rf -- "$STAGING_DIR"
  fi
}

trim_input() {
  local value="$1"
  value="${value##+([[:space:]])}"
  value="${value%%+([[:space:]])}"
  printf '%s' "$value"
}

trap cleanup_staging EXIT

MODEL_KEYS=(primary balanced utility deep)
MODEL_TITLES=(
  "Primary Sol"
  "Balanced Terra"
  "Utility Luna"
  "Deep Sol-Pro"
)
MODEL_DESCRIPTIONS=(
  "Routine orchestration and build, plus high-effort planning, fixing, security, and architecture."
  "General work, source synthesis, summaries, compaction, design, and normal review."
  "Exploration, titles, high-volume utility work, and fast sanity checks."
  "Bounded deep-review council work only."
)
MODEL_DEFAULTS=(
  "openai/gpt-5.6-sol"
  "openai/gpt-5.6-terra"
  "openai/gpt-5.6-luna"
  "openai/gpt-5.6-sol-pro"
)
TEMPLATE_ENTRIES=(
  "opencode.jsonc"
  "oh-my-opencode-slim.jsonc"
  "opencode.env"
  "oh-my-opencode-slim"
  "skills"
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
    model="$(trim_input "$model")"
    if [[ "$model" =~ ^openai/[^[:space:]]+$ ]]; then
      MODELS+=("$model")
    fi
  done < <("$OPENCODE_BIN" models openai </dev/null 2>/dev/null || true)
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
      echo "No OpenAI models were returned by opencode. You can still type a full openai/model id." >&2
    fi

    if ! read -r -p "Choose model number or openai/model for '$key' [Enter = default]: " answer; then
      answer=""
    fi
    answer="$(trim_input "$answer")"

    if [[ -z "$answer" ]]; then
      printf '%s\n' "$default_model"
      return 0
    fi

    if [[ "$answer" =~ ^[0-9]+$ ]]; then
      selected_index=$((10#$answer - 1))
      if [[ $selected_index -ge 0 && $selected_index -lt ${#MODELS[@]} ]]; then
        printf '%s\n' "${MODELS[$selected_index]}"
        return 0
      fi
    fi

    if [[ "$answer" =~ ^openai/[^[:space:]]+$ ]]; then
      printf '%s\n' "$answer"
      return 0
    fi

    echo "Invalid selection. Use a listed number, press Enter for default, or type a valid openai/model id without whitespace." >&2
  done
}

apply_model_choices() {
  local opencode_config="$STAGED_CONFIG_DIR/opencode.jsonc"
  local slim_config="$STAGED_CONFIG_DIR/oh-my-opencode-slim.jsonc"

  if [[ "$JSON_RUNTIME" == "node" ]]; then
    "$JSON_RUNTIME_BIN" - "$opencode_config" "$slim_config" "$PRIMARY_MODEL" "$BALANCED_MODEL" "$UTILITY_MODEL" "$DEEP_MODEL" <<'NODE'
const fs = require('fs');
const [
  opencodePath,
  slimPath,
  primary,
  balanced,
  utility,
  deep,
] = process.argv.slice(2);

function readJson(path) {
  return JSON.parse(fs.readFileSync(path, 'utf8'));
}

function writeJson(path, value) {
  fs.writeFileSync(path, JSON.stringify(value, null, 2) + '\n');
}

const opencode = readJson(opencodePath);
opencode.model = primary;
opencode.small_model = utility;
opencode.agent.build.model = primary;
opencode.agent.build.variant = 'medium';
opencode.agent.build.mode = 'primary';
opencode.agent.build.disable = false;
opencode.agent.build.hidden = false;
opencode.agent.plan.model = primary;
opencode.agent.plan.variant = 'high';
opencode.agent.plan.mode = 'primary';
opencode.agent.plan.disable = false;
opencode.agent.plan.hidden = false;
opencode.agent.general.model = balanced;
opencode.agent.general.variant = 'medium';
opencode.agent.explore.model = utility;
opencode.agent.explore.variant = 'low';
opencode.agent.title.model = utility;
opencode.agent.title.variant = 'none';
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
  { id: balanced, variant: 'xhigh' },
];
preset.council.model = [
  { id: primary, variant: 'high' },
  { id: balanced, variant: 'high' },
];
preset.explorer.model = [
  { id: utility, variant: 'low' },
  { id: balanced, variant: 'low' },
];
preset.librarian.model = [
  { id: balanced, variant: 'low' },
  { id: utility, variant: 'low' },
];
preset.fixer.model = [
  { id: primary, variant: 'high' },
  { id: balanced, variant: 'high' },
];
preset.designer.model = [
  { id: balanced, variant: 'medium' },
  { id: primary, variant: 'medium' },
];
slim.agents['code-reviewer'].model = balanced;
slim.agents['code-reviewer'].variant = 'high';
slim.agents['repo-architect'].model = primary;
slim.agents['repo-architect'].variant = 'high';
slim.agents['test-writer'].model = balanced;
slim.agents['test-writer'].variant = 'medium';
slim.agents['security-reviewer'].model = primary;
slim.agents['security-reviewer'].variant = 'high';
const councilPreset = slim.council.presets['generic-review-board'];
councilPreset['deep-review'].model = deep;
councilPreset['deep-review'].variant = 'high';
councilPreset['fast-sanity'].model = utility;
councilPreset['fast-sanity'].variant = 'low';
councilPreset['security-sanity'].model = balanced;
councilPreset['security-sanity'].variant = 'high';
writeJson(slimPath, slim);
NODE
    return 0
  fi

  if [[ "$JSON_RUNTIME" == "python3" ]]; then
    "$JSON_RUNTIME_BIN" - "$opencode_config" "$slim_config" "$PRIMARY_MODEL" "$BALANCED_MODEL" "$UTILITY_MODEL" "$DEEP_MODEL" <<'PY'
import json
import sys

(
    opencode_path,
    slim_path,
    primary,
    balanced,
    utility,
    deep,
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
opencode["small_model"] = utility
opencode["agent"]["build"].update(model=primary, variant="medium", mode="primary", disable=False, hidden=False)
opencode["agent"]["plan"].update(model=primary, variant="high", mode="primary", disable=False, hidden=False)
opencode["agent"]["general"].update(model=balanced, variant="medium")
opencode["agent"]["explore"].update(model=utility, variant="low")
opencode["agent"]["title"].update(model=utility, variant="none")
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
    {"id": balanced, "variant": "xhigh"},
]
preset["council"]["model"] = [
    {"id": primary, "variant": "high"},
    {"id": balanced, "variant": "high"},
]
preset["explorer"]["model"] = [
    {"id": utility, "variant": "low"},
    {"id": balanced, "variant": "low"},
]
preset["librarian"]["model"] = [
    {"id": balanced, "variant": "low"},
    {"id": utility, "variant": "low"},
]
preset["fixer"]["model"] = [
    {"id": primary, "variant": "high"},
    {"id": balanced, "variant": "high"},
]
preset["designer"]["model"] = [
    {"id": balanced, "variant": "medium"},
    {"id": primary, "variant": "medium"},
]
slim["agents"]["code-reviewer"].update(model=balanced, variant="high")
slim["agents"]["repo-architect"].update(model=primary, variant="high")
slim["agents"]["test-writer"].update(model=balanced, variant="medium")
slim["agents"]["security-reviewer"].update(model=primary, variant="high")
council_preset = slim["council"]["presets"]["generic-review-board"]
council_preset["deep-review"].update(model=deep, variant="high")
council_preset["fast-sanity"].update(model=utility, variant="low")
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

for entry in "${TEMPLATE_ENTRIES[@]}"; do
  if [[ ! -e "$SOURCE_DIR/$entry" ]]; then
    echo "Required template entry not found: $SOURCE_DIR/$entry" >&2
    exit 1
  fi
done

if [[ -e "$DEST_DIR" && "$FORCE" != "1" ]]; then
  echo "Target already has .opencode. Re-run with FORCE=1 to merge and overwrite matching template files." >&2
  exit 1
fi

if [[ "$NON_INTERACTIVE" != "1" ]]; then
  echo ""
  echo "Interactive model routing"
  echo "Provider queried: openai"
  if [[ ${#MODELS[@]} -gt 0 ]]; then
    echo "Found ${#MODELS[@]} model(s) via opencode models openai."
  else
    echo "No model list was available from opencode models openai. Defaults still work when the configured OpenAI models are available."
  fi
  if ! read -r -p "Customize model routing now? [Y/n]: " customize_answer; then
    customize_answer=""
  fi
  customize_answer="$(trim_input "$customize_answer")"
  case "$customize_answer" in
    n|N|[nN][oO])
      NON_INTERACTIVE="1"
      ;;
  esac
fi

PRIMARY_MODEL=""
BALANCED_MODEL=""
UTILITY_MODEL=""
DEEP_MODEL=""

SELECTED_MODELS=()
for index in "${!MODEL_KEYS[@]}"; do
  selected="$(select_model "${MODEL_KEYS[$index]}" "${MODEL_TITLES[$index]}" "${MODEL_DESCRIPTIONS[$index]}" "${MODEL_DEFAULTS[$index]}")"
  SELECTED_MODELS+=("$selected")
done

PRIMARY_MODEL="${SELECTED_MODELS[0]}"
BALANCED_MODEL="${SELECTED_MODELS[1]}"
UTILITY_MODEL="${SELECTED_MODELS[2]}"
DEEP_MODEL="${SELECTED_MODELS[3]}"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opencode-openai-config.XXXXXX")"
STAGED_CONFIG_DIR="$STAGING_DIR/.opencode"
mkdir -p "$STAGED_CONFIG_DIR"
for entry in "${TEMPLATE_ENTRIES[@]}"; do
  cp -R "$SOURCE_DIR/$entry" "$STAGED_CONFIG_DIR"/
done
apply_model_choices

if [[ "$FORCE" != "1" ]]; then
  if [[ -e "$DEST_DIR" ]]; then
    echo "Target acquired .opencode during installation. No files were copied; re-run with --force only if overwriting is intended." >&2
    exit 1
  fi
  if ! mkdir "$DEST_DIR"; then
    echo "Could not exclusively create target .opencode; no files were copied." >&2
    exit 1
  fi
else
  mkdir -p "$DEST_DIR"
fi
cp -R "$STAGED_CONFIG_DIR"/. "$DEST_DIR"/
cleanup_staging
STAGING_DIR=""

echo "Installed generic OpenCode config to $DEST_DIR"
echo ""
echo "Selected model routing:"
for index in "${!MODEL_KEYS[@]}"; do
  echo "  ${MODEL_KEYS[$index]}: ${SELECTED_MODELS[$index]}"
done
echo ""
echo "Start OpenCode with the required runtime features enabled:"
echo "  OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true OPENCODE_ENABLE_EXA=1 OH_MY_OPENCODE_SLIM_PRESET=generic-openai opencode"
echo ""
echo "For persistent setup, export the two OPENCODE_* variables from your shell profile. Keep OH_MY_OPENCODE_SLIM_PRESET project-scoped so it does not override unrelated projects."
