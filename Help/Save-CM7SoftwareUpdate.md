# Save-CM7SoftwareUpdate

## SYNOPSIS

Saves one or more software updates to update groups and deployment packages using CIM connectivity.

## DESCRIPTION

The Save-CM7SoftwareUpdate function allows you to save software updates to update groups and deployment packages in MECM, using CIM connectivity. You can specify updates by name, ID, object, or group. Supports download location, retry logic, and language selection.

## PARAMETERS

### SoftwareUpdateName

Array of software update names to save.

- Type: String[]
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### SoftwareUpdateId

Array of software update IDs to save.

- Type: String[]
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### SoftwareUpdate

Software update CIM instance to save.

- Type: PSObject
- Required: true
- Accept pipeline input: true (ByValue)
- Accept wildcard characters: false

### SoftwareUpdateGroupName

Array of software update group names to save updates from.

- Type: String[]
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### SoftwareUpdateGroupId

Array of software update group IDs to save updates from.

- Type: String[]
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### SoftwareUpdateGroup

Software update group CIM instance to save updates from.

- Type: PSObject
- Required: true
- Accept pipeline input: true (ByValue)
- Accept wildcard characters: false

### DeploymentPackageName

Name of the software update deployment package to save updates to.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### DeploymentPackageID

ID of the software update deployment package to save updates to.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### DownloadOnly

If specified, the function will only download the update content to the specified location without adding it to a deployment package.

- Type: SwitchParameter
- Required: true
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### Location

Download source location for software updates.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### RetryCount

Number of times to retry downloading the update (default: 3).

- Type: UInt32
- Required: false
- Default value: 3
- Accept pipeline input: false
- Accept wildcard characters: false

### RetryDelaySec

Number of seconds to wait before retrying (default: 2).

- Type: UInt32
- Required: false
- Default value: 2
- Accept pipeline input: false
- Accept wildcard characters: false

### SoftwareUpdateLanguage

Array of software update languages.

- Type: String[]
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### DisableWildcardHandling

Treats wildcard characters as literal character values.

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### ForceWildcardHandling

Processes wildcard characters (not recommended).

- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### TimeoutSec

Timeout in seconds for each download attempt (default: 300).

- Type: Int32
- Required: false
- Default value: 300
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
Save-CM7SoftwareUpdate -SoftwareUpdateGroupName "Test-SoftwareUpdateGroup" -DeploymentPackageName "Test-DeploymentPackage" -Location "\\mecm.yordomain.local\Patches\test"
```

### Example 2

```powershell
Save-CM7SoftwareUpdate -SoftwareUpdateName "Cumulative Update for Windows 10 (KB3095020)" -DeploymentPackageName "Test-DeploymentPackage" -Location "\\mecm.yourdomain.local\Patches\test"
```
