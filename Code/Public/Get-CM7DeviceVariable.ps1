function Get-CM7DeviceVariable {
    <#
        .SYNOPSIS
            Retrieves device variables from a MECM device using CIM.

        .DESCRIPTION
            Queries the SMS_MachineSettings WMI class to retrieve device-specific variables
            for a specified MECM device. Device variables are name-value pairs that
            can be used during task sequence execution and other MECM operations.
            Supports filtering by device name, ResourceId, or variable name.
            Requires an active connection established via Connect-CM7.

            This is the CIM-based equivalent of the Get-CMDeviceVariable cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER DeviceName
            Specifies the name of the device to retrieve variables for.

        .PARAMETER ResourceId
            Specifies the ResourceID of the device to retrieve variables for.

        .PARAMETER VariableName
            Specifies the name of the variable to retrieve. Supports wildcard characters (*).
            If not specified, all variables for the device are returned.

        .EXAMPLE
            Get-CM7DeviceVariable -DeviceName "Test-2016-1"
            Retrieves all device variables for the device "Test-2016-1".

        .EXAMPLE
            Get-CM7DeviceVariable -ResourceId 16893210
            Retrieves all device variables for the device with ResourceID 16893210.

        .EXAMPLE
            Get-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "TestVar"
            Retrieves the variable named "TestVar" from the device "Test-2016-1".

        .EXAMPLE
            Get-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "Test*"
            Retrieves all variables whose names start with "Test" from the specified device.

        .NOTES
            This function is the CIM-based equivalent of the Get-CMDeviceVariable cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The MachineVariables property of SMS_MachineSettings is a lazy property,
            so the function retrieves the full instance to access it.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByDeviceName')]
    param(
        [Parameter(ParameterSetName = 'ByDeviceName', Position = 0)]
        [string]$DeviceName,

        [Parameter(ParameterSetName = 'ByResourceId', Mandatory = $true)]
        [int]$ResourceId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$VariableName
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Determine which device identifier to use
        $resourceIdToUse = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByDeviceName') {
            if (-not $DeviceName) {
                throw "DeviceName must be provided when using the ByDeviceName parameter set."
            }
            # Resolve device name to ResourceID
            $deviceQuery = "SELECT ResourceID FROM SMS_R_System WHERE Name = '$DeviceName'"
            Write-Verbose "Resolving device name to ResourceID: $deviceQuery"

            $device = Get-CimInstance @queryParams -Query $deviceQuery
            if (-not $device) {
                Write-Verbose "Device '$DeviceName' not found."
                return
            }
            if (@($device).Count -gt 1) {
                Write-Warning "Multiple devices found with name '$DeviceName'. Using the first match (ResourceID: $($device[0].ResourceID))."
                $resourceIdToUse = $device[0].ResourceID
            } else {
                $resourceIdToUse = $device.ResourceID
            }
        } else {
            $resourceIdToUse = $ResourceId
        }

        Write-Verbose "Using ResourceID: $resourceIdToUse"

        # Query SMS_MachineSettings for the device
        $settingsQuery = "SELECT * FROM SMS_MachineSettings WHERE ResourceID = $resourceIdToUse"
        Write-Verbose "Executing query: $settingsQuery"

        $settings = Get-CimInstance @queryParams -Query $settingsQuery

        if (-not $settings) {
            Write-Verbose "No machine settings found for ResourceID '$resourceIdToUse'. The device may have no variables defined."
            return
        }

        # MachineVariables is a lazy property - re-retrieve the instance using
        # Get-CimInstance -InputObject to force loading all lazy properties
        Write-Verbose "Retrieving full instance to load lazy property MachineVariables..."
        $fullSettings = $settings | Get-CimInstance

        if (-not $fullSettings) {
            Write-Verbose "Could not retrieve full machine settings for ResourceID '$resourceIdToUse'."
            return
        }

        # Access the MachineVariables property
        $variables = $fullSettings.MachineVariables

        if (-not $variables -or $variables.Count -eq 0) {
            Write-Verbose "No device variables found for ResourceID '$resourceIdToUse'."
            return
        }

        # Filter by variable name if specified
        if ($VariableName) {
            if ($VariableName -match '[*?]') {
                # Wildcard filter
                $variables = $variables | Where-Object { $_.Name -like $VariableName }
            } else {
                # Exact match
                $variables = $variables | Where-Object { $_.Name -eq $VariableName }
            }
        }

        if (-not $variables) {
            Write-Verbose "No variables matching the filter were found."
            return
        }

        # Output results
        foreach ($variable in $variables) {
            [PSCustomObject]@{
                PSTypeName = 'MECM7.DeviceVariable'
                Name       = $variable.Name
                Value      = $variable.Value
                IsMasked   = $variable.IsMasked
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
