# Get-CM7BoundaryGroup

## SYNOPSIS

Retrieves boundary group information from MECM using CIM.

## DESCRIPTION

Queries the SMS_BoundaryGroup WMI class to retrieve boundary group information from MECM.
Supports filtering by Name and GroupID.
Requires an active connection established via Connect-CM7.

This function is the CIM-based equivalent of the Get-CMBoundaryGroup cmdlet
from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

## PARAMETERS

### Name

The name of the boundary group to retrieve. Supports wildcard characters (* and ?).
When no parameters are specified, all boundary groups are returned.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: true

### Id

The GroupID(s) of one or more boundary groups to retrieve. Accepts an array of strings.
Alias: GroupId

- Type: String[]
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### DisableWildcardHandling

Treats wildcard characters as literal character values.
Cannot be combined with ForceWildcardHandling.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### ForceWildcardHandling

Forces wildcard character processing even in contexts where it is not normally supported.
May lead to unexpected behavior (not recommended).
Cannot be combined with DisableWildcardHandling.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
Get-CM7BoundaryGroup
            Retrieves all boundary groups.
```

### Example 2

```powershell
Get-CM7BoundaryGroup -Name "Test Gino"
            Retrieves the boundary group named "Test Gino".
```

### Example 3

```powershell
Get-CM7BoundaryGroup -Name "Test*"
            Retrieves all boundary groups whose name starts with "Test".
```

### Example 4

```powershell
Get-CM7BoundaryGroup -Id "16777428"
            Retrieves the boundary group with GroupID 16777428.
```

### Example 5

```powershell
Get-CM7BoundaryGroup -Id "16777428", "16777429"
            Retrieves multiple boundary groups by their GroupIDs.
```

## NOTES

Requires an active connection established via Connect-CM7.
The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
For more information on return object properties, see SMS_BoundaryGroup server WMI class:
https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class
