# Connect-CM7

## SYNOPSIS

Establishes a connection to a Microsoft Endpoint Configuration Manager (MECM) site server.

## DESCRIPTION

The `Connect-CM7` function establishes a CIM (Common Information Model) connection to the SMS Provider on your MECM site server. This connection is required before using other MECM7 module functions.

The function performs the following actions:

1. Creates a CIM session to the specified site server using WinRM
2. Discovers the SMS Provider location from the WMI `SMS_ProviderLocation` class
3. Extracts and validates the site code
4. Stores connection information in module-scoped variables for reuse by other functions

The connection details are stored in `$script:CMConnection` hashtable containing:
- `SiteServer` - The site server name
- `SiteCode` - The three-character site code
- `ProviderMachineName` - The SMS Provider server name
- `CimSession` - The active CIM session object
- `Credential` - The credentials used (if provided)
- `SkipCertificateCheck` - Certificate validation bypass flag
- `UseSsl` - SSL flag for future HTTPS connections

## PARAMETERS

### -SiteServer

Specifies the fully qualified domain name (FQDN) or IP address of the MECM site server.

- **Type**: String
- **Position**: Named
- **Default**: None
- **Required**: Yes
- **Accept pipeline input**: False
- **Accept wildcard characters**: False

Example: `mecm.yourdomain.local` or `192.168.1.100`

### -Credential

Specifies a PSCredential object (username and password) to use for authentication. If not specified, the current user's credentials are used.

- **Type**: PSCredential
- **Position**: Named
- **Default**: Current user credentials
- **Required**: No
- **Accept pipeline input**: False
- **Accept wildcard characters**: False

Example: `(Get-Credential)`

### -SkipCertificateCheck

When specified, SSL certificate validation is bypassed. Use this when:
- The SMS Provider uses self-signed certificates
- There are certificate chain validation issues
- Testing in non-production environments

Important: Only use when necessary, as this reduces security.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Accept pipeline input**: False

### -UseSsl

Specifies that SSL (HTTPS) should be used instead of standard HTTP for the WinRM connection.

Note: The target server must have HTTPS WinRM configured on port 5986.

- **Type**: SwitchParameter
- **Position**: Named
- **Default**: False
- **Required**: No
- **Accept pipeline input**: False

## EXAMPLES

### EXAMPLE 1: Connect using current user credentials

```powershell
Connect-CM7 -SiteServer "mecm.yourdomain.local"
```

Connects to the MECM site server using the currently logged-in user's credentials. This is the simplest approach when the current user has appropriate permissions.

### EXAMPLE 2: Connect using specific credentials

```powershell
$cred = Get-Credential -UserName "contoso\cm_admin" -Message "Enter MECM admin credentials"
Connect-CM7 -SiteServer "mecm.yourdomain.local" -Credential $cred
```

Prompts for credentials and uses them to connect. Useful when running scripts with different privilege levels or remote execution.

### EXAMPLE 3: Connect with certificate bypass for self-signed certificates

```powershell
Connect-CM7 -SiteServer "mecm.yourdomain.local" -SkipCertificateCheck
```

Bypasses SSL certificate validation, allowing connection to servers with self-signed or invalid certificates. Common in lab and test environments.

### EXAMPLE 4: Connect and use returned connection info

```powershell
$connectionInfo = Connect-CM7 -SiteServer "mecm.yourdomain.local"
Write-Host "Connected to site: $($connectionInfo.SiteCode)"
Write-Host "Provider server: $($connectionInfo.ProviderMachineName)"
```

The function returns a PSCustomObject with connection details:
- `SiteServer` - Site server FQDN/IP
- `SiteCode` - Three-character site code (e.g., "CM1")
- `ProviderMachineName` - SMS Provider machine name
- `CimSessionId` - The CIM session ID for reference

### EXAMPLE 5: Connect with all parameters

```powershell
$cred = Get-Credential
Connect-CM7 -SiteServer "mecm.yourdomain.local" `
    -Credential $cred `
    -SkipCertificateCheck `
    -UseSsl
```

Full connection with explicit credentials, certificate bypass, and SSL/HTTPS.

## OUTPUTS

### PSCustomObject

The function returns a custom object with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| SiteServer | string | The MECM site server name |
| SiteCode | string | The three-character site code |
| ProviderMachineName | string | The SMS Provider server name |
| CimSessionId | string | The ID of the CIM session |

Additionally, connection information is stored in `$script:CMConnection` for use by other module functions:

```powershell
$script:CMConnection = @{
    SiteServer = "mecm.yourdomain.local"
    SiteCode = "CM1"
    ProviderMachineName = "mecm.yourdomain.local"
    CimSession = <CimSession object>
    Credential = <PSCredential object> # or $null
    SkipCertificateCheck = $true/$false
    UseSsl = $true/$false
}
```

## NOTES

### Requirements

- **PowerShell Version**: 5.1 or higher
- **WinRM**: Must be enabled on the SMS Provider server
- **Permissions**: User account must have MECM administrative rights
- **Network**: Access to WinRM port 5985 (HTTP) or 5986 (HTTPS)
- **CIM Module**: Must be available (included with PowerShell 5.1+)

### WinRM Verification

Before connecting, verify WinRM is accessible:

```powershell
Test-WSMan -ComputerName "mecm.yourdomain.local"
```

If unreachable, on the target server run:

```powershell
winrm quickconfig
```

### Connection Persistence

The connection is stored in module-scoped variables and persists for the PowerShell session. Subsequent MECM7 functions automatically use the stored connection.

To disconnect, use:

```powershell
Remove-CimSession -CimSession $script:CMConnection.CimSession
$script:CMConnection = $null
```

### Error Handling

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| "Access is denied" | Invalid credentials or insufficient permissions | Verify credentials and MECM admin rights |
| "SMS Provider location not found" | Cannot access WMI namespace | Verify user has permissions to SMS namespace |
| "The client cannot connect to the destination" | WinRM not running or firewalled | Enable WinRM on target server |
| "Cannot bind argument parameter 'CimSession' because it is null" | Function called without active connection | Run `Connect-CM7` first |

### Performance

For production scripts, consider:
- Reusing the same connection for multiple operations
- Closing unused connections: `Remove-CimSession -CimSession $session`
- Using connection timeouts for long operations

## RELATED LINKS

- [Get-CimInstance](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance)
- [New-CimSession](https://docs.microsoft.com/en-us/powershell/module/cimcmdlets/new-cimsession)
- [Test-WSMan](https://docs.microsoft.com/en-us/powershell/module/wsman/test-wsman)
- [MECM7 README](../README.md)
- [Help Directory](README.md)
