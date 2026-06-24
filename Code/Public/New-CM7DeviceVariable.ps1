function New-CM7DeviceVariable {
    <#
        .SYNOPSIS
            Creates a new device variable on a MECM device using CIM.

        .DESCRIPTION
            Creates a new device variable (name-value pair) on a specified device in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. Device variables are
            stored in the SMS_MachineSettings WMI class and can be used during task sequence
            execution and other MECM operations.

            This is the CIM-based equivalent of the New-CMDeviceVariable cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the device (by name or ResourceId)
            3. Retrieves existing SMS_MachineSettings (or creates new settings if none exist)
            4. If a variable with the same name already exists, it is overwritten
            5. Creates and appends (or replaces) the SMS_MachineVariable embedded instance
            6. Writes the updated settings back via CIM

        .PARAMETER DeviceName
            Specifies the name of the device to add the variable to.
            Mutually exclusive with ResourceId.

        .PARAMETER ResourceId
            Specifies the ResourceID of the device to add the variable to.
            Mutually exclusive with DeviceName.

        .PARAMETER VariableName
            Specifies the name of the variable to create or overwrite. Variable names must not
            contain spaces. If a variable with the same name already exists, its value and
            IsMasked setting will be overwritten.

        .PARAMETER Value
            Specifies the value of the variable. Can be an empty string.

        .PARAMETER IsMasked
            Specifies whether the variable value should be masked (hidden) in the MECM console.
            When set to $true, the value is obscured in the UI. Defaults to $false.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "OSDComputerName" -Value "WKS-001"
            Creates a new device variable named "OSDComputerName" with value "WKS-001" on the specified device.

        .EXAMPLE
            New-CM7DeviceVariable -ResourceId 16893210 -VariableName "InstallSoftware" -Value "True"
            Creates a new device variable on the device identified by its ResourceID.

        .EXAMPLE
            New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "SecretKey" -Value "P@ssw0rd!" -IsMasked
            Creates a masked (hidden) device variable. The value will be obscured in the MECM console.

        .EXAMPLE
            New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "EmptyVar" -Value ""
            Creates a device variable with an empty value.

        .NOTES
            This function is the CIM-based equivalent of the New-CMDeviceVariable cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The MachineVariables property of SMS_MachineSettings is a lazy property,
            so the function retrieves the full instance to access it.

            If the device has no existing SMS_MachineSettings, the function creates
            a new settings instance before adding the variable.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByDeviceName')]
    param(
        [Parameter(ParameterSetName = 'ByDeviceName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(ParameterSetName = 'ByResourceId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$ResourceId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\S+$')]
        [string]$VariableName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter()]
        [switch]$IsMasked,

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

            # ---- Retrieve or Create SMS_MachineSettings ----
            $settingsQuery = "SELECT * FROM SMS_MachineSettings WHERE ResourceID = $resourceIdToUse"
            Write-Verbose "Querying machine settings: $settingsQuery"
            $settings = Get-CimInstance @cimParams -Query $settingsQuery

            $isNewSettings = $false

            if ($settings) {
                # Retrieve full instance to load lazy properties (MachineVariables)
                Write-Verbose "Retrieving full instance to load lazy property MachineVariables..."
                $fullSettings = $settings | Get-CimInstance

                if (-not $fullSettings) {
                    throw "Could not retrieve full machine settings for ResourceID '$resourceIdToUse'."
                }
            }
            else {
                Write-Verbose "No existing SMS_MachineSettings found for ResourceID '$resourceIdToUse'. Will create new settings."
                $isNewSettings = $true
                $fullSettings = $null
            }

            # ---- Get existing variables ----
            $existingVariables = @()
            if ($fullSettings -and $fullSettings.MachineVariables) {
                $existingVariables = @($fullSettings.MachineVariables)
            }

            # ---- Check for duplicate variable name ----
            $duplicateVar = $existingVariables | Where-Object { $_.Name -eq $VariableName }
            if ($duplicateVar) {
                Write-Verbose "A variable named '$VariableName' already exists on device '$deviceDisplayName' (ResourceID: $resourceIdToUse). It will be overwritten."
            }

            # ---- Build the new variable ----
            Write-Verbose "Creating new device variable: Name='$VariableName', IsMasked=$($IsMasked.IsPresent)"

            $variableClass = Get-CimClass -CimSession $script:CMConnection.CimSession -Namespace $namespace -ClassName 'SMS_MachineVariable'
            $newVariable = New-CimInstance -CimClass $variableClass -ClientOnly -Property @{
                Name     = $VariableName
                Value    = $Value
                IsMasked = [bool]$IsMasked.IsPresent
            }

            # ---- Build updated variables list (replace if duplicate, append if new) ----
            $updatedVariables = [System.Collections.Generic.List[CimInstance]]::new()
            foreach ($v in $existingVariables) {
                if ($v.Name -eq $VariableName) {
                    # Replace existing variable with new one
                    $updatedVariables.Add($newVariable)
                } else {
                    $updatedVariables.Add($v)
                }
            }
            if (-not $duplicateVar) {
                $updatedVariables.Add($newVariable)
            }

            # ---- ShouldProcess ----
            $maskedDisplay = if ($IsMasked.IsPresent) { " (masked)" } else { "" }
            $actionDescription = "Create variable '$VariableName' = '$( if ($IsMasked.IsPresent) { '********' } else { $Value } )'$maskedDisplay on device '$deviceDisplayName' (ResourceID: $resourceIdToUse)"

            if ($Force -or $PSCmdlet.ShouldProcess($actionDescription, "New-CM7DeviceVariable")) {

                if ($isNewSettings) {
                    # Create SMS_MachineSettings with ResourceID and SourceSite, then
                    # re-retrieve, modify MachineVariables, and Put_ again.
                    Write-Verbose "Creating new SMS_MachineSettings for ResourceID '$resourceIdToUse'..."

                    $null = New-CimInstance @cimParams -ClassName 'SMS_MachineSettings' -Property @{
                        ResourceID = [UInt32]$resourceIdToUse
                        SourceSite = $script:CMConnection.SiteCode
                        LocaleID   = [UInt32]1033
                    }

                    # Re-retrieve the full instance (loads lazy properties)
                    Write-Verbose "Re-retrieving newly created SMS_MachineSettings..."
                    $fullSettings = Get-CimInstance @cimParams -ClassName 'SMS_MachineSettings' -Filter "ResourceID = $resourceIdToUse" |
                        Get-CimInstance

                    if (-not $fullSettings) {
                        throw "Failed to create or retrieve SMS_MachineSettings for ResourceID '$resourceIdToUse'."
                    }
                }

                # Modify the MachineVariables property directly on the CIM instance,
                # then call Set-CimInstance (equivalent of WMI Put_) to commit all properties.
                Write-Verbose "Updating SMS_MachineSettings for ResourceID '$resourceIdToUse'..."
                $fullSettings.CimInstanceProperties['MachineVariables'].Value = [CimInstance[]]$updatedVariables.ToArray()
                $fullSettings | Set-CimInstance

                Write-Verbose "Successfully saved SMS_MachineSettings with variable '$VariableName'."

                # Return the created variable
                [PSCustomObject]@{
                    PSTypeName = 'MECM7.DeviceVariable'
                    Name       = $VariableName
                    Value      = $Value
                    IsMasked   = $IsMasked.IsPresent
                    ResourceId = $resourceIdToUse
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
