# Get-CM7SoftwareUpdateDeployment

## SYNOPSIS

Retrieves software update deployment information from Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `Get-CM7SoftwareUpdateDeployment` function queries the SMS_UpdatesAssignment WMI class to retrieve software update deployment information from MECM. It provides flexible filtering options including assignment ID, deployment name (with wildcard support), and collection name (with wildcard support).

This function is the CIM-based equivalent of the `Get-CMSoftwareUpdateDeployment` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Builds a WQL query based on the provided parameters
3. When filtering by collection name, first resolves collection names to IDs via the SMS_Collection class
4. Queries the SMS_UpdatesAssignment class via CIM
5. Resolves collection IDs back to friendly names for display
6. Returns formatted software update deployment objects with commonly used properties

Key features:
- **Wildcard Support**: Use `*` and `?` in deployment names and collection names for pattern matching
- **Collection Name Filtering**: Filter by collection name even though SMS_UpdatesAssignment stores only collection IDs
- **Fast Mode**: Return limited properties for faster queries on large environments
- **Friendly Names**: Assignment action and desired config type are returned as human-readable strings
- **Flexible Querying**: Query by assignment ID, deployment name, collection name, or retrieve all deployments

## PARAMETERS

### -AssignmentId

Specifies the unique assignment ID (integer) of the software update deployment to retrieve.

- **Type**: Int32
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByAssignmentId parameter set)
- **Parameter Set**: ByAssignmentId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `16777220`

### -Name

Specifies the name of the software update deployment. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByName parameter set)
- **Parameter Set**: ByName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `2024-01 Security Updates` - Exact match
- `2024*` - All deployments whose names start with "2024"
- `*Critical*` - All deployments containing "Critical" in the name

### -CollectionName

Specifies the name of the collection targeted by the software update deployment. Supports PowerShell wildcard characters (`*` and `?`).

The function resolves collection names to collection IDs via the SMS_Collection class before querying SMS_UpdatesAssignment.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `SP_ACC_2024-01-18_18:00_00:00_automatic_reboot` - Exact match
- `SP_ACC_*` - All deployments targeting collections starting with "SP_ACC_"
- `*Servers*` - All deployments targeting collections containing "Servers"

### -Fast

Returns limited properties for faster performance. Only essential properties are returned:
- AssignmentID
- AssignmentName
- TargetCollectionID
- CollectionName
- AssignmentDescription
- AssignmentAction
- DesiredConfigType
- StartTime
- EnforcementDeadline
- SuppressReboot
- UseGMTTimes
- NotifyUser
- OverrideServiceWindows
- RebootOutsideOfServiceWindows
- Enabled

This is useful when querying large numbers of software update deployments or when you only need basic information.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

## EXAMPLES

### EXAMPLE 1: Get all software update deployments

```powershell
Get-CM7SoftwareUpdateDeployment
```

Retrieves all software update deployments from MECM.

### EXAMPLE 2: Get a software update deployment by assignment ID

```powershell
Get-CM7SoftwareUpdateDeployment -AssignmentId 16777220
```

Retrieves the specific software update deployment with the given assignment ID.

### EXAMPLE 3: Get software update deployments by name

```powershell
Get-CM7SoftwareUpdateDeployment -Name "2024-01 Security Updates"
```

Retrieves the software update deployment with the specified name.

### EXAMPLE 4: Get software update deployments using wildcard name

```powershell
Get-CM7SoftwareUpdateDeployment -Name "2024*"
```

Retrieves all software update deployments whose names start with "2024".

### EXAMPLE 5: Get software update deployments by collection name

```powershell
Get-CM7SoftwareUpdateDeployment -CollectionName "SP_ACC_2024-01-18_18:00_00:00_automatic_reboot"
```

Retrieves all software update deployments targeting the specified collection.

### EXAMPLE 6: Get software update deployments using wildcard collection name

```powershell
Get-CM7SoftwareUpdateDeployment -CollectionName "SP_ACC_*"
```

Retrieves all software update deployments targeting collections whose names start with "SP_ACC_".

### EXAMPLE 7: Get software update deployments with Fast mode

```powershell
Get-CM7SoftwareUpdateDeployment -Fast
```

Retrieves all software update deployments with limited properties for faster performance.

### EXAMPLE 8: Get software update deployment summary information

```powershell
Get-CM7SoftwareUpdateDeployment |
    Select-Object AssignmentName, CollectionName, DesiredConfigType, StartTime, EnforcementDeadline, Enabled |
    Format-Table -AutoSize
```

Retrieves all software update deployments and displays a summary table.

### EXAMPLE 9: Export software update deployment information

```powershell
Get-CM7SoftwareUpdateDeployment -Fast |
    Export-Csv -Path "SoftwareUpdateDeployments.csv" -NoTypeInformation
```

Exports all software update deployments with limited properties to a CSV file.

### EXAMPLE 10: Find required software update deployments

```powershell
Get-CM7SoftwareUpdateDeployment | Where-Object { $_.DesiredConfigType -eq 'Required' } |
    Select-Object AssignmentName, CollectionName, EnforcementDeadline |
    Sort-Object EnforcementDeadline
```

Finds all required software update deployments and sorts by enforcement deadline.

### EXAMPLE 11: Get software update deployments with verbose output

```powershell
Get-CM7SoftwareUpdateDeployment -CollectionName "SP_ACC_2024-01-18_18:00_00:00_automatic_reboot" -Verbose
```

Retrieves software update deployments with verbose output showing the WQL queries being executed.

## OUTPUTS

### PSCustomObject (MECM7.SoftwareUpdateDeployment)

The function returns custom objects with the following commonly used properties:

| Property | Type | Description |
|----------|------|-------------|
| AssignmentID | int | Unique assignment identifier |
| AssignmentName | string | Name of the software update deployment |
| TargetCollectionID | string | Target collection ID |
| CollectionName | string | Target collection name (resolved from ID) |
| AssignmentDescription | string | Description of the deployment |
| AssignmentAction | string | Action type (Detect, Install) |
| DesiredConfigType | string | Configuration type (Required, Optional) |
| StartTime | datetime | Deployment start time |
| EnforcementDeadline | datetime | Enforcement deadline |
| SuppressReboot | bool | Whether reboot is suppressed |
| UseGMTTimes | bool | Whether times are in GMT |
| NotifyUser | bool | Whether user is notified |
| OverrideServiceWindows | bool | Whether service windows are overridden |
| RebootOutsideOfServiceWindows | bool | Whether reboot is allowed outside service windows |
| Enabled | bool | Whether the deployment is enabled |

When not using `-Fast` mode, all properties from the SMS_UpdatesAssignment class are included in the output object.

Example object:

```powershell
PSTypeName                    : MECM7.SoftwareUpdateDeployment
AssignmentID                  : 16777220
AssignmentName                : 2024-01 Security Updates
TargetCollectionID            : SD101C00
CollectionName                : SP_ACC_2024-01-18_18:00_00:00_automatic_reboot
AssignmentDescription         : Monthly security updates deployment
AssignmentAction              : Install
DesiredConfigType             : Required
StartTime                     : 2024-01-18 18:00:00
EnforcementDeadline           : 2024-01-25 18:00:00
SuppressReboot                : False
UseGMTTimes                   : True
NotifyUser                    : True
OverrideServiceWindows        : False
RebootOutsideOfServiceWindows : False
Enabled                       : True
```

## NOTES

### Requirements

- **Connection**: Must have an active connection established via `Connect-CM7`
- **Permissions**: User must have read access to SMS_UpdatesAssignment and SMS_Collection classes in MECM
- **PowerShell**: Version 5.1 or higher
- **Module**: MECM7 module loaded

### Performance Considerations

1. **Use Fast Mode**: When querying many deployments or when you need only basic information, use the `-Fast` switch
2. **Filter Early**: Use parameters to filter results server-side rather than using `Where-Object` on large result sets
3. **Collection Name Lookup**: When filtering by collection name, an additional CIM query is made to resolve collection names to IDs. For best performance, use `-AssignmentId` or `-Name` when possible
4. **Wildcard Patterns**: Be specific with wildcards to reduce result set size

### WQL Query Examples

The function translates parameters into WQL queries:

```sql
-- All software update deployments
SELECT * FROM SMS_UpdatesAssignment

-- By Assignment ID
SELECT * FROM SMS_UpdatesAssignment WHERE AssignmentID = 16777220

-- By Name (exact)
SELECT * FROM SMS_UpdatesAssignment WHERE AssignmentName = '2024-01 Security Updates'

-- By Name (wildcard)
SELECT * FROM SMS_UpdatesAssignment WHERE AssignmentName LIKE '2024%'

-- By Collection Name (resolved to ID first)
SELECT CollectionID, Name FROM SMS_Collection WHERE Name = 'MyCollection'
SELECT * FROM SMS_UpdatesAssignment WHERE TargetCollectionID = 'SD101C00'

-- Fast mode
SELECT AssignmentID, AssignmentName, TargetCollectionID, ... FROM SMS_UpdatesAssignment
```

### Assignment Action Values

| Friendly Name | WMI Value |
|---------------|-----------|
| Detect | 0 |
| Install | 1 |

### Desired Config Type Values

| Friendly Name | WMI Value |
|---------------|-----------|
| Required | 1 |
| Optional | 2 |

### Common Scenarios

**Deployment Monitoring**: Check software update deployment configuration
```powershell
Get-CM7SoftwareUpdateDeployment -CollectionName "Production*" |
    Select-Object AssignmentName, CollectionName, DesiredConfigType, EnforcementDeadline, Enabled
```

**Audit Deployments**: Find all required deployments with enforcement deadlines
```powershell
Get-CM7SoftwareUpdateDeployment | Where-Object { $_.DesiredConfigType -eq 'Required' -and $_.EnforcementDeadline } |
    Sort-Object EnforcementDeadline
```

**Reporting**: Export deployment summary
```powershell
Get-CM7SoftwareUpdateDeployment -Fast | Export-Csv deployments.csv -NoTypeInformation
```

### Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| "Not connected to MECM" | No active connection | Run `Connect-CM7` first |
| "Access denied" | Insufficient permissions | Verify MECM security rights |
| No results returned | No matching deployments | Verify software update deployment exists in MECM console |
| No collections found | Collection name doesn't match | Verify the collection name is correct |

### Differences from Get-CMSoftwareUpdateDeployment

Compared to the ConfigurationManager module's `Get-CMSoftwareUpdateDeployment`:

| Feature | Get-CMSoftwareUpdateDeployment | Get-CM7SoftwareUpdateDeployment |
|---------|--------------------------------|----------------------------------|
| Connection | Requires CM drive | Uses CIM/WinRM |
| Console Required | Yes | No |
| Remote Execution | Limited | Full support |
| Wildcard Support | Limited | Full (name & collection name) |
| Performance | Moderate | Fast with -Fast switch |
| Output Format | CMSoftwareUpdateDeployment | PSCustomObject |
| Action / Config Type | Integer values | Friendly name strings |
| Collection Name | Returned directly | Resolved from ID via SMS_Collection |

## RELATED LINKS

- [Connect-CM7](Connect-CM7.md) - Establish MECM connection
- [Get-CM7Deployment](Get-CM7Deployment.md) - Retrieve general deployment information
- [Get-CM7Collection](Get-CM7Collection.md) - Retrieve collection information
- [Get-CM7Device](Get-CM7Device.md) - Retrieve device information
- [Get-CimInstance](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance) - CIM cmdlet used internally
- [SMS_UpdatesAssignment Server WMI Class](https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/sum/sms_updatesassignment-server-wmi-class) - MECM WMI class documentation
- [MECM7 README](../README.md) - Module overview
- [Help Directory](README.md) - All function documentation
