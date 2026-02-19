# Get-CM7SoftwareUpdateDeploymentPackage

## SYNOPSIS

Retrieves software update deployment package information from Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `Get-CM7SoftwareUpdateDeploymentPackage` function queries the SMS_SoftwareUpdatePackage WMI class to retrieve software update deployment package information from MECM. It provides flexible filtering options including package ID and package name (with wildcard support).

This function is the CIM-based equivalent of the `Get-CMSoftwareUpdateDeploymentPackage` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Builds a WQL query based on the provided parameters
3. Queries the SMS_SoftwareUpdatePackage class via CIM
4. Maps priority and source flag integer values to friendly names
5. Returns formatted software update deployment package objects with commonly used properties

Key features:
- **Wildcard Support**: Use `*` and `?` in package names for pattern matching
- **Package ID Filtering**: Look up a specific deployment package by its unique PackageID
- **Fast Mode**: Return limited properties for faster queries on large environments
- **Friendly Names**: Priority and source flag are returned as human-readable strings
- **Flexible Querying**: Query by package ID, package name, or retrieve all deployment packages

## PARAMETERS

### -Id

Specifies the unique package ID of the software update deployment package to retrieve. This is the PackageID property (e.g., "ABC00001").

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ById parameter set)
- **Parameter Set**: ById
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"ABC00001"`

### -Name

Specifies the name of the software update deployment package. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByName parameter set)
- **Parameter Set**: ByName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `"My-SecurityPatches-2024-01"` - Exact match
- `"My-Security*"` - All packages whose names start with "My-Security"
- `"*Patches*"` - All packages containing "Patches" in the name

### -Fast

Returns limited properties for faster performance. Only essential properties are returned:
- PackageID
- Name
- Description
- SourceSite
- PkgSourcePath
- PackageSize
- SourceVersion
- StoredPkgVersion
- LastRefreshTime
- Priority
- PkgSourceFlag
- ImagePath

This is useful when querying large numbers of software update deployment packages or when you only need basic information.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

## EXAMPLES

### EXAMPLE 1: Get all software update deployment packages

```powershell
Get-CM7SoftwareUpdateDeploymentPackage
```

Retrieves all software update deployment packages from MECM.

### EXAMPLE 2: Get a software update deployment package by ID

```powershell
Get-CM7SoftwareUpdateDeploymentPackage -Id "ABC00001"
```

Retrieves the specific software update deployment package with the given package ID.

### EXAMPLE 3: Get software update deployment packages by name

```powershell
Get-CM7SoftwareUpdateDeploymentPackage -Name "My-SecurityPatches-2024-01"
```

Retrieves the software update deployment package with the specified name.

### EXAMPLE 4: Get software update deployment packages using wildcard name

```powershell
Get-CM7SoftwareUpdateDeploymentPackage -Name "My-Security*"
```

Retrieves all software update deployment packages whose names start with "My-Security".

### EXAMPLE 5: Get software update deployment packages containing a keyword

```powershell
Get-CM7SoftwareUpdateDeploymentPackage -Name "*SecurityPatches*"
```

Retrieves all software update deployment packages containing "SecurityPatches" in the name.

### EXAMPLE 6: Get software update deployment packages with Fast mode

```powershell
Get-CM7SoftwareUpdateDeploymentPackage -Fast
```

Retrieves all software update deployment packages with limited properties for faster performance.

### EXAMPLE 7: Get software update deployment package summary information

```powershell
Get-CM7SoftwareUpdateDeploymentPackage |
    Select-Object PackageID, Name, PackageSize, Priority, LastRefreshTime |
    Format-Table -AutoSize
```

Retrieves all software update deployment packages and displays a summary table.

### EXAMPLE 8: Export software update deployment package information

```powershell
Get-CM7SoftwareUpdateDeploymentPackage -Fast |
    Export-Csv -Path "SoftwareUpdateDeploymentPackages.csv" -NoTypeInformation
```

Exports all software update deployment packages with limited properties to a CSV file.

### EXAMPLE 9: Find large software update deployment packages

```powershell
Get-CM7SoftwareUpdateDeploymentPackage -Fast |
    Sort-Object PackageSize -Descending |
    Select-Object PackageID, Name, @{Name='SizeGB'; Expression={[math]::Round($_.PackageSize / 1KB, 2)}} |
    Format-Table -AutoSize
```

Finds all software update deployment packages sorted by size (largest first).

### EXAMPLE 10: Get software update deployment packages with verbose output

```powershell
Get-CM7SoftwareUpdateDeploymentPackage -Name "My-SecurityPatches-2024-01" -Verbose
```

Retrieves software update deployment packages with verbose output showing the WQL queries being executed.

### EXAMPLE 11: Find packages by source path pattern

```powershell
Get-CM7SoftwareUpdateDeploymentPackage |
    Where-Object { $_.PkgSourcePath -like '*SecurityPatches*' } |
    Select-Object PackageID, Name, PkgSourcePath
```

Finds all software update deployment packages whose source path contains "SecurityPatches".

## OUTPUTS

### PSCustomObject (MECM7.SoftwareUpdateDeploymentPackage)

The function returns custom objects with the following commonly used properties:

| Property | Type | Description |
|----------|------|-------------|
| PackageID | string | Unique package identifier (e.g., "ABC00001") |
| Name | string | Name of the software update deployment package |
| Description | string | Description of the package |
| SourceSite | string | Source site code |
| PkgSourcePath | string | UNC path to the package source |
| PackageSize | long | Size of the package in kilobytes |
| SourceVersion | int | Source content version number |
| StoredPkgVersion | int | Stored package version number |
| LastRefreshTime | datetime | Date/time the package was last refreshed |
| Priority | string | Distribution priority (High, Normal, Low) |
| PkgSourceFlag | string | Package source type (StorageDirect, StorageCompressed, StorageNoPackage) |
| ImagePath | string | Image path of the package |

When not using `-Fast` mode, all properties from the SMS_SoftwareUpdatePackage class are included in the output object.

Example object:

```powershell
PSTypeName         : MECM7.SoftwareUpdateDeploymentPackage
PackageID          : ABC00001
Name               : My-SecurityPatches-2024-01
Description        : Security patches for servers - January 2024
SourceSite         : CM1
PkgSourcePath      : \\server\share\Updates\SecurityPatches\2024-01
PackageSize        : 1048576
SourceVersion      : 15
StoredPkgVersion   : 15
LastRefreshTime    : 2024-01-15 10:30:00
Priority           : Normal
PkgSourceFlag      : StorageDirect
ImagePath          : \\server\share\Updates\SecurityPatches\2024-01
```

## NOTES

### Requirements

- **Connection**: Must have an active connection established via `Connect-CM7`
- **Permissions**: User must have read access to SMS_SoftwareUpdatePackage class in MECM
- **PowerShell**: Version 5.1 or higher
- **Module**: MECM7 module loaded

### Performance Considerations

1. **Use Fast Mode**: When querying many deployment packages or when you need only basic information, use the `-Fast` switch
2. **Filter Early**: Use parameters to filter results server-side rather than using `Where-Object` on large result sets
3. **Use Package ID**: When you know the exact package ID, use `-Id` for the most efficient query
4. **Wildcard Patterns**: Be specific with wildcards to reduce result set size

### WQL Query Examples

The function translates parameters into WQL queries:

```sql
-- All software update deployment packages
SELECT * FROM SMS_SoftwareUpdatePackage

-- By Package ID
SELECT * FROM SMS_SoftwareUpdatePackage WHERE PackageID = 'ABC00001'

-- By Name (exact)
SELECT * FROM SMS_SoftwareUpdatePackage WHERE Name = 'My-SecurityPatches-2024-01'

-- By Name (wildcard)
SELECT * FROM SMS_SoftwareUpdatePackage WHERE Name LIKE 'My-Security%'

-- Fast mode
SELECT PackageID, Name, Description, SourceSite, PkgSourcePath, PackageSize, ... FROM SMS_SoftwareUpdatePackage
```

### Priority Values

| Friendly Name | WMI Value |
|---------------|-----------|
| High | 1 |
| Normal | 2 |
| Low | 3 |

### PkgSourceFlag Values

| Friendly Name | WMI Value |
|---------------|-----------|
| StorageDirect | 1 |
| StorageCompressed | 2 |
| StorageNoPackage | 3 |

### Common Scenarios

**Package Inventory**: List all software update deployment packages with their sizes
```powershell
Get-CM7SoftwareUpdateDeploymentPackage -Fast |
    Select-Object PackageID, Name, @{Name='SizeGB'; Expression={[math]::Round($_.PackageSize / 1KB, 2)}}, Priority |
    Format-Table -AutoSize
```

**Package Monitoring**: Check when packages were last refreshed
```powershell
Get-CM7SoftwareUpdateDeploymentPackage -Fast |
    Select-Object PackageID, Name, LastRefreshTime |
    Sort-Object LastRefreshTime -Descending
```

**Source Path Audit**: Verify package source paths
```powershell
Get-CM7SoftwareUpdateDeploymentPackage |
    Select-Object PackageID, Name, PkgSourcePath, PkgSourceFlag |
    Format-Table -AutoSize
```

### Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| "Not connected to MECM" | No active connection | Run `Connect-CM7` first |
| "Access denied" | Insufficient permissions | Verify MECM security rights |
| No results returned | No matching packages | Verify package exists in MECM console |
| Slow query performance | Too many results | Use `-Fast` switch and/or more specific filters |

### Differences from Get-CMSoftwareUpdateDeploymentPackage

Compared to the ConfigurationManager module's `Get-CMSoftwareUpdateDeploymentPackage`:

| Feature | Get-CMSoftwareUpdateDeploymentPackage | Get-CM7SoftwareUpdateDeploymentPackage |
|---------|---------------------------------------|---------------------------------------|
| Connection | Requires CM drive | Uses CIM/WinRM |
| Console Required | Yes | No |
| Remote Execution | Limited | Full support |
| Wildcard Support | Limited | Full (name) |
| Performance | Moderate | Fast with -Fast switch |
| Output Format | IResultObject | PSCustomObject |
| Priority | Integer values | Friendly name strings |
| Source Flag | Integer values | Friendly name strings |

## RELATED LINKS

- [Connect-CM7](Connect-CM7.md) - Establish MECM connection
- [Get-CM7SoftwareUpdate](Get-CM7SoftwareUpdate.md) - Retrieve software update information
- [Get-CM7SoftwareUpdateDeployment](Get-CM7SoftwareUpdateDeployment.md) - Retrieve software update deployment information
- [Get-CM7Deployment](Get-CM7Deployment.md) - Retrieve general deployment information
- [Get-CimInstance](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance) - CIM cmdlet used internally
- [SMS_SoftwareUpdatePackage Server WMI Class](https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/sum/sms_softwareupdatepackage-server-wmi-class) - MECM WMI class documentation
- [MECM7 README](../README.md) - Module overview
- [Help Directory](README.md) - All function documentation
