# New-CM7Folder

## SYNOPSIS

Creates a new folder in MECM using CIM.

## DESCRIPTION

Creates a new folder under a specified parent folder path or parent folder object in Microsoft Endpoint Configuration Manager (MECM) using CIM. This is the CIM-based equivalent of New-CMFolder from the ConfigurationManager module.

## PARAMETERS

### ParentFolderPath

The path of the parent folder (e.g., 'DeviceCollection\\TestCollections\\Test').

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### InputObject

The parent folder object (from Get-CM7Folder) to create the new folder under.

- Type: Object
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Name

The name of the new folder to create.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### ObjectType

The type of folder to create (e.g., 'DeviceCollection').

- Type: String
- Required: false
- Default value: DeviceCollection
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
New-CM7Folder -ParentFolderPath 'TestCollections\\Test' -Name 'ChildTestFolder'
            Creates a new folder named 'ChildTestFolder' under 'DeviceCollection\\TestCollections\\Test'.
```
