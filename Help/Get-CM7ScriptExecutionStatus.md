# Get-CM7ScriptExecutionStatus

## SYNOPSIS

Retrieves the execution status of MECM scripts using CIM.

## DESCRIPTION

The `Get-CM7ScriptExecutionStatus` function returns the current execution status and results of MECM scripts that have been invoked via `Invoke-CM7Script` or through the MECM console. This function is the CIM-based equivalent of querying the `SMS_ScriptsExecutionTask` and `SMS_ScriptsExecutionStatus` WMI classes.

The function supports multiple query modes:

- **By ClientOperationId**: Retrieve detailed status and per-device results for a specific script execution
- **By ScriptName**: Filter executions by the script name
- **By CollectionName**: Filter executions by the target collection name
- **By CollectionId**: Filter executions by the target collection ID
- **Combined filters**: Combine ScriptName with CollectionName or CollectionId
- **No filter (list mode)**: When no parameters are specified, returns a summary list of all script executions with Operation ID, Script Name, Script GUID, Collection info, and Last Update Time — but without detailed per-device results

When a `ClientOperationId` is provided and completed clients exist, the function retrieves per-device results including script output, exit codes, and parsed output objects.

Key features:
- **Flexible Filtering**: Query by operation ID, script name, collection name, collection ID, or any combination
- **Summary List Mode**: Without a ClientOperationId, returns a quick overview of all script executions
- **Detailed Results**: With a ClientOperationId, returns full per-device script output and status
- **JSON Parsing**: Automatically attempts to parse script output as JSON into an OutputObject property

## PARAMETERS

### -ClientOperationId

Specifies the client operation ID returned by `Invoke-CM7Script`. When specified, retrieves detailed execution status and per-device results for that specific operation.

This parameter is not mandatory. If omitted, a summary list of all script executions is returned without per-device results.

- **Type**: Int32
- **Position**: Named
- **Default**: None
- **Required**: No
- **Parameter Set**: ByClientOperationId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `16819576`

### -ScriptName

Specifies the name of the script to filter execution results by. Can be combined with `CollectionName` or `CollectionId` for more specific filtering.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByScriptName parameter set), No (for combined parameter sets)
- **Parameter Set**: ByScriptName, ByCollectionName_ScriptName, ByCollectionId_ScriptName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"get pending reboot"`

### -CollectionName

Specifies the target collection name to filter execution results by. Can be combined with `ScriptName` for more specific filtering.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionName and ByCollectionName_ScriptName parameter sets)
- **Parameter Set**: ByCollectionName, ByCollectionName_ScriptName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"Test-Collection-Direct"`

### -CollectionId

Specifies the target collection ID to filter execution results by. Can be combined with `ScriptName` for more specific filtering.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId and ByCollectionId_ScriptName parameter sets)
- **Parameter Set**: ByCollectionId, ByCollectionId_ScriptName
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"SD101129"`

## OUTPUTS

### MECM7.ScriptExecutionStatus (Detail Mode — with ClientOperationId)

The function returns a PSCustomObject with the following properties:

- **OperationID** (Int): The client operation ID
- **ScriptName** (String): The name of the executed script
- **ScriptVersion** (String): The version of the script
- **ScriptGuid** (String): The GUID of the script
- **CollectionID** (String): The target collection ID
- **CollectionName** (String): The target collection name
- **Results** (Array): Array of per-device result objects (see below), or `$null` if no clients have completed
- **Status** (String): Current execution status text (`all clients completed`, `some clients completed`, `no client completed`, `not found`)
- **TotalClients** (Int): Total number of targeted clients
- **CompletedClients** (Int): Number of clients that completed execution
- **FailedClients** (Int): Number of clients that failed
- **OfflineClients** (Int): Number of offline clients
- **NotApplicableClients** (Int): Number of not-applicable clients
- **UnknownClients** (Int): Number of clients with unknown status
- **LastUpdateTime** (DateTime): Last time the status was updated

#### Per-Device Result Properties (within Results array)

- **ResourceID** (Int): The device's ResourceID
- **DeviceName** (String): The device name
- **ScriptExecutionState** (Int): Execution state code
- **ScriptExitCode** (Int): Exit code from the script
- **ScriptOutput** (String): Raw script output text
- **OutputObject** (Object): Parsed JSON output (or raw text if parsing fails)

### MECM7.ScriptExecutionSummary (List Mode — without ClientOperationId)

When called without `ClientOperationId`, returns summary objects with:

- **OperationID** (Int): The client operation ID
- **ScriptName** (String): The name of the executed script
- **ScriptGuid** (String): The GUID of the script
- **CollectionID** (String): The target collection ID
- **CollectionName** (String): The target collection name
- **LastUpdateTime** (DateTime): Last time the status was updated
- **TotalClients** (Int): Total number of targeted clients
- **CompletedClients** (Int): Number of clients that completed
- **FailedClients** (Int): Number of clients that failed
- **OfflineClients** (Int): Number of offline clients

## EXAMPLES

### Example 1: List all script executions (summary mode)

```powershell
Get-CM7ScriptExecutionStatus
```

Returns a summary list of all script executions. Each entry includes the Operation ID, Script Name, Script GUID, Collection info, client counts, and Last Update Time — but no per-device results.

### Example 2: Get detailed status for a specific operation

```powershell
Get-CM7ScriptExecutionStatus -ClientOperationId 16819576
```

Retrieves full execution details including per-device results, script output, and exit codes.

### Example 3: Filter by script name

```powershell
Get-CM7ScriptExecutionStatus -ScriptName "get pending reboot"
```

Returns summary entries for all executions of the script "get pending reboot".

### Example 4: Filter by collection name

```powershell
Get-CM7ScriptExecutionStatus -CollectionName "Test-Collection-Direct"
```

Returns summary entries for all script executions targeted at the collection "Test-Collection-Direct".

### Example 5: Combined filter — collection ID and script name

```powershell
Get-CM7ScriptExecutionStatus -CollectionId "SD101129" -ScriptName "get pending reboot"
```

Returns summary entries for the script "get pending reboot" run specifically against collection "SD101129".

### Example 6: Invoke a script and track execution to completion

```powershell
# Step 1: Invoke the script
$invocation = Invoke-CM7Script -ScriptName "get pending reboot" -DeviceName "TEST-2016-1"
Write-Host "Script invoked with OperationID: $($invocation.OperationID)"

# Step 2: Poll for completion
do {
    Start-Sleep -Seconds 5
    $status = Get-CM7ScriptExecutionStatus -ClientOperationId $invocation.OperationID
    Write-Host "Status: $($status.Status) - Completed: $($status.CompletedClients)/$($status.TotalClients)"
} while ($status.CompletedClients -lt $status.TotalClients -and $status.Status -ne 'not found')

# Step 3: Review results
$status.Results | Format-Table DeviceName, ScriptExitCode, ScriptOutput
```

### Example 7: Get parsed JSON output from script results

```powershell
$status = Get-CM7ScriptExecutionStatus -ClientOperationId 16819576
foreach ($result in $status.Results) {
    Write-Host "Device: $($result.DeviceName)"
    Write-Host "Output Object:" -ForegroundColor Cyan
    $result.OutputObject | Format-List
}
```

## NOTES

- **Connection Required**: An active MECM connection must be established via `Connect-CM7` before using this function.
- **List vs. Detail Mode**: When no `ClientOperationId` is provided, the function returns a lightweight summary list. Provide a `ClientOperationId` to get full per-device results.
- **JSON Parsing**: The function automatically attempts to parse each device's script output as JSON. If parsing fails, the raw output string is used as the `OutputObject`.
- **WMI Classes Used**: `SMS_ScriptsExecutionTask` for task-level information and `SMS_ScriptsExecutionStatus` for per-device results.
- **Operation Tracking**: Use the `OperationID` returned by `Invoke-CM7Script` to track a specific script execution.

## REQUIREMENTS

- PowerShell 5.1 or higher
- An active MECM connection (via `Connect-CM7`)
- MECM administrative rights to view script execution status
- WinRM access to the SMS Provider server

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Invoke-CM7Script](./Invoke-CM7Script.md) - Invoke an approved MECM script
- [Get-CM7Device](./Get-CM7Device.md) - Retrieve device information
- [Get-CM7Collection](./Get-CM7Collection.md) - Retrieve collection information
