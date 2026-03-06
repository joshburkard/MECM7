# New-CM7Boundary

## SYNOPSIS

Creates a new boundary in MECM using CIM.

## DESCRIPTION

Creates a new boundary (SMS_Boundary) in Microsoft Endpoint Configuration Manager (MECM) using CIM.
Supports creation of boundaries by Name, BoundaryType, and Value. Requires an active connection via Connect-CM7.
This is the CIM-based equivalent of the New-CMBoundary cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

## PARAMETERS

### Name

The name of the boundary to create. Must be unique within the MECM environment.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### BoundaryType

The type of the boundary. Valid values are: 0 (IP Subnet), 1 (Active Directory Site), 2 (IPv6 Prefix), 3 (IP Address Range).

- Type: Object
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Value

The value of the boundary (e.g., subnet, AD site name, IP range).

- Type: String
- Required: true
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
New-CM7Boundary -Name "TestSubnet" -BoundaryType 0 -Value "192.168.1.0"
            Creates a new IP Subnet boundary named "TestSubnet".
```

### Example 2

```powershell
New-CM7Boundary -Name "TestRange" -BoundaryType 3 -Value "192.168.2.1-192.168.3.255"
            Creates a new IP Address Range boundary named "TestRange".
```

## NOTES

Requires an active connection established via Connect-CM7.
The SMS_Boundary WMI class is used to represent boundaries in MECM.
