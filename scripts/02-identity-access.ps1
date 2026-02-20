<#
.SYNOPSIS
    Identity & Access: Who can access what?
.DESCRIPTION
    Exports Conditional Access policies, audits privileged role assignments,
    inventories service principals, and analyses OAuth2 consent grants.
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
$report += "# Identity & Access Report"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Tenant: $((Get-MgContext).TenantId)"
$report += ""

# Conditional Access Policies
$report += "## Conditional Access Policies"
try {
    $policies = Get-MgIdentityConditionalAccessPolicy -All
    $enabled = ($policies | Where-Object { $_.State -eq "enabled" }).Count
    $reportOnly = ($policies | Where-Object { $_.State -eq "enabledForReportingButNotEnforced" }).Count
    $disabledCount = ($policies | Where-Object { $_.State -eq "disabled" }).Count

    $report += "| State | Count |"
    $report += "|-------|------:|"
    $report += "| Enabled | $enabled |"
    $report += "| Report-Only | $reportOnly |"
    $report += "| Disabled | $disabledCount |"
    $report += "| **Total** | **$($policies.Count)** |"
    $report += ""

    $report += "### Policy List"
    $report += "| Policy | State | Excluded Users | Excluded Groups |"
    $report += "|--------|-------|---------------:|----------------:|"
    foreach ($p in $policies) {
        $exUsers = $p.Conditions.Users.ExcludeUsers.Count
        $exGroups = $p.Conditions.Users.ExcludeGroups.Count
        $report += "| $($p.DisplayName) | $($p.State) | $exUsers | $exGroups |"
    }
    $report += ""

    $broadExclusions = $policies | Where-Object {
        $_.Conditions.Users.ExcludeGroups.Count -gt 0 -or
        $_.Conditions.Users.ExcludeUsers.Count -gt 3
    }
    if ($broadExclusions) {
        $report += "### Policies with Broad Exclusions"
        foreach ($p in $broadExclusions) {
            $report += "- **$($p.DisplayName)**: $($p.Conditions.Users.ExcludeUsers.Count) excluded users, $($p.Conditions.Users.ExcludeGroups.Count) excluded groups"
        }
        $report += ""
    }

    # Export full JSON
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    $policies | ConvertTo-Json -Depth 10 | Out-File (Join-Path $OutputPath "ca-policies-export.json") -Encoding utf8
    $report += "*Full CA policy JSON exported to ca-policies-export.json*"
    $report += ""
} catch {
    $report += "*CA policies unavailable: $($_.Exception.Message -split [char]10 | Select-Object -First 1)*"
    $report += ""
}

# Privileged Access Review
$report += "## Privileged Access Review"
try {
    # Graph limits $expand to one property per query
    $roleAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All -ExpandProperty "roleDefinition"

    $privilegedUsers = foreach ($ra in $roleAssignments) {
        $principal = Get-MgDirectoryObject -DirectoryObjectId $ra.PrincipalId
        [PSCustomObject]@{
            Role          = $ra.RoleDefinition.DisplayName
            Principal     = $principal.AdditionalProperties.displayName
            PrincipalType = $principal.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.', ''
        }
    }

    $globalAdmins = $privilegedUsers | Where-Object { $_.Role -eq "Global Administrator" }
    $report += "**Global Administrators: $($globalAdmins.Count)**"
    $report += ""

    if ($globalAdmins) {
        $report += "| Principal | Type |"
        $report += "|-----------|------|"
        foreach ($ga in $globalAdmins) {
            $report += "| $($ga.Principal) | $($ga.PrincipalType) |"
        }
        $report += ""
    }

    $report += "### Role Assignment Summary"
    $report += "| Role | Assignments |"
    $report += "|------|------------:|"
    $roleSummary = $privilegedUsers | Group-Object Role | Sort-Object Count -Descending
    foreach ($r in $roleSummary) {
        $report += "| $($r.Name) | $($r.Count) |"
    }
    $report += ""
} catch {
    $report += "*Role assignments unavailable: $($_.Exception.Message -split [char]10 | Select-Object -First 1)*"
    $report += ""
}

# Service Principals
$report += "## Application Permissions"
try {
    $sps = Get-MgServicePrincipal -All -Property "DisplayName,AppId" -Filter "servicePrincipalType eq 'Application'"
    $report += "Application service principals: $($sps.Count)"
    $report += ""
} catch {
    $report += "*Service principals unavailable: $($_.Exception.Message -split [char]10 | Select-Object -First 1)*"
    $report += ""
}

# OAuth2 Permission Grants
$report += "## Delegated Permission Grants (Consent)"
try {
    $grants = Get-MgOAuth2PermissionGrant -All
    $report += "Total delegated permission grants: $($grants.Count)"
    if ($grants.Count -gt 0) {
        $report += ""
        $report += "| Client App ID | Scope | Consent Type |"
        $report += "|--------------|-------|-------------|"
        foreach ($g in $grants | Select-Object -First 20) {
            $scope = if ($g.Scope) { $g.Scope.Trim() } else { "(all)" }
            $report += "| $($g.ClientId) | $scope | $($g.ConsentType) |"
        }
        if ($grants.Count -gt 20) {
            $report += "| ... | *($($grants.Count - 20) more)* | |"
        }
    }
    $report += ""
} catch {
    $report += "*Consent grants unavailable: $($_.Exception.Message -split [char]10 | Select-Object -First 1)*"
    $report += ""
}

# Write output
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$outputFile = Join-Path $OutputPath "02-identity-access.md"
($report -join "`n") | Out-File $outputFile -Encoding utf8
Write-Host "`nReport written to: $outputFile"
Write-Host ($report -join "`n")
