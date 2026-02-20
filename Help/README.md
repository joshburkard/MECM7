# MECM7 Help Documentation

This directory contains markdown documentation for all MECM7 module functions.

## Functions

| Function Name | Synopsis |
|---------------|----------|
| [Connect-CM7](./Connect-CM7.md) | Connects to MECM / SCCM on a specified site server through WinRM/CIM. |
| [Get-CM7Device](./Get-CM7Device.md) | Retrieves device information from MECM using CIM. |
| [Get-CM7Collection](./Get-CM7Collection.md) | Retrieves collection information from MECM using CIM. |
| [Get-CM7DeviceCollection](./Get-CM7DeviceCollection.md) | Retrieves device collection information from MECM using CIM. Wrapper for Get-CM7Collection -CollectionType Device. |
| [Get-CM7UserCollection](./Get-CM7UserCollection.md) | Retrieves user collection information from MECM using CIM. Wrapper for Get-CM7Collection -CollectionType User. |
| [Get-CM7CollectionMember](./Get-CM7CollectionMember.md) | Retrieves all members of a MECM collection using CIM. |
| [Get-CM7CollectionDirectMembership](./Get-CM7CollectionDirectMembership.md) | Retrieves direct membership information for a MECM collection using CIM. |
| [Get-CM7CollectionExcludeMembershipRule](./Get-CM7CollectionExcludeMembershipRule.md) | Retrieves exclude membership rules for a MECM collection using CIM. |
| [Get-CM7CollectionIncludeMembershipRule](./Get-CM7CollectionIncludeMembershipRule.md) | Retrieves include membership rules for a MECM collection using CIM. |
| [Get-CM7CollectionQueryMembershipRule](./Get-CM7CollectionQueryMembershipRule.md) | Retrieves query membership rules for a MECM collection using CIM. |
| [Add-CM7CollectionMembershipRule](./Add-CM7CollectionMembershipRule.md) | Adds a membership rule (direct, query, include, or exclude) to a MECM collection using CIM. |
| [Remove-CM7CollectionMembershipRule](./Remove-CM7CollectionMembershipRule.md) | Removes a membership rule (direct, query, include, or exclude) from a MECM collection using CIM. |
| [Get-CM7CollectionVariable](./Get-CM7CollectionVariable.md) | Retrieves collection variables from a MECM collection using CIM. |
| [New-CM7DeviceCollectionVariable](./New-CM7DeviceCollectionVariable.md) | Creates a new collection variable on a MECM device collection using CIM. |
| [Remove-CM7DeviceCollectionVariable](./Remove-CM7DeviceCollectionVariable.md) | Removes a collection variable from a MECM device collection using CIM. |
| [Get-CM7DeviceVariable](./Get-CM7DeviceVariable.md) | Retrieves device variables from a MECM device using CIM. |
| [New-CM7DeviceVariable](./New-CM7DeviceVariable.md) | Creates a new device variable on a MECM device using CIM. |
| [Remove-CM7DeviceVariable](./Remove-CM7DeviceVariable.md) | Removes a device variable from a MECM device using CIM. |
| [Get-CM7MaintenanceWindow](./Get-CM7MaintenanceWindow.md) | Retrieves maintenance windows from a MECM collection using CIM. |
| [New-CM7MaintenanceWindow](./New-CM7MaintenanceWindow.md) | Creates a new maintenance window on a MECM collection using CIM. |
| [Remove-CM7MaintenanceWindow](./Remove-CM7MaintenanceWindow.md) | Removes a maintenance window from a MECM collection using CIM. |
| [New-CM7Schedule](./New-CM7Schedule.md) | Creates an SMS schedule token for use with MECM CIM-based functions. |
| [Invoke-CM7Script](./Invoke-CM7Script.md) | Invokes (runs) an approved MECM script on target devices or a collection using CIM. |
| [Invoke-CM7ClientNotification](./Invoke-CM7ClientNotification.md) | Sends a client notification action (policy refresh, inventory, restart, etc.) to target devices or a collection using CIM. |
| [Invoke-CM7CollectionUpdate](./Invoke-CM7CollectionUpdate.md) | Triggers a collection membership evaluation (refresh) on a MECM collection using CIM. |
| [Get-CM7ScriptExecutionStatus](./Get-CM7ScriptExecutionStatus.md) | Retrieves the execution status and results of MECM scripts using CIM. |
| [Get-CM7Deployment](./Get-CM7Deployment.md) | Retrieves deployment information from MECM using CIM. |
| [Get-CM7SoftwareUpdate](./Get-CM7SoftwareUpdate.md) | Retrieves software update information from MECM using CIM. |
| [Get-CM7SoftwareUpdateDeployment](./Get-CM7SoftwareUpdateDeployment.md) | Retrieves software update deployment information from MECM using CIM. |
| [Get-CM7SoftwareUpdateDeploymentPackage](./Get-CM7SoftwareUpdateDeploymentPackage.md) | Retrieves software update deployment package information from MECM using CIM. |
| [Get-CM7SoftwareUpdateGroup](./Get-CM7SoftwareUpdateGroup.md) | Retrieves software update group information from MECM using CIM. |
| [New-CM7SoftwareUpdateGroup](./New-CM7SoftwareUpdateGroup.md) | Creates a new software update group in MECM using CIM. |
| [Add-CM7SoftwareUpdateToGroup](./Add-CM7SoftwareUpdateToGroup.md) | Adds one or more software updates to a software update group in MECM using CIM. |
| [New-CM7SoftwareUpdateDeployment](./New-CM7SoftwareUpdateDeployment.md) | Creates a new software update deployment in MECM using CIM. |
| [Get-CM7TaskSequence](./Get-CM7TaskSequence.md) | Retrieves task sequence information from MECM using CIM. |
| [Get-CM7TaskSequenceDeployment](./Get-CM7TaskSequenceDeployment.md) | Retrieves task sequence deployment information from MECM using CIM. |
| [New-CM7TaskSequenceDeployment](./New-CM7TaskSequenceDeployment.md) | Creates a new task sequence deployment in MECM using CIM. |
| [Move-CM7Object](./Move-CM7Object.md) | Moves MECM objects (collections, packages, etc.) between folders using CIM. |
| [New-CM7Collection](./New-CM7Collection.md) | Creates a new device or user collection in MECM using CIM. |
| [Remove-CM7Collection](./Remove-CM7Collection.md) | Removes a device or user collection from MECM using CIM. |

## Using Help

### PowerShell Built-in Help

Get help directly in PowerShell using the `Get-Help` cmdlet:

```powershell
# Get full help for a function
Get-Help Connect-CM7

# Get examples
Get-Help Connect-CM7 -Examples

# Get detailed parameter information
Get-Help Connect-CM7 -Full

# Online help (if available)
Get-Help Connect-CM7 -Online
```

### Markdown Documentation

The `.md` files in this directory provide detailed documentation including:
- Comprehensive descriptions
- Parameter types and validations
- Multiple usage examples
- Requirements and prerequisites
- Related functions and links

## Documentation Format

Each function documentation file includes:

1. **SYNOPSIS** - Brief description
2. **DESCRIPTION** - Detailed explanation
3. **PARAMETERS** - Parameter definitions with types and descriptions
4. **EXAMPLES** - Real-world usage examples
5. **NOTES** - Additional information and requirements
6. **RELATED LINKS** - Cross-references to related functions

## Contributing Documentation

When adding new functions:

1. Add inline PowerShell help in the `.ps1` file (within `<# ... #>` comment)
2. Create corresponding `.md` file in this Help directory
3. Follow the documentation format established in existing files
4. Include examples that can actually be tested
