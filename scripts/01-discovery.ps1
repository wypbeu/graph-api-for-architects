<#
.SYNOPSIS
    Discovery: What do we have?
.DESCRIPTION
    Pulls user, group, device, and Intune enrollment counts to produce a one-page tenant summary.
    Identifies the Entra-to-Intune enrollment gap.
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
$report += "# Discovery Report"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Tenant: $((Get-MgContext).TenantId)"
$report += ""

# Users
$users = Get-MgUser -All -Property "Id,UserType,AccountEnabled" -ConsistencyLevel eventual -CountVariable userCount
$members = ($users | Where-Object { $_.UserType -eq "Member" }).Count
$guests = ($users | Where-Object { $_.UserType -eq "Guest" }).Count
$disabled = ($users | Where-Object { -not $_.AccountEnabled }).Count

$report += "## Users"
$report += "| Metric | Count |"
$report += "|--------|------:|"
$report += "| Total | $($users.Count) |"
$report += "| Members | $members |"
$report += "| Guests | $guests |"
$report += "| Disabled | $disabled |"
$report += ""

# Groups
$groups = Get-MgGroup -All -Property "Id,GroupTypes,SecurityEnabled,MailEnabled,DisplayName"
$m365Groups = ($groups | Where-Object { $_.GroupTypes -contains "Unified" }).Count
$securityGroups = ($groups | Where-Object { $_.SecurityEnabled -and $_.GroupTypes -notcontains "Unified" }).Count
$dynamicGroups = ($groups | Where-Object { $_.GroupTypes -contains "DynamicMembership" }).Count

$report += "## Groups"
$report += "| Metric | Count |"
$report += "|--------|------:|"
$report += "| Total | $($groups.Count) |"
$report += "| M365 Groups | $m365Groups |"
$report += "| Security Groups | $securityGroups |"
$report += "| Dynamic Groups | $dynamicGroups |"
$report += ""

# Devices (Entra)
$devices = Get-MgDevice -All -Property "Id,DisplayName,OperatingSystem,TrustType"
$entraJoined = ($devices | Where-Object { $_.TrustType -eq "AzureAd" }).Count
$hybridJoined = ($devices | Where-Object { $_.TrustType -eq "ServerAd" }).Count
$registered = ($devices | Where-Object { $_.TrustType -eq "Workplace" }).Count

$report += "## Devices (Entra)"
$report += "| Metric | Count |"
$report += "|--------|------:|"
$report += "| Total | $($devices.Count) |"
$report += "| Entra Joined | $entraJoined |"
$report += "| Hybrid Joined | $hybridJoined |"
$report += "| Workplace Registered | $registered |"
$report += ""

if ($devices.Count -gt 0) {
    $report += "### Device List"
    $report += "| Name | OS | Trust Type |"
    $report += "|------|-----|-----------|"
    foreach ($d in $devices) {
        $report += "| $($d.DisplayName) | $($d.OperatingSystem) | $($d.TrustType) |"
    }
    $report += ""
}

# Managed Devices (Intune)
$managedDeviceCount = 0
$report += "## Managed Devices (Intune)"
try {
    $managedDevices = Get-MgDeviceManagementManagedDevice -All -Property "Id,DeviceName,OperatingSystem,ComplianceState"
    $managedDeviceCount = $managedDevices.Count
    $compliant = ($managedDevices | Where-Object { $_.ComplianceState -eq "compliant" }).Count
    $report += "| Metric | Count |"
    $report += "|--------|------:|"
    $report += "| Enrolled | $managedDeviceCount |"
    $report += "| Compliant | $compliant |"
    $report += "| Non-compliant | $($managedDeviceCount - $compliant) |"
} catch {
    $report += "*Intune data unavailable (requires DeviceManagementManagedDevices.Read.All and Intune licensing).*"
}
$report += ""

# Entra-to-Intune gap
$gap = $devices.Count - $managedDeviceCount
$report += "## Entra-to-Intune Gap"
$report += "**$gap devices** registered in Entra but not managed in Intune."

# Write output
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$outputFile = Join-Path $OutputPath "01-discovery.md"
($report -join "`n") | Out-File $outputFile -Encoding utf8
Write-Host "`nReport written to: $outputFile"
Write-Host ($report -join "`n")
