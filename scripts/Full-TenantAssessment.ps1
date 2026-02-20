<#
.SYNOPSIS
    Full Tenant Assessment — runs all five modules and produces a combined report.
.DESCRIPTION
    Executes discovery, identity & access, security posture, governance, and
    licensing scripts in sequence. Each module writes its own report; this script
    combines them into a single Full-TenantAssessment.md.
.PARAMETER ClientId
    App registration client ID. If omitted, uses interactive auth.
.PARAMETER TenantId
    Entra ID tenant ID. Required for app-only auth.
.PARAMETER ClientSecret
    Client secret value. Required for app-only auth.
.PARAMETER OutputPath
    Directory for report output. Defaults to ../output relative to this script.
.EXAMPLE
    # Interactive auth
    ./Full-TenantAssessment.ps1

    # App-only auth
    ./Full-TenantAssessment.ps1 -ClientId "your-app-id" -TenantId "your-tenant-id" -ClientSecret "your-secret"
#>

param(
    [string]$ClientId,
    [string]$TenantId,
    [string]$ClientSecret,
    [string]$OutputPath = "$PSScriptRoot/../output"
)

$ErrorActionPreference = "Continue"
$scriptDir = $PSScriptRoot

# Pass auth params through to each module
$authParams = @{}
if ($ClientId) { $authParams["ClientId"] = $ClientId }
if ($TenantId) { $authParams["TenantId"] = $TenantId }
if ($ClientSecret) { $authParams["ClientSecret"] = $ClientSecret }
$authParams["OutputPath"] = $OutputPath

$modules = @(
    @{ Script = "01-discovery.ps1";       Name = "Discovery" }
    @{ Script = "02-identity-access.ps1"; Name = "Identity & Access" }
    @{ Script = "03-security-posture.ps1"; Name = "Security Posture" }
    @{ Script = "04-governance.ps1";      Name = "Governance" }
    @{ Script = "05-licensing-usage.ps1"; Name = "Licensing & Usage" }
)

Write-Host "============================================"
Write-Host "  Graph API for Architects"
Write-Host "  Full Tenant Assessment"
Write-Host "============================================"
Write-Host ""

foreach ($module in $modules) {
    Write-Host "--- Running: $($module.Name) ---"
    & "$scriptDir/$($module.Script)" @authParams
    Write-Host ""
}

# Combine individual reports into one
Write-Host "--- Combining reports ---"
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$combined = @()
$combined += "# Full Tenant Assessment"
$combined += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$combined += ""
$combined += "---"
$combined += ""

foreach ($module in $modules) {
    $reportFile = Join-Path $OutputPath "$($module.Script -replace '\.ps1$', '.md')"
    if (Test-Path $reportFile) {
        $content = Get-Content $reportFile -Raw
        # Strip the individual report header (first two lines) to avoid duplication
        $lines = $content -split "`n"
        $combined += ($lines | Select-Object -Skip 2) -join "`n"
        $combined += ""
        $combined += "---"
        $combined += ""
    }
}

$fullReport = Join-Path $OutputPath "Full-TenantAssessment.md"
($combined -join "`n") | Out-File $fullReport -Encoding utf8

Write-Host ""
Write-Host "============================================"
Write-Host "  Assessment complete"
Write-Host "  Full report: $fullReport"
Write-Host "  Individual reports: $OutputPath"
Write-Host "============================================"
