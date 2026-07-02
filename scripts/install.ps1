param(
  [string]$ProjectPath = (Get-Location).Path,
  [switch]$Force,
  [switch]$NonInteractive,
  [string]$Provider = "openai"
)

$ErrorActionPreference = "Stop"

$ModelSlots = @(
  [ordered]@{
    Key = "core"
    Title = "Core reasoning and orchestration"
    Description = "Primary coordinator plus built-in build, plan, and general agents. Use your strongest reliable coding model."
    Default = "openai/gpt-5.5"
  },
  [ordered]@{
    Key = "explorer"
    Title = "Explorer and code search"
    Description = "Fast repo navigation, grep, file discovery, and context mapping. Use a fast inexpensive coding model."
    Default = "openai/gpt-5.3-codex-spark"
  },
  [ordered]@{
    Key = "fixer"
    Title = "Fixer and bounded implementation"
    Description = "Focused code edits after scope is clear. Use a fast coding model that is good at mechanical changes."
    Default = "openai/gpt-5.3-codex-spark"
  },
  [ordered]@{
    Key = "designer"
    Title = "Designer and UI/UX work"
    Description = "User-facing UI, responsive layout, visual polish, and interaction changes. Use a model that handles frontend design well."
    Default = "openai/gpt-5.3-codex-spark"
  },
  [ordered]@{
    Key = "title"
    Title = "Title generation"
    Description = "Short session or conversation titles. Use a fast cheap model; this does not need deep reasoning."
    Default = "openai/gpt-5.3-codex-spark"
  },
  [ordered]@{
    Key = "summary"
    Title = "Summary generation"
    Description = "Short session summaries and handoff summaries. Use a fast model with decent compression quality."
    Default = "openai/gpt-5.3-codex-spark"
  },
  [ordered]@{
    Key = "compaction"
    Title = "Context compaction"
    Description = "Compresses long conversations before continuing. Use a reliable model because bad compaction loses context."
    Default = "openai/gpt-5.5"
  },
  [ordered]@{
    Key = "librarian"
    Title = "Librarian and docs research"
    Description = "External docs, library behavior, examples, and reference lookups. Use a reliable model; low variant is configured in the preset."
    Default = "openai/gpt-5.5"
  },
  [ordered]@{
    Key = "reviewer"
    Title = "Code reviewer"
    Description = "Correctness, regressions, maintainability, edge cases, and test-gap review. Use a strong reasoning model."
    Default = "openai/gpt-5.5"
  },
  [ordered]@{
    Key = "architect"
    Title = "Architecture reviewer"
    Description = "Module boundaries, API contracts, migrations, data flow, and technical tradeoffs. Use a strong reasoning model."
    Default = "openai/gpt-5.5"
  },
  [ordered]@{
    Key = "test"
    Title = "Test writer"
    Description = "Test strategy, fixtures, regression coverage, and reproduction cases. Use a capable coding model."
    Default = "openai/gpt-5.3-codex-spark"
  },
  [ordered]@{
    Key = "security"
    Title = "Security reviewer"
    Description = "Defensive auth, secrets, injection, unsafe IO, dependency, deployment, and data exposure review. Use a strong reasoning model."
    Default = "openai/gpt-5.5"
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
  $OpenCodeConfig.model = $Models["core"]
  $OpenCodeConfig.small_model = $Models["explorer"]
  $OpenCodeConfig.agent.build.model = $Models["core"]
  $OpenCodeConfig.agent.plan.model = $Models["core"]
  $OpenCodeConfig.agent.general.model = $Models["core"]
  $OpenCodeConfig.agent.explore.model = $Models["explorer"]
  $OpenCodeConfig.agent.title.model = $Models["title"]
  $OpenCodeConfig.agent.summary.model = $Models["summary"]
  $OpenCodeConfig.agent.compaction.model = $Models["compaction"]
  ConvertTo-PrettyJsonFile -InputObject $OpenCodeConfig -Path $OpenCodeConfigPath

  $SlimConfig = Get-Content -LiteralPath $SlimConfigPath -Raw | ConvertFrom-Json
  $Preset = $SlimConfig.presets."generic-openai"
  $Preset.orchestrator.model = $Models["core"]
  $Preset.oracle.model = $Models["core"]
  $Preset.council.model = $Models["core"]
  $Preset.explorer.model = $Models["explorer"]
  $Preset.librarian.model = $Models["librarian"]
  $Preset.fixer.model = $Models["fixer"]
  $Preset.designer.model = $Models["designer"]

  $SlimConfig.agents."code-reviewer".model = $Models["reviewer"]
  $SlimConfig.agents."repo-architect".model = $Models["architect"]
  $SlimConfig.agents."test-writer".model = $Models["test"]
  $SlimConfig.agents."security-reviewer".model = $Models["security"]

  $CouncilPreset = $SlimConfig.council.presets."generic-review-board"
  $CouncilPreset."deep-review".model = $Models["reviewer"]
  $CouncilPreset."fast-sanity".model = $Models["explorer"]
  $CouncilPreset."security-sanity".model = $Models["security"]
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
