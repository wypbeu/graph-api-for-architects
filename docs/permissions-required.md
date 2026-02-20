# Required Permissions

All permissions are **read-only**. Nothing in this toolkit modifies your tenant.

## Application Permissions (App-Only Auth)

Grant these via **Entra ID > App registrations > API permissions > Add a permission > Microsoft Graph > Application permissions**, then click **Grant admin consent**.

| Permission | Required For |
|-----------|-------------|
| `User.Read.All` | Discovery, identity, governance, licensing |
| `Group.Read.All` | Discovery (group inventory) |
| `Device.Read.All` | Discovery (Entra device inventory) |
| `DeviceManagementManagedDevices.Read.All` | Discovery (Intune enrolled devices), security posture |
| `Policy.Read.All` | Identity & access (Conditional Access policies) |
| `RoleManagement.Read.Directory` | Identity & access (admin role assignments) |
| `Application.Read.All` | Identity & access (service principals) |
| `SecurityEvents.Read.All` | Security posture (Secure Score, alerts) |
| `Reports.Read.All` | Governance (MFA registration), licensing (usage reports) |
| `AuditLog.Read.All` | Governance (sign-in logs, directory audit logs) |
| `Directory.Read.All` | General directory queries |
| `Organization.Read.All` | Licensing (subscribed SKUs) |

## Delegated Permissions (Interactive Auth)

If using interactive auth (`Connect-MgGraph -Scopes`), request the same permission names as delegated scopes. A Global Reader or Security Reader role is sufficient for most queries.

## Notes

- **`AuditLog.Read.All` propagation:** After granting admin consent for this permission, it can take a few minutes to propagate. Queries that include `SignInActivity` may return 403 during this window.
- **Usage report privacy:** By default, M365 usage reports obfuscate user-identifying information. To get actual UPNs, a Global Admin must disable the privacy setting in **M365 Admin Centre > Settings > Org Settings > Reports**.
- **Defender and Governance licensing:** The security alerts endpoint requires Microsoft Defender licensing. Access reviews require Entra ID Governance licensing. Scripts handle these gracefully if unavailable.
