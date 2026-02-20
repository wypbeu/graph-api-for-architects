<#
.SYNOPSIS
    Shared connection helper for Graph API for Architects scripts.
.DESCRIPTION
    Connects to Microsoft Graph using either app-only (client secret) or interactive (delegated) auth.
    Dot-source this from other scripts: . "$PSScriptRoot/Connect-Graph.ps1"
.PARAMETER ClientId
    App registration client ID. If omitted, uses interactive auth.
.PARAMETER TenantId
    Entra ID tenant ID. Required for app-only auth.
.PARAMETER ClientSecret
    Client secret value. Required for app-only auth.
#>

param(
    [string]$ClientId,
    [string]$TenantId,
    [string]$ClientSecret
)

if ($ClientId -and $TenantId -and $ClientSecret) {
    $credential = New-Object System.Management.Automation.PSCredential(
        $ClientId,
        (ConvertTo-SecureString $ClientSecret -AsPlainText -Force)
    )
    Connect-MgGraph -ClientSecretCredential $credential -TenantId $TenantId -NoWelcome
    Write-Host "Connected (app-only) to tenant: $((Get-MgContext).TenantId)"
} else {
    $scopes = @(
        "User.Read.All", "Group.Read.All", "Device.Read.All",
        "DeviceManagementManagedDevices.Read.All", "Policy.Read.All",
        "RoleManagement.Read.Directory", "Application.Read.All",
        "SecurityEvents.Read.All", "Reports.Read.All",
        "AuditLog.Read.All", "Directory.Read.All", "Organization.Read.All"
    )
    Connect-MgGraph -Scopes $scopes -NoWelcome
    Write-Host "Connected (interactive) to tenant: $((Get-MgContext).TenantId)"
}
