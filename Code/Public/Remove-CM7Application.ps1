function Remove-CM7Application {
    <#
        .SYNOPSIS
            Removes an application from MECM using CIM connectivity.

        .DESCRIPTION
            Retires and deletes an application from MECM via the SMS_Application WMI class using CIM connectivity.
            Requires an active connection established via Connect-CM7.
            You must retire the application (SetIsExpired) before deletion.

        .PARAMETER Name
            The display name of the application to remove. Supports wildcards. (Mutually exclusive with ID)

        .PARAMETER ID
            The CI_ID of the application to remove. (Mutually exclusive with Name)

        .PARAMETER InputObject
            A collection of objects representing applications to remove. Each object must have a CI_ID property. (Mutually exclusive with Name and ID)

        .PARAMETER Force
            If specified, does not prompt for confirmation.

        .EXAMPLE
            Remove-CM7Application -Name "Test"
            Retires and deletes the application named "Test".

        .EXAMPLE
            Remove-CM7Application -ID 12345678
            Retires and deletes the application with CI_ID 12345678.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByID', Mandatory = $true, Position = 0)]
        [int]$ID,

        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSObject]$InputObject,

        [Parameter()]
        [switch]$Force
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $session   = $script:CMConnection.CimSession

    # Resolve application(s)
    switch ($PSCmdlet.ParameterSetName) {
        'ByName' {
            $apps = Get-CimInstance -CimSession $session -Namespace $namespace -ClassName SMS_Application -Filter "LocalizedDisplayName = '$Name' AND IsLatest = 1"
            if (-not $apps) {
                Write-Warning "No application found with Name '$Name'."
                return $false
            }
        }
        'ByID' {
            $apps = Get-CimInstance -CimSession $session -Namespace $namespace -ClassName SMS_Application -Filter "CI_ID = $ID AND IsLatest = 1"
            if (-not $apps) {
                Write-Warning "No application found with CI_ID $ID."
                return $false
            }
        }
        'ByInputObject' {
            # Not implemented in this version
            $apps = @()
            foreach ($obj in $InputObject) {
                if ($obj.PSObject.Properties.Name -contains 'CI_ID') {
                    $id = $obj.CI_ID
                    $app = Get-CimInstance -CimSession $session -Namespace $namespace -ClassName SMS_Application -Filter "CI_ID = $id AND IsLatest = 1"
                    if ($app) {
                        $apps += $app
                    }
                }
            }
        }
    }

    foreach ($app in $apps) {
        $appId = $app.CI_ID
        $appName = $app.LocalizedDisplayName
        if ($PSCmdlet.ShouldProcess("Application '$appName' (CI_ID: $appId)", 'Remove')) {
            if (-not $Force) {
                $confirm = $PSCmdlet.ShouldContinue("Remove application '$appName' (CI_ID: $appId)? This will retire and delete the application.", 'Confirm Application Removal')
                if (-not $confirm) { continue }
            }
            try {
                # Step 1 – retire (required before WMI deletion for SMS_Application)
                Invoke-CimMethod -CimSession $session -Namespace $namespace `
                    -Query "SELECT * FROM SMS_Application WHERE CI_ID = $appId AND IsLatest = 1" `
                    -MethodName SetIsExpired -Arguments @{ Expired = $true } -ErrorAction SilentlyContinue | Out-Null
                # Step 2 – delete all versions
                Remove-CimInstance -CimSession $session -Namespace $namespace `
                    -Query "SELECT * FROM SMS_Application WHERE CI_ID = $appId" -ErrorAction SilentlyContinue
                Write-Verbose "Removed application '$appName' (CI_ID: $appId)"
                Write-Output $true
            } catch {
                Write-Warning "Failed to remove application '$appName' (CI_ID: $appId): $_"
                Write-Output $false
            }
        }
    }
}
