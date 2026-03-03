# Get-CM7Boundary

## SYNOPSIS

Retrieves boundary information from MECM using CIM.

## DESCRIPTION

Queries the SMS_Boundary WMI class to retrieve boundary information from MECM.
Supports filtering by Name, BoundaryID, BoundaryType, and Value.
Requires an active connection established via Connect-CM7.

This function is the CIM-based equivalent of the Get-CMBoundary cmdlet
from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

## PARAMETERS

### Name

The name of the boundary to retrieve. Supports wildcard characters (* and ?).

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: true

### BoundaryId

The BoundaryID of the boundary to retrieve.

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### BoundaryType

The type of the boundary. Valid values are: 0 (IP Subnet), 1 (Active Directory Site), 2 (IPv6 Prefix), 3 (IP Address Range).

- Type: Int32
- Required: false
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### Value

The value of the boundary (e.g., subnet, AD site name, IP range).

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Fast

Returns limited properties for faster queries. Only returns essential properties like BoundaryID, Name, BoundaryType, and Value.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
Get-CM7Boundary -Name "TEST GINO"
            Retrieves the boundary named "TEST GINO".
```

### Example 2

```powershell
Get-CM7Boundary -BoundaryId 12345678
            Retrieves the boundary with the specified BoundaryID.
```

### Example 3

```powershell
Get-CM7Boundary
            Retrieves all boundaries.
```
