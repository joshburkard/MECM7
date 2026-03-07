# Add-CM7BoundaryToGroup

## SYNOPSIS

Assigns a boundary to a boundary group in MECM using CIM.

## DESCRIPTION

Assigns an existing boundary to an existing boundary group in Microsoft Endpoint
Configuration Manager (MECM) using CIM. The boundary group and the boundary can each
be identified by their ID, name, or by passing an object from Get-CM7BoundaryGroup /
Get-CM7Boundary respectively.

Internally, the function invokes the AddBoundary instance method on the
SMS_BoundaryGroup WMI class.

This is the CIM-based equivalent of the Add-CMBoundaryToGroup cmdlet from the
ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
instead of requiring the ConfigMgr console or PowerShell drive.

## PARAMETERS

### BoundaryGroupId

The GroupID (integer) of the existing boundary group to assign the boundary to.

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### BoundaryGroupName

The name of the existing boundary group to assign the boundary to.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### BoundaryGroupInputObject

A boundary group object (e.g. from Get-CM7BoundaryGroup) to assign the boundary to.
Alias: BoundaryGroup

- Type: PSObject
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### BoundaryId

The BoundaryID (integer) of the boundary to assign.

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### BoundaryName

The name of the boundary to assign.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### InputObject

A boundary object (e.g. from Get-CM7Boundary) to assign.
Accepts pipeline input.
Aliases: Boundary, BoundaryInputObject

- Type: PSObject
- Required: true
- Accept pipeline input: true (ByValue)
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
Add-CM7BoundaryToGroup -BoundaryGroupId 16777219 -BoundaryName "CLBound03"
            Assigns the boundary named "CLBound03" to the boundary group with GroupID 16777219.
```

### Example 2

```powershell
Add-CM7BoundaryToGroup -BoundaryGroupName "MyBoundaryGroup" -BoundaryId 16777230
            Assigns the boundary with BoundaryID 16777230 to the boundary group named "MyBoundaryGroup".
```

### Example 3

```powershell
$group    = Get-CM7BoundaryGroup -Name "MyBoundaryGroup"
            $boundary = Get-CM7Boundary     -Name "MyBoundary"
            Add-CM7BoundaryToGroup -BoundaryGroupInputObject $group -InputObject $boundary
            Assigns the boundary to the group using objects from Get-CM7BoundaryGroup and Get-CM7Boundary.
```

### Example 4

```powershell
Get-CM7Boundary -Name "MyBoundary" | Add-CM7BoundaryToGroup -BoundaryGroupName "MyBoundaryGroup"
            Pipes a boundary object to the function and assigns it to the named group.
```

### Example 5

```powershell
Add-CM7BoundaryToGroup -BoundaryGroupName "MyBoundaryGroup" -BoundaryName "MyBoundary" -WhatIf
            Shows what would happen without actually making the assignment.
```

## NOTES

Requires an active connection established via Connect-CM7.

The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
The AddBoundary instance method accepts an array of uint32 BoundaryIDs and adds them
to the boundary group.

For more information on the SMS_BoundaryGroup class and the AddBoundary method, see:
https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class

Related functions:
- Get-CM7Boundary
- Get-CM7BoundaryGroup
- New-CM7BoundaryGroup
- New-CM7Boundary
