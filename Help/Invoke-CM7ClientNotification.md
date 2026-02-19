# Invoke-CM7ClientNotification

## SYNOPSIS

Sends a client notification action to target devices or a collection using CIM.

## DESCRIPTION

The `Invoke-CM7ClientNotification` function sends a client notification to MECM-managed devices, triggering actions like policy refresh, inventory cycles, software update scans, and more. This function is the CIM-based equivalent of the `Invoke-CMClientNotification` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Maps the requested ActionType to the corresponding `SMS_ClientOperation` type code
3. Resolves target devices by name or collection name if needed
4. Invokes the `SMS_ClientOperation.InitiateClientOperationEx` CIM method
5. Returns the client operation result including the OperationID

### Supported Notification Action Types

#### Client Notifications

| ActionType | Code | Description |
|---|---|---|
| `ClientNotificationRequestMachinePolicyNow` | 8 | Machine Policy Retrieval & Evaluation Cycle |
| `ClientNotificationRequestUsersPolicyNow` | 9 | User Policy Retrieval & Evaluation Cycle |
| `ClientNotificationRequestDDRNow` | 10 | Discovery Data Collection Cycle |
| `ClientNotificationRequestSWInvNow` | 11 | Software Inventory Cycle |
| `ClientNotificationRequestHWInvNow` | 12 | Hardware Inventory Cycle |
| `ClientNotificationAppDeplEvalNow` | 13 | Application Deployment Evaluation Cycle |
| `ClientNotificationSUMDeplEvalNow` | 14 | Software Updates Deployment Evaluation Cycle |
| `ClientRequestSUPChangeNow` | 15 | Request SUP Change Now |
| `ClientRequestDHAChangeNow` | 16 | Request DHA Change Now |
| `ClientNotificationRebootMachine` | 17 | Restart Computer |
| `ClientNotificationCheckComplianceNow` | 125 | Check Compliance Now |
| `ClientNotificationWakeUpClientNow` | - | Wake Up Client Now |

#### Diagnostics

| ActionType | Code | Description |
|---|---|---|
| `DiagnosticsEnableVerboseLogging` | 20 | Enable Verbose Logging |
| `DiagnosticsDisableVerboseLogging` | 21 | Disable Verbose Logging |
| `DiagnosticsCollectFiles` | 22 | Collect Diagnostic Files |

#### Endpoint Protection

| ActionType | Code | Description |
|---|---|---|
| `EndpointProtectionFullScan` | 1 | Full Scan |
| `EndpointProtectionQuickScan` | 2 | Quick Scan |
| `EndpointProtectionDownloadDefinition` | 3 | Download Definition |
| `EndpointProtectionEvaluateSoftwareUpdate` | 4 | Evaluate Software Update |
| `EndpointProtectionExcludeScanPaths` | 5 | Exclude Scan Paths |
| `EndpointProtectionAllowThreat` | 6 | Allow Threat |
| `EndpointProtectionRestoreQuarantinedItems` | 7 | Restore Quarantined Items |
| `EndpointProtectionRestoreWithDeps` | 100 | Restore With Dependencies |

## PARAMETERS

### -ActionType

Specifies the type of client notification action to send. Must be one of the supported notification action types listed in the description.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes
- **Parameter Set**: All
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"ClientNotificationRequestMachinePolicyNow"`

### -DeviceName

Specifies the name of the target device to send the notification to. The device is resolved to its ResourceID via the SMS_R_System class.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByDeviceName parameter set)
- **Parameter Set**: ByDeviceName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"SERVER01"`

### -ResourceId

Specifies the ResourceID of the target device(s) to send the notification to. Accepts a single integer or an array of integers for targeting multiple devices.

- **Type**: Int32[] (array of integers)
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByResourceId parameter set)
- **Parameter Set**: ByResourceId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Examples:
- Single device: `16893210`
- Multiple devices: `@(16893210, 16893465)`

### -CollectionId

Specifies the CollectionID of the target collection. The notification will be sent to all members of the specified collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"SD101C00"`

### -CollectionName

Specifies the name of the target collection. The collection is resolved to its CollectionID. The notification will be sent to all members of the specified collection.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionName parameter set)
- **Parameter Set**: ByCollectionName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"Test-Collection-Direct"`

## OUTPUTS

### MECM7.ClientNotification

The function returns a PSCustomObject with the following properties:

- **OperationID** (Int): The client operation ID for tracking
- **ActionType** (String): The notification action type that was sent
- **ReturnValue** (Int): The return value from the CIM method invocation (0 = success)

## EXAMPLES

### Example 1: Send machine policy refresh to a device by name

```powershell
Invoke-CM7ClientNotification -ActionType ClientNotificationRequestMachinePolicyNow -DeviceName "SERVER01"
```

Sends a machine policy refresh notification to the device named "SERVER01". This is equivalent to triggering "Download Computer Policy" on the client.

### Example 2: Trigger hardware inventory on a device by ResourceID

```powershell
Invoke-CM7ClientNotification -ActionType ClientNotificationRequestHWInvNow -ResourceId 16893210
```

Triggers a hardware inventory cycle on the device with ResourceID 16893210.

### Example 3: Send software updates deployment evaluation to a collection by CollectionID

```powershell
Invoke-CM7ClientNotification -ActionType ClientNotificationSUMDeplEvalNow -CollectionId "SD101C00"
```

Triggers a software updates deployment evaluation cycle on all members of the collection with ID "SD101C00".

### Example 4: Send notification to a collection by name

```powershell
Invoke-CM7ClientNotification -ActionType ClientNotificationSUMDeplEvalNow -CollectionName "Test-Collection-Direct"
```

Triggers a software updates deployment evaluation cycle on all members of the collection named "Test-Collection-Direct".

### Example 5: Send notification to multiple devices

```powershell
Invoke-CM7ClientNotification -ActionType ClientNotificationRequestMachinePolicyNow -ResourceId @(16893210, 16893465)
```

Sends a machine policy refresh notification to two devices specified by their ResourceIDs.

### Example 6: Restart a device with confirmation

```powershell
Invoke-CM7ClientNotification -ActionType ClientNotificationRebootMachine -DeviceName "SERVER01" -Confirm
```

Restarts the device "SERVER01" after asking for confirmation. Use `-WhatIf` to preview without executing.

### Example 7: Preview a notification without executing

```powershell
Invoke-CM7ClientNotification -ActionType ClientNotificationRebootMachine -DeviceName "SERVER01" -WhatIf
```

Shows what would happen without actually sending the restart notification.

### Example 8: Trigger Endpoint Protection quick scan

```powershell
Invoke-CM7ClientNotification -ActionType EndpointProtectionQuickScan -DeviceName "SERVER01"
```

Triggers an Endpoint Protection quick scan on the device "SERVER01".

## NOTES

- **Connection Required**: An active MECM connection must be established via `Connect-CM7` before using this function.
- **Target Exclusivity**: You must specify exactly one target type: `DeviceName`, `ResourceId`, `CollectionId`, or `CollectionName`. You cannot combine them.
- **ShouldProcess Support**: The function supports `-WhatIf` and `-Confirm` parameters. This is especially useful for destructive actions like `ClientNotificationRebootMachine`.
- **Operation Type Mapping**: The function internally maps ActionType names to `SMS_ClientOperation` type codes used by the CIM method.
- **Client Requirement**: The target device must be an active MECM client with a working client agent to receive and process the notification.
- **Permissions**: Some actions (like restart) may require elevated MECM administrative permissions.

## REQUIREMENTS

- PowerShell 5.1 or higher
- An active MECM connection (via `Connect-CM7`)
- MECM administrative rights appropriate for the notification type
- WinRM access to the SMS Provider server

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7Device](./Get-CM7Device.md) - Retrieve device information
- [Get-CM7Collection](./Get-CM7Collection.md) - Retrieve collection information
- [Invoke-CM7Script](./Invoke-CM7Script.md) - Invoke MECM scripts on target devices
