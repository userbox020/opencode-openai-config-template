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
    Description = "Complex planning, fixing, review, security, architecture, and quality-profile work."
    Default = "openai/gpt-5.6-sol"
  },
  [ordered]@{
    Key = "balanced"
    Title = "Balanced Terra"
    Description = "Balanced-profile orchestration and build, plus general work, synthesis, compaction, design, and normal review."
    Default = "openai/gpt-5.6-terra"
  },
  [ordered]@{
    Key = "utility"
    Title = "Utility Luna"
    Description = "Exploration, titles, summaries, high-volume utility work, and fast sanity checks."
    Default = "openai/gpt-5.6-luna"
  }
)

function Get-OpenCodeCommand {
  if ($env:OPENCODE_BIN) {
    $Configured = Get-Command $env:OPENCODE_BIN -ErrorAction SilentlyContinue
    if ($Configured) {
      return $Configured.Source
    }
    if (Test-Path -LiteralPath $env:OPENCODE_BIN -PathType Leaf) {
      return (Resolve-Path -LiteralPath $env:OPENCODE_BIN).Path
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
    } | Where-Object {
      $_ -match "^openai/[A-Za-z0-9._-]+$" -and $_ -notmatch "-pro$"
    })
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

    if ($Answer -match "^openai/[A-Za-z0-9._-]+$") {
      if ($Answer -match "-pro$") {
        Write-Host "ChatGPT OAuth does not expose OpenCode Pro-mode IDs. Choose a standard model."
        continue
      }
      if ($AvailableModels.Count -gt 0 -and $Answer -notin $AvailableModels) {
        Write-Host "That model was not returned by opencode models openai. Choose a listed model."
        continue
      }
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

function Test-OpenCodeVersion {
  param(
    [string]$OpenCodeCommand
  )

  if (-not $OpenCodeCommand) {
    return
  }

  try {
    $RawVersion = @(& $OpenCodeCommand --version 2>$null)[0].Trim()
    if ($RawVersion -notmatch "^v?(\d+)\.(\d+)\.(\d+)(?:\+[0-9A-Za-z.-]+)?$") {
      throw "Unrecognized version: $RawVersion"
    }
    $VersionText = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
    if ([version]$VersionText -lt [version]"1.18.10") {
      Write-Warning "OpenCode $RawVersion detected. Upgrade to 1.18.10 or newer before using this template."
    }
  } catch {
    Write-Warning "Could not verify the OpenCode version. This template requires OpenCode 1.18.10 or newer."
  }
}

function Set-RoutingProfileModels {
  param(
    [string]$Path,
    [string]$Primary,
    [string]$Balanced,
    [string]$Utility
  )

  $Content = [System.IO.File]::ReadAllText($Path)
  foreach ($Entry in @(
    @{ Key = "primary"; Value = $Primary },
    @{ Key = "balanced"; Value = $Balanced },
    @{ Key = "utility"; Value = $Utility }
  )) {
    $Pattern = "(?m)^(\s*$($Entry.Key):\s*)`"[^`"]+`""
    $JsonValue = $Entry.Value | ConvertTo-Json -Compress
    $Content = [regex]::Replace($Content, $Pattern, {
      param($Match)
      return $Match.Groups[1].Value + $JsonValue
    })
  }

  $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Apply-ModelChoices {
  param(
    [string]$DestinationPath,
    [hashtable]$Models
  )

  $OpenCodeConfigPath = Join-Path -Path $DestinationPath -ChildPath "opencode.jsonc"
  $SlimConfigPath = Join-Path -Path $DestinationPath -ChildPath "oh-my-opencode-slim.jsonc"
  $RoutingProfilePath = Join-Path -Path $DestinationPath -ChildPath "routing-profile.js"

  $OpenCodeConfig = Get-Content -LiteralPath $OpenCodeConfigPath -Raw | ConvertFrom-Json
  $Primary = $Models["primary"]
  $Balanced = $Models["balanced"]
  $Utility = $Models["utility"]

  $OpenCodeConfig.model = $Balanced
  $OpenCodeConfig.small_model = $Utility
  $OpenCodeConfig.agent.build.model = $Balanced
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
  $OpenCodeConfig.agent.summary.model = $Utility
  $OpenCodeConfig.agent.summary.variant = "low"
  $OpenCodeConfig.agent.compaction.model = $Balanced
  $OpenCodeConfig.agent.compaction.variant = "medium"
  ConvertTo-PrettyJsonFile -InputObject $OpenCodeConfig -Path $OpenCodeConfigPath
  Set-RoutingProfileModels -Path $RoutingProfilePath -Primary $Primary -Balanced $Balanced -Utility $Utility

  $SlimConfig = Get-Content -LiteralPath $SlimConfigPath -Raw | ConvertFrom-Json
  $BalancedPreset = $SlimConfig.presets.balanced
  $BalancedPreset.orchestrator.model = @(
    [pscustomobject]@{ id = $Balanced; variant = "medium" },
    [pscustomobject]@{ id = $Primary; variant = "medium" }
  )
  $BalancedPreset.oracle.model = $Primary
  $BalancedPreset.oracle.variant = "xhigh"
  $BalancedPreset.council.model = $Primary
  $BalancedPreset.council.variant = "high"
  $BalancedPreset.explorer.model = $Utility
  $BalancedPreset.explorer.variant = "low"
  $BalancedPreset.librarian.model = $Balanced
  $BalancedPreset.librarian.variant = "low"
  $BalancedPreset.fixer.model = $Primary
  $BalancedPreset.fixer.variant = "high"
  $BalancedPreset.designer.model = @(
    [pscustomobject]@{ id = $Balanced; variant = "medium" },
    [pscustomobject]@{ id = $Primary; variant = "medium" }
  )
  $BalancedPreset."code-reviewer".model = $Balanced
  $BalancedPreset."code-reviewer".variant = "high"
  $BalancedPreset."repo-architect".model = $Primary
  $BalancedPreset."repo-architect".variant = "high"
  $BalancedPreset."test-writer".model = $Balanced
  $BalancedPreset."test-writer".variant = "medium"
  $BalancedPreset."security-reviewer".model = $Primary
  $BalancedPreset."security-reviewer".variant = "high"

  $QualityPreset = $SlimConfig.presets.quality
  $QualityPreset.orchestrator.model = @(
    [pscustomobject]@{ id = $Primary; variant = "medium" },
    [pscustomobject]@{ id = $Balanced; variant = "medium" }
  )
  $QualityPreset.oracle.model = $Primary
  $QualityPreset.oracle.variant = "max"
  $QualityPreset.council.model = $Primary
  $QualityPreset.council.variant = "xhigh"
  $QualityPreset.explorer.model = $Balanced
  $QualityPreset.explorer.variant = "low"
  $QualityPreset.librarian.model = $Primary
  $QualityPreset.librarian.variant = "medium"
  $QualityPreset.fixer.model = $Primary
  $QualityPreset.fixer.variant = "xhigh"
  $QualityPreset.designer.model = @(
    [pscustomobject]@{ id = $Primary; variant = "medium" },
    [pscustomobject]@{ id = $Balanced; variant = "medium" }
  )
  $QualityPreset."code-reviewer".model = $Primary
  $QualityPreset."code-reviewer".variant = "xhigh"
  $QualityPreset."repo-architect".model = $Primary
  $QualityPreset."repo-architect".variant = "xhigh"
  $QualityPreset."test-writer".model = $Primary
  $QualityPreset."test-writer".variant = "high"
  $QualityPreset."security-reviewer".model = $Primary
  $QualityPreset."security-reviewer".variant = "xhigh"

  $SlimConfig.council.timeout = 300000
  $SlimConfig.council.councillor_retries = 1
  $BalancedCouncil = $SlimConfig.council.presets.balanced
  $BalancedCouncil."deep-review".model = $Primary
  $BalancedCouncil."deep-review".variant = "xhigh"
  $BalancedCouncil."fast-sanity".model = $Utility
  $BalancedCouncil."fast-sanity".variant = "low"
  $BalancedCouncil."security-sanity".model = $Balanced
  $BalancedCouncil."security-sanity".variant = "high"
  $QualityCouncil = $SlimConfig.council.presets.quality
  $QualityCouncil."deep-review".model = $Primary
  $QualityCouncil."deep-review".variant = "max"
  $QualityCouncil."fast-sanity".model = $Balanced
  $QualityCouncil."fast-sanity".variant = "low"
  $QualityCouncil."security-sanity".model = $Primary
  $QualityCouncil."security-sanity".variant = "high"
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
$null = Test-OpenCodeVersion -OpenCodeCommand $OpenCodeCommand
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

if (@($SelectedModels.Values | Select-Object -Unique).Count -ne $ModelSlots.Count) {
  throw "The primary, balanced, and utility model slots must use distinct models."
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
"  profiles: balanced (default), quality"
""
"Restart OpenCode in the target project so it loads the new config."
