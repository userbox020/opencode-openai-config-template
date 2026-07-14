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
    Description = "Routine orchestration and build, plus high-effort planning, fixing, security, and architecture."
    Default = "openai/gpt-5.6-sol"
  },
  [ordered]@{
    Key = "balanced"
    Title = "Balanced Terra"
    Description = "General work, source synthesis, summaries, compaction, design, and normal review."
    Default = "openai/gpt-5.6-terra"
  },
  [ordered]@{
    Key = "utility"
    Title = "Utility Luna"
    Description = "Exploration, titles, high-volume utility work, and fast sanity checks."
    Default = "openai/gpt-5.6-luna"
  },
  [ordered]@{
    Key = "deep"
    Title = "Deep Sol-Pro"
    Description = "Bounded deep-review council work only."
    Default = "openai/gpt-5.6-sol-pro"
  }
)

function Get-OpenCodeCommand {
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

  $OpenCodeConfig.model = $Primary
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
  $Preset.orchestrator.model = @(
    [pscustomobject]@{ id = $Primary; variant = "medium" },
    [pscustomobject]@{ id = $Balanced; variant = "medium" }
  )
  $Preset.oracle.model = @(
    [pscustomobject]@{ id = $Primary; variant = "xhigh" },
    [pscustomobject]@{ id = $Balanced; variant = "xhigh" }
  )
  $Preset.council.model = @(
    [pscustomobject]@{ id = $Primary; variant = "high" },
    [pscustomobject]@{ id = $Balanced; variant = "high" }
  )
  $Preset.explorer.model = @(
    [pscustomobject]@{ id = $Utility; variant = "low" },
    [pscustomobject]@{ id = $Balanced; variant = "low" }
  )
  $Preset.librarian.model = @(
    [pscustomobject]@{ id = $Balanced; variant = "low" },
    [pscustomobject]@{ id = $Utility; variant = "low" }
  )
  $Preset.fixer.model = @(
    [pscustomobject]@{ id = $Primary; variant = "high" },
    [pscustomobject]@{ id = $Balanced; variant = "high" }
  )
  $Preset.designer.model = @(
    [pscustomobject]@{ id = $Balanced; variant = "medium" },
    [pscustomobject]@{ id = $Primary; variant = "medium" }
  )

  $SlimConfig.agents."code-reviewer".model = $Balanced
  $SlimConfig.agents."code-reviewer".variant = "high"
  $SlimConfig.agents."repo-architect".model = $Primary
  $SlimConfig.agents."repo-architect".variant = "high"
  $SlimConfig.agents."test-writer".model = $Balanced
  $SlimConfig.agents."test-writer".variant = "medium"
  $SlimConfig.agents."security-reviewer".model = $Primary
  $SlimConfig.agents."security-reviewer".variant = "high"

  $CouncilPreset = $SlimConfig.council.presets."generic-review-board"
  $SlimConfig.council.timeout = 300000
  $SlimConfig.council.councillor_retries = 1
  $CouncilPreset."deep-review".model = $Deep
  $CouncilPreset."deep-review".variant = "high"
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
$Source = Join-Path -Path $RepoRoot -ChildPath "template\.opencode"
$Destination = Join-Path -Path $ProjectPath -ChildPath ".opencode"

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
  throw "Template source not found: $Source"
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
  Get-ChildItem -LiteralPath $Source -Force | Copy-Item -Destination $StagedConfig -Recurse -Force
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
"Restart OpenCode in the target project so it loads the new config."
