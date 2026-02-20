<#
.SYNOPSIS
    Governance: Is it compliant?
.DESCRIPTION
    Produces an MFA gap report by department, pulls recent sign-in and directory
    audit logs, and checks access review status.
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
$report += "# Governance Report"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Tenant: $((Get-MgContext).TenantId)"
$report += ""

# MFA Registration Gap
$report += "## MFA Registration Gap"
try {
    $mfaStatus = Get-MgReportAuthenticationMethodUserRegistrationDetail -All

    $enabledUsers = Get-MgUser -All -Filter "accountEnabled eq true and userType eq 'Member'" `
        -Property "Id,UserPrincipalName,Department" -ConsistencyLevel eventual

    $mfaGaps = foreach ($user in $enabledUsers) {
        $registration = $mfaStatus | Where-Object { $_.Id -eq $user.Id }
        if ($registration -and -not $registration.IsMfaRegistered) {
            [PSCustomObject]@{
                UPN        = $user.UserPrincipalName
                Department = if ($user.Department) { $user.Department } else { "Unset" }
                MfaRegistered = $false
                MethodsRegistered = ($registration.MethodsRegistered -join ", ")
            }
        }
    }

    $report += "**Enabled members without MFA:** $($mfaGaps.Count) of $($enabledUsers.Count)"
    $report += ""

    if ($mfaGaps.Count -gt 0) {
        $report += "### Gap by Department"
        $report += "| Department | Count |"
        $report += "|------------|------:|"
        $deptGroups = $mfaGaps | Group-Object Department | Sort-Object Count -Descending
        foreach ($d in $deptGroups) {
            $report += "| $($d.Name) | $($d.Count) |"
        }
        $report += ""

        $report += "### Users Without MFA"
        $report += "| UPN | Department | Methods Registered |"
        $report += "|-----|-----------|-------------------|"
        foreach ($u in $mfaGaps) {
            $methods = if ($u.MethodsRegistered) { $u.MethodsRegistered } else { "none" }
            $report += "| $($u.UPN) | $($u.Department) | $methods |"
        }
        $report += ""
    }
} catch {
    $report += "*MFA data unavailable: $($_.Exception.Message -split [char]10 | Select-Object -First 1)*"
    $report += ""
}

# Sign-in Logs
$report += "## Recent Sign-In Activity (last 7 days)"
try {
    $sevenDaysAgo = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $signIns = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/auditLogs/signIns?`$top=20&`$filter=createdDateTime ge $sevenDaysAgo&`$orderby=createdDateTime desc" -Method GET

    $report += "Showing up to 20 most recent sign-ins:"
    $report += ""
    $report += "| User | App | Status | Date |"
    $report += "|------|-----|--------|------|"
    foreach ($s in $signIns.value) {
        $status = if ($s.status.errorCode -eq 0) { "Success" } else { "Failed ($($s.status.errorCode))" }
        $report += "| $($s.userPrincipalName) | $($s.appDisplayName) | $status | $($s.createdDateTime) |"
    }
    $report += ""
} catch {
    $report += "*Sign-in logs unavailable: $($_.Exception.Message -split [char]10 | Select-Object -First 1)*"
    $report += ""
}

# Directory Audit Logs
$report += "## Recent Directory Changes (last 7 days)"
try {
    $sevenDaysAgo = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $audits = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/auditLogs/directoryAudits?`$top=20&`$filter=activityDateTime ge $sevenDaysAgo&`$orderby=activityDateTime desc" -Method GET

    $report += "Showing up to 20 most recent changes:"
    $report += ""
    $report += "| Activity | Category | Initiated By | Date |"
    $report += "|----------|----------|-------------|------|"
    foreach ($a in $audits.value) {
        $initiator = if ($a.initiatedBy.app) { $a.initiatedBy.app.displayName } else { $a.initiatedBy.user.userPrincipalName }
        $report += "| $($a.activityDisplayName) | $($a.category) | $initiator | $($a.activityDateTime) |"
    }
    $report += ""
} catch {
    $report += "*Audit logs unavailable: $($_.Exception.Message -split [char]10 | Select-Object -First 1)*"
    $report += ""
}

# Access Reviews
$report += "## Access Reviews"
try {
    $reviews = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/identityGovernance/accessReviews/definitions" -Method GET
    $report += "Active access review definitions: $($reviews.value.Count)"
    if ($reviews.value.Count -gt 0) {
        $report += ""
        $report += "| Review | Status |"
        $report += "|--------|--------|"
        foreach ($r in $reviews.value) {
            $report += "| $($r.displayName) | $($r.status) |"
        }
    }
    $report += ""
} catch {
    $report += "*Access reviews unavailable (requires Entra ID Governance licensing).*"
    $report += ""
}

# Write output
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$outputFile = Join-Path $OutputPath "04-governance.md"
($report -join "`n") | Out-File $outputFile -Encoding utf8
Write-Host "`nReport written to: $outputFile"
Write-Host ($report -join "`n")
