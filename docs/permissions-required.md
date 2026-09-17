# Required Permissions

All permissions are **read-only**. Nothing in this toolkit modifies your tenant.

## Application Permissions (App-Only Auth)

Grant these via **Entra ID > App registrations > API permissions > Add a permission > Microsoft Graph > Application permissions**, then click **Grant admin consent**.

| Permission | Required For |
|-----------|-------------|
| `User.Read.All` | Discovery, identity, governance |
| `Group.Read.All` | Discovery (group inventory) |
| `Device.Read.All` | Discovery (Entra device inventory) |
| `DeviceManagementManagedDevices.Read.All` | Discovery (Intune enrolled devices), security posture |
| `DeviceManagementApps.Read.All` | Discovery (mobile app inventory) |
| `Policy.Read.All` | Identity & access (Conditional Access policies) |
| `RoleManagement.Read.Directory` | Identity & access (admin role assignments) |
| `Application.Read.All` | Identity & access (service principals) |
| `SecurityEvents.Read.All` | Security posture (Secure Score) |
| `SecurityAlert.Read.All` | Security posture (Defender alerts) |
| `AccessReview.Read.All` | Governance (access review status) |
| `Reports.Read.All` | Governance, licensing & usage (usage reports) |
| `AuditLog.Read.All` | Governance (sign-in logs, directory audit logs) |
| `Directory.Read.All` | General directory queries, licence inventory |

## Delegated Permissions

If using interactive auth (`Connect-MgGraph -Scopes`), request the application permission names above as delegated scopes, plus the permission below, which has no application form.

| Permission | Required For |
|-----------|-------------|
| `LicenseAssignment.Read.All` | Licensing (`licenseDetails`; no application permission exists for this endpoint, so this call needs a signed-in delegated session rather than the certificate or secret behind every other call) |

A Global Reader or Security Reader role is sufficient for most queries.

## Notes

- **`AuditLog.Read.All` propagation:** After granting admin consent for this permission, it can take a few minutes to propagate. Queries that include `SignInActivity` may return 403 during this window.
- **Usage report privacy:** By default, M365 usage reports obfuscate user-identifying information. To get actual UPNs, a Global Admin must disable the privacy setting in **M365 Admin Centre > Settings > Org Settings > Reports**.
- **Defender and Governance licensing:** The security alerts endpoint requires Microsoft Defender licensing and `SecurityAlert.Read.All`. Access reviews require Entra ID Governance licensing and `AccessReview.Read.All`. Scripts handle these gracefully if unavailable.
