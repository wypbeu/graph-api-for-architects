<#
.SYNOPSIS
    Licensing & Usage: What's it costing us?
.DESCRIPTION
    Pulls licence inventory with utilisation percentages, flags under-utilised
    paid SKUs, and summarises workload activity from usage reports.
.PARAMETER ClientId
    App registration client ID. If omitted, uses interactive auth.
.PARAMETER TenantId
    Entra ID tenant ID. Required for app-only auth.
.PARAMETER ClientSecret
    Client secret value. Required for app-only auth.
.PARAMETER OutputPath
    Directory for report output. Defaults to ../output relative to this script.
#>

param(
    [string]$ClientId,
    [string]$TenantId,
    [string]$ClientSecret,
    [string]$OutputPath = "$PSScriptRoot/../output"
)

. "$PSScriptRoot/Connect-Graph.ps1" @PSBoundParameters

$report = @()
$report += "# Licensing & Usage Report"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Tenant: $((Get-MgContext).TenantId)"
$report += ""

# SKU friendly name lookup — extend for your tenant's SKUs
$skuNames = @{
    "ENTERPRISEPREMIUM"                = "Microsoft 365 E5"
    "ENTERPRISEPACK"                   = "Microsoft 365 E3"
    "SPE_E5"                           = "Microsoft 365 E5 (unified)"
    "SPE_E3"                           = "Microsoft 365 E3 (unified)"
    "EMSPREMIUM"                       = "EMS E5"
    "Microsoft_365_Copilot"            = "Microsoft 365 Copilot"
    "SPB"                              = "Microsoft 365 Business Premium"
    "O365_BUSINESS_PREMIUM"            = "Microsoft 365 Business Standard"
    "SMB_BUSINESS_PREMIUM"             = "Microsoft 365 Business Premium"
    "FLOW_FREE"                        = "Power Automate Free"
    "POWER_BI_STANDARD"                = "Power BI Free"
    "Microsoft_Teams_Exploratory_Dept" = "Microsoft Teams Exploratory"
    "TEAMS_EXPLORATORY"                = "Microsoft Teams Exploratory"
    "DEVELOPERPACK_E5"                 = "Microsoft 365 E5 Developer"
}

$report += "## Licence Inventory"
try {
    $skus = Get-MgSubscribedSku -All

    $summary = $skus | Where-Object { $_.AppliesTo -eq "User" -and $_.PrepaidUnits.Enabled -gt 0 } |
        Select-Object @{Name="Licence"; Expression={
            $name = $skuNames[$_.SkuPartNumber]
            if ($name) { $name } else { $_.SkuPartNumber }
        }},
        @{Name="SKU"; Expression={$_.SkuPartNumber}},
        @{Name="Purchased"; Expression={$_.PrepaidUnits.Enabled}},
        @{Name="Assigned"; Expression={$_.ConsumedUnits}},
        @{Name="Available"; Expression={$_.PrepaidUnits.Enabled - $_.ConsumedUnits}},
        @{Name="Utilisation"; Expression={
            [math]::Round(($_.ConsumedUnits / $_.PrepaidUnits.Enabled) * 100, 1)
        }}

    $report += "| Licence | SKU | Purchased | Assigned | Available | Utilisation |"
    $report += "|---------|-----|----------:|---------:|----------:|------------:|"
    foreach ($s in ($summary | Sort-Object Licence)) {
        $report += "| $($s.Licence) | $($s.SKU) | $($s.Purchased) | $($s.Assigned) | $($s.Available) | $($s.Utilisation)% |"
    }
    $report += ""

    # Flag under-utilised paid SKUs
    $underUtilised = $summary | Where-Object {
        $_.Utilisation -lt 70 -and $_.Licence -notmatch "Free|Trial|Exploratory"
    }
    if ($underUtilised) {
        $report += "### Under-Utilised Paid Licences (below 70%)"
        $report += "| Licence | Utilisation |"
        $report += "|---------|------------:|"
        foreach ($u in $underUtilised) {
            $report += "| $($u.Licence) | $($u.Utilisation)% |"
        }
        $report += ""
    }
} catch {
    $report += "*Licence data unavailable: $($_.Exception.Message -split [char]10 | Select-Object -First 1)*"
    $report += ""
}

# Usage Reports
$report += "## Workload Usage (180-day)"
try {
    $uri = "https://graph.microsoft.com/v1.0/reports/getOffice365ActiveUserDetail(period='D180')"
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    $usagePath = Join-Path $OutputPath "M365Usage.csv"
    Invoke-MgGraphRequest -Uri $uri -OutputFilePath $usagePath
    $usage = Import-Csv $usagePath

    $report += "Users in usage report: $($usage.Count)"
    $report += ""

    $exchangeActive = ($usage | Where-Object { $_.'Exchange Last Activity Date' -ne "" }).Count
    $teamsActive = ($usage | Where-Object { $_.'Teams Last Activity Date' -ne "" }).Count
    $spActive = ($usage | Where-Object { $_.'SharePoint Last Activity Date' -ne "" }).Count
    $odActive = ($usage | Where-Object { $_.'OneDrive Last Activity Date' -ne "" }).Count

    $report += "### Workload Activity (last 180 days)"
    $report += "| Workload | Active Users |"
    $report += "|----------|------------:|"
    $report += "| Exchange | $exchangeActive |"
    $report += "| Teams | $teamsActive |"
    $report += "| SharePoint | $spActive |"
    $report += "| OneDrive | $odActive |"
    $report += ""
} catch {
    $report += "*Usage reports unavailable: $($_.Exception.Message -split [char]10 | Select-Object -First 1)*"
    $report += ""
}

# Write output
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$outputFile = Join-Path $OutputPath "05-licensing-usage.md"
($report -join "`n") | Out-File $outputFile -Encoding utf8
Write-Host "`nReport written to: $outputFile"
Write-Host ($report -join "`n")
