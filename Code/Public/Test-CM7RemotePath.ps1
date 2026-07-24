function Test-CM7RemotePath {
    <#
        .SYNOPSIS
            Tests whether a path is accessible from the MECM server side.

        .DESCRIPTION
            Opens a temporary PSSession to the MECM server using the credentials stored by Connect-CM7,
            then runs Test-Path on the remote server. This ensures the path check reflects the server's
            perspective (e.g. UNC paths that the MECM service account can reach) rather than the local
            client's perspective.

        .PARAMETER Path
            The path to test. Typically a UNC path (e.g. \\server\share\folder).

        .OUTPUTS
            [bool] $true if the path exists and is a container (directory) on the MECM server, $false otherwise.

        .EXAMPLE
            if (-not (Test-CM7RemotePath -Path "\\fileserver\share\MECM\Patches")) {
                throw "Path is not accessible from the MECM server."
            }

        .NOTES
            This is an internal helper function for the MECM7 module and is not intended to be called directly by users.
            Requires an active connection via Connect-CM7.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $sessionParams = @{
        ComputerName = $script:CMConnection.SiteServer
        ErrorAction  = 'Stop'
    }
    if ($script:CMConnection.Credential) {
        $sessionParams.Credential = $script:CMConnection.Credential
    }
    if ($script:CMConnection.UseSsl) {
        $sessionParams.UseSSL = $true
    }
    if ($script:CMConnection.SkipCertificateCheck) {
        $sessionParams.SessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
    }

    $psSession = New-PSSession @sessionParams
    try {
        return Invoke-Command -Session $psSession -ScriptBlock {
            param($p)
            try {
                Test-Path -Path $p -PathType Container
            } catch {
                Write-Verbose "Error testing path '$p' on remote server: $($_.Exception.Message)"
                return $false
            }
        } -ArgumentList $Path
    }
    finally {
        Remove-PSSession $psSession -ErrorAction SilentlyContinue
    }
}
