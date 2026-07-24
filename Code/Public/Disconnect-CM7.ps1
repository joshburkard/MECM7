function Disconnect-CM7 {
    <#
    .SYNOPSIS
        Disconnects from the current CM7 session.

    .DESCRIPTION
        Clears the current CM7 connection information stored in the script scope.

    .EXAMPLE
        Disconnect-CM7
    #>
    [CmdletBinding()]
    param (
    )

    try {
        $ComputerName = $script:CMConnection.SiteServer
        $script:CMConnection.CimSession | ForEach-Object {
            if ($_.State -eq 'Opened') {
                Write-Verbose "Closing CIM session to $ComputerName..."
                $_.Close()
            }
            try {
                Remove-CimSession -CimSession $_ -ErrorAction SilentlyContinue
            } catch {
                Write-Verbose "Failed to remove CIM session to $ComputerName. Error: $_"
            }
        }

        if (-not $ComputerName) {
            Write-Warning "No active CM7 connection found. Nothing to disconnect."
            return
        }

        Write-Verbose "Attempting to disconnect from CM7 on $ComputerName..."

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

        Write-Output "Successfully disconnected from CM7 on $ComputerName."
    } catch {
        Write-Error "Failed to disconnect from CM7 on $ComputerName. Error: $_"
    }
}
