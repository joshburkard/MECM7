# Set-CM7Folder

## SYNOPSIS

Modifies an existing folder in MECM using CIM (rename, move, change parent).

## DESCRIPTION

Updates folder properties in MECM via CIM, including renaming and moving folders. CIM-based equivalent of Set-CMFolder from the ConfigurationManager module.

## PARAMETERS

### Path

The path of the folder to modify (e.g., 'DeviceCollection\TestCollections\Test').

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Name

The name of the folder to modify (used with Path).

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### ContainerNodeID

The unique ContainerNodeID of the folder to modify.

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### NewName

The new name for the folder.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### NewParentPath

The path of the new parent folder.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### ObjectType

The type of folder (e.g., 'DeviceCollection').

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
Set-CM7Folder -Path 'TestCollections\Test' -Name 'ChildTestFolder' -NewName 'RenamedChildFolder'
            Renames the folder 'ChildTestFolder' to 'RenamedChildFolder'.
```

### Example 2

```powershell
Set-CM7Folder -ContainerNodeID 12345 -NewParentPath 'TestCollections\MovedHere'
            Moves the folder to a new parent folder.
```
