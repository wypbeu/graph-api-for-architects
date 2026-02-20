# Graph API for Architects

Production-ready PowerShell scripts for Microsoft 365 tenant assessment using Microsoft Graph API. Companion repository for [Graph API for Architects: The Endpoints That Actually Matter](https://sbd.org.uk/blog/graph-api-architects).

## What This Does

Five modular scripts that answer the five questions every M365 Solution Architect asks on day one:

| Script | Question | Output |
|--------|----------|--------|
| `01-discovery.ps1` | What do we have? | Users, groups, devices, Intune enrollment, Entra-to-Intune gap |
| `02-identity-access.ps1` | Who can access what? | CA policies, role assignments, service principals, consent grants |
| `03-security-posture.ps1` | Is it secure? | Secure Score, compliance state, stale devices, security alerts |
| `04-governance.ps1` | Is it compliant? | MFA gaps by department, sign-in logs, audit trail, access reviews |
| `05-licensing-usage.ps1` | What's it costing us? | Licence inventory, utilisation, workload activity |

`Full-TenantAssessment.ps1` runs all five and produces a combined markdown report.

## Prerequisites

- PowerShell 7+ (cross-platform — works on macOS, Linux, Windows)
- [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation)

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

- An Entra ID app registration with the permissions listed in [docs/permissions-required.md](docs/permissions-required.md)

## Quick Start

```powershell
# Clone the repo
git clone https://github.com/wypbeu/graph-api-for-architects.git
cd graph-api-for-architects/scripts

# Run the full assessment (interactive auth)
./Full-TenantAssessment.ps1

# Or run a single section
./01-discovery.ps1

# App-only auth (for automation)
./Full-TenantAssessment.ps1 -ClientId "your-app-id" -TenantId "your-tenant-id" -ClientSecret "your-secret"
```

Reports are written to the `output/` directory as markdown files.

## Related

- [Graph API for Architects](https://sbd.org.uk/blog/graph-api-architects) — the blog post that walks through every endpoint and script
- [The M365 Licensing Audit Nobody Wants to Do](https://sbd.org.uk/blog/m365-licensing-audit) — deep dive on licence waste identification
- [m365-license-audit](https://github.com/wypbeu/m365-license-audit) — companion repo for the licensing audit post

## Licence

MIT
