# Move-CM7Object

## SYNOPSIS

Moves one or more MECM objects to a specified folder using CIM.

## DESCRIPTION

The `Move-CM7Object` function moves MECM objects (such as collections, packages, applications, etc.) from their current folder location to a specified destination folder. It uses the `SMS_ObjectContainerItem` WMI class and `MoveMembers` method via CIM.

This function is the CIM-based equivalent of the `Move-CMObject` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Validates the destination folder exists (unless moving to root)
3. Looks up the current container for each object
4. Calls the `MoveMembers` WMI method on `SMS_ObjectContainerItem` to move each object
5. Returns a result object for each move operation

Key features:
- **Multiple Object Types**: Supports all MECM object types (collections, packages, applications, etc.)
- **Batch Move**: Move multiple objects in a single call
- **Root Folder Support**: Use FolderId 0 to move objects to the root
- **FolderPath Resolution**: Specify a human-readable folder path (e.g., `CM1:\DeviceCollection\MyFolder`) instead of a numeric folder ID
- **WhatIf/Confirm**: Full ShouldProcess support for safe operations
- **Pipeline Support**: Accept objects from other CM7 functions via pipeline (InputObject)
- **Skip Detection**: Automatically skips objects already in the target folder

## PARAMETERS

### -FolderId

Specifies the ID of the destination folder. Use `0` to move the object to the root folder (no folder).
Mutually exclusive with `-FolderPath`.

- **Type**: Int32
- **Position**: Named
- **Default**: None
- **Required**: Yes (when not using -FolderPath)
- **Parameter Set**: ByObjectIdFolderId, ByInputObjectFolderId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Examples:
- `0` - Root folder (no folder)
- `3` - Folder with ID 3
- `42` - Folder with ID 42

### -FolderPath

Specifies the folder path in MECM format: `SiteCode:\ObjectType\Folder[\SubFolder\...]`.
The path is resolved by walking the `SMS_ObjectContainerNode` hierarchy using WQL queries.
The `ObjectType` is automatically derived from the path category (e.g., `DeviceCollection`, `UserCollection`, `Package`).
Mutually exclusive with `-FolderId`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when not using -FolderId)
- **Parameter Set**: ByObjectIdFolderPath, ByInputObjectFolderPath
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Path format: `SiteCode:\Category\Folder1\Folder2\...`

Valid categories:

| Category | SMS ObjectTypeName | Object Type |
|----------|-------------------|-------------|
| DeviceCollection | SMS_Collection_Device | 5000 |
| UserCollection | SMS_Collection_User | 5001 |
| Package | SMS_Package | 2 |
| Application | SMS_ApplicationLatest | 6000 |
| BootImagePackage | SMS_BootImagePackage | 19 |
| DriverPackage | SMS_DriverPackage | 23 |
| Driver | SMS_Driver | 25 |
| ImagePackage | SMS_ImagePackage | 18 |
| OSInstallPackage | SMS_OperatingSystemInstallPackage | 14 |
| TaskSequencePackage | SMS_TaskSequencePackage | 20 |
| SoftwareUpdateGroup | SMS_AuthorizationList | 1011 |
| ConfigurationBaseline | SMS_ConfigurationBaselineInfo | 2011 |
| ConfigurationItem | SMS_ConfigurationItemLatest | 6001 |
| Query | SMS_Query | 7 |
| MeteringRule | SMS_MeteredProductRule | 9 |
| StateMigration | SMS_MigrationEntity | 17 |

Examples:
- `"CM1:\DeviceCollection\TestCollections\Test"` - Subfolder under TestCollections
- `"CM1:\DeviceCollection"` - Root of DeviceCollection (FolderId = 0)
- `"CM1:\Application\Production"` - Application folder named Production

### -ObjectId

Specifies an array of object IDs (instance keys) to move. These are typically the collection ID (e.g., `CM100001`), package ID, or other MECM identifiers.

- **Type**: String[]
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByObjectId parameter set)
- **Parameter Set**: ByObjectId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Examples:
- `"CM100001"` - Single collection ID
- `"CM100001", "CM100002"` - Multiple collection IDs

### -ObjectType

Specifies the type of MECM object being moved. This determines which `SMS_ObjectContainerItem` entries to look up.
When using `-FolderPath`, this parameter is not required — the object type is automatically derived from the path category.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByObjectIdFolderId parameter set only)
- **Parameter Set**: ByObjectIdFolderId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Valid values and their numeric equivalents:

| Value | Numeric | Description |
|-------|---------|-------------|
| Package | 2 | Software distribution package |
| Query | 7 | WMI query |
| MeteringRule | 9 | Software metering rule |
| OSInstallPackage | 14 | Operating system install package |
| StateMigration | 17 | State migration point |
| ImagePackage | 18 | Operating system image package |
| BootImagePackage | 19 | Boot image package |
| TaskSequencePackage | 20 | Task sequence package |
| DriverPackage | 23 | Driver package |
| Driver | 25 | Device driver |
| SoftwareUpdateGroup | 1011 | Software update group |
| ConfigurationBaseline | 2011 | Configuration baseline |
| DeviceCollection | 5000 | Device collection |
| UserCollection | 5001 | User collection |
| Application | 6000 | Application |
| ConfigurationItem | 6001 | Configuration item |

### -InputObject

Specifies one or more CIM objects to move. The function attempts to extract the instance key and object type from the object properties (e.g., `CollectionID`, `PackageID`, `CI_ID`, or `InstanceKey`).

- **Type**: Object[]
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByInputObject parameter set)
- **Parameter Set**: ByInputObject
- **Accept pipeline input**: Yes (ByValue)
- **Accept wildcard characters**: No

### -Force

Suppresses confirmation prompts when moving objects.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

### -WhatIf

Shows what would happen if the cmdlet runs. The cmdlet is not run.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No

### -Confirm

Prompts you for confirmation before running the cmdlet.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No

## EXAMPLES

### EXAMPLE 1: Move a device collection to a folder

```powershell
Move-CM7Object -ObjectId "CM100001" -ObjectType DeviceCollection -FolderId 3
```

Moves the device collection with ID "CM100001" to the folder with ID 3.

### EXAMPLE 2: Move using FolderPath

```powershell
Move-CM7Object -ObjectId "CM100001" -FolderPath "CM1:\DeviceCollection\TestCollections\Test"
```

Moves the device collection to the `TestCollections\Test` folder. The folder path is automatically resolved by traversing the `SMS_ObjectContainerNode` hierarchy via WQL queries. The `ObjectType` is derived from the `DeviceCollection` category in the path.

### EXAMPLE 3: Move a collection to the root folder

```powershell
Move-CM7Object -ObjectId "CM100001" -ObjectType DeviceCollection -FolderId 0
```

Moves the device collection to the root folder (removes it from any folder).

### EXAMPLE 4: Move to root using FolderPath

```powershell
Move-CM7Object -ObjectId "CM100001" -FolderPath "CM1:\DeviceCollection"
```

When only the category is specified (no sub-folders), the object is moved to the root of that category (FolderId = 0).

### EXAMPLE 5: Move multiple collections

```powershell
Move-CM7Object -ObjectId "CM100001", "CM100002", "CM100003" -ObjectType DeviceCollection -FolderId 5
```

Moves three device collections to folder ID 5 in a single operation.

### EXAMPLE 6: Move with WhatIf

```powershell
Move-CM7Object -ObjectId "CM100001" -FolderPath "CM1:\DeviceCollection\Archive" -WhatIf
```

Shows what would happen without actually performing the move. Useful for verifying the operation before executing.

### EXAMPLE 7: Move collections found by name pattern using FolderPath

```powershell
$collections = Get-CM7Collection -Name "Test-*"
$objectIds = $collections | ForEach-Object { $_.CollectionID }
Move-CM7Object -ObjectId $objectIds -FolderPath "CM1:\DeviceCollection\Archive"
```

Retrieves all collections matching "Test-*" and moves them to the Archive folder. No need to specify `-ObjectType` since it is derived from the path.

### EXAMPLE 8: Move with Force (no confirmation)

```powershell
Move-CM7Object -ObjectId "CM100001" -ObjectType DeviceCollection -FolderId 3 -Force
```

Moves the object without prompting for confirmation.

### EXAMPLE 9: Move a user collection

```powershell
Move-CM7Object -ObjectId "SD200001" -FolderPath "CM1:\UserCollection\Archive"
```

Moves a user collection to the Archive folder under UserCollection.

### EXAMPLE 10: Move a package

```powershell
Move-CM7Object -ObjectId "CM100005" -ObjectType Package -FolderId 2
```

Moves a software distribution package to folder ID 2.

### EXAMPLE 11: Move with verbose output

```powershell
Move-CM7Object -ObjectId "CM100001" -FolderPath "CM1:\DeviceCollection\TestCollections\Test" -Force -Verbose
```

Moves the collection with verbose output showing the folder path resolution WQL queries, current location lookup, and move method calls.

### EXAMPLE 12: Check move results

```powershell
$results = Move-CM7Object -ObjectId "CM100001", "CM100002" -ObjectType DeviceCollection -FolderId 5 -Force
$results | Format-Table InstanceKey, SourceFolder, TargetFolder, Success, Message
```

Moves multiple objects and displays the results in a formatted table.

## OUTPUTS

### PSCustomObject (MECM7.MoveResult)

The function returns custom objects for each move operation with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| InstanceKey | string | The ID of the object that was moved |
| ObjectType | int | Numeric object type identifier |
| SourceFolder | int | The folder ID the object was moved from (0 = root) |
| TargetFolder | int | The folder ID the object was moved to (0 = root) |
| Success | bool | Whether the move operation succeeded |
| Message | string | Status message describing the result |

Example output:

```powershell
PSTypeName   : MECM7.MoveResult
InstanceKey  : CM100001
ObjectType   : 5000
SourceFolder : 0
TargetFolder : 3
Success      : True
Message      : Object moved successfully
```

## NOTES

### Requirements

- **Connection**: Must have an active connection established via `Connect-CM7`
- **Permissions**: User must have move permissions for the object type in MECM
- **PowerShell**: Version 5.1 or higher
- **Module**: MECM7 module loaded

### MECM Folder Structure

MECM uses a folder structure managed through the following WMI classes:
- `SMS_ObjectContainerNode` - Represents folders
- `SMS_ObjectContainerItem` - Associates objects with folders

Each folder has an `ObjectType` property that determines what kind of objects it can contain. The function validates that the destination folder type matches the object type being moved.

### Object Type Mapping

The function uses the `SMS_ObjectContainerItem.MoveMembers` WMI method internally. This method requires:
- Source container node ID (determined automatically)
- Target container node ID (the `FolderId` parameter, or resolved from `FolderPath`)
- Instance keys (the `ObjectId` array)
- Object type (determined from `ObjectType` parameter, `FolderPath` category, or `InputObject`)

### FolderPath Resolution

When using `-FolderPath`, the function resolves the path to a folder ID by:

1. Parsing the path format `SiteCode:\Category\Folder1\Folder2\...`
2. Mapping the category (e.g., `DeviceCollection`) to the SMS `ObjectTypeName` (e.g., `SMS_Collection_Device`)
3. Walking the folder hierarchy via WQL queries against `SMS_ObjectContainerNode`:
   ```sql
   SELECT * FROM SMS_ObjectContainerNode
   WHERE ObjectTypeName = 'SMS_Collection_Device'
     AND ParentContainerNodeID = <parentId>
     AND SearchFolder = 0
     AND Name = '<folderName>'
   ```
4. Using the final `ContainerNodeID` as the `FolderId`

If only the category is provided (e.g., `CM1:\DeviceCollection`), the target is the root folder (ID 0).

### Common Scenarios

**Organize collections into folders using FolderPath**:
```powershell
# Move all test collections to a "Testing" folder
$testColls = Get-CM7Collection -Name "Test-*"
$ids = $testColls | ForEach-Object { $_.CollectionID }
Move-CM7Object -ObjectId $ids -FolderPath "CM1:\DeviceCollection\Testing" -Force
```

**Organize collections into folders using FolderId**:
```powershell
# Move all test collections to a "Testing" folder
$testColls = Get-CM7Collection -Name "Test-*"
$ids = $testColls | ForEach-Object { $_.CollectionID }
Move-CM7Object -ObjectId $ids -ObjectType DeviceCollection -FolderId 10 -Force
```

**Move collection back to root**:
```powershell
Move-CM7Object -ObjectId "CM100001" -ObjectType DeviceCollection -FolderId 0 -Force
```

**Verify folder contents after move**:
```powershell
# Query folders in MECM
$namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace `
    -Query "SELECT * FROM SMS_ObjectContainerItem WHERE ContainerNodeID = 3"
```

### Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| "Not connected to MECM" | No active connection | Run `Connect-CM7` first |
| "Destination folder with ID X was not found" | Invalid folder ID | Verify the folder exists in MECM console |
| "Folder type does not match object type" | Mismatched folder/object | Use correct folder for the object type |
| "Unable to determine instance key" | Invalid InputObject | Use -ObjectId and -ObjectType instead |
| "Folder 'X' was not found under 'Y'" | Invalid folder path segment | Verify folder path exists in MECM console |
| "Invalid object type category" | Invalid category in FolderPath | Use a valid category (DeviceCollection, Package, etc.) |
| Move failed with return value | Server-side error | Check MECM logs for details |

### Differences from Move-CMObject

Compared to the ConfigurationManager module's `Move-CMObject`:

| Feature | Move-CMObject | Move-CM7Object |
|---------|---------------|----------------|
| Connection | Requires CM drive | Uses CIM/WinRM |
| Console Required | Yes | No |
| Remote Execution | Limited | Full support |
| FolderPath | Yes (CM drive path) | Yes (SiteCode:\Category\Path) |
| Object Type | Auto-detected from IResultObject | Specified via parameter, auto-detected from FolderPath, or detected from InputObject |
| ShouldProcess | Yes | Yes |
| Pipeline Support | Yes (IResultObject) | Yes (CIM objects) |
| Output | None | MoveResult objects |
| Folder Validation | Internal | Explicit with warning |

## RELATED LINKS

- [Connect-CM7](Connect-CM7.md) - Establish MECM connection
- [Get-CM7Collection](Get-CM7Collection.md) - Retrieve collection information
- [Get-CM7Device](Get-CM7Device.md) - Retrieve device information
- [Invoke-CimMethod](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/invoke-cimmethod) - CIM method cmdlet used internally
- [SMS_ObjectContainerItem Server WMI Class](https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/console/sms_objectcontaineritem-server-wmi-class) - MECM WMI class documentation
- [SMS_ObjectContainerNode Server WMI Class](https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/console/sms_objectcontainernode-server-wmi-class) - MECM folder WMI class documentation
- [MECM7 README](../README.md) - Module overview
- [Help Directory](README.md) - All function documentation
