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
SOURCE_DIR="$REPO_ROOT/template/.opencode"
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

version_at_least() {
  local current="$1"
  local required="$2"
  local current_parts=()
  local required_parts=()
  local index=0
  local current_part=0
  local required_part=0

  if [[ ! "$current" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)(\+[0-9A-Za-z.-]+)?$ ]]; then
    return 2
  fi
  current="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  IFS='.' read -r -a current_parts <<< "$current"
  IFS='.' read -r -a required_parts <<< "$required"
  for index in 0 1 2; do
    current_part="${current_parts[$index]:-0}"
    required_part="${required_parts[$index]:-0}"
    if ((10#$current_part > 10#$required_part)); then
      return 0
    fi
    if ((10#$current_part < 10#$required_part)); then
      return 1
    fi
  done
  return 0
}

trap cleanup_staging EXIT

MODEL_KEYS=(primary balanced utility)
MODEL_TITLES=(
  "Primary Sol"
  "Balanced Terra"
  "Utility Luna"
)
MODEL_DESCRIPTIONS=(
  "Complex planning, fixing, review, security, architecture, and quality-profile work."
  "Balanced-profile orchestration and build, plus general work, synthesis, compaction, design, and normal review."
  "Exploration, titles, summaries, high-volume utility work, and fast sanity checks."
)
MODEL_DEFAULTS=(
  "openai/gpt-5.6-sol"
  "openai/gpt-5.6-terra"
  "openai/gpt-5.6-luna"
)

JSON_RUNTIME="${OPENCODE_INSTALL_JSON_RUNTIME:-}"
JSON_RUNTIME_BIN=""
if [[ "$JSON_RUNTIME" == "node" ]]; then
  if ! command -v node >/dev/null 2>&1; then
    echo "OPENCODE_INSTALL_JSON_RUNTIME=node was requested, but Node.js was not found." >&2
    exit 1
  fi
  JSON_RUNTIME_BIN="$(command -v node)"
elif [[ "$JSON_RUNTIME" == "python3" ]]; then
  if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; sys.exit(0 if sys.version_info.major == 3 else 1)' >/dev/null 2>&1; then
    JSON_RUNTIME_BIN="$(command -v python3)"
  elif command -v python >/dev/null 2>&1 && python -c 'import sys; sys.exit(0 if sys.version_info.major == 3 else 1)' >/dev/null 2>&1; then
    JSON_RUNTIME_BIN="$(command -v python)"
  else
    echo "OPENCODE_INSTALL_JSON_RUNTIME=python3 was requested, but Python 3 was not found." >&2
    exit 1
  fi
elif [[ -n "$JSON_RUNTIME" ]]; then
  echo "Unsupported OPENCODE_INSTALL_JSON_RUNTIME value: $JSON_RUNTIME" >&2
  exit 1
elif command -v node >/dev/null 2>&1; then
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
  OPENCODE_VERSION="$($OPENCODE_BIN --version </dev/null 2>/dev/null || true)"
  OPENCODE_VERSION="$(trim_input "$OPENCODE_VERSION")"
  if [[ -z "$OPENCODE_VERSION" ]]; then
    echo "Warning: Could not verify the OpenCode version. This template requires OpenCode 1.18.10 or newer." >&2
  elif version_at_least "$OPENCODE_VERSION" "1.18.10"; then
    :
  elif [[ $? -eq 1 ]]; then
    echo "Warning: OpenCode $OPENCODE_VERSION detected. Upgrade to 1.18.10 or newer before using this template." >&2
  else
    echo "Warning: Could not parse OpenCode version '$OPENCODE_VERSION'. This template requires 1.18.10 or newer." >&2
  fi
  while IFS= read -r model; do
    model="$(trim_input "$model")"
    if [[ "$model" =~ ^openai/[A-Za-z0-9._-]+$ && ! "$model" =~ -pro$ ]]; then
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

    if [[ "$answer" =~ ^openai/[A-Za-z0-9._-]+$ ]]; then
      if [[ "$answer" =~ -pro$ ]]; then
        echo "ChatGPT OAuth does not expose OpenCode Pro-mode IDs. Choose a standard model." >&2
        continue
      fi
      if [[ ${#MODELS[@]} -gt 0 ]] && [[ ! " ${MODELS[*]} " =~ " ${answer} " ]]; then
        echo "That model was not returned by opencode models openai. Choose a listed model." >&2
        continue
      fi
      printf '%s\n' "$answer"
      return 0
    fi

    echo "Invalid selection. Use a listed number, press Enter for default, or type a valid openai/model id without whitespace." >&2
  done
}

apply_model_choices() {
  local opencode_config="$STAGED_CONFIG_DIR/opencode.jsonc"
  local slim_config="$STAGED_CONFIG_DIR/oh-my-opencode-slim.jsonc"
  local routing_profile="$STAGED_CONFIG_DIR/routing-profile.js"

  if [[ "$JSON_RUNTIME" == "node" ]]; then
    "$JSON_RUNTIME_BIN" - "$opencode_config" "$slim_config" "$routing_profile" "$PRIMARY_MODEL" "$BALANCED_MODEL" "$UTILITY_MODEL" <<'NODE'
const fs = require('fs');
const [
  opencodePath,
  slimPath,
  routingProfilePath,
  primary,
  balanced,
  utility,
] = process.argv.slice(2);

function readJson(path) {
  return JSON.parse(fs.readFileSync(path, 'utf8'));
}

function writeJson(path, value) {
  fs.writeFileSync(path, JSON.stringify(value, null, 2) + '\n');
}

const opencode = readJson(opencodePath);
opencode.model = balanced;
opencode.small_model = utility;
opencode.agent.build.model = balanced;
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
opencode.agent.summary.model = utility;
opencode.agent.summary.variant = 'low';
opencode.agent.compaction.model = balanced;
opencode.agent.compaction.variant = 'medium';
writeJson(opencodePath, opencode);

let routingProfile = fs.readFileSync(routingProfilePath, 'utf8');
for (const [key, value] of Object.entries({ primary, balanced, utility })) {
  const pattern = new RegExp(`^(\\s*${key}:\\s*)"[^"]+"`, 'm');
  routingProfile = routingProfile.replace(pattern, (_match, prefix) => `${prefix}${JSON.stringify(value)}`);
}
fs.writeFileSync(routingProfilePath, routingProfile);

const slim = readJson(slimPath);
const balancedPreset = slim.presets.balanced;
balancedPreset.orchestrator.model = [
  { id: balanced, variant: 'medium' },
  { id: primary, variant: 'medium' },
];
Object.assign(balancedPreset.oracle, { model: primary, variant: 'xhigh' });
Object.assign(balancedPreset.council, { model: primary, variant: 'high' });
Object.assign(balancedPreset.explorer, { model: utility, variant: 'low' });
Object.assign(balancedPreset.librarian, { model: balanced, variant: 'low' });
Object.assign(balancedPreset.fixer, { model: primary, variant: 'high' });
balancedPreset.designer.model = [
  { id: balanced, variant: 'medium' },
  { id: primary, variant: 'medium' },
];
Object.assign(balancedPreset['code-reviewer'], { model: balanced, variant: 'high' });
Object.assign(balancedPreset['repo-architect'], { model: primary, variant: 'high' });
Object.assign(balancedPreset['test-writer'], { model: balanced, variant: 'medium' });
Object.assign(balancedPreset['security-reviewer'], { model: primary, variant: 'high' });

const qualityPreset = slim.presets.quality;
qualityPreset.orchestrator.model = [
  { id: primary, variant: 'medium' },
  { id: balanced, variant: 'medium' },
];
Object.assign(qualityPreset.oracle, { model: primary, variant: 'max' });
Object.assign(qualityPreset.council, { model: primary, variant: 'xhigh' });
Object.assign(qualityPreset.explorer, { model: balanced, variant: 'low' });
Object.assign(qualityPreset.librarian, { model: primary, variant: 'medium' });
Object.assign(qualityPreset.fixer, { model: primary, variant: 'xhigh' });
qualityPreset.designer.model = [
  { id: primary, variant: 'medium' },
  { id: balanced, variant: 'medium' },
];
Object.assign(qualityPreset['code-reviewer'], { model: primary, variant: 'xhigh' });
Object.assign(qualityPreset['repo-architect'], { model: primary, variant: 'xhigh' });
Object.assign(qualityPreset['test-writer'], { model: primary, variant: 'high' });
Object.assign(qualityPreset['security-reviewer'], { model: primary, variant: 'xhigh' });

slim.council.timeout = 300000;
slim.council.councillor_retries = 1;
const balancedCouncil = slim.council.presets.balanced;
Object.assign(balancedCouncil['deep-review'], { model: primary, variant: 'xhigh' });
Object.assign(balancedCouncil['fast-sanity'], { model: utility, variant: 'low' });
Object.assign(balancedCouncil['security-sanity'], { model: balanced, variant: 'high' });
const qualityCouncil = slim.council.presets.quality;
Object.assign(qualityCouncil['deep-review'], { model: primary, variant: 'max' });
Object.assign(qualityCouncil['fast-sanity'], { model: balanced, variant: 'low' });
Object.assign(qualityCouncil['security-sanity'], { model: primary, variant: 'high' });
writeJson(slimPath, slim);
NODE
    return 0
  fi

  if [[ "$JSON_RUNTIME" == "python3" ]]; then
    "$JSON_RUNTIME_BIN" - "$opencode_config" "$slim_config" "$routing_profile" "$PRIMARY_MODEL" "$BALANCED_MODEL" "$UTILITY_MODEL" <<'PY'
import json
import re
import sys

(
    opencode_path,
    slim_path,
    routing_profile_path,
    primary,
    balanced,
    utility,
) = sys.argv[1:]

def read_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)

def write_json(path, value):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")

opencode = read_json(opencode_path)
opencode["model"] = balanced
opencode["small_model"] = utility
opencode["agent"]["build"].update(model=balanced, variant="medium", mode="primary", disable=False, hidden=False)
opencode["agent"]["plan"].update(model=primary, variant="high", mode="primary", disable=False, hidden=False)
opencode["agent"]["general"].update(model=balanced, variant="medium")
opencode["agent"]["explore"].update(model=utility, variant="low")
opencode["agent"]["title"].update(model=utility, variant="none")
opencode["agent"]["summary"].update(model=utility, variant="low")
opencode["agent"]["compaction"].update(model=balanced, variant="medium")
write_json(opencode_path, opencode)

with open(routing_profile_path, "r", encoding="utf-8") as handle:
    routing_profile = handle.read()
for key, value in {"primary": primary, "balanced": balanced, "utility": utility}.items():
    pattern = rf'^(\s*{key}:\s*)"[^"]+"'
    routing_profile = re.sub(pattern, lambda match: match.group(1) + json.dumps(value), routing_profile, count=1, flags=re.MULTILINE)
with open(routing_profile_path, "w", encoding="utf-8") as handle:
    handle.write(routing_profile)

slim = read_json(slim_path)
balanced_preset = slim["presets"]["balanced"]
balanced_preset["orchestrator"]["model"] = [
    {"id": balanced, "variant": "medium"},
    {"id": primary, "variant": "medium"},
]
balanced_preset["oracle"].update(model=primary, variant="xhigh")
balanced_preset["council"].update(model=primary, variant="high")
balanced_preset["explorer"].update(model=utility, variant="low")
balanced_preset["librarian"].update(model=balanced, variant="low")
balanced_preset["fixer"].update(model=primary, variant="high")
balanced_preset["designer"]["model"] = [
    {"id": balanced, "variant": "medium"},
    {"id": primary, "variant": "medium"},
]
balanced_preset["code-reviewer"].update(model=balanced, variant="high")
balanced_preset["repo-architect"].update(model=primary, variant="high")
balanced_preset["test-writer"].update(model=balanced, variant="medium")
balanced_preset["security-reviewer"].update(model=primary, variant="high")

quality_preset = slim["presets"]["quality"]
quality_preset["orchestrator"]["model"] = [
    {"id": primary, "variant": "medium"},
    {"id": balanced, "variant": "medium"},
]
quality_preset["oracle"].update(model=primary, variant="max")
quality_preset["council"].update(model=primary, variant="xhigh")
quality_preset["explorer"].update(model=balanced, variant="low")
quality_preset["librarian"].update(model=primary, variant="medium")
quality_preset["fixer"].update(model=primary, variant="xhigh")
quality_preset["designer"]["model"] = [
    {"id": primary, "variant": "medium"},
    {"id": balanced, "variant": "medium"},
]
quality_preset["code-reviewer"].update(model=primary, variant="xhigh")
quality_preset["repo-architect"].update(model=primary, variant="xhigh")
quality_preset["test-writer"].update(model=primary, variant="high")
quality_preset["security-reviewer"].update(model=primary, variant="xhigh")

slim["council"]["timeout"] = 300000
slim["council"]["councillor_retries"] = 1
balanced_council = slim["council"]["presets"]["balanced"]
balanced_council["deep-review"].update(model=primary, variant="xhigh")
balanced_council["fast-sanity"].update(model=utility, variant="low")
balanced_council["security-sanity"].update(model=balanced, variant="high")
quality_council = slim["council"]["presets"]["quality"]
quality_council["deep-review"].update(model=primary, variant="max")
quality_council["fast-sanity"].update(model=balanced, variant="low")
quality_council["security-sanity"].update(model=primary, variant="high")
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

SELECTED_MODELS=()
for index in "${!MODEL_KEYS[@]}"; do
  selected="$(select_model "${MODEL_KEYS[$index]}" "${MODEL_TITLES[$index]}" "${MODEL_DESCRIPTIONS[$index]}" "${MODEL_DEFAULTS[$index]}")"
  SELECTED_MODELS+=("$selected")
done

PRIMARY_MODEL="${SELECTED_MODELS[0]}"
BALANCED_MODEL="${SELECTED_MODELS[1]}"
UTILITY_MODEL="${SELECTED_MODELS[2]}"

if [[ "$PRIMARY_MODEL" == "$BALANCED_MODEL" || "$PRIMARY_MODEL" == "$UTILITY_MODEL" || "$BALANCED_MODEL" == "$UTILITY_MODEL" ]]; then
  echo "The primary, balanced, and utility model slots must use distinct models." >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opencode-openai-config.XXXXXX")"
STAGED_CONFIG_DIR="$STAGING_DIR/.opencode"
mkdir -p "$STAGED_CONFIG_DIR"
cp -R "$SOURCE_DIR"/. "$STAGED_CONFIG_DIR"/
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
echo "  profiles: balanced (default), quality"
echo ""
echo "Restart OpenCode in the target project so it loads the new config."
