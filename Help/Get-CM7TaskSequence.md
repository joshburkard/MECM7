# Get-CM7TaskSequence

## SYNOPSIS

Retrieves task sequence information from Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `Get-CM7TaskSequence` function queries the SMS_TaskSequencePackage WMI class to retrieve task sequence information from MECM. It provides flexible filtering options including PackageID and task sequence name (with wildcard support).

This function is the CIM-based equivalent of the `Get-CMTaskSequence` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Builds a WQL query based on the provided parameters
3. Queries the SMS_TaskSequencePackage class via CIM
4. Returns formatted task sequence objects with commonly used properties

Key features:
- **Wildcard Support**: Use `*` and `?` in task sequence names for pattern matching
- **PackageID Filtering**: Look up a specific task sequence by its unique PackageID
- **Fast Mode**: Return limited properties for faster queries on large environments
- **Flexible Querying**: Query by PackageID, name, or retrieve all task sequences
- **Full Instance Retrieval**: In non-Fast mode, retrieves all non-lazy properties from SMS_TaskSequencePackage. Lazy properties (Sequence, References, Duration, PackageSize, SourceVersion, etc.) cannot be retrieved over WinRM.

## PARAMETERS

### -TaskSequencePackageId

Specifies the unique PackageID of the task sequence to retrieve. This is the PackageID property (string).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ById parameter set)
- **Parameter Set**: ById
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"ABC00001"`

### -Name

Specifies the name of the task sequence. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByName parameter set)
- **Parameter Set**: ByName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `"Install Windows Server - OS - non-PRD"` - Exact match
- `"Install Windows*"` - All task sequences whose names start with "Install Windows"
- `"*OS*"` - All task sequences containing "OS" in the name

### -Fast

Returns only PackageID and Name for maximum performance. Use this for quick inventory or when you only need identifiers.

In non-Fast mode, all non-lazy properties are returned (50+ properties from SMS_TaskSequencePackage).

Note: Lazy properties (Sequence, References, SupportedOperatingSystems, Duration, PackageSize, SourceVersion, Icon, ISVData, ExtendedData, RefreshSchedule, etc.) cannot be retrieved via WQL over WinRM and are excluded from all queries.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

## EXAMPLES

### EXAMPLE 1: Get all task sequences

```powershell
Get-CM7TaskSequence
```

Retrieves all task sequences from MECM.

### EXAMPLE 2: Get a task sequence by PackageID

```powershell
Get-CM7TaskSequence -TaskSequencePackageId "ABC00001"
```

Retrieves the specific task sequence with the given PackageID.

### EXAMPLE 3: Get task sequences by name

```powershell
Get-CM7TaskSequence -Name "Install Windows Server - OS - non-PRD"
```

Retrieves the task sequence with the specified name.

### EXAMPLE 4: Get task sequences using wildcard name

```powershell
Get-CM7TaskSequence -Name "Install Windows*"
```

Retrieves all task sequences whose names start with "Install Windows".

### EXAMPLE 5: Get task sequences containing a keyword

```powershell
Get-CM7TaskSequence -Name "*OS*"
```

Retrieves all task sequences containing "OS" in the name.

### EXAMPLE 6: Get task sequences with Fast mode

```powershell
Get-CM7TaskSequence -Fast
```

Retrieves all task sequences with limited properties for faster performance.

### EXAMPLE 7: Get task sequence summary information

```powershell
Get-CM7TaskSequence |
    Select-Object PackageID, Name, BootImageID, ProgramFlags, TsEnabled |
    Format-Table -AutoSize
```

Retrieves all task sequences and displays a summary table.

### EXAMPLE 8: Export task sequence information

```powershell
Get-CM7TaskSequence -Fast |
    Export-Csv -Path "TaskSequences.csv" -NoTypeInformation
```

Exports all task sequences with limited properties to a CSV file.

### EXAMPLE 9: Find task sequences with a specific boot image

```powershell
Get-CM7TaskSequence -Fast |
    Where-Object { $_.BootImageID -eq "ABC00002" } |
    Select-Object PackageID, Name, BootImageID |
    Format-Table -AutoSize
```

Finds all task sequences using a specific boot image.

### EXAMPLE 10: Get task sequences with verbose output

```powershell
Get-CM7TaskSequence -Name "Install Windows Server - OS - non-PRD" -Verbose
```

Retrieves task sequences with verbose output showing the WQL queries being executed.

### EXAMPLE 11: List task sequences sorted by last modification

```powershell
Get-CM7TaskSequence -Fast |
    Sort-Object LastRefreshTime -Descending |
    Select-Object PackageID, Name, LastRefreshTime |
    Format-Table -AutoSize
```

Lists all task sequences sorted by their last refresh time.

### EXAMPLE 12: Get detailed task sequence properties

```powershell
$ts = Get-CM7TaskSequence -Name "Install Windows Server - OS - non-PRD"
$ts | Format-List *
```

Retrieves the full instance of a task sequence (including lazy properties) and displays all properties.

## OUTPUTS

### PSCustomObject (MECM7.TaskSequence)

The function returns custom objects with the type name `MECM7.TaskSequence`.

**Fast mode** returns only:

| Property | Type | Description |
|----------|------|-------------|
| PackageID | string | Unique package identifier for the task sequence |
| Name | string | Display name of the task sequence |

**Normal mode** returns all non-lazy properties (50+), including:

| Property | Type | Description |
|----------|------|-------------|
| PackageID | string | Unique package identifier for the task sequence |
| Name | string | Display name of the task sequence |
| Description | string | Description of the task sequence |
| SourceDate | datetime | Date/time the task sequence source was last updated |
| LastRefreshTime | datetime | Date/time the task sequence was last refreshed |
| BootImageID | string | PackageID of the associated boot image |
| SourceSite | string | Source site code |
| ProgramFlags | int | Program flags associated with the task sequence |
| PackageType | int | Package type identifier |
| ObjectPath | string | Console folder path |
| TsEnabled | bool | Whether the task sequence is enabled |
| HighImpactTaskSequence | bool | Whether marked as high-impact |
| TaskSequenceFlags | int | Task sequence specific flags |
| EstimatedRunTimeMinutes | int | Estimated run time in minutes |
| EstimatedDownloadSizeMB | int | Estimated download size in MB |

**Lazy properties NOT available over WinRM** (excluded from all queries):

| Property | Reason |
|----------|--------|
| Sequence | Full task sequence XML — exceeds WS-Management envelope size |
| References | Lazy array of referenced packages |
| SupportedOperatingSystems | Lazy array |
| Duration | Lazy property — causes HRESULT 0x80041001 in WQL SELECT |
| PackageSize | Lazy property — causes HRESULT 0x80041001 in WQL SELECT |
| SourceVersion | Lazy property — causes HRESULT 0x80041001 in WQL SELECT |
| Icon / ISVData / ExtendedData | Lazy binary properties |

Example object (normal mode):

```powershell
PSTypeName      : MECM7.TaskSequence
PackageID       : SD100D27
Name            : Install Windows Server - OS - non-PRD
Description     :
BootImageID     :
SourceDate      :
LastRefreshTime :
SourceSite      :
ProgramFlags    :
PackageType     :
ObjectPath      :
TsEnabled       :
HighImpactTaskSequence :
```

## NOTES

### Requirements

- **Connection**: Must have an active connection established via `Connect-CM7`
- **Permissions**: User must have read access to SMS_TaskSequencePackage class in MECM
- **PowerShell**: Version 5.1 or higher
- **Module**: MECM7 module loaded

### Performance Considerations

1. **Use Fast Mode**: When you only need PackageID and Name, use the `-Fast` switch for fastest performance.
2. **Filter Early**: Use parameters to filter results server-side rather than using `Where-Object` on large result sets
3. **Use PackageID**: When you know the exact PackageID, use `-TaskSequencePackageId` for the most efficient query
4. **Wildcard Patterns**: Be specific with wildcards to reduce result set size
5. **Lazy Property Limitation**: Properties like `Duration`, `PackageSize`, `SourceVersion`, `Sequence`, and `References` are lazy in the SMS Provider and cannot be retrieved via WQL over WinRM. Use the native `Get-CMTaskSequence` cmdlet if you need these properties.

### WQL Query Examples

The function builds WQL queries internally. Here are examples of the generated queries:

```sql
-- Get all task sequences (non-Fast, explicit non-lazy columns)
SELECT PackageID, Name, Description, BootImageID, SourceDate, LastRefreshTime, ... FROM SMS_TaskSequencePackage

-- Get by PackageID
SELECT PackageID, Name, Description, ... FROM SMS_TaskSequencePackage WHERE PackageID = 'SD100D27'

-- Get by exact name
SELECT PackageID, Name, Description, ... FROM SMS_TaskSequencePackage WHERE Name = 'Install Windows Server - OS - non-PRD'

-- Get by wildcard name
SELECT PackageID, Name, Description, ... FROM SMS_TaskSequencePackage WHERE Name LIKE 'Install Windows%'

-- Fast mode (minimal properties)
SELECT PackageID, Name FROM SMS_TaskSequencePackage
```

> **Important**: `SELECT *` is never safe on SMS_TaskSequencePackage over WinRM — the Sequence XML property exceeds WS-Management envelope size limits. This function always uses explicit column lists.

### SMS_TaskSequencePackage WMI Class

The SMS_TaskSequencePackage class represents task sequence packages in MECM. Key characteristics:

- **Lazy Properties**: Many properties (e.g., `Sequence`, `References`, `Duration`, `PackageSize`, `SourceVersion`) are lazy and cannot be retrieved via WQL SELECT over WinRM. They cause HRESULT 0x80041001 or exceed WS-Management envelope size limits.
- **PackageID**: The unique identifier assigned to each task sequence package
- **BootImageID**: References the boot image used during OS deployment
- **SELECT * Not Safe**: Never use `SELECT *` on this class over WinRM — use explicit non-lazy column lists
- **Sequence**: XML content that defines all task sequence steps — too large for WinRM even for a single instance

### Common Scenarios

| Scenario | Command |
|----------|---------|
| List all task sequences | `Get-CM7TaskSequence` |
| Find task sequence by name | `Get-CM7TaskSequence -Name "TaskSequenceName"` |
| Find task sequences by pattern | `Get-CM7TaskSequence -Name "*Windows*"` |
| Find by PackageID | `Get-CM7TaskSequence -TaskSequencePackageId "ABC00001"` |
| List with boot image info | `Get-CM7TaskSequence -Fast \| Select-Object Name, BootImageID` |
| Quick inventory | `Get-CM7TaskSequence -Fast` |

### Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| "Not connected to MECM" | No active CIM connection | Run `Connect-CM7` first |
| Empty result | No matching task sequences found | Verify the name or PackageID is correct |
| Access denied | Insufficient permissions | Ensure MECM read access to SMS_TaskSequencePackage |

### Comparison with Native Cmdlet

| Feature | Get-CMTaskSequence | Get-CM7TaskSequence |
|---------|--------------------|---------------------|
| Requires ConfigMgr Console | Yes | No |
| Connection Method | PSDrive | CIM/WinRM |
| PowerShell 7 Support | Limited | Full |
| Remote Management | Local only | Remote via WinRM |
| Wildcard Support | Yes | Yes |
| Fast Mode | Yes | Yes |
| Lazy Properties | Yes (local COM) | No (WinRM limitation) |
| Returns | SMS objects | PSCustomObject |

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md)
- [Get-CM7Deployment](./Get-CM7Deployment.md)
- [Get-CM7Device](./Get-CM7Device.md)
- [Get-CM7DeviceCollection](./Get-CM7DeviceCollection.md)
- [SMS_TaskSequencePackage WMI Class](https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/osd/sms_tasksequencepackage-server-wmi-class)
