function Connect-CM7 {
    <#
        .SYNOPSIS
            Connects to a MECM site using CIM over WinRM.

        .DESCRIPTION
            Creates a CIM session to the target site server, discovers the SMS Provider
            location via root\SMS, and stores connection details for later commands.

        .PARAMETER SiteServer
            The hostname or IP address of the MECM site server or SMS Provider.

        .PARAMETER Credential
            Optional. A PSCredential object for authentication.

        .PARAMETER UseSsl
            Use HTTPS for WinRM.

        .PARAMETER SkipCertificateCheck
            Skip certificate checks when using SSL.

        .PARAMETER AddToTrustedHosts
            Adds the SiteServer to the WinRM TrustedHosts list before connecting.
            Required when the client computer is not domain-joined or is in a different domain/workgroup.
            Requires running PowerShell as Administrator.

        .EXAMPLE
            Connect-CM7 -SiteServer "mecm.contoso.local"

        .EXAMPLE
            $cred = Get-Credential
            Connect-CM7 -SiteServer "mecm.contoso.local" -Credential $cred -UseSsl -SkipCertificateCheck
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

    try {
        # Call the private function with direct parameters to avoid splatting issues with switches
        $connectionInfo = Invoke-CM7Connection -SiteServer $SiteServer -Credential:$Credential -UseSsl:$UseSsl -SkipCertificateCheck:$SkipCertificateCheck -AddToTrustedHosts:$AddToTrustedHosts

        $script:CMConnection = @{
            SiteServer = $SiteServer
            CimSession = $connectionInfo.CimSession
            SiteCode = $connectionInfo.SiteCode
            ProviderMachineName = $connectionInfo.ProviderMachineName
            SkipCertificateCheck = [bool]$SkipCertificateCheck
            UseSsl = [bool]$UseSsl
            AddToTrustedHosts = [bool]$AddToTrustedHosts
            Credential = if ($Credential) { $Credential } else { $null }
        }

        Write-Verbose "Connected to $SiteServer (SiteCode: $($script:CMConnection.SiteCode), Provider: $($script:CMConnection.ProviderMachineName))"

        return [PSCustomObject]@{
            SiteServer = $script:CMConnection.SiteServer
            SiteCode = $script:CMConnection.SiteCode
            ProviderMachineName = $script:CMConnection.ProviderMachineName
            CimSessionId = $script:CMConnection.CimSession.Id
        }
    }
    catch {
        throw $_
    }
}

# Module-scoped variables
$script:CMConnection = @{
    SiteServer = $null
    CimSession = $null
    SiteCode = $null
    ProviderMachineName = $null
    Credential = $null
    SkipCertificateCheck = $false
    UseSsl = $false
    AddToTrustedHosts = $false
}
