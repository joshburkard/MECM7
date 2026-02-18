# Get-CM7Device

## SYNOPSIS

Retrieves device information from Microsoft Endpoint Configuration Manager (MECM) using CIM.

## DESCRIPTION

The `Get-CM7Device` function queries the SMS_R_System WMI class to retrieve detailed device information from MECM. It provides flexible filtering options including device name (with wildcard support), ResourceID, and collection membership.

This function is the CIM-based equivalent of the `Get-CMDevice` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Builds a WQL query based on the provided parameters
3. Queries the SMS_R_System class via CIM
4. Returns formatted device objects with commonly used properties

Key features:
- **Wildcard Support**: Use `*` and `?` in device names for pattern matching
- **Collection Filtering**: Filter devices by collection membership
- **Fast Mode**: Return limited properties for faster queries on large environments
- **Flexible Querying**: Query by name, ResourceID, or retrieve all devices

## PARAMETERS

### -Name

Specifies the name of the device to retrieve. Supports PowerShell wildcard characters (`*` and `?`).

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: No
- **Parameter Set**: ByName
- **Accept pipeline input**: False
- **Accept wildcard characters**: Yes

Examples:
- `COMPUTER01` - Exact match
- `TEST-*` - All devices starting with "TEST-"
- `*SERVER*` - All devices containing "SERVER"

### -ResourceId

Specifies the ResourceID of the device to retrieve. This is the unique identifier assigned by MECM to each device.

- **Type**: Integer
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByResourceId parameter set)
- **Parameter Set**: ByResourceId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `16777220`

### -CollectionId

Filter devices by Collection ID. Returns only devices that are members of the specified collection.

For large collections (>500 members), the function automatically batches queries to avoid WMI query size limits.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `SMS00001` (All Systems collection)

### -CollectionName

Filter devices by Collection Name. Returns only devices that are members of the specified collection.

For large collections (>500 members), the function automatically batches queries to avoid WMI query size limits.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `All Systems`

### -Fast

Returns limited properties for faster performance. Only essential properties are returned:
- ResourceID
- Name
- LastLogonTimestamp
- LastLogonUserName
- OperatingSystemNameandVersion
- MACAddresses
- IPAddresses

This is useful when querying large numbers of devices or when you only need basic information.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False

## EXAMPLES

### EXAMPLE 1: Get a device by exact name

```powershell
Get-CM7Device -Name "COMPUTER01"
```

Retrieves the device with the exact name "COMPUTER01".

### EXAMPLE 2: Get devices using wildcard pattern

```powershell
Get-CM7Device -Name "TEST-*"
```

Retrieves all devices whose names start with "TEST-". The wildcard `*` matches zero or more characters.

### EXAMPLE 3: Get devices containing a string

```powershell
Get-CM7Device -Name "*SERVER*"
```

Retrieves all devices with "SERVER" anywhere in their name.

### EXAMPLE 4: Get a device by ResourceID

```powershell
Get-CM7Device -ResourceId 16777220
```

Retrieves the device with ResourceID 16777220.

### EXAMPLE 5: Get all devices in a collection

```powershell
Get-CM7Device -CollectionName "All Systems"
```

Retrieves all devices that are members of the "All Systems" collection.

### EXAMPLE 6: Get devices by Collection ID

```powershell
Get-CM7Device -CollectionId "SMS00001"
```

Retrieves all devices in the collection with ID "SMS00001" (typically the "All Systems" collection).

### EXAMPLE 7: Use Fast mode for quick queries

```powershell
Get-CM7Device -Name "TEST-*" -Fast
```

Retrieves all devices starting with "TEST-" but returns only essential properties for faster performance.

### EXAMPLE 8: Get all devices (use with caution)

```powershell
Get-CM7Device
```

Retrieves all devices from MECM. Warning: This can return a large result set in production environments. Consider using `-Fast` switch or filtering by collection.

### EXAMPLE 9: Get device properties

```powershell
$device = Get-CM7Device -Name "COMPUTER01"
Write-Host "Device: $($device.Name)"
Write-Host "ResourceID: $($device.ResourceId)"
Write-Host "OS: $($device.OperatingSystem)"
Write-Host "Last User: $($device.LastLogonUser)"
Write-Host "IP Address: $($device.IPAddresses -join ', ')"
```

Retrieves a device and displays specific properties.

### EXAMPLE 10: Filter and export devices

```powershell
Get-CM7Device -CollectionName "Servers" -Fast |
    Where-Object { $_.OperatingSystem -like "*Server 2019*" } |
    Export-Csv -Path "Server2019Devices.csv" -NoTypeInformation
```

Gets all devices in the "Servers" collection, filters for Windows Server 2019, and exports to CSV.

### EXAMPLE 11: Count devices by operating system

```powershell
Get-CM7Device -Fast |
    Group-Object -Property OperatingSystem |
    Sort-Object Count -Descending |
    Select-Object Name, Count
```

Retrieves all devices in fast mode and groups them by operating system, showing the count for each.

### EXAMPLE 12: Get devices with verbose output

```powershell
Get-CM7Device -Name "TEST-2016-1" -Verbose
```

Retrieves the device with verbose output showing the WQL query being executed.

## OUTPUTS

### PSCustomObject (MECM7.Device)

The function returns custom objects with the following commonly used properties:

| Property | Type | Description |
|----------|------|-------------|
| ResourceId | int | Unique MECM resource identifier |
| Name | string | Device name |
| NetbiosName | string | NetBIOS name of the device |
| OperatingSystem | string | Operating system name and version |
| LastLogonUser | string | Last user who logged on |
| LastLogonTimestamp | datetime | Timestamp of last logon |
| MACAddresses | string[] | Array of MAC addresses |
| IPAddresses | string[] | Array of IP addresses |
| Domain | string | Domain or workgroup |
| Client | int | MECM client installed (0 or 1) |
| ClientVersion | string | MECM client version |
| Active | int | Device is active |
| Obsolete | int | Device is marked obsolete |
| ADSiteName | string | Active Directory site name |
| SiteCode | string | MECM site code |

When not using `-Fast` mode, all properties from the SMS_R_System class are included in the output object.

Example object:

```powershell
PSTypeName               : MECM7.Device
ResourceId               : 16777220
Name                     : COMPUTER01
NetbiosName              : COMPUTER01
OperatingSystem          : Microsoft Windows NT Workstation 10.0
LastLogonUser            : DOMAIN\user01
LastLogonTimestamp       : 2/16/2026 2:30:00 PM
MACAddresses             : {00:15:5D:00:00:01}
IPAddresses              : {192.168.1.100}
Domain                   : DOMAIN
Client                   : 1
ClientVersion            : 5.00.9088.1025
Active                   : 1
Obsolete                 : 0
ADSiteName               : Default-First-Site-Name
SiteCode                 : CM1
```

## NOTES

### Requirements

- **Connection**: Must have an active connection established via `Connect-CM7`
- **Permissions**: User must have read access to SMS_R_System class in MECM
- **PowerShell**: Version 5.1 or higher
- **Module**: MECM7 module loaded

### Performance Considerations

1. **Use Fast Mode**: When querying many devices or when you need only basic information, use the `-Fast` switch
2. **Filter Early**: Use parameters to filter results server-side rather than using `Where-Object` on large result sets
3. **Collection Filtering**: When working with subsets of devices, filter by collection for better performance
4. **Wildcard Patterns**: Be specific with wildcards to reduce result set size
5. **Large Collections**: Collections with more than 500 members are automatically processed in batches to avoid WMI query size limits. This is transparent to the user but may take longer for very large collections.

### WQL Query Examples

The function translates parameters into WQL queries:

```sql
-- By Name (exact)
SELECT * FROM SMS_R_System WHERE Name = 'COMPUTER01'

-- By Name (wildcard)
SELECT * FROM SMS_R_System WHERE Name LIKE 'TEST-%'

-- By ResourceId
SELECT * FROM SMS_R_System WHERE ResourceID = 16777220

-- Fast mode
SELECT ResourceID, Name, LastLogonTimestamp, ... FROM SMS_R_System

-- By Collection (two-step process)
-- Step 1: Get collection members
SELECT ResourceID FROM SMS_FullCollectionMembership WHERE CollectionID = 'SMS00001'
-- Step 2: Get devices
SELECT * FROM SMS_R_System WHERE ResourceID IN (16777220, 16777221, ...)
```

### Common Scenarios

**Inventory Management**: Quickly find devices by name or pattern
```powershell
Get-CM7Device -Name "LAB-*" -Fast
```

**Troubleshooting**: Get detailed device information
```powershell
Get-CM7Device -Name "PROBLEM-PC" | Format-List *
```

**Reporting**: Export device lists for specific collections
```powershell
Get-CM7Device -CollectionName "Workstations" | Export-Csv devices.csv
```

**Property Inspection**: View specific properties
```powershell
(Get-CM7Device -Name "COMPUTER01").IPAddresses
```

### Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| "Not connected to MECM" | No active connection | Run `Connect-CM7` first |
| "Access denied" | Insufficient permissions | Verify MECM security rights |
| No results returned | Device doesn't exist or wrong filter | Verify device name/ID in MECM console |
| "Collection not found" | Invalid collection name | Verify collection name spelling |

### Differences from Get-CMDevice

Compared to the ConfigurationManager module's `Get-CMDevice`:

| Feature | Get-CMDevice | Get-CM7Device |
|---------|--------------|---------------|
| Connection | Requires CM drive | Uses CIM/WinRM |
| Console Required | Yes | No |
| Remote Execution | Limited | Full support |
| Wildcard Support | Yes | Yes |
| Performance | Moderate | Fast with -Fast switch |
| Output Format | CMDevice object | PSCustomObject |

## RELATED LINKS

- [Connect-CM7](Connect-CM7.md) - Establish MECM connection
- [Get-CimInstance](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance) - CIM cmdlet used internally
- [SMS_R_System Server WMI Class](https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/core/clients/manage/sms_r_system-server-wmi-class) - MECM WMI class documentation
- [MECM7 README](../README.md) - Module overview
- [Help Directory](README.md) - All function documentation
