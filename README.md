# MECM7 PowerShell Module

A PowerShell module for managing Microsoft Endpoint Configuration Manager (MECM) via CIM.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-blue)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)

## 📋 Table of Contents

- [Overview](#-overview)


## 🎯 Overview

MECM7 provides a collection of PowerShell functions for common MECM administration tasks. The module works with PowerShell 5.1+ and PowerShell 7.x, using CIM (Common Information Model) cmdlets for remote management via WinRM.

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

### Connection Management

- [`Connect-CM7`](./Help/Connect-CM7.md) - Establish a connection to MECM through WinRM/CIM

### Device Management

- [`Get-CM7Device`](./Help/Get-CM7Device.md) - Retrieve device information from MECM

### Collection Management

- [`Get-CM7Collection`](./Help/Get-CM7Collection.md) - Retrieve collection information from MECM
- [`New-CM7Collection`](./Help/New-CM7Collection.md) - Create a new device or user collection in MECM
- [`Remove-CM7Collection`](./Help/Remove-CM7Collection.md) - Remove a device or user collection from MECM
- [`Get-CM7CollectionMember`](./Help/Get-CM7CollectionMember.md) - Retrieve all members of a collection using CIM
- [`Get-CM7CollectionDirectMembership`](./Help/Get-CM7CollectionDirectMembership.md) - Retrieve direct members of a collection using CIM
- [`Get-CM7CollectionExcludeMembershipRule`](./Help/Get-CM7CollectionExcludeMembershipRule.md) - Retrieve exclude membership rules for a collection using CIM
- [`Get-CM7CollectionIncludeMembershipRule`](./Help/Get-CM7CollectionIncludeMembershipRule.md) - Retrieve include membership rules for a collection using CIM
- [`Get-CM7CollectionQueryMembershipRule`](./Help/Get-CM7CollectionQueryMembershipRule.md) - Retrieve query membership rules for a collection using CIM
- [`Add-CM7CollectionMembershipRule`](./Help/Add-CM7CollectionMembershipRule.md) - Add a membership rule (direct, query, include, or exclude) to a collection using CIM
- [`Remove-CM7CollectionMembershipRule`](./Help/Remove-CM7CollectionMembershipRule.md) - Remove a membership rule (direct, query, include, or exclude) from a collection using CIM
- [`Get-CM7CollectionVariable`](./Help/Get-CM7CollectionVariable.md) - Retrieve collection variables from a collection using CIM
- [`New-CM7DeviceCollectionVariable`](./Help/New-CM7DeviceCollectionVariable.md) - Create a new collection variable on a device collection using CIM
- [`Remove-CM7DeviceCollectionVariable`](./Help/Remove-CM7DeviceCollectionVariable.md) - Remove a collection variable from a device collection using CIM
- [`Get-CM7DeviceVariable`](./Help/Get-CM7DeviceVariable.md) - Retrieve device variables from a MECM device using CIM
- [`New-CM7DeviceVariable`](./Help/New-CM7DeviceVariable.md) - Create a new device variable on a MECM device using CIM
- [`Remove-CM7DeviceVariable`](./Help/Remove-CM7DeviceVariable.md) - Remove a device variable from a MECM device using CIM
- [`Get-CM7MaintenanceWindow`](./Help/Get-CM7MaintenanceWindow.md) - Retrieve maintenance windows from a collection using CIM
- [`New-CM7MaintenanceWindow`](./Help/New-CM7MaintenanceWindow.md) - Create a new maintenance window on a collection using CIM
- [`Remove-CM7MaintenanceWindow`](./Help/Remove-CM7MaintenanceWindow.md) - Remove a maintenance window from a collection using CIM

### Object Management

- [`Move-CM7Object`](./Help/Move-CM7Object.md) - Move MECM objects (collections, packages, etc.) between folders using CIM

## Testing

The module includes comprehensive Pester tests:

```powershell
# Run tests for Connect-CM7
Invoke-Pester -Path ".\Tests\Test-Connect-CM7.Tests.ps1"

# Run tests for Get-CM7Device
Invoke-Pester -Path ".\Tests\Test-Get-CM7Device.Tests.ps1"

# Run tests for Get-CM7Collection
Invoke-Pester -Path ".\Tests\Test-Get-CM7Collection.Tests.ps1"

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
├── Code/
│   ├── Public/          # User-facing functions
│   │   ├── Connect-CM7.ps1
│   │   ├── Get-CM7Device.ps1
│   │   ├── Get-CM7Collection.ps1
│   │   ├── Get-CM7CollectionMember.ps1
│   │   ├── Get-CM7CollectionDirectMembership.ps1
│   │   ├── Get-CM7CollectionExcludeMembershipRule.ps1
│   │   ├── Get-CM7CollectionIncludeMembershipRule.ps1
│   │   ├── Get-CM7CollectionQueryMembershipRule.ps1
│   │   ├── Add-CM7CollectionMembershipRule.ps1
│   │   ├── Remove-CM7CollectionMembershipRule.ps1
│   │   ├── Get-CM7CollectionVariable.ps1
│   │   ├── New-CM7DeviceCollectionVariable.ps1
│   │   ├── Get-CM7DeviceVariable.ps1
│   │   ├── New-CM7DeviceVariable.ps1
│   │   ├── Remove-CM7DeviceVariable.ps1
│   │   ├── Move-CM7Object.ps1
│   │   ├── New-CM7Collection.ps1
│   │   ├── New-CM7MaintenanceWindow.ps1
│   │   ├── Remove-CM7MaintenanceWindow.ps1
│   │   ├── Remove-CM7Collection.ps1
│   │   └── ...
│   └── Private/         # Internal helper functions
│       ├── Invoke-CM7Connection.ps1
│       └── ...
├── Tests/               # Pester test files
│   ├── Test-Connect-CM7.Tests.ps1
│   ├── Test-Get-CM7Device.Tests.ps1
│   ├── Test-Get-CM7Collection.Tests.ps1
│   ├── Test-Get-CM7CollectionMember.Tests.ps1
│   ├── Test-Get-CM7CollectionDirectMembership.Tests.ps1
│   ├── Test-Get-CM7CollectionExcludeMembershipRule.Tests.ps1
│   ├── Test-Get-CM7CollectionIncludeMembershipRule.Tests.ps1
│   ├── Test-Get-CM7CollectionQueryMembershipRule.Tests.ps1
│   ├── Test-Add-CM7CollectionMembershipRule.Tests.ps1
│   ├── Test-Remove-CM7CollectionMembershipRule.Tests.ps1
│   ├── Test-Get-CM7CollectionVariable.Tests.ps1
│   ├── Test-New-CM7DeviceCollectionVariable.Tests.ps1
│   ├── Test-Remove-CM7DeviceCollectionVariable.Tests.ps1
│   ├── Test-Get-CM7DeviceVariable.Tests.ps1
│   ├── Test-New-CM7DeviceVariable.Tests.ps1
│   ├── Test-Remove-CM7DeviceVariable.Tests.ps1
│   ├── Test-Move-CM7Object.Tests.ps1
│   ├── Test-New-CM7Collection.Tests.ps1
│   ├── Test-New-CM7MaintenanceWindow.Tests.ps1
│   ├── Test-Remove-CM7MaintenanceWindow.Tests.ps1
│   ├── Test-Remove-CM7Collection.Tests.ps1
│   ├── declarations.ps1
│   └── declarations_sample.ps1
├── Help/                # Function documentation
│   ├── Connect-CM7.md
│   ├── Get-CM7Device.md
│   ├── Get-CM7Collection.md
│   ├── Get-CM7CollectionMember.md
│   ├── Get-CM7CollectionDirectMembership.md
│   ├── Get-CM7CollectionExcludeMembershipRule.md
│   ├── Get-CM7CollectionIncludeMembershipRule.md
│   ├── Get-CM7CollectionQueryMembershipRule.md
│   ├── Add-CM7CollectionMembershipRule.md
│   ├── Remove-CM7CollectionMembershipRule.md
│   ├── Get-CM7CollectionVariable.md
│   ├── New-CM7DeviceCollectionVariable.md
│   ├── Remove-CM7DeviceCollectionVariable.md
│   ├── Get-CM7DeviceVariable.md
│   ├── New-CM7DeviceVariable.md
│   ├── Remove-CM7DeviceVariable.md
│   ├── Move-CM7Object.md
│   ├── New-CM7Collection.md
│   ├── New-CM7MaintenanceWindow.md
│   ├── Remove-CM7MaintenanceWindow.md
│   ├── Remove-CM7Collection.md
│   └── ...
└── Examples/            # Usage examples
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

## Support

For issues, questions, or contributions, refer to the project documentation or contact the module maintainers.

## License

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
