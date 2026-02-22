# Get-CM7SoftwareUpdateGroup

## SYNOPSIS

Retrieves software update group information from Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `Get-CM7SoftwareUpdateGroup` function queries the SMS_AuthorizationList WMI class to retrieve software update group information from MECM. It provides flexible filtering options including CI_ID and group name (with wildcard support).

This function is the CIM-based equivalent of the `Get-CMSoftwareUpdateGroup` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Builds a WQL query based on the provided parameters
3. Queries the SMS_AuthorizationList class via CIM
4. Returns formatted software update group objects with commonly used properties

Key features:
- **Wildcard Support**: Use `*` and `?` in group names for pattern matching
- **CI_ID Filtering**: Look up a specific software update group by its unique CI_ID
- **Fast Mode**: Return limited properties for faster queries on large environments
- **Flexible Querying**: Query by CI_ID, group name, or retrieve all software update groups
- **Full Instance Retrieval**: In non-Fast mode, retrieves full instances including lazy properties (e.g., Updates array)

## PARAMETERS

### -Id

Specifies the unique CI_ID of the software update group to retrieve. This is the CI_ID property (integer).

- **Type**: Int32
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ById parameter set)
- **Parameter Set**: ById
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `12345`

### -Name

Specifies the name (LocalizedDisplayName) of the software update group. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByName parameter set)
- **Parameter Set**: ByName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `"Servers-SecurityPatches"` - Exact match
- `"Servers*"` - All groups whose names start with "Test-SUG"
- `"*SecurityPatches*"` - All groups containing "SecurityPatches" in the name

### -Fast

Returns limited properties for faster performance. Only essential properties are returned:
- CI_ID
- CI_UniqueID
- LocalizedDisplayName
- LocalizedDescription
- IsDeployed
- IsExpired
- IsSuperseded
- NumberOfUpdates
- DateCreated
- DateLastModified
- LocalizedCategoryInstanceNames

This is useful when querying large numbers of software update groups or when you only need basic information. Note: In Fast mode, lazy properties such as the `Updates` array are not retrieved.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

## EXAMPLES

### EXAMPLE 1: Get all software update groups

```powershell
Get-CM7SoftwareUpdateGroup
```

Retrieves all software update groups from MECM.

### EXAMPLE 2: Get a software update group by CI_ID

```powershell
Get-CM7SoftwareUpdateGroup -Id 12345
```

Retrieves the specific software update group with the given CI_ID.

### EXAMPLE 3: Get software update groups by name

```powershell
Get-CM7SoftwareUpdateGroup -Name "Test-SUG"
```

Retrieves the software update group with the specified name.

### EXAMPLE 4: Get software update groups using wildcard name

```powershell
Get-CM7SoftwareUpdateGroup -Name "Test-SUG*"
```

Retrieves all software update groups whose names start with "Test-SUG".

### EXAMPLE 5: Get software update groups containing a keyword

```powershell
Get-CM7SoftwareUpdateGroup -Name "*SecurityPatches*"
```

Retrieves all software update groups containing "SecurityPatches" in the name.

### EXAMPLE 6: Get software update groups with Fast mode

```powershell
Get-CM7SoftwareUpdateGroup -Fast
```

Retrieves all software update groups with limited properties for faster performance.

### EXAMPLE 7: Get software update group summary information

```powershell
Get-CM7SoftwareUpdateGroup |
    Select-Object CI_ID, LocalizedDisplayName, NumberOfUpdates, IsDeployed, DateLastModified |
    Format-Table -AutoSize
```

Retrieves all software update groups and displays a summary table.

### EXAMPLE 8: Export software update group information

```powershell
Get-CM7SoftwareUpdateGroup -Fast |
    Export-Csv -Path "SoftwareUpdateGroups.csv" -NoTypeInformation
```

Exports all software update groups with limited properties to a CSV file.

### EXAMPLE 9: Find deployed software update groups

```powershell
Get-CM7SoftwareUpdateGroup -Fast |
    Where-Object { $_.IsDeployed -eq $true } |
    Select-Object CI_ID, LocalizedDisplayName, NumberOfUpdates, DateLastModified |
    Format-Table -AutoSize
```

Finds all software update groups that are currently deployed.

### EXAMPLE 10: Get software update groups with verbose output

```powershell
Get-CM7SoftwareUpdateGroup -Name "Test-SUG" -Verbose
```

Retrieves software update groups with verbose output showing the WQL queries being executed.

### EXAMPLE 11: Find software update groups with superseded updates

```powershell
Get-CM7SoftwareUpdateGroup -Fast |
    Where-Object { $_.IsSuperseded -eq $true } |
    Select-Object CI_ID, LocalizedDisplayName, NumberOfUpdates
```

Finds all software update groups that contain superseded updates.

### EXAMPLE 12: Get the list of update CI_IDs in a software update group

```powershell
$group = Get-CM7SoftwareUpdateGroup -Name "Test-SUG"
$group.Updates
```

Retrieves the full instance of a software update group (including lazy properties) and lists all update CI_IDs contained in it.

## OUTPUTS

### PSCustomObject (MECM7.SoftwareUpdateGroup)

The function returns custom objects with the following commonly used properties:

| Property | Type | Description |
|----------|------|-------------|
| CI_ID | int | Unique configuration item identifier |
| CI_UniqueID | string | Globally unique identifier for the configuration item |
| LocalizedDisplayName | string | Display name of the software update group |
| LocalizedDescription | string | Description of the software update group |
| IsDeployed | bool | Whether the group is currently deployed |
| IsExpired | bool | Whether the group contains expired updates |
| IsSuperseded | bool | Whether the group contains superseded updates |
| NumberOfUpdates | int | Number of software updates in the group |
| DateCreated | datetime | Date/time the group was created |
| DateLastModified | datetime | Date/time the group was last modified |
| LocalizedCategoryInstanceNames | string[] | Category names associated with the group |

When not using `-Fast` mode, all properties from the SMS_AuthorizationList class are included in the output object, including lazy properties such as:

| Property | Type | Description |
|----------|------|-------------|
| Updates | int[] | Array of CI_IDs of the software updates in the group |
| LocalizedInformation | object | Localized information about the group |

Example object:

```powershell
PSTypeName                      : MECM7.SoftwareUpdateGroup
CI_ID                           : 12345
CI_UniqueID                     : ScopeId_XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/AuthList_XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
LocalizedDisplayName            : Test-SUG
LocalizedDescription            : Security patches for servers - January 2024
IsDeployed                      : True
IsExpired                       : False
IsSuperseded                    : False
NumberOfUpdates                 : 42
DateCreated                     : 2024-01-15 10:30:00
DateLastModified                : 2024-01-20 14:15:00
LocalizedCategoryInstanceNames  : {Software Updates}
```

## NOTES

### Requirements

- **Connection**: Must have an active connection established via `Connect-CM7`
- **Permissions**: User must have read access to SMS_AuthorizationList class in MECM
- **PowerShell**: Version 5.1 or higher
- **Module**: MECM7 module loaded

### Performance Considerations

1. **Use Fast Mode**: When querying many software update groups or when you need only basic information, use the `-Fast` switch. This avoids retrieving lazy properties which require additional round-trips.
2. **Filter Early**: Use parameters to filter results server-side rather than using `Where-Object` on large result sets
3. **Use CI_ID**: When you know the exact CI_ID, use `-Id` for the most efficient query
4. **Wildcard Patterns**: Be specific with wildcards to reduce result set size

### WQL Query Examples

The function builds WQL queries internally. Here are examples of the generated queries:

```sql
-- Get all software update groups
SELECT * FROM SMS_AuthorizationList

-- Get by CI_ID
SELECT * FROM SMS_AuthorizationList WHERE CI_ID = 12345

-- Get by exact name
SELECT * FROM SMS_AuthorizationList WHERE LocalizedDisplayName = 'Test-SUG'

-- Get by wildcard name
SELECT * FROM SMS_AuthorizationList WHERE LocalizedDisplayName LIKE '%SUG%'

-- Fast mode (limited properties)
SELECT CI_ID, CI_UniqueID, LocalizedDisplayName, LocalizedDescription, IsDeployed, IsExpired, IsSuperseded, NumberOfUpdates, DateCreated, DateLastModified, LocalizedCategoryInstanceNames FROM SMS_AuthorizationList
```

### SMS_AuthorizationList WMI Class

The SMS_AuthorizationList class represents software update groups (also known as authorization lists) in MECM. Key characteristics:

- **Lazy Properties**: Some properties (e.g., `Updates`, `LocalizedInformation`) are lazy and only loaded when the full instance is retrieved. The `-Fast` switch does not retrieve these properties.
- **NumberOfUpdates**: Reflects the count of updates currently in the group
- **IsDeployed**: Indicates whether the group has active deployments
- **IsExpired/IsSuperseded**: Indicate the compliance state of the contained updates

### Common Scenarios

| Scenario | Command |
|----------|---------|
| List all groups | `Get-CM7SoftwareUpdateGroup` |
| Find group by name | `Get-CM7SoftwareUpdateGroup -Name "GroupName"` |
| Find groups by pattern | `Get-CM7SoftwareUpdateGroup -Name "*2024*"` |
| List deployed groups | `Get-CM7SoftwareUpdateGroup -Fast \| Where-Object IsDeployed` |
| Get update list from group | `(Get-CM7SoftwareUpdateGroup -Name "GroupName").Updates` |
| Quick inventory | `Get-CM7SoftwareUpdateGroup -Fast` |

### Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| "Not connected to MECM" | No active CIM connection | Run `Connect-CM7` first |
| Empty result | No matching groups found | Verify the name or CI_ID is correct |
| Access denied | Insufficient permissions | Ensure MECM read access to SMS_AuthorizationList |

### Comparison with Native Cmdlet

| Feature | Get-CMSoftwareUpdateGroup | Get-CM7SoftwareUpdateGroup |
|---------|--------------------------|---------------------------|
| Requires ConfigMgr Console | Yes | No |
| Connection Method | PSDrive | CIM/WinRM |
| PowerShell 7 Support | Limited | Full |
| Remote Management | Local only | Remote via WinRM |
| Wildcard Support | Yes | Yes |
| Fast Mode | Yes | Yes |
| Returns | SMS objects | PSCustomObject |

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md)
- [Get-CM7SoftwareUpdate](./Get-CM7SoftwareUpdate.md)
- [Get-CM7SoftwareUpdateDeployment](./Get-CM7SoftwareUpdateDeployment.md)
- [Get-CM7SoftwareUpdateDeploymentPackage](./Get-CM7SoftwareUpdateDeploymentPackage.md)
- [SMS_AuthorizationList WMI Class](https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/sum/sms_authorizationlist-server-wmi-class)
