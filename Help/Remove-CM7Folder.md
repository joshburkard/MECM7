# Remove-CM7Folder

## SYNOPSIS

Removes a folder in MECM using CIM.

## DESCRIPTION

Removes a folder by path, name, ContainerNodeID, or input object from Microsoft Endpoint Configuration Manager (MECM) using CIM. This is the CIM-based equivalent of Remove-CMFolder from the ConfigurationManager module.

## PARAMETERS

### Path

The path of the folder to remove (e.g., 'DeviceCollection\\TestCollections\\Test').

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Name

The name of the folder to remove. Used with ParentContainerNodeID or ParentFolder.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### ParentContainerNodeID

The ContainerNodeID of the parent folder.

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### ContainerNodeID

The unique ContainerNodeID of the folder to remove.

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### InputObject

The folder object (from Get-CM7Folder) to remove.

- Type: Object
- Required: true
- Accept pipeline input: true (ByValue)
- Accept wildcard characters: false

### ParentFolder

The parent folder object (from Get-CM7Folder).

- Type: Object
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### ObjectType

The type of folder to remove (e.g., 'DeviceCollection').

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
Remove-CM7Folder -Path 'DeviceCollection\\TestCollections\\Test' -ObjectType DeviceCollection
            Removes the folder at the specified path for DeviceCollection type.
```
