# Remove-CM7Application

## SYNOPSIS

Removes an application from MECM using CIM connectivity.

## DESCRIPTION

Retires and deletes an application from MECM via the SMS_Application WMI class using CIM connectivity.
Requires an active connection established via Connect-CM7.
You must retire the application (SetIsExpired) before deletion.

## PARAMETERS

### Name

The display name of the application to remove. Supports wildcards. (Mutually exclusive with ID)

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### ID

The CI_ID of the application to remove. (Mutually exclusive with Name)

- Type: Int32
- Required: true
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

### InputObject

A collection of objects representing applications to remove. Each object must have a CI_ID property. (Mutually exclusive with Name and ID)

- Type: PSObject
- Required: true
- Accept pipeline input: true (ByValue)
- Accept wildcard characters: false

### Force

If specified, does not prompt for confirmation.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### WhatIf



- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Confirm



- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
Remove-CM7Application -Name "Test"
            Retires and deletes the application named "Test".
```

### Example 2

```powershell
Remove-CM7Application -ID 12345678
            Retires and deletes the application with CI_ID 12345678.
```
