param(
  [string]$ProjectPath = (Get-Location).Path,
  [switch]$Force,
  [switch]$NonInteractive,
  [string]$Provider = "openai"
)

$ErrorActionPreference = "Stop"

$ModelSlots = @(
  [ordered]@{
    Key = "primary"
    Title = "Primary and deep reasoning"
    Description = "Planning, fixing, Oracle, architecture, and high-stakes specialist work."
    Default = "openai/gpt-5.6-sol"
  },
  [ordered]@{
    Key = "balanced"
    Title = "Fast and balanced work"
    Description = "Routine orchestration, general work, exploration, docs, design, titles, summaries, and compaction."
    Default = "openai/gpt-5.6-terra"
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
    [string]$OpenCodeCommand,
    [string]$ProviderName
  )

  if (-not $OpenCodeCommand) {
    return @()
  }

  try {
    $Models = @(& $OpenCodeCommand models $ProviderName 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^[^/\s]+/.+" })
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
      Write-Host "No models were returned by opencode. You can still type a full provider/model id."
    }

    $Answer = Read-Host "Choose model number or provider/model for '$($Slot["Key"])' [Enter = default]"
    $Answer = $Answer.Trim()

    if ($Answer -eq "") {
      return $Default
    }

    if ($Answer -match "^\d+$") {
      $SelectedIndex = [int]$Answer - 1
      if ($SelectedIndex -ge 0 -and $SelectedIndex -lt $AvailableModels.Count) {
        return $AvailableModels[$SelectedIndex]
      }
    }

    if ($Answer -match "^[^\s/]+/.+$") {
      return $Answer
    }

    Write-Host "Invalid selection. Use a listed number, press Enter for default, or type provider/model."
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

  $OpenCodeConfig.model = $Primary
  $OpenCodeConfig.small_model = $Balanced
  $OpenCodeConfig.agent.build.model = $Primary
  $OpenCodeConfig.agent.build.variant = "medium"
  $OpenCodeConfig.agent.plan.model = $Primary
  $OpenCodeConfig.agent.plan.variant = "high"
  $OpenCodeConfig.agent.general.model = $Balanced
  $OpenCodeConfig.agent.general.variant = "medium"
  $OpenCodeConfig.agent.explore.model = $Balanced
  $OpenCodeConfig.agent.explore.variant = "low"
  $OpenCodeConfig.agent.title.model = $Balanced
  $OpenCodeConfig.agent.title.variant = "low"
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
    [pscustomobject]@{ id = $Balanced; variant = "high" }
  )
  $Preset.council.model = @(
    [pscustomobject]@{ id = $Primary; variant = "high" },
    [pscustomobject]@{ id = $Balanced; variant = "high" }
  )
  $Preset.explorer.model = @(
    [pscustomobject]@{ id = $Balanced; variant = "low" },
    [pscustomobject]@{ id = $Primary; variant = "low" }
  )
  $Preset.librarian.model = @(
    [pscustomobject]@{ id = $Balanced; variant = "low" },
    [pscustomobject]@{ id = $Primary; variant = "low" }
  )
  $Preset.fixer.model = @(
    [pscustomobject]@{ id = $Primary; variant = "high" },
    [pscustomobject]@{ id = $Balanced; variant = "high" }
  )
  $Preset.designer.model = @(
    [pscustomobject]@{ id = $Balanced; variant = "medium" },
    [pscustomobject]@{ id = $Primary; variant = "high" }
  )

  $SlimConfig.agents."code-reviewer".model = $Balanced
  $SlimConfig.agents."code-reviewer".variant = "high"
  $SlimConfig.agents."repo-architect".model = $Primary
  $SlimConfig.agents."repo-architect".variant = "xhigh"
  $SlimConfig.agents."test-writer".model = $Balanced
  $SlimConfig.agents."test-writer".variant = "medium"
  $SlimConfig.agents."security-reviewer".model = $Primary
  $SlimConfig.agents."security-reviewer".variant = "xhigh"

  $CouncilPreset = $SlimConfig.council.presets."generic-review-board"
  $SlimConfig.council.councillor_retries = 1
  $CouncilPreset."deep-review".model = $Primary
  $CouncilPreset."deep-review".variant = "xhigh"
  $CouncilPreset."fast-sanity".model = $Balanced
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

if (-not (Test-Path -LiteralPath $Destination)) {
  New-Item -ItemType Directory -Path $Destination | Out-Null
}

Get-ChildItem -LiteralPath $Source -Force | Copy-Item -Destination $Destination -Recurse -Force

$OpenCodeCommand = Get-OpenCodeCommand
$AvailableModels = Get-AvailableModels -OpenCodeCommand $OpenCodeCommand -ProviderName $Provider
$SkipModelPrompt = $NonInteractive

if (-not $NonInteractive) {
  ""
  "Interactive model routing"
  "Provider queried: $Provider"
  if ($AvailableModels.Count -gt 0) {
    "Found $($AvailableModels.Count) model(s) via opencode models $Provider."
  } else {
    "No model list was available from opencode models $Provider. Defaults still work if your provider supports them."
  }

  $CustomizeAnswer = Read-Host "Customize model routing now? [Y/n]"
  if ($CustomizeAnswer.Trim() -match "^(n|no)$") {
    $SkipModelPrompt = $true
  }
}

$SelectedModels = @{}
foreach ($Slot in $ModelSlots) {
  $SelectedModels[$Slot["Key"]] = Select-Model -Slot $Slot -AvailableModels $AvailableModels -SkipPrompt:$SkipModelPrompt
}

Apply-ModelChoices -DestinationPath $Destination -Models $SelectedModels

"Installed generic OpenCode config to $Destination"
""
"Selected model routing:"
foreach ($Slot in $ModelSlots) {
  "  $($Slot["Key"]): $($SelectedModels[$Slot["Key"]])"
}
""
"Restart OpenCode in the target project so it loads the new config."
