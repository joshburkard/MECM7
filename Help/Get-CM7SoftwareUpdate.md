# Get-CM7SoftwareUpdate

## SYNOPSIS

Retrieves software update information from MECM using CIM.

## DESCRIPTION

Queries the SMS_SoftwareUpdate WMI class to retrieve software update information
from MECM. Supports filtering by article ID, bulletin ID, name, severity,
deployment status, and supersedence status.
Requires an active connection established via Connect-CM7.

This function is the CIM-based equivalent of the Get-CMSoftwareUpdate cmdlet
from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
instead of requiring the ConfigMgr console or PowerShell drive.

## PARAMETERS

### ArticleId

The KB article ID of the software update to retrieve (e.g. "4038779").

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### BulletinId

The security bulletin ID of the software update to retrieve (e.g. "MS17-010").
Supports wildcard characters (* and ?).

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: true

### Name

The localized display name of the software update. Supports wildcard characters (* and ?).

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: true

### CI_ID

The unique Configuration Item ID of the software update to retrieve.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Severity

The severity of the software update. Valid values are:
None, Low, Moderate, Important, Critical.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### IsDeployed

Filter by deployment status. When $true, only returns updates that have been deployed.
When $false, only returns updates that have not been deployed.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### IsSuperseded

Filter by supersedence status. When $true, only returns superseded updates.
When $false, only returns non-superseded updates.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### CategoryName

Filter by update classification or product category name.
Supports wildcard characters (* and ?).
Note: This performs a sub-query against SMS_CIToCategory and SMS_CategoryInstance.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: true

### Fast

Returns limited properties for faster queries. Only returns essential properties like
CI_ID, ArticleID, BulletinID, LocalizedDisplayName, LocalizedDescription,
DatePosted, DateRevised, IsDeployed, IsSuperseded, NumMissing, NumPresent,
NumTotal, SeverityName, and PercentCompliant.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
Get-CM7SoftwareUpdate
            Retrieves all software updates.
```

### Example 2

```powershell
Get-CM7SoftwareUpdate -ArticleId "4038779"
            Retrieves the software update with the specified KB article ID.
```

### Example 3

```powershell
Get-CM7SoftwareUpdate -Name "*Cumulative*"
            Retrieves all software updates whose names contain "Cumulative".
```

### Example 4

```powershell
Get-CM7SoftwareUpdate -Severity Critical -IsDeployed $false
            Retrieves all critical software updates that have not yet been deployed.
```

### Example 5

```powershell
Get-CM7SoftwareUpdate -IsSuperseded $false -Fast
            Retrieves all non-superseded software updates with limited properties.
```

## NOTES

Requires an active connection established via Connect-CM7.
