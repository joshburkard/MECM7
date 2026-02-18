# Invoke-CM7Script

## SYNOPSIS

Invokes (runs) a Configuration Manager script on target devices or a collection using CIM.

## DESCRIPTION

The `Invoke-CM7Script` function runs an approved MECM script on one or more target devices or on all members of a collection. This function is the CIM-based equivalent of the `Invoke-CMScript` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

In addition to the origin cmdlet `Invoke-CMScript`, it allows passing input parameters to the script.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the script by name or GUID via the SMS_Scripts WMI class
3. Validates the script is approved (ApprovalState = 3)
4. Resolves target devices by name if needed (via SMS_R_System)
5. Builds the script execution XML payload with optional parameters
6. Invokes the `SMS_ClientOperation.InitiateClientOperationEx` CIM method
7. Returns the client operation result including the OperationID for status tracking

Key features:
- **Script by Name or GUID**: Identify the script to run by its display name or ScriptGuid
- **Target by Device or Collection**: Run on specific devices (by name or ResourceId) or an entire collection
- **Parameter Support**: Pass script input parameters as a hashtable
- **Approval Validation**: Only approved scripts can be executed
- **Hidden Parameter Handling**: Hidden parameters automatically use their default values

## PARAMETERS

### -ScriptName

Specifies the name of the MECM script to invoke. The script must exist and be approved.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByScriptName* parameter sets)
- **Parameter Set**: ByScriptNameAndDeviceName, ByScriptNameAndResourceId, ByScriptNameAndCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"get pending reboot"`

### -ScriptGuid

Specifies the GUID of the MECM script to invoke. The script must exist and be approved.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByScriptGuid* parameter sets)
- **Parameter Set**: ByScriptGuidAndDeviceName, ByScriptGuidAndResourceId, ByScriptGuidAndCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"DF90142C-1534-4A0B-B26A-6B917699A873"`

### -DeviceName

Specifies the name of the target device to run the script on. The device is resolved to its ResourceID via the SMS_R_System class.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for *AndDeviceName parameter sets)
- **Parameter Set**: ByScriptNameAndDeviceName, ByScriptGuidAndDeviceName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"SERVER01"`

### -ResourceId

Specifies the ResourceID of the target device(s) to run the script on. Accepts a single integer or an array of integers for targeting multiple devices.

- **Type**: Int32[] (array of integers)
- **Position**: Named
- **Default**: None
- **Required**: Yes (for *AndResourceId parameter sets)
- **Parameter Set**: ByScriptNameAndResourceId, ByScriptGuidAndResourceId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Examples:
- Single device: `16893210`
- Multiple devices: `@(16893210, 16893465)`

### -CollectionId

Specifies the CollectionID of the target collection. The script will be executed on all members of the specified collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for *AndCollectionId parameter sets)
- **Parameter Set**: ByScriptNameAndCollectionId, ByScriptGuidAndCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"SD101129"`

### -ScriptParameters

Specifies a hashtable of parameters to pass to the script. The keys must match the script's parameter names. If the script has hidden parameters, their default values are used automatically. If the script has required (non-hidden) parameters that are not provided, an error is thrown.

- **Type**: Hashtable
- **Position**: Named
- **Default**: Empty hashtable `@{}`
- **Required**: No
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `@{ Detail = "TRUE"; Verbose = "FALSE" }`

## OUTPUTS

### MECM7.ScriptInvocation

The function returns a PSCustomObject with the following properties:

- **OperationID** (Int): The client operation ID that can be used to track execution status via `Get-CM7ScriptExecutionStatus`
- **ScriptName** (String): The name of the script that was invoked
- **ScriptGuid** (String): The GUID of the script
- **ReturnValue** (Int): The return value from the CIM method invocation (0 = success)

## EXAMPLES

### Example 1: Run a script on a single device by name

```powershell
Invoke-CM7Script -ScriptName "get pending reboot" -DeviceName "SERVER01"
```

Runs the approved script "get pending reboot" on the device named "SERVER01" without any input parameters.

### Example 2: Run a script with parameters

```powershell
$params = @{ Detail = "TRUE" }
Invoke-CM7Script -ScriptName "get pending reboot" -DeviceName "SERVER01" -ScriptParameters $params
```

Runs the script with the parameter `Detail` set to `"TRUE"`.

### Example 3: Run a script by GUID on a device by ResourceID

```powershell
Invoke-CM7Script -ScriptGuid "DF90142C-1534-4A0B-B26A-6B917699A873" -ResourceId 16893210
```

Runs the script identified by its GUID on the device with ResourceID 16893210.

### Example 4: Run a script on multiple devices

```powershell
Invoke-CM7Script -ScriptName "get pending reboot" -ResourceId @(16893210, 16893465)
```

Runs the script on two devices specified by their ResourceIDs.

### Example 5: Run a script on a collection

```powershell
Invoke-CM7Script -ScriptName "get pending reboot" -CollectionId "SD101129"
```

Runs the script on all members of the collection with ID "SD101129".

### Example 6: Run a script and track its execution

```powershell
$invocation = Invoke-CM7Script -ScriptName "get pending reboot" -DeviceName "SERVER01"
Write-Host "Script invoked with OperationID: $($invocation.OperationID)"

# Track execution status (requires Get-CM7ScriptExecutionStatus)
# Get-CM7ScriptExecutionStatus -ClientOperationId $invocation.OperationID
```

## NOTES

- **Connection Required**: An active MECM connection must be established via `Connect-CM7` before using this function.
- **Script Approval**: The target script must be approved (ApprovalState = 3). Unapproved or declined scripts cannot be executed.
- **Target Exclusivity**: You must specify exactly one target type: `DeviceName`, `ResourceId`, or `CollectionId`. You cannot combine them.
- **Script Parameters**: If the script defines required parameters that are not hidden, they must be provided in the `-ScriptParameters` hashtable. Hidden parameters automatically use their default values.
- **Operation Type**: The function uses CIM method `SMS_ClientOperation.InitiateClientOperationEx` with operation type 135 (Run Script).
- **Execution Tracking**: The returned `OperationID` can be used with `Get-CM7ScriptExecutionStatus` to monitor script execution progress and results.

## REQUIREMENTS

- PowerShell 5.1 or higher
- An active MECM connection (via `Connect-CM7`)
- MECM administrative rights to execute scripts
- The target script must be approved in the MECM console
- WinRM access to the SMS Provider server

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7Device](./Get-CM7Device.md) - Retrieve device information
- [Get-CM7Collection](./Get-CM7Collection.md) - Retrieve collection information
