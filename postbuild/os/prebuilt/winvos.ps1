Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-FreeDriveLetters {
	param(
		[int] $Count
	)

	$used = (Get-Volume | Where-Object { $_.DriveLetter } | ForEach-Object { $_.DriveLetter.ToString().ToUpperInvariant() })
	$available = @('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') | Where-Object { $_ -notin $used }
	if ($available.Count -lt $Count) {
		throw "Not enough free drive letters for VHDX staging."
	}

	return $available[0..($Count - 1)]
}

function Invoke-External {
	param(
		[string] $FilePath,
		[string[]] $Arguments
	)

	& $FilePath @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "$FilePath failed with exit code $LASTEXITCODE"
	}
}

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	throw "Run this script from an elevated PowerShell session (Administrator)."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$isoPath = Join-Path $scriptDir "ValidationOS.iso"
$pkgList = Join-Path $scriptDir "armvirt_config.pkg"
$policyReg = Join-Path $scriptDir "armvirt_policy.reg"
$wimPath = Join-Path $scriptDir "ValidationOS.wim"
$vhdxPath = Join-Path $scriptDir "ValidationOS.vhdx"

if (-not (Test-Path $pkgList)) {
	throw "Missing package list: $pkgList"
}

if (-not (Test-Path $policyReg)) {
	throw "Missing registry policy file: $policyReg"
}

if (Test-Path $isoPath) {
	Write-Host "Validation OS ISO already present, skipping download."
} else {
	Write-Host "Downloading Validation OS ISO..."
	$ProgressPreference = 'SilentlyContinue'
	Invoke-WebRequest -Uri "https://aka.ms/DownloadValidationOS_arm64" -OutFile $isoPath
}

$isoMount = $null
$attachedVhdx = $false
$efiLetter = $null
$windowsLetter = $null

try {
	Write-Host "Mounting ISO and running GenImage.cmd..."
	$isoMount = Mount-DiskImage -ImagePath (Resolve-Path $isoPath).Path -PassThru
	$isoDrive = ($isoMount | Get-Volume).DriveLetter
	if (-not $isoDrive) {
		throw "Could not resolve mounted ISO drive letter."
	}

	$genImageCmd = "{0}:\GenImage\GenImage.cmd" -f $isoDrive
	if (-not (Test-Path $genImageCmd)) {
		throw "GenImage.cmd not found at $genImageCmd"
	}

	$genImageArgs = @(
		"/c"
		"`"$genImageCmd`" -PackagesList:$pkgList -PackagePath:${isoDrive}:\cabs -ImagePath:${isoDrive}:\ -RegistryImport:$policyReg -OutPath:$scriptDir -wim -NoWait"
	)
	Invoke-External -FilePath "cmd.exe" -Arguments $genImageArgs

	if (-not (Test-Path $wimPath)) {
		$generatedWim = Get-ChildItem -Path $scriptDir -Filter "*.wim" -File | Select-Object -First 1
		if (-not $generatedWim) {
			throw "No WIM was generated in $scriptDir"
		}
		$wimPath = $generatedWim.FullName
	}

	if (Test-Path $vhdxPath) {
		Remove-Item -Path $vhdxPath -Force
	}

	Write-Host "Creating and partitioning ValidationOS.vhdx..."
	$letters = Get-FreeDriveLetters -Count 2
	$efiLetter = $letters[0]
	$windowsLetter = $letters[1]

	$createScript = @"
create vdisk file="$vhdxPath" maximum=32768 type=expandable
select vdisk file="$vhdxPath"
attach vdisk
convert gpt
create partition efi size=100
format quick fs=fat32 label="SYSTEM"
assign letter=$efiLetter
create partition msr size=16
create partition primary
format quick fs=ntfs label="Windows"
assign letter=$windowsLetter
exit
"@

	$createScriptPath = Join-Path $env:TEMP ("diskpart-create-{0}.txt" -f [guid]::NewGuid().ToString())
	Set-Content -Path $createScriptPath -Value $createScript -Encoding ascii
	try {
		Invoke-External -FilePath "diskpart.exe" -Arguments @("/s", $createScriptPath)
	} finally {
		Remove-Item -Path $createScriptPath -Force -ErrorAction SilentlyContinue
	}
	$attachedVhdx = $true

	Write-Host "Applying WIM image to VHDX..."
	Invoke-External -FilePath "dism.exe" -Arguments @("/Apply-Image", "/ImageFile:$wimPath", "/Index:1", "/ApplyDir:${windowsLetter}:\")

	Write-Host "Creating UEFI boot files..."
	Invoke-External -FilePath "bcdboot.exe" -Arguments @("${windowsLetter}:\Windows", "/s", "${efiLetter}:", "/f", "UEFI")

	Write-Host "ValidationOS.vhdx generated at: $vhdxPath"
}
finally {
	if ($attachedVhdx) {
		$detachScript = @"
select vdisk file="$vhdxPath"
detach vdisk
exit
"@
		$detachScriptPath = Join-Path $env:TEMP ("diskpart-detach-{0}.txt" -f [guid]::NewGuid().ToString())
		Set-Content -Path $detachScriptPath -Value $detachScript -Encoding ascii
		try {
			& diskpart.exe /s $detachScriptPath | Out-Null
		} finally {
			Remove-Item -Path $detachScriptPath -Force -ErrorAction SilentlyContinue
		}
	}

	if ($isoMount) {
		Dismount-DiskImage -ImagePath $isoMount.ImagePath
	}
}
