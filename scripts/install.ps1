[CmdletBinding()]
param(
  [string]$ProjectPath = (Get-Location).Path,
  [switch]$Force,
  [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"

$ModelSlots = @(
  [ordered]@{
    Key = "primary"
    Title = "Primary Sol"
    Description = "Direct build work plus high-effort planning, architecture, security, council synthesis, and Oracle reasoning."
    Default = "openai/gpt-5.6-sol"
  },
  [ordered]@{
    Key = "balanced"
    Title = "Balanced Terra"
    Description = "High-effort orchestration plus general work, source synthesis, summaries, compaction, design, and normal review."
    Default = "openai/gpt-5.6-terra"
  },
  [ordered]@{
    Key = "utility"
    Title = "Utility Luna"
    Description = "Exploration, research, bounded implementation, visual analysis, titles, and fast sanity checks."
    Default = "openai/gpt-5.6-luna"
  },
  [ordered]@{
    Key = "deep"
    Title = "Deep Review"
    Description = "Max-effort bounded deep-review council work only."
    Default = "openai/gpt-5.6-sol"
  }
)

$TemplateEntries = @(
  "opencode.jsonc",
  "oh-my-opencode-slim.jsonc",
  "opencode.env",
  "oh-my-opencode-slim",
  "skills"
)

function Get-OpenCodeCommand {
  if ($env:OPENCODE_BIN) {
    $Command = Get-Command $env:OPENCODE_BIN -ErrorAction SilentlyContinue
    if ($Command) {
      return $Command.Source
    }
    return $null
  }

  foreach ($Candidate in @("opencode.cmd", "opencode")) {
    $Command = Get-Command $Candidate -ErrorAction SilentlyContinue
    if ($Command) {
      return $Command.Source
    }
  }

  return $null
}

function Get-AvailableModels {
  param(
    [string]$OpenCodeCommand
  )

  if (-not $OpenCodeCommand) {
    return @()
  }

  try {
    $Models = @(& $OpenCodeCommand models openai 2>$null | ForEach-Object {
      if ($null -ne $_) { $_.Trim() }
    } | Where-Object { $_ -match "^openai/[^\s]+$" })
    if ($Models.Count -gt 0) {
      return $Models
    }
  } catch {
    return @()
  }

  return @()
}

function Select-Model {
  param(
    [object]$Slot,
    [string[]]$AvailableModels,
    [switch]$SkipPrompt
  )

  $Default = $Slot["Default"]

  if ($SkipPrompt) {
    return $Default
  }

  while ($true) {
    Write-Host ""
    Write-Host "== $($Slot["Title"]) =="
    Write-Host $Slot["Description"]
    Write-Host "Default: $Default"

    if ($AvailableModels.Count -gt 0) {
      Write-Host ""
      Write-Host "Available models:"
      for ($Index = 0; $Index -lt $AvailableModels.Count; $Index++) {
        $Marker = ""
        if ($AvailableModels[$Index] -eq $Default) {
          $Marker = " (default)"
        }
        Write-Host "  $($Index + 1). $($AvailableModels[$Index])$Marker"
      }
    } else {
      Write-Host ""
      Write-Host "No OpenAI models were returned by opencode. You can still type a full openai/model id."
    }

    $Answer = Read-Host "Choose model number or openai/model for '$($Slot["Key"])' [Enter = default]"
    if ($null -eq $Answer) {
      $Answer = ""
    } else {
      $Answer = $Answer.Trim()
    }

    if ($Answer -eq "") {
      return $Default
    }

    if ($Answer -match "^\d+$") {
      $SelectedIndex = [int]$Answer - 1
      if ($SelectedIndex -ge 0 -and $SelectedIndex -lt $AvailableModels.Count) {
        return $AvailableModels[$SelectedIndex]
      }
    }

    if ($Answer -match "^openai/[^\s]+$") {
      return $Answer
    }

    Write-Host "Invalid selection. Use a listed number, press Enter for default, or type a valid openai/model id without whitespace."
  }
}

function ConvertTo-PrettyJsonFile {
  param(
    [object]$InputObject,
    [string]$Path
  )

  $Json = $InputObject | ConvertTo-Json -Depth 100
  $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, ($Json + [Environment]::NewLine), $Utf8NoBom)
}

function Apply-ModelChoices {
  param(
    [string]$DestinationPath,
    [hashtable]$Models
  )

  $OpenCodeConfigPath = Join-Path -Path $DestinationPath -ChildPath "opencode.jsonc"
  $SlimConfigPath = Join-Path -Path $DestinationPath -ChildPath "oh-my-opencode-slim.jsonc"

  $OpenCodeConfig = Get-Content -LiteralPath $OpenCodeConfigPath -Raw | ConvertFrom-Json
  $Primary = $Models["primary"]
  $Balanced = $Models["balanced"]
  $Utility = $Models["utility"]
  $Deep = $Models["deep"]

  $OpenCodeConfig.model = $Balanced
  $OpenCodeConfig.small_model = $Utility
  $OpenCodeConfig.agent.build.model = $Primary
  $OpenCodeConfig.agent.build.variant = "medium"
  $OpenCodeConfig.agent.build.mode = "primary"
  $OpenCodeConfig.agent.build.disable = $false
  $OpenCodeConfig.agent.build.hidden = $false
  $OpenCodeConfig.agent.plan.model = $Primary
  $OpenCodeConfig.agent.plan.variant = "high"
  $OpenCodeConfig.agent.plan.mode = "primary"
  $OpenCodeConfig.agent.plan.disable = $false
  $OpenCodeConfig.agent.plan.hidden = $false
  $OpenCodeConfig.agent.general.model = $Balanced
  $OpenCodeConfig.agent.general.variant = "medium"
  $OpenCodeConfig.agent.explore.model = $Utility
  $OpenCodeConfig.agent.explore.variant = "low"
  $OpenCodeConfig.agent.title.model = $Utility
  $OpenCodeConfig.agent.title.variant = "none"
  $OpenCodeConfig.agent.summary.model = $Balanced
  $OpenCodeConfig.agent.summary.variant = "medium"
  $OpenCodeConfig.agent.compaction.model = $Balanced
  $OpenCodeConfig.agent.compaction.variant = "medium"
  ConvertTo-PrettyJsonFile -InputObject $OpenCodeConfig -Path $OpenCodeConfigPath

  $SlimConfig = Get-Content -LiteralPath $SlimConfigPath -Raw | ConvertFrom-Json
  $Preset = $SlimConfig.presets."generic-openai"
  $Preset.orchestrator.model = $Balanced
  $Preset.orchestrator.variant = "high"
  $Preset.oracle.model = $Primary
  $Preset.oracle.variant = "max"
  $Preset.council.model = $Primary
  $Preset.council.variant = "high"
  $Preset.explorer.model = $Utility
  $Preset.explorer.variant = "low"
  $Preset.librarian.model = $Utility
  $Preset.librarian.variant = "low"
  $Preset.fixer.model = $Utility
  $Preset.fixer.variant = "high"
  $Preset.designer.model = $Balanced
  $Preset.designer.variant = "medium"
  $Preset.observer.model = $Utility
  $Preset.observer.variant = "medium"

  $SlimConfig.agents."code-reviewer".model = $Balanced
  $SlimConfig.agents."code-reviewer".variant = "high"
  $SlimConfig.agents."repo-architect".model = $Primary
  $SlimConfig.agents."repo-architect".variant = "high"
  $SlimConfig.agents."test-writer".model = $Balanced
  $SlimConfig.agents."test-writer".variant = "medium"
  $SlimConfig.agents."security-reviewer".model = $Primary
  $SlimConfig.agents."security-reviewer".variant = "high"

  $CouncilPreset = $SlimConfig.council.presets."generic-review-board"
  $CouncilPreset."deep-review".model = $Deep
  $CouncilPreset."deep-review".variant = "max"
  $CouncilPreset."fast-sanity".model = $Utility
  $CouncilPreset."fast-sanity".variant = "low"
  $CouncilPreset."security-sanity".model = $Balanced
  $CouncilPreset."security-sanity".variant = "high"
  ConvertTo-PrettyJsonFile -InputObject $SlimConfig -Path $SlimConfigPath
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  throw "ProjectPath does not exist or is not a directory: $ProjectPath"
}

$RepoRoot = Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath "..")
$Source = if ($env:OPENCODE_TEMPLATE_SOURCE) {
  $env:OPENCODE_TEMPLATE_SOURCE
} else {
  Join-Path -Path $RepoRoot -ChildPath "template\.opencode"
}
$Destination = Join-Path -Path $ProjectPath -ChildPath ".opencode"

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
  throw "Template source not found: $Source"
}

foreach ($Entry in $TemplateEntries) {
  $SourceEntry = Join-Path -Path $Source -ChildPath $Entry
  if (-not (Test-Path -LiteralPath $SourceEntry)) {
    throw "Required template entry not found: $SourceEntry"
  }
}

if ((Test-Path -LiteralPath $Destination) -and -not $Force) {
  throw "Target already has .opencode. Re-run with -Force to merge and overwrite matching template files."
}

$OpenCodeCommand = Get-OpenCodeCommand
$AvailableModels = Get-AvailableModels -OpenCodeCommand $OpenCodeCommand
$SkipModelPrompt = $NonInteractive

if (-not $NonInteractive) {
  ""
  "Interactive model routing"
  "Provider queried: openai"
  if ($AvailableModels.Count -gt 0) {
    "Found $($AvailableModels.Count) model(s) via opencode models openai."
  } else {
    "No model list was available from opencode models openai. Defaults still work when the configured OpenAI models are available."
  }

  $CustomizeAnswer = Read-Host "Customize model routing now? [Y/n]"
  if ($null -eq $CustomizeAnswer) {
    $CustomizeAnswer = ""
  } else {
    $CustomizeAnswer = $CustomizeAnswer.Trim()
  }
  if ($CustomizeAnswer -match "^(n|no)$") {
    $SkipModelPrompt = $true
  }
}

$SelectedModels = @{}
foreach ($Slot in $ModelSlots) {
  $SelectedModels[$Slot["Key"]] = Select-Model -Slot $Slot -AvailableModels $AvailableModels -SkipPrompt:$SkipModelPrompt
}

$StagingRoot = $null
try {
  $StagingRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("opencode-openai-config-" + [guid]::NewGuid().ToString("N"))
  $StagedConfig = Join-Path -Path $StagingRoot -ChildPath ".opencode"
  New-Item -ItemType Directory -Path $StagedConfig | Out-Null
  foreach ($Entry in $TemplateEntries) {
    Copy-Item -LiteralPath (Join-Path -Path $Source -ChildPath $Entry) -Destination $StagedConfig -Recurse -Force
  }
  Apply-ModelChoices -DestinationPath $StagedConfig -Models $SelectedModels

  if (-not $Force) {
    if (Test-Path -LiteralPath $Destination) {
      throw "Target acquired .opencode during installation. No files were copied; re-run with -Force only if overwriting is intended."
    }
    New-Item -ItemType Directory -Path $Destination | Out-Null
  } elseif (-not (Test-Path -LiteralPath $Destination)) {
    New-Item -ItemType Directory -Path $Destination | Out-Null
  }
  Get-ChildItem -LiteralPath $StagedConfig -Force | Copy-Item -Destination $Destination -Recurse -Force
} finally {
  if ($StagingRoot -and (Test-Path -LiteralPath $StagingRoot)) {
    Remove-Item -LiteralPath $StagingRoot -Recurse -Force
  }
}

"Installed generic OpenCode config to $Destination"
""
"Selected model routing:"
foreach ($Slot in $ModelSlots) {
  "  $($Slot["Key"]): $($SelectedModels[$Slot["Key"]])"
}
""
"Before starting OpenCode in the target project, enable required runtime features in the current PowerShell session:"
'  $env:OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true"'
'  $env:OPENCODE_ENABLE_EXA = "1"'
'  $env:OH_MY_OPENCODE_SLIM_PRESET = "generic-openai"'
"  opencode"
""
"For persistent setup, add the two OPENCODE_* variables to your shell profile. Keep OH_MY_OPENCODE_SLIM_PRESET project-scoped so it does not override unrelated projects."
