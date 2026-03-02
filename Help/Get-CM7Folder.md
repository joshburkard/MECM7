# Get-CM7Folder

## SYNOPSIS

Retrieves folder information from MECM using CIM.

## DESCRIPTION

Queries the SMS_ObjectContainerNode WMI class to retrieve folder information from MECM.
Supports filtering by folder path, name, and ObjectType. Enumerates folders to resolve full path.
CIM-based equivalent of Get-CMFolder from the ConfigurationManager module.

## PARAMETERS

### Path

The path of the folder to retrieve. Supports wildcards (*, ?).

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: true

### Name

The name of the folder to retrieve. Supports wildcards (*, ?).

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: true

### ContainerNodeID

The unique ContainerNodeID of the folder to retrieve.

- Type: Int32
- Required: false
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### ParentContainerNodeID

The ContainerNodeID of the parent folder to filter by.

- Type: Int32
- Required: false
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### ParentFolder

The parent folder object to filter by. Must have a ContainerNodeID property.

- Type: Object
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### ObjectType

The type of folder to enumerate. Use tab completion for allowed types.

- Type: String
- Required: false
- Default value: DeviceCollection
- Accept pipeline input: false
- Accept wildcard characters: false

### Fast

Returns limited properties for faster queries. Only returns essential properties like ContainerNodeID, Name, ObjectType, and ParentContainerNodeID.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
Get-CM7Folder -Path "DeviceCollection\\TestCollections\\Test" -ObjectType DeviceCollection
            Retrieves the folder at the specified path for DeviceCollection type.
```

### Example 2

```powershell
Get-CM7Folder -Name "Test*" -ObjectType DeviceCollection
            Retrieves all folders whose names start with "Test" for DeviceCollection type.
```

### Example 3

```powershell
Get-CM7Folder -Fast -ObjectType DeviceCollection
            Retrieves all folders with limited properties for faster query performance for DeviceCollection type.
```
