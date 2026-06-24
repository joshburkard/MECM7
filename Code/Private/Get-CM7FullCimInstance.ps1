function Get-CM7FullCimInstance {
    <#
        .SYNOPSIS
            Retrieves full CIM instances from MECM based on the key properties of a given instances.

        .DESCRIPTION
            This is a private helper function that takes an array of CIM instances (usually with limited properties) and retrieves the full CIM instance for each one by querying MECM with the key properties (like CI_ID).
            This is useful for functions that initially query with a limited set of properties for performance reasons, but then need to retrieve the full instance for further processing.

        .PARAMETER Instance
            An array of CIM instances that contain at least the key properties (e.g., CI_ID) needed to uniquely identify the instance in MECM.
            The function will use these key properties to query MECM and retrieve the full CIM instance with all properties.

        .OUTPUTS
            An array of full CIM instances retrieved from MECM.
            Each instance will have all properties available from the SMS Provider.

        .EXAMPLE
            $partialApps = Get-CM7Application -Name "PowerShell*" -Fast
            $fullApps = Get-CM7FullCimInstance -Instance $partialApps

            This example retrieves applications with only key properties using the -Fast switch, and then gets the full CIM instances for those applications.

        .NOTES
            This is an internal helper function for the MECM7 module and is not intended to be called directly by users.
            It is used by other functions that need to retrieve full CIM instances after an initial query with limited properties.

            Ensure that you have an active connection to MECM using Connect-CM7 before calling this function, as it relies on the CIM session established by that connection.

            Perhaps you receive error messages about to small WSMAN Envelope size when running a Get-CM7 function with the -Fast switch.
            Please look then at this setup: https://docs.microsoft.com/en-us/windows/win32/winrm/installation-and-configuration-for-windows-remote-management#envelope-size-limits

            Get-Item -Path WSMan:\localhost\MaxEnvelopeSizeKb
            you can set the envelope size to 2048 KB (2MB) for example with:
            Set-Item -Path WSMan:\localhost\MaxEnvelopeSizeKb -Value 2048

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [CimInstance[]]$Instance
    )
    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        Write-Verbose "Retrieving full CIM instances for $($Instance.Count) items of class $($Instance[0].CimClass.CimClassName)."
        $fullInstances = @()
        foreach ($inst in $Instance) {
            try {
                Get-CimInstance -CimSession $Script:CMConnection.CimSession -InputObject $inst -ErrorAction Stop | ForEach-Object {
                    $fullInstances += $_
                }
            } catch {
                if ($_.Exception.Message -match 'exceeds the maximum envelope size that is allowed') {
                    $msg = @(
                        $_.Exception.Message,
                        '',
                        'Recommendation: Increase the WinRM MaxEnvelopeSizekb setting on both client and server to at least 2048 (2MB) using:',
                        '    Set-Item -Path WSMan:\\localhost\\MaxEnvelopeSizekb -Value 2048',
                        '    Set-Item -Path WSMan:\\localhost\\Client\\MaxEnvelopeSizekb -Value 2048',
                        'Then restart the powershell session and retry your operation.'
                    ) -join "`n"
                    throw $msg
                } else {
                    throw "Failed to retrieve full CIM instance for CI_ID $($inst.CI_ID): $_"
                }
            }
        }
        return $fullInstances
    }
    catch {
        throw $_
    }
}
