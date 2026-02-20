<#
.SYNOPSIS
    Security Posture: Is it secure?
.DESCRIPTION
    Pulls Microsoft Secure Score with top improvement actions, device compliance
    state with stale device detection, and recent security alerts.
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
$report += "# Security Posture Report"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Tenant: $((Get-MgContext).TenantId)"
$report += ""

# Secure Score
$report += "## Microsoft Secure Score"
try {
    $scores = Get-MgSecuritySecureScore -Top 1 -Sort "createdDateTime desc"
    if ($scores) {
        $latest = $scores[0]
        $pct = if ($latest.MaxScore -gt 0) {
            [math]::Round(($latest.CurrentScore / $latest.MaxScore) * 100, 1)
        } else { 0 }

        $report += "| Metric | Value |"
        $report += "|--------|------:|"
        $report += "| Current Score | $($latest.CurrentScore) |"
        $report += "| Max Score | $($latest.MaxScore) |"
        $report += "| Percentage | ${pct}% |"
        $report += ""

        $improvements = $latest.ControlScores |
            Where-Object { $_.Score -lt $_.ScoreInPercentage } |
            Sort-Object @{Expression={$_.ScoreInPercentage - $_.Score}; Descending=$true} |
            Select-Object -First 5

        if ($improvements) {
            $report += "### Top 5 Improvement Actions"
            $report += "| Control | Current | Max | Potential Gain |"
            $report += "|---------|--------:|----:|--------------:|"
            foreach ($i in $improvements) {
                $gain = $i.ScoreInPercentage - $i.Score
                $report += "| $($i.ControlName) | $($i.Score) | $($i.ScoreInPercentage) | $gain |"
            }
            $report += ""
        }
    } else {
        $report += "*No Secure Score data available for this tenant.*"
        $report += ""
    }
} catch {
    $report += "*Secure Score unavailable (requires SecurityEvents.Read.All and may need Defender licensing): $($_.Exception.Message -split [char]10 | Select-Object -First 1)*"
    $report += ""
}

# Device Compliance
$report += "## Device Compliance"
try {
    $managedDevices = Get-MgDeviceManagementManagedDevice -All `
        -Property "DeviceName,OperatingSystem,ComplianceState,LastSyncDateTime,UserPrincipalName"

    $complianceSummary = $managedDevices | Group-Object ComplianceState |
        Select-Object @{Name="State"; Expression={$_.Name}}, Count |
        Sort-Object Count -Descending

    $report += "| State | Count |"
    $report += "|-------|------:|"
    foreach ($c in $complianceSummary) {
        $report += "| $($c.State) | $($c.Count) |"
    }
    $report += ""

    # Stale devices (not synced in 30+ days)
    $staleDevices = $managedDevices | Where-Object {
        $_.LastSyncDateTime -and $_.LastSyncDateTime -lt (Get-Date).AddDays(-30)
    }
    $report += "**Devices not synced in 30+ days:** $($staleDevices.Count)"
    if ($staleDevices.Count -gt 0) {
        $report += ""
        $report += "| Device | OS | Last Sync | User |"
        $report += "|--------|-----|-----------|------|"
        foreach ($d in $staleDevices | Select-Object -First 20) {
            $report += "| $($d.DeviceName) | $($d.OperatingSystem) | $($d.LastSyncDateTime) | $($d.UserPrincipalName) |"
        }
    }
    $report += ""
} catch {
    $report += "*Device compliance unavailable (requires Intune licensing): $($_.Exception.Message -split [char]10 | Select-Object -First 1)*"
    $report += ""
}

# Security Alerts
$report += "## Security Alerts"
try {
    $alerts = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/security/alerts_v2?`$top=10" -Method GET
    $alertCount = $alerts.value.Count
    $report += "Recent alerts: $alertCount"
    if ($alertCount -gt 0) {
        $report += ""
        $report += "| Title | Severity | Status | Created |"
        $report += "|-------|----------|--------|---------|"
        foreach ($a in $alerts.value) {
            $report += "| $($a.title) | $($a.severity) | $($a.status) | $($a.createdDateTime) |"
        }
    }
    $report += ""
} catch {
    $report += "*Security alerts unavailable (requires Defender licensing).*"
    $report += ""
}

# Write output
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$outputFile = Join-Path $OutputPath "03-security-posture.md"
($report -join "`n") | Out-File $outputFile -Encoding utf8
Write-Host "`nReport written to: $outputFile"
Write-Host ($report -join "`n")
