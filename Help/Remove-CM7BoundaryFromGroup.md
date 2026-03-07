# Remove-CM7BoundaryFromGroup

## SYNOPSIS

Removes a boundary from a boundary group in MECM using CIM.

## DESCRIPTION

Removes an existing boundary from an existing boundary group in Microsoft Endpoint
Configuration Manager (MECM) using CIM. The boundary group and the boundary can each
be identified by their ID, name, or by passing an object from Get-CM7BoundaryGroup /
Get-CM7Boundary respectively.

Internally, the function invokes the RemoveBoundary instance method on the
SMS_BoundaryGroup WMI class.

This is the CIM-based equivalent of the Remove-CMBoundaryFromGroup cmdlet from the
ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
instead of requiring the ConfigMgr console or PowerShell drive.

## PARAMETERS

### BoundaryGroupId

The GroupID (integer) of the boundary group to remove the boundary from.

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### BoundaryGroupName

The name of the boundary group to remove the boundary from.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### BoundaryGroupInputObject

A boundary group object (e.g. from Get-CM7BoundaryGroup) to remove the boundary from.
Alias: BoundaryGroup

- Type: PSObject
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### BoundaryId

The BoundaryID (integer) of the boundary to remove.

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### BoundaryName

The name of the boundary to remove.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### BoundaryInputObject

A boundary object (e.g. from Get-CM7Boundary) to remove.
Alias: Boundary

- Type: PSObject
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Force

Suppresses confirmation prompts and removes the boundary from the group without asking.

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

Forces wildcard character processing even in contexts where it is not normally
supported. May lead to unexpected behavior (not recommended).
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
Remove-CM7BoundaryFromGroup -BoundaryGroupId 16777219 -BoundaryName "CLBound03"
            Removes the boundary named "CLBound03" from the boundary group with GroupID 16777219.
```

### Example 2

```powershell
Remove-CM7BoundaryFromGroup -BoundaryGroupName "MyBoundaryGroup" -BoundaryId 16777230 -Force
            Removes the boundary with BoundaryID 16777230 from the named group without prompting.
```

### Example 3

```powershell
$group    = Get-CM7BoundaryGroup -Name "MyBoundaryGroup"
            $boundary = Get-CM7Boundary     -Name "MyBoundary"
            Remove-CM7BoundaryFromGroup -BoundaryGroupInputObject $group -BoundaryInputObject $boundary -Force
            Removes the boundary from the group using objects from Get-CM7BoundaryGroup and Get-CM7Boundary.
```

### Example 4

```powershell
Remove-CM7BoundaryFromGroup -BoundaryGroupName "MyBoundaryGroup" -BoundaryId 16777230 -WhatIf
            Shows what would happen without actually removing the boundary from the group.
```

## NOTES

Requires an active connection established via Connect-CM7.

The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
The RemoveBoundary instance method accepts an array of uint32 BoundaryIDs and removes
them from the boundary group.

For more information on the SMS_BoundaryGroup class and the RemoveBoundary method, see:
https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class

Related functions:
- Add-CM7BoundaryToGroup
- Get-CM7Boundary
- Get-CM7BoundaryGroup
