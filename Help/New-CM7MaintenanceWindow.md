# New-CM7MaintenanceWindow

## SYNOPSIS

Creates a new maintenance window on a Microsoft Endpoint Configuration Manager (MECM) collection using CIM.

## DESCRIPTION

The `New-CM7MaintenanceWindow` function creates a new maintenance window (service window) on a specified MECM collection. Maintenance windows define scheduled time periods during which deployments and other operations can be applied to collection members.

This function is the CIM-based equivalent of the `New-CMMaintenanceWindow` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive. It also integrates schedule building (equivalent to `New-CMSchedule`) directly into the function for convenience.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the collection (by name or CollectionID)
3. Builds a schedule token using the `SMS_ScheduleMethods::WriteToString` WMI method
4. Retrieves existing `SMS_CollectionSettings` (or creates new settings if none exist)
5. Creates and appends the `SMS_ServiceWindow` embedded instance
6. Writes the updated settings back via `Set-CimInstance`

Key features:
- **Name or ID Lookup**: Target collection by name or CollectionID
- **Multiple Recurrence Types**: None, Daily, Weekly, MonthlyByWeekday, MonthlyByDate
- **Raw Schedule Token**: Optionally provide a pre-built schedule token for advanced scenarios
- **Type Control**: Create general, software-updates-only, or task-sequences-only windows
- **ShouldProcess Support**: Full `-WhatIf` and `-Confirm` support
- **Lazy Property Handling**: Properly handles lazy properties from `SMS_CollectionSettings`

## PARAMETERS

### -CollectionName

Specifies the name of the collection to add the maintenance window to. Mutually exclusive with `-CollectionId`.

- **Type**: String
- **Position**: 0 (first positional parameter)
- **Default**: None
- **Required**: Yes (for ByCollectionName/ByCollectionNameScheduleToken parameter sets)
- **Parameter Sets**: ByCollectionName, ByCollectionNameScheduleToken
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `Test-Collection-Direct`

### -CollectionId

Specifies the CollectionID of the collection to add the maintenance window to. Mutually exclusive with `-CollectionName`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId/ByCollectionIdScheduleToken parameter sets)
- **Parameter Sets**: ByCollectionId, ByCollectionIdScheduleToken
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `CM101C00`

### -Name

Specifies the name of the maintenance window. This name is displayed in the MECM console.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes
- **Parameter Sets**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `Daily Patch Window`

### -Description

Specifies an optional description for the maintenance window.

- **Type**: String
- **Position**: Named
- **Default**: Empty string
- **Required**: No
- **Parameter Sets**: All
- **Accept pipeline input**: False

### -StartTime

Specifies the start date and time of the maintenance window. For recurring windows, this is the start time of the first occurrence.

- **Type**: DateTime
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionName/ByCollectionId parameter sets)
- **Parameter Sets**: ByCollectionName, ByCollectionId
- **Accept pipeline input**: False

Example: `(Get-Date).AddDays(1).Date.AddHours(22)` (tomorrow at 10 PM)

### -DurationMinutes

Specifies the duration of the maintenance window in minutes. Valid range: 1 to 43,200 (30 days).

- **Type**: Int32
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionName/ByCollectionId parameter sets)
- **Parameter Sets**: ByCollectionName, ByCollectionId
- **Validation**: Range 1-43200
- **Accept pipeline input**: False

Examples:
- `30` - 30 minutes
- `60` - 1 hour
- `120` - 2 hours
- `240` - 4 hours

### -RecurrenceType

Specifies the recurrence type for the maintenance window.

- **Type**: String
- **Position**: Named
- **Default**: `None`
- **Required**: No
- **Parameter Sets**: ByCollectionName, ByCollectionId
- **Valid Values**: `None`, `Daily`, `Weekly`, `MonthlyByWeekday`, `MonthlyByDate`

| Value | Description | Additional Parameters Required |
|-------|-------------|-------------------------------|
| `None` | One-time maintenance window | None |
| `Daily` | Repeats every N days | `-DaySpan` (optional, default 1) |
| `Weekly` | Repeats every N weeks on a specific day | `-DayOfWeek` (required), `-ForNumberOfWeeks` (optional) |
| `MonthlyByWeekday` | Repeats monthly on a specific weekday | `-DayOfWeek` (required), `-WeekOrder` (optional), `-ForNumberOfMonths` (optional) |
| `MonthlyByDate` | Repeats monthly on a specific date | `-MonthDay` (required), `-ForNumberOfMonths` (optional) |

### -DaySpan

Specifies the interval in days for a Daily recurrence. For example, `DaySpan=2` means every other day.

- **Type**: Int32
- **Position**: Named
- **Default**: 1
- **Required**: No
- **Parameter Sets**: ByCollectionName, ByCollectionId
- **Validation**: Range 1-31
- **Used when**: RecurrenceType is `Daily`

### -DayOfWeek

Specifies the day of the week for Weekly and MonthlyByWeekday recurrences.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes when RecurrenceType is `Weekly` or `MonthlyByWeekday`
- **Parameter Sets**: ByCollectionName, ByCollectionId
- **Valid Values**: `Sunday`, `Monday`, `Tuesday`, `Wednesday`, `Thursday`, `Friday`, `Saturday`

### -ForNumberOfWeeks

Specifies the weekly recurrence interval. For example, `ForNumberOfWeeks=2` means every other week.

- **Type**: Int32
- **Position**: Named
- **Default**: 1
- **Required**: No
- **Parameter Sets**: ByCollectionName, ByCollectionId
- **Validation**: Range 1-4
- **Used when**: RecurrenceType is `Weekly`

### -WeekOrder

Specifies which week of the month for MonthlyByWeekday recurrence.

- **Type**: String
- **Position**: Named
- **Default**: `First`
- **Required**: No
- **Parameter Sets**: ByCollectionName, ByCollectionId
- **Valid Values**: `First`, `Second`, `Third`, `Fourth`, `Last`
- **Used when**: RecurrenceType is `MonthlyByWeekday`

### -MonthDay

Specifies the day of the month for MonthlyByDate recurrence. Use `0` for the last day of the month.

- **Type**: Int32
- **Position**: Named
- **Default**: None
- **Required**: Yes when RecurrenceType is `MonthlyByDate`
- **Parameter Sets**: ByCollectionName, ByCollectionId
- **Validation**: Range 0-31

### -ForNumberOfMonths

Specifies the monthly recurrence interval. For example, `ForNumberOfMonths=2` means every other month.

- **Type**: Int32
- **Position**: Named
- **Default**: 1
- **Required**: No
- **Parameter Sets**: ByCollectionName, ByCollectionId
- **Validation**: Range 1-12
- **Used when**: RecurrenceType is `MonthlyByWeekday` or `MonthlyByDate`

### -Schedule

Specifies a raw SMS schedule token string for advanced scenarios. Use this when you have a pre-built schedule token, for example copied from an existing maintenance window's `ServiceWindowSchedules` property. Mutually exclusive with `-StartTime`, `-DurationMinutes`, and `-RecurrenceType`.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionNameScheduleToken/ByCollectionIdScheduleToken parameter sets)
- **Parameter Sets**: ByCollectionNameScheduleToken, ByCollectionIdScheduleToken

### -ApplyTo

Specifies the type of maintenance window, determining which deployments can run during this window.

- **Type**: String
- **Position**: Named
- **Default**: `Any`
- **Required**: No
- **Parameter Sets**: All
- **Valid Values**: `Any`, `SoftwareUpdatesOnly`, `TaskSequencesOnly`

| Value | Description | ServiceWindowType |
|-------|-------------|------------------|
| `Any` | All deployments (general) | 1 |
| `SoftwareUpdatesOnly` | Software updates only | 4 |
| `TaskSequencesOnly` | Task sequences only | 5 |

### -IsEnabled

Specifies whether the maintenance window is enabled. Set to `$false` to create a disabled window.

- **Type**: Boolean
- **Position**: Named
- **Default**: `$true`
- **Required**: No
- **Parameter Sets**: All

### -IsUtc

Specifies that the maintenance window schedule uses UTC time. When not specified, the schedule uses local time.

- **Type**: Switch
- **Position**: Named
- **Default**: `$false`
- **Required**: No
- **Parameter Sets**: All

### -Force

Suppresses confirmation prompts.

- **Type**: Switch
- **Position**: Named
- **Default**: `$false`

### -WhatIf

Shows what would happen if the cmdlet runs. The cmdlet is not run.

### -Confirm

Prompts you for confirmation before running the cmdlet.

## OUTPUTS

### MECM7.MaintenanceWindow

The function returns a PSCustomObject with the following properties:

- **Name** (String): The name of the maintenance window
- **Description** (String): The description of the maintenance window
- **ServiceWindowID** (String): The unique GUID identifier assigned by MECM
- **IsEnabled** (Boolean): Whether the maintenance window is enabled
- **ServiceWindowType** (String): The type of maintenance window (`General`, `SoftwareUpdatesOnly`, `TaskSequencesOnly`)
- **StartTime** (DateTime): The start time of the maintenance window
- **Duration** (Int): The duration of the maintenance window in minutes
- **RecurrenceType** (String): The recurrence schedule type (`None`, `Daily`, `Weekly`, `MonthlyByWeekday`, `MonthlyByDate`)
- **IsGMT** (Boolean): Whether the maintenance window uses UTC/GMT time
- **ServiceWindowSchedules** (String): The raw schedule token string from MECM
- **CollectionID** (String): The CollectionID the maintenance window belongs to

## EXAMPLES

### Example 1: Create a daily maintenance window

```powershell
New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "Daily Patch Window" -StartTime "2026-02-20 22:00" -DurationMinutes 60 -RecurrenceType Daily -Force
```

Creates a daily maintenance window starting at 10 PM, lasting 1 hour, applying to all deployments.

### Example 2: Create a weekly software updates window

```powershell
New-CM7MaintenanceWindow -CollectionId "CM101C00" -Name "Weekly Updates" -StartTime "2026-02-21 02:00" -DurationMinutes 120 -RecurrenceType Weekly -DayOfWeek Saturday -ApplyTo SoftwareUpdatesOnly -Force
```

Creates a weekly maintenance window for software updates only, every Saturday at 2 AM for 2 hours.

### Example 3: Create a monthly-by-weekday maintenance window

```powershell
New-CM7MaintenanceWindow -CollectionName "Servers" -Name "Patch Tuesday" -StartTime "2026-03-01 01:00" -DurationMinutes 240 -RecurrenceType MonthlyByWeekday -DayOfWeek Tuesday -WeekOrder Second -ApplyTo SoftwareUpdatesOnly -Force
```

Creates a monthly maintenance window on the second Tuesday of each month (Patch Tuesday) at 1 AM for 4 hours, applying only to software updates.

### Example 4: Create a monthly-by-date maintenance window

```powershell
New-CM7MaintenanceWindow -CollectionName "Workstations" -Name "Monthly Maintenance" -StartTime "2026-03-15 23:00" -DurationMinutes 180 -RecurrenceType MonthlyByDate -MonthDay 15 -Force
```

Creates a monthly maintenance window on the 15th of each month at 11 PM for 3 hours.

### Example 5: Create a one-time maintenance window

```powershell
New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "Emergency Patch" -StartTime "2026-03-15 23:00" -DurationMinutes 30 -RecurrenceType None -Force
```

Creates a one-time maintenance window on March 15 at 11 PM for 30 minutes.

### Example 6: Create a disabled maintenance window

```powershell
New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "Future Window" -StartTime "2026-04-01 02:00" -DurationMinutes 60 -RecurrenceType Daily -IsEnabled $false -Force
```

Creates a disabled daily maintenance window. It can be enabled later through MECM console or a Set function.

### Example 7: Copy a schedule from an existing maintenance window

```powershell
$existingMW = Get-CM7MaintenanceWindow -CollectionName "Source-Collection" -MaintenanceWindowName "Existing MW"
New-CM7MaintenanceWindow -CollectionName "Target-Collection" -Name "Copied MW" -Schedule $existingMW.ServiceWindowSchedules -Force
```

Copies a maintenance window schedule from one collection to another using the raw schedule token.

### Example 8: Create a UTC maintenance window

```powershell
New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "UTC Window" -StartTime "2026-02-20 22:00" -DurationMinutes 60 -RecurrenceType None -IsUtc -Force
```

Creates a maintenance window using UTC time instead of local time.

### Example 9: Create a task-sequences-only window

```powershell
New-CM7MaintenanceWindow -CollectionName "OSD-Collections" -Name "OSD Window" -StartTime "2026-02-20 20:00" -DurationMinutes 480 -RecurrenceType Daily -ApplyTo TaskSequencesOnly -Force
```

Creates a daily 8-hour maintenance window that only allows task sequence deployments.

### Example 10: Use verbose output for troubleshooting

```powershell
New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "Debug MW" -StartTime "2026-02-20 22:00" -DurationMinutes 60 -RecurrenceType Daily -Force -Verbose
```

Creates a maintenance window with detailed verbose output showing schedule token generation and CIM operations.

## NOTES

### Schedule Token Generation

The function builds SMS schedule tokens using the `SMS_ScheduleMethods::WriteToString` WMI method, which is the same method used internally by MECM. This ensures proper encoding of the schedule information, including start time, duration, and recurrence pattern.

The schedule token classes used are:

| RecurrenceType | SMS Class | Description |
|----------------|-----------|-------------|
| None | `SMS_ST_NonRecurring` | One-time schedule |
| Daily | `SMS_ST_RecurInterval` | Recurring at day intervals |
| Weekly | `SMS_ST_RecurWeekly` | Weekly recurring |
| MonthlyByWeekday | `SMS_ST_RecurMonthlyByWeekday` | Monthly by weekday (e.g., 2nd Tuesday) |
| MonthlyByDate | `SMS_ST_RecurMonthlyByDate` | Monthly by date (e.g., 15th) |

### Maintenance Window Types

MECM supports three types of maintenance windows:

| Type | ApplyTo Value | ServiceWindowType | Description |
|------|---------------|-------------------|-------------|
| **General** | `Any` | 1 | Applies to all deployments |
| **Software Updates** | `SoftwareUpdatesOnly` | 4 | Applies only to software update deployments |
| **Task Sequences** | `TaskSequencesOnly` | 5 | Applies only to task sequence deployments |

### Lazy Properties

The `ServiceWindows` property of `SMS_CollectionSettings` is a lazy property in MECM WMI. The function handles this by performing a secondary retrieval of the full instance using `Get-CimInstance -InputObject` to ensure lazy properties are populated before modification.

### Duplicate Names

MECM allows multiple maintenance windows with the same name on a collection. The function will warn if a duplicate name is detected but will proceed with creation.

### New Collection Settings

If the target collection has no existing `SMS_CollectionSettings`, the function automatically creates a new settings instance before adding the maintenance window.

### Related Functions

- **Get-CM7MaintenanceWindow** - Retrieves existing maintenance windows
- **Get-CM7Collection** - Retrieves collection properties
- **Get-CM7CollectionVariable** - Retrieves collection variables
- **Connect-CM7** - Establishes connection to MECM

### Prerequisites

- PowerShell 5.1 or higher
- WinRM access to the MECM SMS Provider
- An active MECM connection (established via `Connect-CM7`)
- Appropriate MECM administrative permissions (Create/Modify collection settings)

### ConfigurationManager Equivalence

This function combines the equivalent of both `New-CMSchedule` and `New-CMMaintenanceWindow` from the ConfigurationManager module:

```powershell
# ConfigurationManager module (requires ConfigMgr console)
$schedule = New-CMSchedule -Start "2026-02-20 22:00" -DurationInterval Hours -DurationCount 1 -RecurInterval Days -RecurCount 1
New-CMMaintenanceWindow -CollectionId "CM101C00" -Schedule $schedule -Name "Daily MW" -ApplyTo AllDeploymentType

# MECM7 module (requires only WinRM access)
New-CM7MaintenanceWindow -CollectionId "CM101C00" -Name "Daily MW" -StartTime "2026-02-20 22:00" -DurationMinutes 60 -RecurrenceType Daily -Force
```

## SEE ALSO

- [Get-CM7MaintenanceWindow](./Get-CM7MaintenanceWindow.md)
- [Get-CM7Collection](./Get-CM7Collection.md)
- [Get-CM7CollectionVariable](./Get-CM7CollectionVariable.md)
- [Get-CM7CollectionMember](./Get-CM7CollectionMember.md)
- [Connect-CM7](./Connect-CM7.md)
- [Microsoft Endpoint Configuration Manager Documentation](https://docs.microsoft.com/en-us/mem/configmgr/)
