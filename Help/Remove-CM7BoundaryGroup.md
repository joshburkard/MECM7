# Remove-CM7BoundaryGroup

## SYNOPSIS

Removes a boundary group from MECM using CIM.

## DESCRIPTION

Removes (deletes) a boundary group from Microsoft Endpoint Configuration Manager (MECM)
using CIM. This function deletes an SMS_BoundaryGroup instance via CIM.

This is the CIM-based equivalent of the Remove-CMBoundaryGroup cmdlet from the
ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

The function supports removing boundary groups by:
- Name:        resolves the boundary group by name (supports wildcard characters)
- Id (GroupID): resolves one or more boundary groups by their integer GroupID
- InputObject:  accepts a boundary group object from the pipeline (e.g., from Get-CM7BoundaryGroup)

## PARAMETERS

### Name

The name of the boundary group to remove. Supports wildcard characters (* and ?).
If multiple boundary groups match the name pattern, all matching groups are removed.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: true

### Id

One or more GroupIDs of boundary groups to remove.
Alias: GroupId

- Type: String[]
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### InputObject

A boundary group object (e.g., from Get-CM7BoundaryGroup) to remove.
Accepts pipeline input. Must have a GroupID property.

- Type: PSObject
- Required: true
- Accept pipeline input: true (ByValue)
- Accept wildcard characters: false

### Force

Suppresses confirmation prompts and removes the boundary group without asking.
By default the function prompts for confirmation before deletion.

- Type: SwitchParameter
- Required: false
- Default value: False
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

### WhatIf

Shows what would happen if the cmdlet runs. The cmdlet is not run.

- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Confirm

Prompts you for confirmation before running the cmdlet.

- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
Remove-CM7BoundaryGroup -Name "Test"
            Removes the boundary group named "Test" after confirmation.
```

### Example 2

```powershell
Remove-CM7BoundaryGroup -Id "16777219" -Force
            Removes the boundary group with GroupID 16777219 without prompting for confirmation.
```

### Example 3

```powershell
Remove-CM7BoundaryGroup -Id "16777219", "16777220" -Force
            Removes multiple boundary groups by their GroupIDs without prompting.
```

### Example 4

```powershell
Get-CM7BoundaryGroup -Name "Test*" | Remove-CM7BoundaryGroup -Force
            Removes all boundary groups whose names start with "Test" via pipeline.
```

### Example 5

```powershell
Remove-CM7BoundaryGroup -Name "TestGroup" -WhatIf
            Shows what would happen without actually removing the boundary group.
```

## NOTES

Requires an active connection established via Connect-CM7.
The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
For more information on return object properties, see SMS_BoundaryGroup server WMI class:
https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class
