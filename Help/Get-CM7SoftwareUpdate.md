# Get-CM7SoftwareUpdate

## SYNOPSIS

Retrieves software update information from Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `Get-CM7SoftwareUpdate` function queries the SMS_SoftwareUpdate WMI class to retrieve software update information from MECM. It provides flexible filtering options including article ID, bulletin ID, name (with wildcard support), severity, deployment status, supersedence status, and category name.

This function is the CIM-based equivalent of the `Get-CMSoftwareUpdate` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Builds a WQL query based on the provided parameters
3. When filtering by category name, first resolves category names to CI_IDs via SMS_CategoryInstance and SMS_CIToCategory
4. Queries the SMS_SoftwareUpdate class via CIM
5. Maps severity integer values to friendly names
6. Returns formatted software update objects with commonly used properties

Key features:
- **Article ID Filtering**: Look up a specific update by its KB article ID
- **Bulletin ID Filtering**: Look up updates by their security bulletin ID (with wildcard support)
- **Name Filtering**: Search by localized display name with wildcard support
- **Severity Filtering**: Filter by severity level (None, Low, Moderate, Important, Critical)
- **Deployment Status**: Filter by whether updates have been deployed
- **Supersedence Status**: Filter by whether updates have been superseded
- **Category Filtering**: Filter by update classification or product category name
- **Fast Mode**: Return limited properties for faster queries on large environments
- **Friendly Names**: Severity is returned as a human-readable string
- **Combinable Filters**: Severity, IsDeployed, and IsSuperseded can be combined with any parameter set

## PARAMETERS

### -ArticleId

Specifies the KB article ID of the software update to retrieve.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByArticleId parameter set)
- **Parameter Set**: ByArticleId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"4038779"`

### -BulletinId

Specifies the security bulletin ID of the software update. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByBulletinId parameter set)
- **Parameter Set**: ByBulletinId
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `"MS17-010"` - Exact match
- `"MS17-*"` - All bulletins starting with "MS17-"

### -Name

Specifies the localized display name of the software update. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByName parameter set)
- **Parameter Set**: ByName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `"Security Update for Windows Server 2019"` - Exact match
- `"*Cumulative*"` - All updates containing "Cumulative"
- `"2024-01*"` - All updates starting with "2024-01"

### -Severity

Specifies the severity level to filter by. Valid values are: None, Low, Moderate, Important, Critical.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: No
- **Parameter Set**: All (can be combined with any parameter set)
- **Accept pipeline input**: False
- **Accept wildcard characters**: No
- **ValidateSet**: None, Low, Moderate, Important, Critical

### -IsDeployed

Filters by deployment status. When `$true`, only returns updates that have been deployed. When `$false`, only returns updates that have not been deployed.

- **Type**: Boolean
- **Position**: Named
- **Default**: None
- **Required**: No
- **Parameter Set**: All (can be combined with any parameter set)
- **Accept pipeline input**: False

### -IsSuperseded

Filters by supersedence status. When `$true`, only returns updates that have been superseded. When `$false`, only returns updates that are not superseded.

- **Type**: Boolean
- **Position**: Named
- **Default**: None
- **Required**: No
- **Parameter Set**: All (can be combined with any parameter set)
- **Accept pipeline input**: False

### -CategoryName

Specifies the update classification or product category name. Supports PowerShell wildcard characters (`*` and `?`).

The function resolves category names through SMS_CategoryInstance and SMS_CIToCategory classes before filtering.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCategoryName parameter set)
- **Parameter Set**: ByCategoryName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `"Security Updates"` - Exact classification match
- `"Critical Updates"` - Critical updates classification
- `"Windows Server*"` - All product categories starting with "Windows Server"

### -Fast

Returns limited properties for faster performance. Only essential properties are returned:
- CI_ID
- ArticleID
- BulletinID
- LocalizedDisplayName
- LocalizedDescription
- Severity
- DatePosted
- DateRevised
- IsDeployed
- IsSuperseded
- NumMissing
- NumPresent
- NumTotal
- PercentCompliant

This is useful when querying large numbers of software updates or when you only need basic information.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

## EXAMPLES

### EXAMPLE 1: Get all software updates

```powershell
Get-CM7SoftwareUpdate
```

Retrieves all software updates from MECM. Note: this may return a large number of results; consider using `-Fast` or applying filters.

### EXAMPLE 2: Get a software update by article ID

```powershell
Get-CM7SoftwareUpdate -ArticleId "4038779"
```

Retrieves the software update(s) matching KB article 4038779.

### EXAMPLE 3: Get software updates by name pattern

```powershell
Get-CM7SoftwareUpdate -Name "*Cumulative Update*"
```

Retrieves all software updates whose names contain "Cumulative Update".

### EXAMPLE 4: Get software updates by bulletin ID

```powershell
Get-CM7SoftwareUpdate -BulletinId "MS17-010"
```

Retrieves software updates associated with security bulletin MS17-010.

### EXAMPLE 5: Get critical software updates

```powershell
Get-CM7SoftwareUpdate -Severity Critical
```

Retrieves all software updates with Critical severity.

### EXAMPLE 6: Get non-superseded, undeployed critical updates

```powershell
Get-CM7SoftwareUpdate -Severity Critical -IsSuperseded $false -IsDeployed $false
```

Retrieves all critical software updates that have not been superseded and have not been deployed yet. Useful for identifying missing deployments.

### EXAMPLE 7: Get software updates with Fast mode

```powershell
Get-CM7SoftwareUpdate -Fast | Where-Object { $_.IsSuperseded -eq $false }
```

Retrieves all software updates with limited properties for faster performance, then filters client-side.

### EXAMPLE 8: Get software updates by category

```powershell
Get-CM7SoftwareUpdate -CategoryName "Security Updates"
```

Retrieves all software updates in the "Security Updates" classification.

### EXAMPLE 9: Export compliance information

```powershell
Get-CM7SoftwareUpdate -Severity Critical -IsSuperseded $false -Fast |
    Select-Object ArticleID, LocalizedDisplayName, NumMissing, NumPresent, PercentCompliant |
    Sort-Object NumMissing -Descending |
    Format-Table -AutoSize
```

Shows a compliance summary of all critical, non-superseded software updates sorted by number of missing clients.

### EXAMPLE 10: Get software updates with verbose output

```powershell
Get-CM7SoftwareUpdate -ArticleId "4038779" -Verbose
```

Retrieves the software update with verbose output showing the WQL queries being executed.

### EXAMPLE 11: Find deployed updates that are superseded

```powershell
Get-CM7SoftwareUpdate -IsDeployed $true -IsSuperseded $true -Fast |
    Select-Object ArticleID, LocalizedDisplayName, DateRevised |
    Sort-Object DateRevised
```

Finds all deployed updates that have been superseded, which may indicate cleanup opportunities.

## OUTPUTS

### PSCustomObject (MECM7.SoftwareUpdate)

The function returns custom objects with the following commonly used properties:

| Property | Type | Description |
|----------|------|-------------|
| CI_ID | int | Unique Configuration Item identifier |
| ArticleID | string | KB article ID (e.g., "4038779") |
| BulletinID | string | Security bulletin ID (e.g., "MS17-010") |
| LocalizedDisplayName | string | Localized display name of the update |
| LocalizedDescription | string | Localized description of the update |
| Severity | string | Severity level (None, Low, Moderate, Important, Critical) |
| DatePosted | datetime | Date the update was posted |
| DateRevised | datetime | Date the update was last revised |
| IsDeployed | bool | Whether the update has been deployed |
| IsSuperseded | bool | Whether the update has been superseded |
| NumMissing | int | Number of clients missing the update |
| NumPresent | int | Number of clients that have the update |
| NumTotal | int | Total number of targeted clients |
| PercentCompliant | int | Compliance percentage |

When not using `-Fast` mode, all properties from the SMS_SoftwareUpdate class are included in the output object.

Example object:

```powershell
PSTypeName           : MECM7.SoftwareUpdate
CI_ID                : 16825678
ArticleID            : 4038779
BulletinID           :
LocalizedDisplayName : 2017-09 Cumulative Update for Windows 10 Version 1703 for x64-based Systems (KB4038779)
LocalizedDescription : A security issue has been identified...
Severity             : Critical
DatePosted           : 2017-09-12 07:00:00
DateRevised          : 2017-09-14 07:00:00
IsDeployed           : True
IsSuperseded         : True
NumMissing           : 0
NumPresent           : 42
NumTotal             : 42
PercentCompliant     : 100
```

## NOTES

### Requirements

- **Connection**: Must have an active connection established via `Connect-CM7`
- **Permissions**: User must have read access to SMS_SoftwareUpdate, SMS_CategoryInstance, and SMS_CIToCategory classes in MECM
- **PowerShell**: Version 5.1 or higher
- **Module**: MECM7 module loaded

### Performance Considerations

1. **Use Fast Mode**: When querying many updates or when you need only basic information, use the `-Fast` switch
2. **Filter Early**: Use parameters to filter results server-side rather than using `Where-Object` on large result sets
3. **Avoid Unfiltered Queries**: `Get-CM7SoftwareUpdate` without filters may return thousands of results. Always apply at least one filter (ArticleId, Name, Severity, IsSuperseded, etc.)
4. **Category Name Lookup**: When filtering by category name, additional CIM queries are made to resolve categories. For best performance, use `-ArticleId` or `-Name` when possible
5. **Combine Filters**: Use `-IsSuperseded $false` with other filters to focus on current updates

### WQL Query Examples

The function translates parameters into WQL queries:

```sql
-- All software updates
SELECT * FROM SMS_SoftwareUpdate

-- By Article ID
SELECT * FROM SMS_SoftwareUpdate WHERE ArticleID = '4038779'

-- By Bulletin ID (exact)
SELECT * FROM SMS_SoftwareUpdate WHERE BulletinID = 'MS17-010'

-- By Bulletin ID (wildcard)
SELECT * FROM SMS_SoftwareUpdate WHERE BulletinID LIKE 'MS17-%'

-- By Name (wildcard)
SELECT * FROM SMS_SoftwareUpdate WHERE LocalizedDisplayName LIKE '%Cumulative%'

-- By Severity (Critical = 10)
SELECT * FROM SMS_SoftwareUpdate WHERE SeverityName = 10

-- Combined filters
SELECT * FROM SMS_SoftwareUpdate WHERE SeverityName = 10 AND IsDeployed = FALSE AND IsSuperseded = FALSE

-- Fast mode
SELECT CI_ID, ArticleID, BulletinID, LocalizedDisplayName, ... FROM SMS_SoftwareUpdate
```

### Severity Values

| Friendly Name | WMI Value |
|---------------|-----------|
| None | 0 |
| Low | 2 |
| Moderate | 6 |
| Important | 8 |
| Critical | 10 |

### Common Scenarios

**Compliance Reporting**: Check compliance for critical updates
```powershell
Get-CM7SoftwareUpdate -Severity Critical -IsSuperseded $false -Fast |
    Where-Object { $_.PercentCompliant -lt 100 } |
    Select-Object ArticleID, LocalizedDisplayName, NumMissing, PercentCompliant |
    Sort-Object NumMissing -Descending
```

**Superseded Update Cleanup**: Find deployed updates that are superseded
```powershell
Get-CM7SoftwareUpdate -IsDeployed $true -IsSuperseded $true -Fast |
    Select-Object ArticleID, LocalizedDisplayName, DateRevised
```

**Missing Updates Report**: Find updates with missing clients
```powershell
Get-CM7SoftwareUpdate -IsSuperseded $false -Fast |
    Where-Object { $_.NumMissing -gt 0 } |
    Sort-Object NumMissing -Descending |
    Format-Table ArticleID, LocalizedDisplayName, NumMissing, PercentCompliant -AutoSize
```

### Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| "Not connected to MECM" | No active connection | Run `Connect-CM7` first |
| "Access denied" | Insufficient permissions | Verify MECM security rights |
| No results returned | No matching updates | Verify article ID or filter criteria |
| No categories found | Category name doesn't match | Verify category name in MECM console |
| Slow query performance | Too many results | Use `-Fast` switch and/or more specific filters |

### Differences from Get-CMSoftwareUpdate

Compared to the ConfigurationManager module's `Get-CMSoftwareUpdate`:

| Feature | Get-CMSoftwareUpdate | Get-CM7SoftwareUpdate |
|---------|----------------------|------------------------|
| Connection | Requires CM drive | Uses CIM/WinRM |
| Console Required | Yes | No |
| Remote Execution | Limited | Full support |
| Wildcard Support | Limited | Full (name, bulletin ID, category) |
| Performance | Moderate | Fast with -Fast switch |
| Output Format | IResultObject | PSCustomObject |
| Severity | Integer or enum | Friendly name strings |
| Category Filtering | Built-in | Via sub-query |
| Additional Filters | DateRevisedMin/Max, OnlyExpired | Via Where-Object post-processing |

## RELATED LINKS

- [Connect-CM7](Connect-CM7.md) - Establish MECM connection
- [Get-CM7SoftwareUpdateDeployment](Get-CM7SoftwareUpdateDeployment.md) - Retrieve software update deployment information
- [Get-CM7Deployment](Get-CM7Deployment.md) - Retrieve general deployment information
- [Get-CM7Device](Get-CM7Device.md) - Retrieve device information
- [Get-CimInstance](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance) - CIM cmdlet used internally
- [SMS_SoftwareUpdate Server WMI Class](https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/sum/sms_softwareupdate-server-wmi-class) - MECM WMI class documentation
- [MECM7 README](../README.md) - Module overview
- [Help Directory](README.md) - All function documentation
