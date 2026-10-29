# Invoke-CM7Query

## SYNOPSIS

Runs a saved Configuration Manager query using CIM.

## DESCRIPTION

Resolves a saved query by name or ID, or accepts a query object from the pipeline,
then runs its WQL expression through the SMS Provider using the active CIM session.
Queries configured with a collection limit are rejected because direct CIM execution
cannot apply the SMS Provider's collection-limit context.

## PARAMETERS

### Id

The QueryID of the saved query to run. The alias QueryId is also supported.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Name

The exact name of the saved query to run.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### InputObject

A saved SMS_Query object with an Expression property. Accepts pipeline input.

- Type: Object
- Required: true
- Accept pipeline input: true (ByValue)
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
Invoke-CM7Query -Id 'SMS012'

            Runs the saved query with QueryID SMS012 and returns the result objects.
```

### Example 2

```powershell
Get-CimInstance -ClassName SMS_Query -Filter "QueryID = 'SMS012'" |
                Invoke-CM7Query

            Runs a saved query object through the active MECM CIM connection.
```

## NOTES

Requires an active MECM connection established via Connect-CM7.
Saved queries with a non-empty LimitToCollectionID are not supported.
