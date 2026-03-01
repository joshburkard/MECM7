# Get-CM7User

Retrieves user information from Microsoft Endpoint Configuration Manager (MECM) using CIM connectivity. This function is the CIM-based equivalent of the ConfigurationManager module's `Get-CMUser`.

## Syntax

```powershell
Get-CM7User [-Name <string>] [-ResourceId <int>] [-Fast] [<CommonParameters>]
```

## Parameters

| Name | Type | Description |
| --- | --- | ----------- |
| Name | string | The name of the user to retrieve. Supports wildcards (*, ?). |
| ResourceId | int | The ResourceID of the user to retrieve. |
| Fast | switch | Returns limited properties for faster queries. |

## Description

Queries the `SMS_R_User` WMI class via CIM to retrieve user information from MECM. Supports filtering by user name (with wildcards) and ResourceId. Requires an active connection via `Connect-CM7`.

## Examples

### Example 1: Get user by name

```powershell
Get-CM7User -Name "dan001\sd221778"
```

### Example 2: Get user by ResourceId

```powershell
Get-CM7User -ResourceId 2063632223
```

### Example 3: Get users by wildcard

```powershell
Get-CM7User -Name "dan001*"
```

### Example 4: Get all users (fast)

```powershell
Get-CM7User -Fast
```

## Output

Returns CIM instances of `SMS_R_User`. If `-Fast` is specified, only key properties are returned.

## Notes

- Requires a connection established via `Connect-CM7`.
- Equivalent to `Get-CMUser` in the ConfigurationManager module, but works in PowerShell 7+.
