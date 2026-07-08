function Invoke-CM7Connection {
    <#
        .SYNOPSIS
            Establishes a CIM session to an MECM SMS Provider and retrieves connection information.

        .DESCRIPTION
            This is a private helper function that creates a CIM session to a specified MECM/SCCM
            site server and discovers the SMS Provider location via WMI queries.

            The function:
            1. Creates a CIM session to the specified site server
            2. Queries the SMS_ProviderLocation class in root\SMS namespace
            3. Retrieves the site code and provider machine name
            4. Returns connection details for use by other MECM7 functions

            This function is called internally by Connect-CM7 and should not be called directly.

        .PARAMETER SiteServer
            The hostname or IP address of the MECM site server or SMS Provider.
            This server must have WinRM enabled and accessible.

        .PARAMETER Credential
            Optional. A PSCredential object for authentication to the site server.
            If not provided, the current user's credentials are used.

        .PARAMETER UseSsl
            Use HTTPS for WinRM communication instead of HTTP.

        .PARAMETER SkipCertificateCheck
            Skip certificate validation when using SSL. Useful for self-signed certificates.

        .PARAMETER AddToTrustedHosts
            Adds the SiteServer to the WinRM TrustedHosts list before connecting.
            Required when the client computer is not domain-joined or is in a different domain/workgroup.
            Requires running PowerShell as Administrator.

        .OUTPUTS
            PSCustomObject with the following properties:
            - CimSession: The established CIM session object
            - SiteCode: The MECM site code (e.g., "CM1")
            - ProviderMachineName: The machine name of the SMS Provider

        .EXAMPLE
            $connection = Invoke-CM7Connection -SiteServer "mecm.contoso.local"

            Establishes a CIM session to the MECM server and returns connection details.

        .EXAMPLE
            $cred = Get-Credential
            $connection = Invoke-CM7Connection -SiteServer "mecm.contoso.local" -Credential $cred -UseSsl -SkipCertificateCheck

            Establishes a CIM session with specific credentials and SSL configuration.

        .NOTES
            This is an internal helper function for the MECM7 module.

            Error Handling:
            - If CIM session creation fails, an error is thrown with details
            - If SMS Provider location cannot be found, the CIM session is automatically closed and an error is thrown
            - The function properly cleans up resources on failure

        .LINK
            Connect-CM7
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteServer,
        [Parameter()]
        [pscredential]$Credential,
        [Parameter()]
        [switch]$UseSsl,
        [Parameter()]
        [switch]$SkipCertificateCheck,
        [Parameter()]
        [switch]$AddToTrustedHosts
    )

    # Add SiteServer to WinRM TrustedHosts if requested (needed for non-domain or cross-domain connections)
    if ($AddToTrustedHosts) {
        Write-Verbose "Adding $SiteServer to WinRM TrustedHosts..."
        try {
            $currentTrustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction Stop).Value
            if ($currentTrustedHosts -notmatch [regex]::Escape($SiteServer)) {
                $newValue = if ([string]::IsNullOrEmpty($currentTrustedHosts)) { $SiteServer } else { "$currentTrustedHosts,$SiteServer" }
                Set-Item WSMan:\localhost\Client\TrustedHosts -Value $newValue -Force -ErrorAction Stop
                Write-Verbose "Added $SiteServer to TrustedHosts."
            } else {
                Write-Verbose "$SiteServer is already in TrustedHosts."
            }
        }
        catch {
            throw "Failed to modify TrustedHosts. Ensure you are running as Administrator. Error: $($_.Exception.Message)"
        }
    }

    # Build CIM session parameters
    $cimParams = @{
        ComputerName = $SiteServer
    }
    if ($Credential) { $cimParams.Credential = $Credential }

    # Only create SessionOption if special options are needed
    if ($UseSsl -or $SkipCertificateCheck) {
        $sessionOptions = New-CimSessionOption -Protocol Wsman

        if ($UseSsl) {
            $sessionOptions.UseSsl = $true
        }
        if ($SkipCertificateCheck) {
            $sessionOptions.CertCACheck = $false
            $sessionOptions.CertCNCheck = $false
            $sessionOptions.CertRevocationCheck = $false
        }

        $cimParams.SessionOption = $sessionOptions
    }

    # Create CIM session - this should not have nested try/catch
    try {
        Write-Verbose "Creating CIM session to $SiteServer..."
        $cimSession = New-CimSession @cimParams
    }
    catch {
        $errorMessage = "Failed to create CIM session to $SiteServer. $($_.Exception.Message)"
        Write-Error -Message $errorMessage -ErrorAction Stop
        return
    }

    # Verify CIM session was created successfully
    if (-not $cimSession) {
        throw "Failed to create CIM session to $SiteServer. Session is null."
    }

    # Query SMS Provider location - separate from session creation
    try {
        Write-Verbose "Querying SMS Provider location..."
        $provider = Get-CimInstance -CimSession $cimSession -Namespace "root\SMS" -ClassName "SMS_ProviderLocation" -ErrorAction Stop |
            Where-Object { $_.ProviderForLocalSite -eq $true } |
            Select-Object -First 1

        if (-not $provider) {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
            throw "SMS Provider location not found in root\SMS on $SiteServer."
        }

        Write-Verbose "Connected to MECM site $($provider.SiteCode) on $($provider.Machine)"

        return [PSCustomObject]@{
            CimSession = $cimSession
            SiteCode = $provider.SiteCode
            ProviderMachineName = $provider.Machine
        }
    }
    catch {
        if ($cimSession) {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
        }
        throw $_
    }
}
