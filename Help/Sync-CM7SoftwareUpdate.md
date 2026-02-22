# Sync-CM7SoftwareUpdate

Synchronizes software updates in MECM using CIM connectivity.

## SYNOPSIS
Synchronizes software updates metadata from Microsoft Update via MECM CIM.

## SYNTAX
Sync-CM7SoftwareUpdate [-FullSync <Boolean>] [-DisableWildcardHandling] [-ForceWildcardHandling] [-WhatIf] [-Confirm] [<CommonParameters>]

## DESCRIPTION
The Sync-CM7SoftwareUpdate function retrieves metadata for software updates in MECM. It performs either a full or delta synchronization using CIM connectivity, enabling cross-platform PowerShell support.

## PARAMETERS
- **FullSync**: Indicates whether to perform a complete synchronization of all updates or a delta synchronization.
- **DisableWildcardHandling**: Treats wildcard characters as literal values.
- **ForceWildcardHandling**: Processes wildcard characters (not recommended).
- **WhatIf**: Shows what would happen if the function runs.
- **Confirm**: Prompts for confirmation before running.

## EXAMPLES
### Example 1: Perform a full synchronization
```
Sync-CM7SoftwareUpdate -FullSync $true
```

### Example 2: Perform a delta synchronization
```
Sync-CM7SoftwareUpdate -FullSync $false
```

## INPUTS
None

## OUTPUTS
System.Object

## NOTES
- Requires CIM connectivity to MECM site server.
- Supports common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable, -ProgressAction, -Verbose, -WarningAction, -WarningVariable.

## RELATED LINKS
- [Get-CM7SoftwareUpdate](./Get-CM7SoftwareUpdate.md)
- [Save-CM7SoftwareUpdate](./Save-CM7SoftwareUpdate.md)
- [Set-CM7SoftwareUpdate](./Set-CM7SoftwareUpdate.md)
