function New-CM7RemotePath {
    <#
        .SYNOPSIS
            Creates a directory on the MECM server at the specified path.

        .DESCRIPTION
            Opens a temporary PSSession to the MECM server using the credentials stored by Connect-CM7,
            then creates a directory at the specified path. This ensures the directory is created from
            the server's perspective (e.g. UNC paths that the MECM service account can reach) rather than
            the local client's perspective.

        .PARAMETER Path
            The path to create. Typically a UNC path (e.g. \\server\share\folder).

        .OUTPUTS
            [bool] $true if the directory was created successfully, $false otherwise.

        .EXAMPLE
            New-CM7RemotePath -Path "\\fileserver\share\MECM\Patches"

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
                New-Item -Path $p -ItemType Directory -Force | Out-Null
                return $true
            } catch {
                Write-Verbose "Error creating directory '$p' on remote server: $($_.Exception.Message)"
                return $false
            }
        } -ArgumentList $Path
    }
    finally {
        Remove-PSSession $psSession -ErrorAction SilentlyContinue
    }
}
