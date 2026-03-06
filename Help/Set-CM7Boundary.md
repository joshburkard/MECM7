# Set-CM7Boundary

## SYNOPSIS

Modifies an existing boundary in MECM using CIM.

## DESCRIPTION

Updates the properties of an existing SMS_Boundary instance in Microsoft Endpoint
Configuration Manager (MECM) using CIM over WinRM.

Supports modifying boundaries by:
- InputObject: a boundary object piped in or retrieved via Get-CM7Boundary
- Id:          unambiguous identification by integer BoundaryID
- Type+Value:  locate the boundary by its current type and value combination

Any combination of -NewName, -NewType, -NewValue, and -ValueStartsWith can be
supplied to update the corresponding properties.

This is the CIM-based equivalent of the Set-CMBoundary cmdlet from the
ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

## PARAMETERS

### InputObject

A boundary object (e.g., from Get-CM7Boundary) whose properties are to be updated.
Accepts pipeline input. Must have a BoundaryID property.

- Type: PSObject
- Required: true
- Accept pipeline input: true (ByValue)
- Accept wildcard characters: false

### Id

The BoundaryID (integer) of the boundary to modify. Alias: BoundaryId.

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### Type

The current boundary type used to locate the boundary (combined with -Value).
Valid values: IPSubnet, ADSite, IPv6Prefix, IPRange, Vpn.
Alias: BoundaryType.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Value

The current value of the boundary used to locate it (combined with -Type).

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### NewName

A new display name to assign to the boundary. Aliases: DisplayName, Name.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### NewType

The new boundary type to assign. Accepted values: IPSubnet, ADSite, IPv6Prefix, IPRange, Vpn.
Alias: NewBoundaryType.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### NewValue

The new value to assign to the boundary (e.g., a new subnet address or IP range).

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### ValueStartsWith

When set to $true, the VPN boundary is matched by the start of the connection name
rather than an exact match. Relevant only for VPN boundary types.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### PassThru

Returns the updated boundary object. By default this cmdlet returns no output.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### Force

Suppresses confirmation prompts.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### WhatIf

Shows what would happen if the cmdlet runs without actually running it.

- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Confirm

Prompts for confirmation before performing the update.

- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
Set-CM7Boundary -Id 16777223 -NewName "Renamed-TestSubnet"
            Renames the boundary with BoundaryID 16777223.
```

### Example 2

```powershell
Set-CM7Boundary -Id 16777223 -NewType IPRange -NewValue "192.168.1.1-192.168.1.255" -PassThru
            Changes the type and value of a boundary and returns the updated object.
```

### Example 3

```powershell
Set-CM7Boundary -Type IPSubnet -Value "192.168.1.0" -NewName "Updated-Subnet" -NewValue "192.168.10.0"
            Locates the IP Subnet boundary with value "192.168.1.0" and updates its name and value.
```

### Example 4

```powershell
Get-CM7Boundary -Name "TestSubnet-192.168.1.0" | Set-CM7Boundary -NewName "UpdatedSubnet" -Force
            Uses pipeline input to rename a boundary.
```

## NOTES

Requires an active connection established via Connect-CM7.
The SMS_Boundary WMI class is used to represent boundaries in MECM.
BoundaryType integer mapping: 0=IPSubnet, 1=ADSite, 2=IPv6Prefix, 3=IPRange, 4=Vpn.
