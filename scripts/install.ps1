param(
  [string]$ProjectPath = (Get-Location).Path,
  [switch]$Force
)

$ErrorActionPreference = "Stop"

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

"Installed generic OpenCode config to $Destination"
"Restart OpenCode in the target project so it loads the new config."
