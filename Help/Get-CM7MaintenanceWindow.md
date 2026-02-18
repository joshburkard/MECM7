# Get-CM7MaintenanceWindow

## SYNOPSIS

Retrieves maintenance windows from a Microsoft Endpoint Configuration Manager (MECM) collection using CIM.

## DESCRIPTION

The `Get-CM7MaintenanceWindow` function queries the SMS_CollectionSettings WMI class to retrieve maintenance windows (service windows) for a specified MECM collection. Maintenance windows define scheduled time periods during which deployments and other operations can be applied to collection members.

This function is the CIM-based equivalent of the `Get-CMMaintenanceWindow` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves collection name to CollectionID if needed
3. Queries the SMS_CollectionSettings class via CIM
4. Retrieves the full instance to load the lazy property `ServiceWindows`
5. Returns formatted maintenance window objects with details including name, type, schedule, and status

Key features:
- **Name or ID Lookup**: Query by collection name or CollectionID
- **Window Name Filtering**: Filter by maintenance window name with wildcard support
- **Lazy Property Handling**: Properly retrieves lazy properties from SMS_CollectionSettings
- **Type Mapping**: Maps numeric ServiceWindowType and RecurrenceType values to friendly names

## PARAMETERS

### -CollectionName

Specifies the name of the collection to retrieve maintenance windows for.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: No (required for ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `Test-Collection-Direct`

### -CollectionId

Specifies the CollectionID of the collection to retrieve maintenance windows for. This is the unique identifier assigned by MECM to each collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `CM101C00`

### -MaintenanceWindowName

Specifies the name of the maintenance window to retrieve. This parameter is optional and can be used in combination with -CollectionName or -CollectionId to filter the results. Supports PowerShell wildcard characters (`*` and `?`). If not specified, all maintenance windows for the collection are returned.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `Daily MW` - Exact match for a single maintenance window
- `Test-*` - All maintenance windows starting with "Test-"
- `*Update*` - All maintenance windows containing "Update"

## OUTPUTS

### MECM7.MaintenanceWindow

The function returns PSCustomObject instances with the following properties:

- **Name** (String): The name of the maintenance window
- **Description** (String): The description of the maintenance window
- **ServiceWindowID** (String): The unique identifier of the maintenance window
- **IsEnabled** (Boolean): Whether the maintenance window is currently enabled
- **ServiceWindowType** (String): The type of maintenance window. Possible values:
  - `General` - All deployments (type 1 and 6)
  - `SoftwareUpdatesOnly` - Software updates only (type 4)
  - `TaskSequencesOnly` - Task sequences only (type 5)
- **StartTime** (DateTime): The start time of the maintenance window
- **Duration** (Int): The duration of the maintenance window in minutes
- **RecurrenceType** (String): The recurrence schedule type. Possible values:
  - `None` - One-time window (type 1)
  - `Daily` - Repeats daily (type 2)
  - `Weekly` - Repeats weekly (type 3)
  - `MonthlyByWeekday` - Repeats monthly on a specific weekday (type 4)
  - `MonthlyByDate` - Repeats monthly on a specific date (type 5)
- **IsGMT** (Boolean): Whether the maintenance window uses UTC/GMT time
- **ServiceWindowSchedules** (String): The raw schedule token string from MECM
- **CollectionID** (String): The CollectionID the maintenance window belongs to

## EXAMPLES

### Example 1: Retrieve all maintenance windows for a collection

```powershell
Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct"
```

Retrieves all maintenance windows defined on the "Test-Collection-Direct" collection.

### Example 2: Retrieve maintenance windows by collection ID

```powershell
Get-CM7MaintenanceWindow -CollectionId "CM101C00"
```

Retrieves all maintenance windows for the collection with ID "CM101C00".

### Example 3: Retrieve a specific maintenance window by name

```powershell
Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Daily MW"
```

Retrieves only the maintenance window named "Daily MW" from the specified collection.

### Example 4: Retrieve maintenance windows matching a wildcard pattern

```powershell
Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Test-*"
```

Retrieves all maintenance windows whose names start with "Test-" from the specified collection.

### Example 5: Check for disabled maintenance windows

```powershell
Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" | Where-Object { $_.IsEnabled -eq $false }
```

Retrieves all disabled maintenance windows from the specified collection.

### Example 6: Filter by maintenance window type

```powershell
Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" | Where-Object { $_.ServiceWindowType -eq 'SoftwareUpdatesOnly' }
```

Retrieves all maintenance windows that apply only to software updates.

### Example 7: Use verbose output for troubleshooting

```powershell
Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Verbose
```

Retrieves all maintenance windows with detailed verbose output showing the WQL queries being executed.

## NOTES

### Maintenance Windows

Maintenance windows in MECM are scheduled time periods that control when deployments and other operations can be applied to the members of a collection. They are essential for:

- **Change Management**: Ensuring deployments only occur during approved time windows
- **Software Updates**: Controlling when software updates are installed on devices
- **Task Sequences**: Managing when OS deployments and other task sequences can run
- **Business Continuity**: Preventing disruptions during business-critical hours

### Maintenance Window Types

MECM supports three types of maintenance windows:

| Type | Description |
|------|-------------|
| **General** | Applies to all deployments (software updates, task sequences, and applications) |
| **SoftwareUpdatesOnly** | Applies only to software update deployments |
| **TaskSequencesOnly** | Applies only to task sequence deployments |

### Recurrence Types

Maintenance windows can be configured with different recurrence schedules:

| Recurrence | Description |
|------------|-------------|
| **None** | One-time maintenance window that occurs only once |
| **Daily** | Repeats every day (or every N days) |
| **Weekly** | Repeats every week on specified day(s) |
| **MonthlyByWeekday** | Repeats monthly on a specific weekday (e.g., 2nd Tuesday) |
| **MonthlyByDate** | Repeats monthly on a specific date (e.g., 15th of each month) |

### Lazy Properties

The `ServiceWindows` property of `SMS_CollectionSettings` is a lazy property in MECM WMI. This means it is not returned by standard WQL queries. The function handles this by performing a secondary retrieval of the full instance using `Get-CimInstance -InputObject` to ensure lazy properties are populated.

### Related Functions

- **Get-CM7Collection** - Retrieves collection properties
- **Get-CM7CollectionVariable** - Retrieves collection variables
- **Get-CM7CollectionMember** - Retrieves all members of a collection
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions

### Performance Considerations

- **Lazy Property Retrieval**: The function performs two CIM queries per call (one to find the settings, one to load lazy properties). This is required by the MECM WMI provider design.
- **Wildcard Patterns**: Wildcard filtering on maintenance window names is performed client-side after retrieving all windows for the collection.

### ConfigurationManager Equivalence

This function is equivalent to the ConfigurationManager module's `Get-CMMaintenanceWindow` cmdlet:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
Get-CMMaintenanceWindow -CollectionId "CM101C00"

# MECM7 module (requires only WinRM access)
Get-CM7MaintenanceWindow -CollectionId "CM101C00"
```

## SEE ALSO

- [Get-CM7Collection](./Get-CM7Collection.md)
- [Get-CM7CollectionVariable](./Get-CM7CollectionVariable.md)
- [Get-CM7CollectionMember](./Get-CM7CollectionMember.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
