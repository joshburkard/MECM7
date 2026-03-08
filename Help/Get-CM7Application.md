# Get-CM7Application

## SYNOPSIS

Retrieves application information from MECM using CIM.

## DESCRIPTION

Queries the SMS_Application WMI class to retrieve application information from MECM.
Supports filtering by application name, CI_ID, or other properties.
Requires an active connection established via Connect-CM7.

## PARAMETERS

### Name

The name of the application to retrieve. Supports wildcard characters (*).

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: true

### ID

The ID of the application to retrieve.

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### IsEnabled

Filter applications by their enabled state.

- Type: Boolean
- Required: false
- Default value: True
- Accept pipeline input: false
- Accept wildcard characters: false

### IsLatest

Filter to only return the latest version of each application.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### ShowHidden

Include hidden applications in the results.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### Fast

Returns only lazy properties for faster queries.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
Get-CM7Application -Name "Microsoft PowerShell 7.4.3"
            Retrieves the application with the exact name "Microsoft PowerShell 7.4.3".
```

### Example 2

```powershell
Get-CM7Application -ID 17123456
            Retrieves the application with ID 17123456.
```

### Example 3

```powershell
Get-CM7Application -Name "PowerShell*"
            Retrieves all applications whose names start with "PowerShell".
```

### Example 4

```powershell
Get-CM7Application
            Retrieves all applications (use with caution on large environments).
```
