# New-CM7Schedule

## SYNOPSIS

Creates an SMS schedule token for use with MECM CIM-based functions.

## DESCRIPTION

Creates an SMS schedule token that can be used with other MECM7 functions such as `New-CM7Collection`, `New-CM7MaintenanceWindow`, and `Set-CM7Collection`.

This is the CIM-based equivalent of the `New-CMSchedule` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function uses the **same parameters and behaviour as `New-CMSchedule`**:

| Parameter Set | Required Parameters | SMS Class | Description |
|---------------|-------------------|-----------|-------------|
| RecurrenceNone (default) | `-Nonrecurring` (optional) | SMS_ST_NonRecurring | One-time schedule, no recurrence |
| RecurrenceInterval | `-RecurInterval`, `-RecurCount` | SMS_ST_RecurInterval | Fixed interval (days, hours, or minutes) |
| RecurrenceWeekly | `-DayOfWeek` | SMS_ST_RecurWeekly | Weekly on a specific day |
| RecurMonthlyByWeekday | `-DayOfWeek`, `-WeekOrder` | SMS_ST_RecurMonthlyByWeekday | Monthly on a specific weekday (e.g., second Tuesday) |
| RecurrenceMonthlyByDate | `-DayOfMonth` | SMS_ST_RecurMonthlyByDate | Monthly on a specific date (e.g., the 15th) |
| RecurMonthlyLastDayOfMonth | `-LastDayOfMonth` | SMS_ST_RecurMonthlyByDate | Monthly on the last day |

Duration can be specified using `-DurationInterval`/`-DurationCount` or `-End`.

By default the function returns a CIM instance. Use the `-ScheduleString` switch to return the schedule as a hex-encoded token string instead.

## SYNTAX

### RecurrenceNone (Default)

```powershell
New-CM7Schedule [-Nonrecurring] [-Start <DateTime>] [-IsUtc] [-ScheduleString]
    [-DurationInterval <String>] [-DurationCount <Int32>] [-End <DateTime>]
```

### RecurrenceInterval

```powershell
New-CM7Schedule -RecurInterval <String> -RecurCount <Int32> [-Start <DateTime>] [-IsUtc]
    [-ScheduleString] [-DurationInterval <String>] [-DurationCount <Int32>] [-End <DateTime>]
```

### RecurrenceWeekly

```powershell
New-CM7Schedule -DayOfWeek <String> [-RecurCount <Int32>] [-Start <DateTime>] [-IsUtc]
    [-ScheduleString] [-DurationInterval <String>] [-DurationCount <Int32>] [-End <DateTime>]
```

### RecurMonthlyByWeekday

```powershell
New-CM7Schedule -DayOfWeek <String> -WeekOrder <String> [-RecurCount <Int32>] [-OffsetDay <Int32>]
    [-Start <DateTime>] [-IsUtc] [-ScheduleString] [-DurationInterval <String>]
    [-DurationCount <Int32>] [-End <DateTime>]
```

### RecurrenceMonthlyByDate

```powershell
New-CM7Schedule -DayOfMonth <Int32> [-RecurCount <Int32>] [-Start <DateTime>] [-IsUtc]
    [-ScheduleString] [-DurationInterval <String>] [-DurationCount <Int32>] [-End <DateTime>]
```

### RecurMonthlyLastDayOfMonth

```powershell
New-CM7Schedule -LastDayOfMonth [-RecurCount <Int32>] [-Start <DateTime>] [-IsUtc]
    [-ScheduleString] [-DurationInterval <String>] [-DurationCount <Int32>] [-End <DateTime>]
```

## PARAMETERS

### -Nonrecurring

Indicates that the schedule does not recur. This creates an `SMS_ST_NonRecurring` schedule token. This is the default behaviour when no recurrence parameters are specified.

- **Type**: SwitchParameter
- **Required**: No
- **ParameterSet**: RecurrenceNone

### -RecurInterval

Specifies the unit of time for the interval-based recurrence. Used together with `-RecurCount`.

- **Type**: String
- **Required**: Yes (in RecurrenceInterval set)
- **ValidateSet**: Minutes, Hours, Days
- **ParameterSet**: RecurrenceInterval

### -RecurCount

Specifies the number of recurrence intervals. The meaning depends on the parameter set:

| Parameter Set | Meaning | Required | Default |
|---------------|---------|----------|---------|
| RecurrenceInterval | Number of minutes, hours, or days between occurrences | Yes | — |
| RecurrenceWeekly | Number of weeks between occurrences | No | 1 |
| RecurMonthlyByWeekday | Number of months between occurrences | No | 1 |
| RecurrenceMonthlyByDate | Number of months between occurrences | No | 1 |
| RecurMonthlyLastDayOfMonth | Number of months between occurrences | No | 1 |

- **Type**: Int32
- **ValidateRange**: 1 to 31

### -DayOfWeek

The day of the week for weekly or monthly-by-weekday schedules. When used without `-WeekOrder`, creates a weekly schedule. When used with `-WeekOrder`, creates a monthly-by-weekday schedule.

- **Type**: String
- **Required**: Yes (in RecurrenceWeekly and RecurMonthlyByWeekday sets)
- **ValidateSet**: Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday

### -WeekOrder

Specifies which week of the month for monthly-by-weekday schedules. Requires `-DayOfWeek`.

- **Type**: String
- **Required**: Yes (in RecurMonthlyByWeekday set)
- **ValidateSet**: First, Second, Third, Fourth, Last

### -OffsetDay

Specifies an offset in days for monthly-by-weekday schedules. Only used with `-DayOfWeek` and `-WeekOrder`.

- **Type**: Int32
- **Required**: No
- **Default**: 0
- **ValidateRange**: 0 to 7
- **ParameterSet**: RecurMonthlyByWeekday

### -DayOfMonth

The day of the month for monthly-by-date schedules.

- **Type**: Int32
- **Required**: Yes (in RecurrenceMonthlyByDate set)
- **ValidateRange**: 1 to 31
- **ParameterSet**: RecurrenceMonthlyByDate

### -LastDayOfMonth

Indicates that the schedule recurs on the last day of each month. Creates an `SMS_ST_RecurMonthlyByDate` token with `MonthDay` set to 0.

- **Type**: SwitchParameter
- **Required**: Yes (in RecurMonthlyLastDayOfMonth set)
- **ParameterSet**: RecurMonthlyLastDayOfMonth

### -Start

The start date and time for the schedule. For recurring schedules, this is the start time of the first occurrence.

- **Type**: DateTime
- **Required**: No
- **Default**: Current date and time

### -IsUtc

Specifies that the schedule uses UTC time instead of local time.

- **Type**: SwitchParameter
- **Required**: No
- **Default**: $false

### -ScheduleString

Switch parameter that indicates the schedule token should be returned as a hex-encoded string instead of a CIM instance. When this switch is specified, the function outputs the schedule token string directly.

- **Type**: SwitchParameter
- **Required**: No
- **Default**: $false

### -DurationInterval

Specifies the unit of time for the schedule duration. Must be used together with `-DurationCount`. Mutually exclusive with `-End`.

- **Type**: String
- **Required**: No
- **ValidateSet**: Minutes, Hours, Days

### -DurationCount

Specifies the number of duration intervals. Must be used together with `-DurationInterval`. Mutually exclusive with `-End`.

- **Type**: Int32
- **Required**: No
- **ValidateRange**: 0 to 31

### -End

Specifies the end date and time for the schedule. The duration is calculated from `-Start` to `-End`. Mutually exclusive with `-DurationInterval`/`-DurationCount`.

- **Type**: DateTime
- **Required**: No

## OUTPUTS

### Microsoft.Management.Infrastructure.CimInstance (default)

When the `-ScheduleString` switch is **not** used, the function returns the actual SMS schedule token CIM instance. The specific CIM class depends on the recurrence type:

| Parameter Set | CIM Class Returned |
|---------------|-------------------|
| RecurrenceNone | `SMS_ST_NonRecurring` |
| RecurrenceInterval | `SMS_ST_RecurInterval` |
| RecurrenceWeekly | `SMS_ST_RecurWeekly` |
| RecurMonthlyByWeekday | `SMS_ST_RecurMonthlyByWeekday` |
| RecurrenceMonthlyByDate | `SMS_ST_RecurMonthlyByDate` |
| RecurMonthlyLastDayOfMonth | `SMS_ST_RecurMonthlyByDate` |

Each returned CIM instance includes these **base properties** (all types):

| Property | Type | Description |
|----------|------|-------------|
| StartTime | DateTime | Schedule start time |
| DayDuration | UInt32 | Days component of duration |
| HourDuration | UInt32 | Hours component of duration |
| MinuteDuration | UInt32 | Minutes component of duration |
| IsGMT | Boolean | Whether UTC time is used |

**RecurInterval** additional properties: `DaySpan`, `HourSpan`, `MinuteSpan`

**RecurWeekly** additional properties: `Day` (bitmask: 1=Sun, 2=Mon, 4=Tue, 8=Wed, 16=Thu, 32=Fri, 64=Sat), `ForNumberOfWeeks`

**RecurMonthlyByWeekday** additional properties: `Day` (bitmask), `WeekOrder` (0=Last, 1=First, 2=Second, 3=Third, 4=Fourth), `ForNumberOfMonths`

**RecurMonthlyByDate** additional properties: `MonthDay` (0=last day), `ForNumberOfMonths`

A `ScheduleString` **NoteProperty** is added to every returned CIM instance containing the hex-encoded schedule token string.

### System.String (with -ScheduleString switch)

When the `-ScheduleString` switch is used, the function returns the hex-encoded schedule token string directly.

## EXAMPLES

### Example 1: Create a non-recurring schedule

```powershell
New-CM7Schedule -Nonrecurring -Start "2026-03-15 22:00"
```

Creates a one-time (non-recurring) schedule starting at March 15, 2026 at 10 PM.

### Example 2: Create a non-recurring schedule with duration

```powershell
New-CM7Schedule -Nonrecurring -Start "2026-03-15 22:00" -DurationInterval Hours -DurationCount 2
```

Creates a one-time schedule starting at March 15, 2026 at 10 PM lasting 2 hours.

### Example 3: Create a non-recurring schedule with -End

```powershell
New-CM7Schedule -Nonrecurring -Start "2026-03-15 22:00" -End "2026-03-16 00:00"
```

Creates a non-recurring schedule with duration calculated automatically from Start to End (2 hours).

### Example 4: Create a daily recurring schedule

```powershell
New-CM7Schedule -RecurInterval Days -RecurCount 1 -Start "2026-03-01 01:00"
```

Creates a daily recurring schedule starting at March 1, 2026 at 1 AM.

### Example 5: Create an hourly recurring schedule

```powershell
New-CM7Schedule -RecurInterval Hours -RecurCount 4 -Start "2026-03-01 01:00"
```

Creates a schedule recurring every 4 hours.

### Example 6: Create a weekly schedule

```powershell
New-CM7Schedule -DayOfWeek Saturday -Start "2026-03-01 02:00"
```

Creates a weekly schedule recurring every Saturday at 2 AM.

### Example 7: Create a bi-weekly schedule

```powershell
New-CM7Schedule -DayOfWeek Monday -RecurCount 2 -Start "2026-03-01 02:00"
```

Creates a schedule recurring every other Monday.

### Example 8: Create a monthly by weekday schedule

```powershell
New-CM7Schedule -DayOfWeek Tuesday -WeekOrder Second -Start "2026-03-01 01:00"
```

Creates a monthly schedule on the second Tuesday of each month.

### Example 9: Create a monthly by date schedule

```powershell
New-CM7Schedule -DayOfMonth 15 -Start "2026-03-01 03:00"
```

Creates a monthly schedule on the 15th of each month.

### Example 10: Create a schedule for the last day of each month

```powershell
New-CM7Schedule -LastDayOfMonth -Start "2026-03-01 03:00"
```

Creates a monthly schedule on the last day of each month.

### Example 11: Create a schedule with duration and recurrence

```powershell
New-CM7Schedule -RecurInterval Days -RecurCount 7 -Start "2026-03-01 22:00" -DurationInterval Hours -DurationCount 2
```

Creates a weekly recurring schedule with a 2-hour duration window.

### Example 12: Get schedule as a string for use with other functions

```powershell
$schedule = New-CM7Schedule -RecurInterval Days -RecurCount 7 -Start "2026-03-01 22:00" -ScheduleString
New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "Weekly MW" -Schedule $schedule -Force
```

Creates a recurring schedule as a token string and passes it to `New-CM7MaintenanceWindow`.

### Example 13: Create a UTC time schedule

```powershell
New-CM7Schedule -Nonrecurring -Start "2026-03-15 22:00" -DurationInterval Hours -DurationCount 1 -IsUtc
```

Creates a one-time schedule using UTC time with a 1-hour duration.

### Example 14: Use CIM instance ScheduleString property

```powershell
$schedule = New-CM7Schedule -RecurInterval Days -RecurCount 1 -Start (Get-Date)
$schedule.ScheduleString  # Access the hex-encoded token string
```

Creates a daily schedule as a CIM instance and accesses the `ScheduleString` NoteProperty.

## NOTES

- Requires an active connection established via `Connect-CM7`.
- The function builds SMS schedule tokens using the `SMS_ScheduleMethods::WriteToString` WMI method, which is the same method used internally by MECM.
- Schedule tokens are hexadecimal strings that encode the schedule's start time, duration, and recurrence pattern.
- The `-DurationInterval`/`-DurationCount` parameters cannot be combined with `-End`. Use one approach or the other.
- The `-DurationInterval` and `-DurationCount` parameters must be used together.
- The `-End` value must be later than `-Start`.

### ConfigurationManager Module Equivalent

This function is the CIM-based equivalent of:

```powershell
# ConfigurationManager module (requires console connection)
New-CMSchedule -RecurInterval Days -RecurCount 1 -Start "2026-03-01"

# MECM7 module (uses CIM/WinRM)
New-CM7Schedule -RecurInterval Days -RecurCount 1 -Start "2026-03-01"
```

The key difference is that `New-CM7Schedule` uses CIM/WinRM to communicate with the SMS Provider directly, while `New-CMSchedule` requires the ConfigurationManager PowerShell module and console connection.

### Schedule Token Classes

| SMS Class | Used For |
|-----------|----------|
| SMS_ST_NonRecurring | One-time (non-recurring) schedules |
| SMS_ST_RecurInterval | Interval-based recurring schedules (days/hours/minutes) |
| SMS_ST_RecurWeekly | Weekly recurring schedules |
| SMS_ST_RecurMonthlyByWeekday | Monthly by weekday (e.g., second Tuesday) |
| SMS_ST_RecurMonthlyByDate | Monthly by date (e.g., the 15th) or last day of month |

## SEE ALSO

- [New-CM7MaintenanceWindow](./New-CM7MaintenanceWindow.md) - Create maintenance windows using schedule tokens
- [New-CM7Collection](./New-CM7Collection.md) - Create collections with refresh schedules
- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
