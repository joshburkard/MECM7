function Remove-CM7DeviceVariable {
    <#
        .SYNOPSIS
            Removes a device variable from a MECM device using CIM.

        .DESCRIPTION
            Removes one or more device variables from a specified device in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. Device variables are
            stored in the SMS_MachineSettings WMI class and can be used during task sequence
            execution and other MECM operations.

            This is the CIM-based equivalent of the Remove-CMDeviceVariable cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the device (by name or ResourceId)
            3. Retrieves existing SMS_MachineSettings and loads the MachineVariables lazy property
            4. Finds the matching variable(s) by exact name or wildcard pattern
            5. Removes the matching variable(s) from the array
            6. Writes the updated settings back via CIM

        .PARAMETER DeviceName
            Specifies the name of the device to remove the variable from.
            Mutually exclusive with ResourceId.

        .PARAMETER ResourceId
            Specifies the ResourceID of the device to remove the variable from.
            Mutually exclusive with DeviceName.

        .PARAMETER VariableName
            Specifies the name of the variable to remove. Supports wildcard characters (* and ?)
            to remove multiple variables matching a pattern.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "OSDComputerName"
            Removes the device variable named "OSDComputerName" from the specified device.

        .EXAMPLE
            Remove-CM7DeviceVariable -ResourceId 16893210 -VariableName "InstallSoftware" -Force
            Removes the device variable from the device identified by its ResourceID without prompting for confirmation.

        .EXAMPLE
            Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "Test*"
            Removes all device variables whose names match the wildcard pattern "Test*".

        .EXAMPLE
            Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "OldVar" -WhatIf
            Shows what would happen without actually removing the variable.

        .NOTES
            This function is the CIM-based equivalent of the Remove-CMDeviceVariable cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The MachineVariables property of SMS_MachineSettings is a lazy property,
            so the function retrieves the full instance to access it.

            If the variable does not exist, a warning is written but no error is thrown.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByDeviceName')]
    param(
        [Parameter(ParameterSetName = 'ByDeviceName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(ParameterSetName = 'ByResourceId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$ResourceId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$VariableName,

        [Parameter()]
        [switch]$Force
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        # Validate connection
        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build common CIM parameters
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            # ---- Resolve Device ----
            $resourceIdToUse = $null
            $deviceDisplayName = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByDeviceName' {
                    $deviceQuery = "SELECT ResourceID, Name FROM SMS_R_System WHERE Name = '$DeviceName'"
                    Write-Verbose "Resolving device name: $deviceQuery"
                    $device = Get-CimInstance @cimParams -Query $deviceQuery

                    if (-not $device) {
                        throw "Device '$DeviceName' not found."
                    }

                    if (@($device).Count -gt 1) {
                        Write-Warning "Multiple devices found with name '$DeviceName'. Using the first match (ResourceID: $($device[0].ResourceID))."
                        $resourceIdToUse = $device[0].ResourceID
                    } else {
                        $resourceIdToUse = $device.ResourceID
                    }

                    $deviceDisplayName = $DeviceName
                    Write-Verbose "Resolved device '$DeviceName' to ResourceID '$resourceIdToUse'"
                }
                'ByResourceId' {
                    # Validate device exists
                    $deviceQuery = "SELECT ResourceID, Name FROM SMS_R_System WHERE ResourceID = $ResourceId"
                    Write-Verbose "Validating device: $deviceQuery"
                    $device = Get-CimInstance @cimParams -Query $deviceQuery

                    if (-not $device) {
                        throw "Device with ResourceID '$ResourceId' not found."
                    }

                    $resourceIdToUse = $ResourceId
                    $deviceDisplayName = $device.Name
                    Write-Verbose "Device '$deviceDisplayName' (ResourceID: $ResourceId) validated."
                }
            }

            # ---- Retrieve SMS_MachineSettings ----
            $settingsQuery = "SELECT * FROM SMS_MachineSettings WHERE ResourceID = $resourceIdToUse"
            Write-Verbose "Querying machine settings: $settingsQuery"
            $settings = Get-CimInstance @cimParams -Query $settingsQuery

            if (-not $settings) {
                Write-Warning "No machine settings found for device '$deviceDisplayName' (ResourceID: $resourceIdToUse). The device has no variables."
                return
            }

            # Retrieve full instance to load lazy properties (MachineVariables)
            Write-Verbose "Retrieving full instance to load lazy property MachineVariables..."
            $fullSettings = $settings | Get-CimInstance

            if (-not $fullSettings) {
                throw "Could not retrieve full machine settings for ResourceID '$resourceIdToUse'."
            }

            # ---- Get existing variables ----
            $existingVariables = @()
            if ($fullSettings.MachineVariables) {
                $existingVariables = @($fullSettings.MachineVariables)
            }

            if ($existingVariables.Count -eq 0) {
                Write-Warning "No device variables found for device '$deviceDisplayName' (ResourceID: $resourceIdToUse)."
                return
            }

            # ---- Find matching variables ----
            $isWildcard = $VariableName -match '[*?]'

            if ($isWildcard) {
                $matchingVars = @($existingVariables | Where-Object { $_.Name -like $VariableName })
            } else {
                $matchingVars = @($existingVariables | Where-Object { $_.Name -eq $VariableName })
            }

            if ($matchingVars.Count -eq 0) {
                Write-Warning "Variable '$VariableName' not found on device '$deviceDisplayName' (ResourceID: $resourceIdToUse)."
                return
            }

            Write-Verbose "Found $($matchingVars.Count) variable(s) matching '$VariableName'."

            # ---- Capture match data before CIM modification ----
            # CIM embedded instances may become stale after modifying the parent
            # instance, so we store the data in plain PowerShell objects first.
            $removedVarInfo = @($matchingVars | ForEach-Object {
                @{
                    Name     = [string]$_.Name
                    Value    = [string]$_.Value
                    IsMasked = [bool]$_.IsMasked
                }
            })

            # ---- Build updated variables list (excluding matched ones) ----
            $matchingNames = $removedVarInfo | ForEach-Object { $_.Name }
            $updatedVariables = [System.Collections.Generic.List[CimInstance]]::new()

            foreach ($v in $existingVariables) {
                if ($v.Name -notin $matchingNames) {
                    $updatedVariables.Add($v)
                }
            }

            # ---- ShouldProcess ----
            $variableNameDisplay = ($matchingNames -join ', ')
            $actionDescription = "Remove variable(s) '$variableNameDisplay' from device '$deviceDisplayName' (ResourceID: $resourceIdToUse)"

            if ($Force -or $PSCmdlet.ShouldProcess($actionDescription, "Remove-CM7DeviceVariable")) {

                # Modify the MachineVariables property and commit
                Write-Verbose "Updating SMS_MachineSettings for ResourceID '$resourceIdToUse'..."

                if ($updatedVariables.Count -eq 0) {
                    # All variables removed - set to empty array
                    $fullSettings.CimInstanceProperties['MachineVariables'].Value = [CimInstance[]]@()
                } else {
                    $fullSettings.CimInstanceProperties['MachineVariables'].Value = [CimInstance[]]$updatedVariables.ToArray()
                }

                $null = ($fullSettings | Set-CimInstance)

                Write-Verbose "Successfully removed variable(s) '$variableNameDisplay' from device '$deviceDisplayName' (ResourceID: $resourceIdToUse)."

                # Return info about removed variables using pre-captured data
                foreach ($info in $removedVarInfo) {
                    [PSCustomObject]@{
                        PSTypeName = 'MECM7.RemovedDeviceVariable'
                        Name       = $info.Name
                        Value      = $info.Value
                        IsMasked   = $info.IsMasked
                        ResourceId = $resourceIdToUse
                        Status     = 'Removed'
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
