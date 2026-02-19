# Get-CM7Deployment

## SYNOPSIS

Retrieves deployment information from Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `Get-CM7Deployment` function queries the SMS_DeploymentSummary WMI class to retrieve deployment information from MECM. It provides flexible filtering options including deployment ID, collection name (with wildcard support), software name (with wildcard support), and feature type.

This function is the CIM-based equivalent of the `Get-CMDeployment` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Builds a WQL query based on the provided parameters
3. Queries the SMS_DeploymentSummary class via CIM
4. Returns formatted deployment objects with commonly used properties

Key features:
- **Wildcard Support**: Use `*` and `?` in collection names and software names for pattern matching
- **Feature Type Filtering**: Filter by Application, Program, SoftwareUpdateGroup, ConfigurationBaseline, or TaskSequence
- **Fast Mode**: Return limited properties for faster queries on large environments
- **Flexible Querying**: Query by deployment ID, collection name, software name, or retrieve all deployments

## PARAMETERS

### -DeploymentId

Specifies the unique identifier of the deployment to retrieve.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByDeploymentId parameter set)
- **Parameter Set**: ByDeploymentId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"{12345678-1234-1234-1234-123456789012}"`

### -CollectionName

Specifies the name of the collection targeted by the deployment. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `Test-Collection-Direct` - Exact match
- `Test-*` - All deployments targeting collections starting with "Test-"
- `*Servers*` - All deployments targeting collections containing "Servers"

### -SoftwareName

Specifies the name of the software being deployed. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for BySoftwareName parameter set)
- **Parameter Set**: BySoftwareName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `Microsoft Office 365` - Exact match
- `Microsoft*` - All deployments for software starting with "Microsoft"

### -FeatureType

Specifies the feature type of the deployment to retrieve. Filters deployments by their type.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByFeatureType parameter set)
- **Parameter Set**: ByFeatureType
- **Accept pipeline input**: False
- **Accept wildcard characters**: No
- **Valid Values**:
  - `Application` (FeatureType = 1)
  - `Program` (FeatureType = 2)
  - `SoftwareUpdateGroup` (FeatureType = 5)
  - `ConfigurationBaseline` (FeatureType = 6)
  - `TaskSequence` (FeatureType = 7)

### -Fast

Returns limited properties for faster performance. Only essential properties are returned:
- DeploymentID
- CollectionID
- CollectionName
- SoftwareName
- PackageID
- FeatureType
- NumberTargeted
- NumberSuccess
- NumberInProgress
- NumberErrors
- NumberOther
- NumberUnknown

This is useful when querying large numbers of deployments or when you only need basic information.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

## EXAMPLES

### EXAMPLE 1: Get all deployments

```powershell
Get-CM7Deployment
```

Retrieves all deployments from MECM.

### EXAMPLE 2: Get a deployment by ID

```powershell
Get-CM7Deployment -DeploymentId "{12345678-1234-1234-1234-123456789012}"
```

Retrieves the specific deployment with the given deployment ID.

### EXAMPLE 3: Get deployments by collection name

```powershell
Get-CM7Deployment -CollectionName "Test-Collection-Direct"
```

Retrieves all deployments targeting the "Test-Collection-Direct" collection.

### EXAMPLE 4: Get deployments using wildcard collection name

```powershell
Get-CM7Deployment -CollectionName "Test-*"
```

Retrieves all deployments targeting collections whose names start with "Test-".

### EXAMPLE 5: Get deployments by software name

```powershell
Get-CM7Deployment -SoftwareName "Microsoft*"
```

Retrieves all deployments for software whose names start with "Microsoft".

### EXAMPLE 6: Get application deployments

```powershell
Get-CM7Deployment -FeatureType Application
```

Retrieves all application deployments.

### EXAMPLE 7: Get software update group deployments with Fast mode

```powershell
Get-CM7Deployment -FeatureType SoftwareUpdateGroup -Fast
```

Retrieves all software update group deployments with limited properties for faster performance.

### EXAMPLE 8: Get deployment summary information

```powershell
Get-CM7Deployment -CollectionName "All Systems" |
    Select-Object SoftwareName, FeatureType, NumberTargeted, NumberSuccess, NumberErrors |
    Format-Table -AutoSize
```

Retrieves deployments for "All Systems" and displays a summary table.

### EXAMPLE 9: Export deployment information

```powershell
Get-CM7Deployment -Fast |
    Export-Csv -Path "Deployments.csv" -NoTypeInformation
```

Exports all deployments with limited properties to a CSV file.

### EXAMPLE 10: Find failed deployments

```powershell
Get-CM7Deployment | Where-Object { $_.NumberErrors -gt 0 } |
    Select-Object SoftwareName, CollectionName, NumberErrors, NumberTargeted |
    Sort-Object NumberErrors -Descending
```

Finds all deployments with errors and sorts by error count.

### EXAMPLE 11: Get deployments with verbose output

```powershell
Get-CM7Deployment -CollectionName "Test-Collection-Direct" -Verbose
```

Retrieves deployments with verbose output showing the WQL query being executed.

## OUTPUTS

### PSCustomObject (MECM7.Deployment)

The function returns custom objects with the following commonly used properties:

| Property | Type | Description |
|----------|------|-------------|
| DeploymentID | string | Unique deployment identifier |
| CollectionID | string | Target collection ID |
| CollectionName | string | Target collection name |
| SoftwareName | string | Name of the deployed software |
| PackageID | string | Package ID of the deployment |
| FeatureType | string | Deployment type (Application, Program, SoftwareUpdateGroup, ConfigurationBaseline, TaskSequence) |
| NumberTargeted | int | Total number of targeted clients |
| NumberSuccess | int | Number of clients reporting success |
| NumberInProgress | int | Number of clients with deployment in progress |
| NumberErrors | int | Number of clients reporting errors |
| NumberOther | int | Number of clients in other states |
| NumberUnknown | int | Number of clients with unknown status |

When not using `-Fast` mode, all properties from the SMS_DeploymentSummary class are included in the output object.

Example object:

```powershell
PSTypeName       : MECM7.Deployment
DeploymentID     : {12345678-1234-1234-1234-123456789012}
CollectionID     : CM101C00
CollectionName   : Test-Collection-Direct
SoftwareName     : My Application
PackageID        : CM100001
FeatureType      : Application
NumberTargeted   : 10
NumberSuccess    : 8
NumberInProgress : 1
NumberErrors     : 1
NumberOther      : 0
NumberUnknown    : 0
```

## NOTES

### Requirements

- **Connection**: Must have an active connection established via `Connect-CM7`
- **Permissions**: User must have read access to SMS_DeploymentSummary class in MECM
- **PowerShell**: Version 5.1 or higher
- **Module**: MECM7 module loaded

### Performance Considerations

1. **Use Fast Mode**: When querying many deployments or when you need only basic information, use the `-Fast` switch
2. **Filter Early**: Use parameters to filter results server-side rather than using `Where-Object` on large result sets
3. **Wildcard Patterns**: Be specific with wildcards to reduce result set size

### WQL Query Examples

The function translates parameters into WQL queries:

```sql
-- All deployments
SELECT * FROM SMS_DeploymentSummary

-- By Deployment ID
SELECT * FROM SMS_DeploymentSummary WHERE DeploymentID = '{12345678-...}'

-- By Collection Name (exact)
SELECT * FROM SMS_DeploymentSummary WHERE CollectionName = 'Test-Collection-Direct'

-- By Collection Name (wildcard)
SELECT * FROM SMS_DeploymentSummary WHERE CollectionName LIKE 'Test-%'

-- By Software Name (wildcard)
SELECT * FROM SMS_DeploymentSummary WHERE SoftwareName LIKE 'Microsoft%'

-- By Feature Type
SELECT * FROM SMS_DeploymentSummary WHERE FeatureType = 1

-- Fast mode
SELECT DeploymentID, CollectionID, CollectionName, ... FROM SMS_DeploymentSummary
```

### Feature Type Values

| Friendly Name | WMI Value |
|---------------|-----------|
| Application | 1 |
| Program | 2 |
| SoftwareUpdateGroup | 5 |
| ConfigurationBaseline | 6 |
| TaskSequence | 7 |

### Common Scenarios

**Deployment Monitoring**: Check deployment status across collections
```powershell
Get-CM7Deployment -CollectionName "Production*" |
    Select-Object CollectionName, SoftwareName, NumberSuccess, NumberErrors
```

**Troubleshooting**: Find deployments with errors
```powershell
Get-CM7Deployment | Where-Object { $_.NumberErrors -gt 0 }
```

**Reporting**: Export deployment summary
```powershell
Get-CM7Deployment -Fast | Export-Csv deployments.csv -NoTypeInformation
```

### Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| "Not connected to MECM" | No active connection | Run `Connect-CM7` first |
| "Access denied" | Insufficient permissions | Verify MECM security rights |
| No results returned | No matching deployments | Verify deployment exists in MECM console |

### Differences from Get-CMDeployment

Compared to the ConfigurationManager module's `Get-CMDeployment`:

| Feature | Get-CMDeployment | Get-CM7Deployment |
|---------|------------------|-------------------|
| Connection | Requires CM drive | Uses CIM/WinRM |
| Console Required | Yes | No |
| Remote Execution | Limited | Full support |
| Wildcard Support | Limited | Full (collection name & software name) |
| Performance | Moderate | Fast with -Fast switch |
| Output Format | CMDeployment object | PSCustomObject |
| Feature Type | Integer parameter | Friendly name parameter |

## RELATED LINKS

- [Connect-CM7](Connect-CM7.md) - Establish MECM connection
- [Get-CM7Collection](Get-CM7Collection.md) - Retrieve collection information
- [Get-CM7Device](Get-CM7Device.md) - Retrieve device information
- [Get-CimInstance](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance) - CIM cmdlet used internally
- [SMS_DeploymentSummary Server WMI Class](https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/apps/sms_deploymentsummary-server-wmi-class) - MECM WMI class documentation
- [MECM7 README](../README.md) - Module overview
- [Help Directory](README.md) - All function documentation
