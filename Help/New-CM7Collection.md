# New-CM7Collection

## SYNOPSIS

Creates a new MECM collection using CIM.

## DESCRIPTION

The `New-CM7Collection` function creates a new device or user collection in Microsoft Endpoint Configuration Manager (MECM) using CIM. It creates an instance of the `SMS_Collection` class via CIM and optionally moves it to a specified folder path.

This function is the CIM-based equivalent of the `New-CMCollection` / `New-CMDeviceCollection` / `New-CMUserCollection` cmdlets from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the limiting collection (by name or ID)
3. Checks for duplicate collection names
4. Creates a new `SMS_Collection` instance via CIM with the specified properties
5. Optionally moves the new collection to a specified folder path using `Move-CM7Object`
6. Returns the created collection as a formatted `MECM7.Collection` object

Key features:
- **Device & User Collections**: Create either device or user collections
- **Limiting Collection**: Specify limiting collection by ID or name
- **Refresh Types**: Configure manual, periodic, continuous, or combined refresh
- **Refresh Schedule**: Set a custom periodic refresh schedule
- **Folder Placement**: Automatically move the new collection to a specific folder after creation
- **Duplicate Detection**: Prevents creation of collections with existing names
- **WhatIf/Confirm**: Full ShouldProcess support for safe operations

## PARAMETERS

### -Name

Specifies the name of the new collection. Must be unique within the MECM environment.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: Yes
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Examples:
- `"My Device Collection"` - Simple collection name
- `"Server-Patching-Group-PROD"` - Descriptive name for patching

### -CollectionType

Specifies the type of collection to create. Valid values are `Device` or `User`.

- Device collections contain device/computer objects
- User collections contain user objects

- **Type**: String
- **Position**: Named
- **Default**: `Device`
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Valid Values**: Device, User

### -LimitingCollectionId

Specifies the CollectionID of the limiting collection. A limiting collection defines the scope of devices or users that can be members of the new collection.
Mutually exclusive with `-LimitingCollectionName`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when not using -LimitingCollectionName)
- **Parameter Set**: ByLimitingId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Examples:
- `"SMS00001"` - All Systems (typical limiting collection for device collections)
- `"SMS00002"` - All Users (typical limiting collection for user collections)

### -LimitingCollectionName

Specifies the name of the limiting collection. A limiting collection defines the scope of devices or users that can be members of the new collection.
Mutually exclusive with `-LimitingCollectionId`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (when not using -LimitingCollectionId)
- **Parameter Set**: ByLimitingName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"All Systems"` - Use the All Systems collection as the limiting collection

### -Comment

Specifies an optional comment or description for the new collection. This text appears in the MECM console and can be used to document the purpose of the collection.

- **Type**: String
- **Position**: Named
- **Default**: None (empty)
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

### -RefreshType

Specifies the collection membership refresh type.

| Value | Numeric | Description |
|-------|---------|-------------|
| Manual | 1 | No automatic refresh; membership is only updated manually |
| Periodic | 2 | Membership is refreshed on a schedule |
| Continuous | 4 | Membership is updated continuously (incremental updates) |
| Both | 6 | Combination of Periodic and Continuous |

- **Type**: String
- **Position**: Named
- **Default**: `Manual`
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Valid Values**: Manual, Periodic, Continuous, Both

### -RefreshSchedule

Specifies a hashtable defining the periodic refresh schedule. Only applicable when `-RefreshType` includes `Periodic` (i.e., `Periodic` or `Both`).

The hashtable can contain the following keys:

| Key | Type | Description |
|-----|------|-------------|
| DaySpan | Int | Number of days between refreshes (e.g., 1 for daily) |
| HourSpan | Int | Number of hours between refreshes |
| MinuteSpan | Int | Number of minutes between refreshes |
| StartTime | String/DateTime | The start time for the schedule (ISO 8601 format or DateTime) |

If no interval is specified, defaults to weekly (DaySpan = 7).

- **Type**: Hashtable
- **Position**: Named
- **Default**: None
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

Example: `@{ DaySpan = 1 }` - Daily refresh schedule

### -FolderPath

Specifies an optional folder path in MECM format to move the new collection to after creation.
The path is resolved by walking the `SMS_ObjectContainerNode` hierarchy.
Uses `Move-CM7Object` internally to perform the move.

If the move fails, the collection is still created but a warning is issued.

- **Type**: String
- **Position**: Named
- **Default**: None (collection stays in root)
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Path format: `SiteCode:\Category\Folder1\Folder2\...`

Examples:
- `"CM1:\DeviceCollection\TestCollections\Test"` - Subfolder under TestCollections
- `"CM1:\DeviceCollection\Production"` - Production folder
- `"CM1:\UserCollection\Groups"` - User collection folder

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

### EXAMPLE 1: Create a basic device collection

```powershell
New-CM7Collection -Name "My Device Collection" -LimitingCollectionId "SMS00001"
```

Creates a new device collection named "My Device Collection" limited to the "All Systems" collection. Uses default values for CollectionType (Device) and RefreshType (Manual).

### EXAMPLE 2: Create a device collection using limiting collection name

```powershell
New-CM7Collection -Name "Server Collection" -LimitingCollectionName "All Systems"
```

Creates a new device collection using the limiting collection name instead of ID. The function resolves the name to the CollectionID automatically.

### EXAMPLE 3: Create a user collection

```powershell
New-CM7Collection -Name "My User Collection" -CollectionType User -LimitingCollectionId "SMS00002"
```

Creates a new user collection limited to the "All Users" collection.

### EXAMPLE 4: Create a collection with a comment

```powershell
New-CM7Collection -Name "Patching Group A" -LimitingCollectionId "SMS00001" -Comment "Servers in patching window A - Tuesday 10PM"
```

Creates a device collection with a descriptive comment that appears in the MECM console.

### EXAMPLE 5: Create a collection with periodic refresh

```powershell
New-CM7Collection -Name "Auto-Refresh Collection" -LimitingCollectionId "SMS00001" -RefreshType Periodic -RefreshSchedule @{ DaySpan = 1 }
```

Creates a device collection that refreshes its membership daily.

### EXAMPLE 6: Create a collection with continuous (incremental) refresh

```powershell
New-CM7Collection -Name "Incremental Collection" -LimitingCollectionId "SMS00001" -RefreshType Continuous
```

Creates a device collection with continuous (incremental) membership updates.

### EXAMPLE 7: Create a collection with both periodic and continuous refresh

```powershell
New-CM7Collection -Name "Full Refresh Collection" -LimitingCollectionId "SMS00001" -RefreshType Both -RefreshSchedule @{ HourSpan = 4 }
```

Creates a device collection with both periodic (every 4 hours) and continuous refresh.

### EXAMPLE 8: Create a collection and move it to a folder

```powershell
New-CM7Collection -Name "My Collection" -LimitingCollectionId "SMS00001" -FolderPath "CM1:\DeviceCollection\Production\Servers"
```

Creates a new device collection and automatically moves it to the specified folder path.

### EXAMPLE 9: Preview collection creation with WhatIf

```powershell
New-CM7Collection -Name "Test Collection" -LimitingCollectionId "SMS00001" -WhatIf
```

Shows what would happen without actually creating the collection.

### EXAMPLE 10: Create a collection and store the result

```powershell
$newColl = New-CM7Collection -Name "Dynamic Servers" -LimitingCollectionName "All Systems" -RefreshType Both -Comment "Auto-created collection"
Write-Host "Created: $($newColl.Name) ($($newColl.CollectionId))"
```

Creates a collection and captures the result for further processing.

## OUTPUTS

### MECM7.Collection

The function returns a custom object of type `MECM7.Collection` with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| CollectionId | String | The unique collection identifier assigned by MECM |
| Name | String | The display name of the collection |
| CollectionType | String | The type of collection: "Device" or "User" |
| TypeValue | Int | Numeric representation: 1=User, 2=Device |
| LimitToCollectionID | String | The CollectionID of the limiting collection |
| LimitToCollectionName | String | The name of the limiting collection |
| MemberCount | Int | Number of members (initially 0 for a new collection) |
| Comment | String | Comment/description for the collection |
| RefreshType | Int | Collection refresh type: 1=Manual, 2=Periodic, 4=Continuous, 6=Both |
| LastRefreshTime | DateTime | Date and time the collection membership was last refreshed |
| LastChangeTime | DateTime | Date and time the collection was last modified |
| OwnedByThisSite | Boolean | Whether this collection is owned by the current site |

All additional WMI properties from the `SMS_Collection` class are also included.

## REQUIREMENTS

- An active MECM/SCCM connection established via `Connect-CM7`
- PowerShell 5.1 or higher
- Access to the MECM SMS Provider via WinRM
- Sufficient MECM permissions to create collections

## NOTES

- The function creates collections using the `SMS_Collection` WMI class directly via CIM sessions.
- A limiting collection must be specified for every new collection. This defines the maximum membership scope.
- For device collections, the typical limiting collection is "All Systems" (`SMS00001`).
- For user collections, the typical limiting collection is "All Users" (`SMS00002`).
- The function checks for duplicate collection names before creation and throws an error if one exists.
- When using `-FolderPath`, the function calls `Move-CM7Object` internally. If the move fails, the collection is still created and a warning is issued.
- RefreshSchedule is only applied when RefreshType includes Periodic. If no schedule is provided with Periodic refresh, MECM uses its default schedule.
- The `PSTypeName` is automatically set to `MECM7.Collection` for improved formatting and type safety.

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7Collection](./Get-CM7Collection.md) - Retrieve collection information
- [Move-CM7Object](./Move-CM7Object.md) - Move MECM objects between folders
- [Get-CM7CollectionMember](./Get-CM7CollectionMember.md) - Retrieve collection members
- [Get-CM7CollectionDirectMembership](./Get-CM7CollectionDirectMembership.md) - Retrieve direct membership rules

## SEE ALSO

- `New-CMCollection` - Native ConfigurationManager module equivalent
- `New-CMDeviceCollection` - Native cmdlet for device collections
- `New-CMUserCollection` - Native cmdlet for user collections
- `New-CimInstance` - PowerShell CIM cmdlet for creating WMI instances
