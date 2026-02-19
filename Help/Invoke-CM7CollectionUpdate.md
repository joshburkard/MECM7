# Invoke-CM7CollectionUpdate

## SYNOPSIS

Triggers a collection membership evaluation (refresh) on a MECM collection using CIM.

## DESCRIPTION

The `Invoke-CM7CollectionUpdate` function forces a collection to re-evaluate its membership rules by invoking the `RequestRefresh` method on the `SMS_Collection` WMI class. This function is the CIM-based equivalent of the `Invoke-CMCollectionUpdate` cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

The function performs the following actions:

1. Validates an active connection exists (established via `Connect-CM7`)
2. Resolves the target collection by Name or CollectionID via the `SMS_Collection` class
3. Invokes the `RequestRefresh` method on the `SMS_Collection` instance
4. Returns the result including the ReturnValue (0 = success)

This is useful when you need to force a collection to update its membership immediately, for example after adding or removing membership rules, or when you need to ensure the collection membership is current before deploying software or running reports.

## PARAMETERS

### -Name

Specifies the name of the collection to update. The collection is resolved via the SMS_Collection class.

- **Type**: String
- **Position**: 0
- **Default**: None
- **Required**: Yes (for ByName parameter set)
- **Parameter Set**: ByName (default)
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"Test-Collection-Query"`

### -CollectionId

Specifies the CollectionID of the collection to update.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes (for ByCollectionId parameter set)
- **Parameter Set**: ByCollectionId
- **Accept pipeline input**: False
- **Accept wildcard characters**: No

Example: `"SMS00001"`

## OUTPUTS

### MECM7.CollectionUpdate

The function returns a PSCustomObject with the following properties:

- **CollectionId** (String): The CollectionID of the updated collection
- **Name** (String): The name of the collection
- **CollectionType** (String): The type of the collection (Device or User)
- **ReturnValue** (Int): The return value from the CIM method invocation (0 = success)

## EXAMPLES

### Example 1: Update a collection by name

```powershell
Invoke-CM7CollectionUpdate -Name "Test-Collection-Query"
```

Forces a membership evaluation on the collection named "Test-Collection-Query".

### Example 2: Update a collection by CollectionID

```powershell
Invoke-CM7CollectionUpdate -CollectionId "SMS00001"
```

Forces a membership evaluation on the collection with CollectionID "SMS00001" (All Systems).

### Example 3: Update a collection with verbose output

```powershell
Invoke-CM7CollectionUpdate -Name "Test-Collection-Query" -Verbose
```

Forces a membership evaluation with verbose output showing the WQL query execution and method invocation details:

```
VERBOSE: Running Invoke-CM7CollectionUpdate
VERBOSE: Start: Execution of WQL query: SELECT * FROM SMS_Collection WHERE Name = 'Test-Collection-Query'
VERBOSE: Performing the operation "Invoke" on target "DeviceCollectionUpdate: Name="Test-Collection-Query"".
VERBOSE: Output properties:
VERBOSE: -- :: ReturnValue == 0
VERBOSE: Finish: Execution of WQL query: SELECT * FROM SMS_Collection WHERE Name = 'Test-Collection-Query'. Processed 1 results.
```

### Example 4: Preview without executing

```powershell
Invoke-CM7CollectionUpdate -Name "Test-Collection-Query" -WhatIf
```

Shows what would happen without actually triggering the collection update.

### Example 5: Update a collection with confirmation

```powershell
Invoke-CM7CollectionUpdate -Name "All Systems" -Confirm
```

Prompts for confirmation before triggering the membership evaluation on "All Systems".

## NOTES

- **Connection Required**: An active MECM connection must be established via `Connect-CM7` before using this function.
- **Target Exclusivity**: You must specify exactly one target type: `Name` or `CollectionId`. You cannot combine them.
- **ShouldProcess Support**: The function supports `-WhatIf` and `-Confirm` parameters for safe operation.
- **CIM Method**: The function uses the `RequestRefresh` method on the `SMS_Collection` WMI class.
- **Collection Types**: Works with both Device and User collections.
- **Permissions**: The user must have appropriate MECM permissions to trigger collection evaluation.

## REQUIREMENTS

- PowerShell 5.1 or higher
- An active MECM connection (via `Connect-CM7`)
- MECM administrative rights to update collections
- WinRM access to the SMS Provider server

## RELATED LINKS

- [Connect-CM7](./Connect-CM7.md) - Establish connection to MECM
- [Get-CM7Collection](./Get-CM7Collection.md) - Retrieve collection information
- [New-CM7Collection](./New-CM7Collection.md) - Create a new collection
- [Remove-CM7Collection](./Remove-CM7Collection.md) - Remove a collection
- [Add-CM7CollectionMembershipRule](./Add-CM7CollectionMembershipRule.md) - Add membership rules to a collection
- [Remove-CM7CollectionMembershipRule](./Remove-CM7CollectionMembershipRule.md) - Remove membership rules from a collection
