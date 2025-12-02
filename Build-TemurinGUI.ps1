#Requires -Version 5.1
<#
.SYNOPSIS
    Build script to package TemurinLTS-GUI.ps1 as a standalone EXE

.DESCRIPTION
    This script uses PS2EXE to compile the PowerShell script into a Windows executable.
    It will automatically install PS2EXE from PSGallery if not present.

.NOTES
    Run this script with PowerShell 7 (pwsh): pwsh -File Build-TemurinGUI.ps1
#>

param(
    [switch]$NoConsole = $true,
    [switch]$RequireAdmin = $false,
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ScriptDir) { $ScriptDir = Get-Location }

$SourceScript = Join-Path $ScriptDir "TemurinLTS-GUI.ps1"
$OutputExe = Join-Path $ScriptDir "TemurinLTS-Manager.exe"
$IconPath = Join-Path $ScriptDir "temurin.ico"

# Metadata
$AppTitle = "Temurin LTS JDK Manager"
$AppDescription = "Manage Eclipse Temurin LTS Java Development Kits via winget"
$AppCompany = "Temurin Manager"
$AppProduct = "Temurin LTS JDK Manager"
$AppVersion = "2.0.0.0"
$AppCopyright = "MIT License"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Temurin LTS GUI - EXE Builder" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check source script exists
if (-not (Test-Path $SourceScript)) {
    Write-Host "[ERROR] Source script not found: $SourceScript" -ForegroundColor Red
    Write-Host "Make sure TemurinLTS-GUI.ps1 is in the same directory as this build script." -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Source script found: $SourceScript" -ForegroundColor Green

# Check/Install PS2EXE
Write-Host ""
Write-Host "Checking for PS2EXE module..." -ForegroundColor Cyan

$ps2exe = Get-Module -ListAvailable -Name ps2exe

if (-not $ps2exe) {
    if ($SkipInstall) {
        Write-Host "[ERROR] PS2EXE module not installed. Run without -SkipInstall to auto-install." -ForegroundColor Red
        exit 1
    }

    Write-Host "[INFO] PS2EXE not found. Installing from PSGallery..." -ForegroundColor Yellow

    try {
        Install-Module -Name ps2exe -Force -Scope CurrentUser -AllowClobber
        Write-Host "[OK] PS2EXE installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to install PS2EXE: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Try installing manually with PowerShell 7:" -ForegroundColor Yellow
        Write-Host "  pwsh -Command 'Install-Module -Name ps2exe -Scope CurrentUser -Force'" -ForegroundColor White
        exit 1
    }
}
else {
    Write-Host "[OK] PS2EXE module found (v$($ps2exe.Version))" -ForegroundColor Green
}

# Import the module
Import-Module ps2exe -Force

# Check for custom icon
if (-not (Test-Path $IconPath)) {
    Write-Host "[INFO] No custom icon found (optional: place temurin.ico in script directory)" -ForegroundColor Yellow
    $IconPath = $null
}
else {
    Write-Host "[OK] Custom icon found: $IconPath" -ForegroundColor Green
}

# Build parameters
Write-Host ""
Write-Host "Building EXE with the following settings:" -ForegroundColor Cyan
Write-Host "  Source:      $SourceScript" -ForegroundColor Gray
Write-Host "  Output:      $OutputExe" -ForegroundColor Gray
Write-Host "  Title:       $AppTitle" -ForegroundColor Gray
Write-Host "  Version:     $AppVersion" -ForegroundColor Gray
Write-Host "  No Console:  $NoConsole" -ForegroundColor Gray
Write-Host "  Admin:       $RequireAdmin" -ForegroundColor Gray
Write-Host ""

# Build the EXE
Write-Host "Compiling..." -ForegroundColor Cyan

$ps2exeParams = @{
    InputFile    = $SourceScript
    OutputFile   = $OutputExe
    Title        = $AppTitle
    Description  = $AppDescription
    Company      = $AppCompany
    Product      = $AppProduct
    Version      = $AppVersion
    Copyright    = $AppCopyright
    NoConsole    = $NoConsole
    RequireAdmin = $RequireAdmin
}

if ($IconPath) {
    $ps2exeParams.IconFile = $IconPath
}

try {
    Invoke-ps2exe @ps2exeParams

    if (Test-Path $OutputExe) {
        $exeInfo = Get-Item $OutputExe
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host "  BUILD SUCCESSFUL" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Output: $OutputExe" -ForegroundColor White
        Write-Host "Size:   $([math]::Round($exeInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray
        Write-Host ""
        Write-Host "You can now run TemurinLTS-Manager.exe" -ForegroundColor Cyan
        Write-Host ""
    }
    else {
        Write-Host "[ERROR] Build completed but EXE not found" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Build failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
