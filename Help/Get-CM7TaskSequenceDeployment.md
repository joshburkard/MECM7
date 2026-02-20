# Get-CM7TaskSequenceDeployment

## SYNOPSIS

Retrieves task sequence deployment information from Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `Get-CM7TaskSequenceDeployment` function queries the SMS_Advertisement WMI class to retrieve task sequence deployment information from MECM. It provides flexible filtering options including advertisement ID (deployment ID), task sequence name (with wildcard support), task sequence PackageID, collection name (with wildcard support), and deployment name (with wildcard support).

This function is the CIM-based equivalent of the `Get-CMTaskSequenceDeployment` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Builds a WQL query based on the provided parameters
3. When filtering by collection name, first resolves collection names to IDs via the SMS_Collection class
4. When filtering by task sequence name, first resolves names to PackageIDs via SMS_TaskSequencePackage
5. Queries SMS_DeploymentSummary (FeatureType = 7) to identify task sequence deployments, then retrieves full details from SMS_Advertisement
6. Resolves collection IDs and PackageIDs back to friendly names for display
7. Returns formatted task sequence deployment objects with commonly used properties

Key features:
- **Wildcard Support**: Use `*` and `?` in deployment names, task sequence names, and collection names for pattern matching
- **Collection Name Filtering**: Filter by collection name even though SMS_Advertisement stores only collection IDs
- **Task Sequence Filtering**: Filter by task sequence name or PackageID
- **Fast Mode**: Return limited properties for faster queries on large environments
- **Friendly Names**: Collection names and task sequence names are resolved and included in output
- **Flexible Querying**: Query by advertisement ID, task sequence, collection, deployment name, or retrieve all deployments

## PARAMETERS

### -AdvertisementID

Specifies the unique advertisement ID (deployment ID) of the task sequence deployment to retrieve. This is the AdvertisementID property (string).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByAdvertisementID parameter set)
- **Parameter Set**: ByAdvertisementID
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"SD120BD2"`

### -TaskSequenceName

Specifies the name of the task sequence associated with the deployment. Supports PowerShell wildcard characters (`*` and `?`).

The function resolves task sequence names to PackageIDs via the SMS_TaskSequencePackage class before querying.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByTaskSequenceName parameter set)
- **Parameter Set**: ByTaskSequenceName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `"Test Josh"` - Exact match
- `"Install Windows*"` - All deployments for task sequences starting with "Install Windows"
- `"*reboot*"` - All deployments for task sequences containing "reboot"

### -TaskSequencePackageId

Specifies the PackageID of the task sequence associated with the deployment.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByTaskSequencePackageId parameter set)
- **Parameter Set**: ByTaskSequencePackageId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"SD100FAD"`

### -CollectionName

Specifies the name of the collection targeted by the task sequence deployment. Supports PowerShell wildcard characters (`*` and `?`).

The function resolves collection names to collection IDs via the SMS_Collection class before querying SMS_Advertisement.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `"SP_ACC_2025-01-30_18:00_00:00_automatic_reboot"` - Exact match
- `"SP_ACC_*"` - All deployments targeting collections starting with "SP_ACC_"
- `"*Servers*"` - All deployments targeting collections containing "Servers"

### -DeploymentName

Specifies the name of the deployment (AdvertisementName). Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByDeploymentName parameter set)
- **Parameter Set**: ByDeploymentName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `"My TS Deployment"` - Exact match
- `"*reboot*"` - All deployments containing "reboot" in the name

### -Fast

Returns limited properties for faster performance. Only essential properties are returned:
- AdvertisementID
- AdvertisementName
- CollectionID
- CollectionName
- PackageID
- TaskSequenceName
- ProgramName
- SourceSite
- AdvertFlags
- RemoteClientFlags
- PresentTime
- ExpirationTime

Note: Lazy properties such as `TimeFlags`, `AssignedScheduleEnabled`, `AssignedSchedule`, `ExpirationTimeEnabled`, etc., are only available in non-Fast (default) mode via `SELECT *`.

This is useful when querying large numbers of task sequence deployments or when you only need basic information.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

## EXAMPLES

### EXAMPLE 1: Get all task sequence deployments

```powershell
Get-CM7TaskSequenceDeployment
```

Retrieves all task sequence deployments from MECM.

### EXAMPLE 2: Get a task sequence deployment by advertisement ID

```powershell
Get-CM7TaskSequenceDeployment -AdvertisementID "SD120BD2"
```

Retrieves the specific task sequence deployment with the given advertisement ID.

### EXAMPLE 3: Get task sequence deployments by collection name

```powershell
Get-CM7TaskSequenceDeployment -CollectionName "SP_ACC_2025-01-30_18:00_00:00_automatic_reboot"
```

Retrieves all task sequence deployments targeting the specified collection.

### EXAMPLE 4: Get task sequence deployments using wildcard collection name

```powershell
Get-CM7TaskSequenceDeployment -CollectionName "SP_ACC_*"
```

Retrieves all task sequence deployments targeting collections whose names start with "SP_ACC_".

### EXAMPLE 5: Get task sequence deployments by task sequence name

```powershell
Get-CM7TaskSequenceDeployment -TaskSequenceName "Test Josh"
```

Retrieves all deployments of the task sequence named "Test Josh".

### EXAMPLE 6: Get task sequence deployments by task sequence PackageID

```powershell
Get-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD"
```

Retrieves all deployments of the task sequence with the specified PackageID.

### EXAMPLE 7: Get task sequence deployments by deployment name with wildcards

```powershell
Get-CM7TaskSequenceDeployment -DeploymentName "*reboot*"
```

Retrieves all task sequence deployments whose names contain "reboot".

### EXAMPLE 8: Get task sequence deployments with Fast mode

```powershell
Get-CM7TaskSequenceDeployment -Fast
```

Retrieves all task sequence deployments with limited properties for faster performance.

### EXAMPLE 9: Get task sequence deployment summary information

```powershell
Get-CM7TaskSequenceDeployment |
    Select-Object AdvertisementID, AdvertisementName, CollectionName, TaskSequenceName, PresentTime |
    Format-Table -AutoSize
```

Retrieves all task sequence deployments and displays a summary table.

### EXAMPLE 10: Export task sequence deployment information

```powershell
Get-CM7TaskSequenceDeployment -Fast |
    Export-Csv -Path "TaskSequenceDeployments.csv" -NoTypeInformation
```

Exports all task sequence deployments with limited properties to a CSV file.

### EXAMPLE 11: Get task sequence deployments with verbose output

```powershell
Get-CM7TaskSequenceDeployment -CollectionName "SP_ACC_2025-01-30_18:00_00:00_automatic_reboot" -Verbose
```

Retrieves task sequence deployments with verbose output showing the WQL queries being executed.

## OUTPUTS

### PSCustomObject (MECM7.TaskSequenceDeployment)

The function returns custom objects with the following commonly used properties:

| Property | Type | Description |
|----------|------|-------------|
| AdvertisementID | string | Unique advertisement/deployment identifier |
| AdvertisementName | string | Name of the deployment |
| CollectionID | string | Target collection ID |
| CollectionName | string | Target collection name (resolved from ID) |
| PackageID | string | PackageID of the associated task sequence |
| TaskSequenceName | string | Name of the associated task sequence (resolved from PackageID) |
| ProgramName | string | Program name (always `*` for task sequence deployments) |
| SourceSite | string | Source site code |
| AdvertFlags | int | Advertisement flags |
| RemoteClientFlags | int | Remote client flags |
| PresentTime | datetime | Available time (when deployment becomes available) |
| ExpirationTime | datetime | Expiration time |

When not using `-Fast` mode, all properties from the SMS_Advertisement class are included in the output object, including lazy properties such as `TimeFlags`, `AssignedScheduleEnabled`, `AssignedSchedule`, `ExpirationTimeEnabled`, `PresentTimeEnabled`, etc.

Example object:

```powershell
PSTypeName              : MECM7.TaskSequenceDeployment
AdvertisementID         : SD120BD2
AdvertisementName       : Test Josh - SP_ACC_2025-01-30
CollectionID            : SD1018FB
CollectionName          : SP_ACC_2025-01-30_18:00_00:00_automatic_reboot
PackageID               : SD100FAD
TaskSequenceName        : Test Josh
ProgramName             : *
SourceSite              : SD1
AdvertFlags             : 42860576
RemoteClientFlags       : 8480
PresentTime             : 2025-01-30 18:00:00
ExpirationTime          : 2025-12-31 23:59:00
TimeFlags               : 8193              # Non-Fast mode only (lazy property)
AssignedScheduleEnabled : True               # Non-Fast mode only (lazy property)
```

## NOTES

### Requirements

- **Connection**: Must have an active connection established via `Connect-CM7`
- **Permissions**: User must have read access to SMS_Advertisement, SMS_DeploymentSummary, SMS_Collection, and SMS_TaskSequencePackage classes in MECM
- **PowerShell**: Version 5.1 or higher
- **Module**: MECM7 module loaded

### Performance Considerations

1. **Use Fast Mode**: When querying many deployments or when you need only basic information, use the `-Fast` switch
2. **Filter Early**: Use parameters to filter results server-side rather than using `Where-Object` on large result sets
3. **Collection Name Lookup**: When filtering by collection name, an additional CIM query is made to resolve collection names to IDs
4. **Task Sequence Name Lookup**: When filtering by task sequence name, an additional CIM query is made to resolve names to PackageIDs
5. **Wildcard Patterns**: Be specific with wildcards to reduce result set size

### How Task Sequence Deployments Work in WMI

Task sequence deployments are stored in the `SMS_Advertisement` class with `ProgramName = '*'`. The function uses `SMS_DeploymentSummary` (filtered by `FeatureType = 7`) to identify task sequence deployments, then retrieves full details from `SMS_Advertisement`.

### WQL Query Examples

The function translates parameters into WQL queries:

```sql
-- Find task sequence deployments via DeploymentSummary
SELECT DeploymentID FROM SMS_DeploymentSummary WHERE FeatureType = 7 AND ProgramName = '*'

-- By Collection (resolved from name)
SELECT CollectionID, Name FROM SMS_Collection WHERE Name = 'MyCollection'
SELECT DeploymentID FROM SMS_DeploymentSummary WHERE FeatureType = 7 AND ProgramName = '*' AND CollectionID = 'SD1018FB'

-- Full advertisement details
SELECT * FROM SMS_Advertisement WHERE AdvertisementID = 'SD120BD2'

-- By Task Sequence Name (resolved to PackageID)
SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE Name = 'Test Josh'
-- Then filter advertisements by PackageID

-- Fast mode
SELECT AdvertisementID, AdvertisementName, CollectionID, PackageID, ... FROM SMS_Advertisement WHERE AdvertisementID = 'SD120BD2'
```

### Common Scenarios

**Deployment Monitoring**: Check task sequence deployment configuration
```powershell
Get-CM7TaskSequenceDeployment -CollectionName "Production*" |
    Select-Object AdvertisementName, CollectionName, TaskSequenceName, PresentTime, ExpirationTime
```

**Find Deployments for a Task Sequence**: See where a task sequence is deployed
```powershell
Get-CM7TaskSequenceDeployment -TaskSequenceName "Install Windows Server - OS - non-PRD" |
    Select-Object AdvertisementName, CollectionName, PresentTime
```

**Reporting**: Export deployment summary
```powershell
Get-CM7TaskSequenceDeployment -Fast | Export-Csv deployments.csv -NoTypeInformation
```

### Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| "Not connected to MECM" | No active connection | Run `Connect-CM7` first |
| "Access denied" | Insufficient permissions | Verify MECM security rights |
| No results returned | No matching deployments | Verify task sequence deployment exists in MECM console |
| No collections found | Collection name doesn't match | Verify the collection name is correct |
| No task sequences found | Task sequence name doesn't match | Verify the task sequence name is correct |

### Differences from Get-CMTaskSequenceDeployment

Compared to the ConfigurationManager module's `Get-CMTaskSequenceDeployment`:

| Feature | Get-CMTaskSequenceDeployment | Get-CM7TaskSequenceDeployment |
|---------|------------------------------|-------------------------------|
| Connection | Requires CM drive | Uses CIM/WinRM |
| Console Required | Yes | No |
| Remote Execution | Limited | Full support |
| Wildcard Support | Limited | Full (name, collection name, TS name) |
| Performance | Moderate | Fast with -Fast switch |
| Output Format | CMAdvertisement | PSCustomObject |
| Collection Name | Returned via lazy property | Resolved from ID via SMS_Collection |
| Task Sequence Name | Via lazy property | Resolved from PackageID via SMS_TaskSequencePackage |
| Lazy Properties | Available (local COM) | Not available (WinRM limitation) |

## RELATED LINKS

- [Connect-CM7](Connect-CM7.md) - Establish MECM connection
- [Get-CM7TaskSequence](Get-CM7TaskSequence.md) - Retrieve task sequence information
- [Get-CM7Deployment](Get-CM7Deployment.md) - Retrieve general deployment information
- [Get-CM7Collection](Get-CM7Collection.md) - Retrieve collection information
- [Get-CM7Device](Get-CM7Device.md) - Retrieve device information
- [Get-CimInstance](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance) - CIM cmdlet used internally
- [SMS_Advertisement Server WMI Class](https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_advertisement-server-wmi-class) - MECM WMI class documentation
- [MECM7 README](../README.md) - Module overview
- [Help Directory](README.md) - All function documentation
