# Remove-CM7Boundary

## SYNOPSIS

Removes a boundary from MECM using CIM.

## DESCRIPTION

Removes (deletes) a boundary from Microsoft Endpoint Configuration Manager (MECM)
using CIM. This function deletes an SMS_Boundary instance via CIM.

This is the CIM-based equivalent of the Remove-CMBoundary cmdlet from the
ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

The function supports removing boundaries by:
- Name (DisplayName): resolves the boundary by display name
- Id (BoundaryID):    resolves the boundary by its integer ID
- InputObject:        accepts a boundary object from the pipeline (e.g., from Get-CM7Boundary)

## PARAMETERS

### Name

The display name of the boundary to remove. Supports wildcard characters (* and ?).
If multiple boundaries match the name, all matching boundaries are removed.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: true

### Id

The BoundaryID (integer) of the boundary to remove. Provides unambiguous identification.

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### InputObject

A boundary object (e.g., from Get-CM7Boundary) to remove.
Accepts pipeline input. Must have a BoundaryID property.

- Type: PSObject
- Required: true
- Accept pipeline input: true (ByValue)
- Accept wildcard characters: false

### Force

Suppresses confirmation prompts and removes the boundary without asking.
By default, the function prompts for confirmation before deletion.

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
Remove-CM7Boundary -Name "TestSubnet-192.168.1.0"
            Removes the boundary named "TestSubnet-192.168.1.0" after confirmation.
```

### Example 2

```powershell
Remove-CM7Boundary -Id 16777223 -Force
            Removes the boundary with the specified BoundaryID without prompting for confirmation.
```

### Example 3

```powershell
Get-CM7Boundary -BoundaryType 0 | Remove-CM7Boundary -Force
            Removes all IP Subnet boundaries via pipeline.
```

### Example 4

```powershell
Remove-CM7Boundary -Name "TestSubnet-*" -WhatIf
            Shows what would happen without actually removing the matching boundaries.
```

### Example 5

```powershell
$boundary = Get-CM7Boundary -BoundaryId 16777223
            Remove-CM7Boundary -InputObject $boundary -Force
            Removes a boundary using a previously retrieved boundary object.
```

## NOTES

Requires an active connection established via Connect-CM7.
The SMS_Boundary WMI class is used to represent boundaries in MECM.
