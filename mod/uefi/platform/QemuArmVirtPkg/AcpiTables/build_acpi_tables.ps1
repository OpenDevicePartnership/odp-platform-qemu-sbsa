# SPDX-License-Identifier: MIT

[CmdletBinding()]
param(
    [string]$InputAsl = "ec.asl",
    [string]$OutputDir = "OUTPUT",
    [string]$OutputDat = "ACPITABL.dat"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    throw $Message
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$inputAslPath = Join-Path $scriptDir $InputAsl
$outputDirPath = if ([System.IO.Path]::IsPathRooted($OutputDir)) { $OutputDir } else { Join-Path $scriptDir $OutputDir }

$scriptDir = (Resolve-Path $scriptDir).Path

if (-not (Test-Path -Path $inputAslPath -PathType Leaf)) {
    Fail "Missing ACPI input ASL file: $inputAslPath"
}

$iaslCmd = Get-Command iasl -ErrorAction SilentlyContinue
if (-not $iaslCmd) {
    Fail "iasl compiler not found in PATH. Install ACPICA iasl on the runner."
}

New-Item -Path $outputDirPath -ItemType Directory -Force | Out-Null

$prefix = Join-Path $outputDirPath ([System.IO.Path]::GetFileNameWithoutExtension($InputAsl))
$amlPath = "$prefix.aml"
$datPath = Join-Path $outputDirPath $OutputDat

Write-Host "[acpi-build] compiling $inputAslPath with iasl"
& $iaslCmd.Source -tc -p $prefix -I $scriptDir $inputAslPath
if ($LASTEXITCODE -ne 0) {
    Fail "iasl failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -Path $amlPath -PathType Leaf)) {
    Fail "Expected AML output not found: $amlPath"
}

Copy-Item -Path $amlPath -Destination $datPath -Force
$datPath = (Resolve-Path $datPath).Path
Write-Host "[acpi-build] ACPITABL.dat: $datPath"

# Export for the remainder of this process (callers that dot/&-invoke this
# script in the same step) and, when running under GitHub Actions, for
# subsequent workflow steps.
$env:ACPITABL_DAT_PATH = $datPath
if ($env:GITHUB_ENV) {
    "ACPITABL_DAT_PATH=$datPath" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
}
