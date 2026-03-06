# MECM7 PowerShell Module

A PowerShell module for managing Microsoft Endpoint Configuration Manager (MECM) via CIM.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-blue)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-brightgreen)

## 📋 Table of Contents

- [Overview](#-overview)
- [Requirements](#requirements)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Available Functions](#-available-functions)
- [Testing](#testing)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [TroubleShooting](#troubleshooting)
- [Important Notes](#️-important-notes)
- [Support](#support)
- [License](#-license)

## 🎯 Overview

The MECM7 PowerShell module provides a collection of PowerShell functions for common MECM administration tasks. The module works with PowerShell 5.1+ and PowerShell 7.x, using CIM (Common Information Model) cmdlets for remote management via WinRM.

The most commands in the legacy ConfigurationManager module are dependent on WMI which isn't anymore possible in PowerShell 7.x. Importing the ConfigurationManager Module with parameter `UseWindowsPowerShell` brings multiple disadvantages.

## Requirements

- **PowerShell**: 5.1 or higher (tested with PowerShell 7.5.4)
- **WinRM**: Must be enabled on the SMS Provider server
- **Credentials**: A user account with MECM administrative privileges
- **Network**: Access to the MECM SMS Provider server (WinRM port 5985/5986)

## 📦 Installation

1. Clone or download the module to your PowerShell modules directory:

   ```powershell
   $ModulePath = Join-Path $PROFILE .. "Modules"
   git clone <repo-url> $ModulePath\MECM7
   ```

2. Import the module:

   ```powershell
   Import-Module MECM7
   ```

## 🚀 Quick Start

### Connect to MECM

```powershell
# Basic connection using current user credentials
Connect-CM7 -SiteServer "mecm.yourdomain.local"

# Connection with specific credentials
$cred = Get-Credential
Connect-CM7 -SiteServer "mecm.yourdomain.local" -Credential $cred

# Connection with certificate bypass (for self-signed certificates)
Connect-CM7 -SiteServer "mecm.yourdomain.local" -SkipCertificateCheck
```

### Use Module Functions

Once connected with `Connect-CM7`, other module functions can use the stored connection:

```powershell
# Get device information
Get-CM7Device -Name "COMPUTER01"
```

other functions will be described in the [Help](./Help/README.md) folder

## 📚 Available Functions

This is a short incomplete overview of available commands:

### Collection Management

- [`Add-CM7CollectionMembershipRule`](./Help/Add-CM7CollectionMembershipRule.md) - Add a membership rule (direct, query, include, or exclude) to a collection
- [`Get-CM7Collection`](./Help/Get-CM7Collection.md) - Retrieve collection information from MECM
- [`Get-CM7CollectionMember`](./Help/Get-CM7CollectionMember.md) - Retrieve all members of a collection
- [`Get-CM7CollectionDirectMembership`](./Help/Get-CM7CollectionDirectMembership.md) - Retrieve direct members of a collection
- [`Get-CM7CollectionExcludeMembershipRule`](./Help/Get-CM7CollectionExcludeMembershipRule.md) - Retrieve exclude membership rules for a collection
- [`Get-CM7CollectionIncludeMembershipRule`](./Help/Get-CM7CollectionIncludeMembershipRule.md) - Retrieve include membership rules for a collection
- [`Get-CM7CollectionQueryMembershipRule`](./Help/Get-CM7CollectionQueryMembershipRule.md) - Retrieve query membership rules for a collection
- [`Get-CM7CollectionVariable`](./Help/Get-CM7CollectionVariable.md) - Retrieve collection variables from a collection
- [`Get-CM7DeviceCollection`](./Help/Get-CM7DeviceCollection.md) - Retrieve device collection information from MECM
- [`Get-CM7DeviceVariable`](./Help/Get-CM7DeviceVariable.md) - Retrieve device variables from a MECM device
- [`Get-CM7MaintenanceWindow`](./Help/Get-CM7MaintenanceWindow.md) - Retrieve maintenance windows from a collection
- [`Get-CM7UserCollection`](./Help/Get-CM7UserCollection.md) - Retrieve user collection information from MECM
- [`Invoke-CM7CollectionUpdate`](./Help/Invoke-CM7CollectionUpdate.md) - Trigger a collection membership evaluation (refresh) on a MECM collection
- [`New-CM7Collection`](./Help/New-CM7Collection.md) - Create a new device or user collection in MECM
- [`New-CM7DeviceCollectionVariable`](./Help/New-CM7DeviceCollectionVariable.md) - Create a new collection variable on a device collection
- [`New-CM7DeviceVariable`](./Help/New-CM7DeviceVariable.md) - Create a new device variable on a MECM device
- [`New-CM7MaintenanceWindow`](./Help/New-CM7MaintenanceWindow.md) - Create a new maintenance window on a collection
- [`Remove-CM7Collection`](./Help/Remove-CM7Collection.md) - Remove a device or user collection from MECM
- [`Remove-CM7CollectionMembershipRule`](./Help/Remove-CM7CollectionMembershipRule.md) - Remove a membership rule (direct, query, include, or exclude) from a collection
- [`Remove-CM7DeviceCollectionVariable`](./Help/Remove-CM7DeviceCollectionVariable.md) - Remove a collection variable from a device collection
- [`Remove-CM7DeviceVariable`](./Help/Remove-CM7DeviceVariable.md) - Remove a device variable from a MECM device
- [`Remove-CM7MaintenanceWindow`](./Help/Remove-CM7MaintenanceWindow.md) - Remove a maintenance window from a collection

### Deployment Management

- [`Get-CM7Deployment`](./Help/Get-CM7Deployment.md) - Retrieve deployment information from MECM

### Folder Management

- [`Get-CM7Folder`](./Help/Get-CM7Folder.md) - Retrieves folder information from MECM using CIM.
- [`Move-CM7Object`](./Help/Move-CM7Object.md) - Move MECM objects (collections, packages, etc.) between folders
- [`New-CM7Folder`](./Help/New-CM7Folder.md) - Createss a new folder in MECM using CIM.
- [`Remove-CM7Folder`](./Help/Remove-CM7Folder) - Removes an existing folder in MECM using CIM.
- [`Set-CM7Folder`](./Help/Set-CM7Folder) - Renames or moves an existing folder in MECM using CIM.

### Schedule Management

- [`New-CM7Schedule`](./Help/New-CM7Schedule.md) - Create an SMS schedule token for use with MECM CIM-based functions

### Script Management

- [`Invoke-CM7Script`](./Help/Invoke-CM7Script.md) - Invoke (run) an approved MECM script on target devices or a collection
- [`Invoke-CM7ClientNotification`](./Help/Invoke-CM7ClientNotification.md) - Send a client notification action (policy refresh, inventory, restart, etc.) to target devices or a collection
- [`Get-CM7ScriptExecutionStatus`](./Help/Get-CM7ScriptExecutionStatus.md) - Retrieve the execution status and results of MECM scripts

### Software Update Management

- [`Get-CM7SoftwareUpdate`](./Help/Get-CM7SoftwareUpdate.md) - Retrieve software update information from MECM
- [`Get-CM7SoftwareUpdateDeployment`](./Help/Get-CM7SoftwareUpdateDeployment.md) - Retrieve software update deployment information from MECM
- [`Get-CM7SoftwareUpdateDeploymentPackage`](./Help/Get-CM7SoftwareUpdateDeploymentPackage.md) - Retrieve software update deployment package information from MECM
- [`Get-CM7SoftwareUpdateGroup`](./Help/Get-CM7SoftwareUpdateGroup.md) - Retrieve software update group information from MECM
- [`New-CM7SoftwareUpdateGroup`](./Help/New-CM7SoftwareUpdateGroup.md) - Create a new software update group in MECM
- [`Add-CM7SoftwareUpdateToGroup`](./Help/Add-CM7SoftwareUpdateToGroup.md) - Add software updates to a software update group in MECM
- [`New-CM7SoftwareUpdateDeployment`](./Help/New-CM7SoftwareUpdateDeployment.md) - Create a new software update deployment in MECM
- [`New-CM7SoftwareUpdateDeploymentPackage`](./Help/New-CM7SoftwareUpdateDeploymentPackage.md) - Create a new software update deployment package in MECM
- [`Remove-CM7SoftwareUpdateDeployment`](./Help/Remove-CM7SoftwareUpdateDeployment.md): Removes a software update deployment from a collection using CIM connectivity. See Help/Remove-CM7SoftwareUpdateDeployment.md for details.
- [`Remove-CM7SoftwareUpdateDeploymentPackage`](./Help/Remove-CM7SoftwareUpdateDeploymentPackage.md) - Remove a software update deployment package from MECM
- [`Remove-CM7SoftwareUpdateGroup`](./Help/Remove-CM7SoftwareUpdateGroup.md) - Remove a software update group from MECM
- [`Sync-CM7SoftwareUpdate`](./Help/Sync-CM7SoftwareUpdate.md) - Synchronizes software updates metadata in MECM using CIM connectivity.

### Task Sequence Management

- [`Get-CM7TaskSequence`](./Help/Get-CM7TaskSequence.md) - Retrieve task sequence information from MECM
- [`Get-CM7TaskSequenceDeployment`](./Help/Get-CM7TaskSequenceDeployment.md) - Retrieve task sequence deployment information from MECM
- [`New-CM7TaskSequenceDeployment`](./Help/New-CM7TaskSequenceDeployment.md) - Create a new task sequence deployment in MECM
- [`Set-CM7TaskSequenceDeployment`](./Help/Set-CM7TaskSequenceDeployment.md) - Configure an existing task sequence deployment in MECM
- [`Remove-CM7TaskSequenceDeployment`](./Help/Remove-CM7TaskSequenceDeployment.md) - Remove a task sequence deployment from MECM

### User Management

- [`Get-CM7User`](./Help/Get-CM7User.md) - Retrieve user information from MECM using CIM connectivity (CIM-based equivalent of Get-CMUser)

### Infrastructure Management

#### Boundaries

- [`Get-CM7Boundary`](./Help/Get-CM7Boundary.md) - Retrieve existing boundary informations from MECM
- [`New-CM7Boundary`](./Help/New-CM7Boundary.md) - Creates a new boundary in MECM
- [`Remove-CM7Boundary`](./Help/Remove-VM7Boundary.md) - Removes an existing boundary from MECM
- [`Set-CM7Boundary`](./Help/Set-VM7Boundary.md) - Modifies an existing boundary from MECM

## Testing

The module includes comprehensive Pester tests:

```powershell
# Run tests for Connect-CM7
Invoke-Pester -Path ".\Tests\Test-Connect-CM7.Tests.ps1"

# Run tests for Get-CM7Device
Invoke-Pester -Path ".\Tests\Test-Get-CM7Device.Tests.ps1"

# Run tests for Get-CM7Collection
Invoke-Pester -Path ".\Tests\Test-Get-CM7Collection.Tests.ps1"

...

# Run all tests
Invoke-Pester -Path ".\Tests\"

# Test results show coverage of:
# - Unit tests for parameter validation
# - Integration tests against live MECM server
# - Connection establishment and SMS Provider discovery
# - Device query functionality and filtering
# - Collection query functionality and filtering
```

### Test Configuration

Test credentials and site server information are configured in:
- `Tests/declarations.ps1` - Your test environment configuration
- `Tests/declarations_sample_v2.ps1` - Template for new environments

Copy `declarations_sample_v2.ps1` to `declarations.ps1` and update with your test environment details.

## Key Features

- **CIM Access**: Direct access to MECM WMI classes via CIM cmdlets
- **PowerShell 7 Compatible**: Works with modern PowerShell versions
- **Certificate Handling**: Built-in support for self-signed certificates
- **Credential Management**: Secure credential handling
- **Module-Scoped Variables**: Connection information stored module-wide for reuse

## Architecture

The module follows this pattern:

```
MECM7/
├── CI/
│   ├── Build-Module.ps1
│   ├── Create-ModuleDocumentation.ps1
│   └── Module-Settings.json
├── Code/
│   ├── Public/          # User-facing functions
│   │   ├── Connect-CM7.ps1
│   │   ├── Get-CM7Device.ps1
│   │   ├── Get-CM7Collection.ps1
│   │   └── ...
│   └── Private/         # Internal helper functions
│       ├── Invoke-CM7Connection.ps1
│       └── ...
├── Examples/            # Usage examples
├── MECM7/               # Module-Versions export
│   ├── 0.01.00001
│   │   ├── MECM7.psd1
│   │   └── MECM7.psm1
│   ├── 0.01.00002
│   └── ...
├── Tests/               # Pester test files
│   ├── Test-Connect-CM7.Tests.ps1
│   ├── Test-Get-CM7Device.Tests.ps1
│   ├── Test-Get-CM7Collection.Tests.ps1
│   └── ...
└── Help/                # Function documentation
    ├── README.md
    ├── Connect-CM7.md
    ├── Get-CM7Device.md
    ├── Get-CM7Collection.md
    └── ...

```

## Troubleshooting

### "Access is denied" when connecting

This typically indicates one of:
1. **Invalid credentials** - Verify username and password
2. **Insufficient permissions** - User must have MECM administrative rights
3. **WinRM not enabled** - Verify WinRM is running on the SMS Provider: `Test-WSMan -ComputerName <server>`
4. **Network connectivity** - Ensure network access to the SMS Provider server

### "SMS Provider location not found"

- Verify the site server name is correct
- Ensure the user has permissions to query the SMS Provider
- Check the site code is correct

### Certificate validation errors

Use the `-SkipCertificateCheck` parameter if using self-signed certificates:

```powershell
Connect-CM7 -SiteServer "your-server" -SkipCertificateCheck
```

## ⚠️ Important Notes

### AI-Assisted Development

Most functions in this module were developed with the assistance of AI (GitHub Copilot). All code has been reviewed, tested, and validated against live MECM environments.

### Differences from the ConfigurationManager Module

This module is **not** a drop-in replacement for the official ConfigurationManager module. Some functions may have:

- **Different parameter names or parameter sets** compared to their ConfigurationManager equivalents
- **Different output types** — functions return CIM instances or custom objects rather than the ConfigurationManager module's proprietary types
- **Different default behavior** — filtering, sorting, or result formatting may differ

Always refer to the [function documentation](./Help/README.md) for the exact parameters and output of each function.

## Support

For issues, questions, or contributions, refer to the project documentation or contact the module maintainers.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
