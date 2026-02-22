function Get-CM7SoftwareUpdateDeploymentPackage {
    <#
        .SYNOPSIS
            Retrieves software update deployment package information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_SoftwareUpdatesPackage WMI class to retrieve software update deployment
            package information from MECM. Supports filtering by package ID, package name,
            and retrieval of all packages.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMSoftwareUpdateDeploymentPackage cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER Id
            The unique package ID of the software update deployment package to retrieve.
            This is the PackageID property (e.g., "CM100DDC").

        .PARAMETER Name
            The name of the software update deployment package. Supports wildcard characters (* and ?).

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            PackageID, Name, Description, SourceSite, PkgSourcePath, PackageSize, SourceVersion,
            LastRefreshTime, and summary flags.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeploymentPackage
            Retrieves all software update deployment packages.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeploymentPackage -Id "CM100DDC"
            Retrieves the software update deployment package with the specified package ID.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeploymentPackage -Name "SecurityPatchesPackage"
            Retrieves the software update deployment package with the specified name.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeploymentPackage -Name "Test-SUG*"
            Retrieves all software update deployment packages whose names start with "Test-SUG".

        .EXAMPLE
            Get-CM7SoftwareUpdateDeploymentPackage -Name "*SecurityPatches*"
            Retrieves all software update deployment packages containing "SecurityPatches" in the name.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeploymentPackage -Fast
            Retrieves all software update deployment packages with limited properties for faster performance.

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [switch]$Fast
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        # Validate connection
        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        # Namespace and CIM params
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Package type mapping for display
        $packageTypeMap = @{
            0 = 'Standard'
            3 = 'Driver'
            4 = 'Task Sequence'
            5 = 'Software Update'
            6 = 'Device Setting'
            257 = 'Image'
            258 = 'Boot Image'
            259 = 'OS Install'
        }

        # Priority mapping for display
        $priorityMap = @{
            1 = 'High'
            2 = 'Normal'
            3 = 'Low'
        }

        # PkgFlags mapping (bitmask) for common flags
        $pkgFlagsMap = @{
            0x01000000 = 'DO_NOT_DOWNLOAD'
            0x02000000 = 'PERSIST_IN_CACHE'
            0x04000000 = 'USE_BINARY_DELTA_REP'
            0x10000000 = 'NO_PACKAGE'
            0x20000000 = 'USE_SPECIAL_MIF'
        }
    }

    process {
        try {
            # Build WQL filter based on parameters
            $filters = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ById' {
                    $filters += "PackageID = '$Id'"
                }
                'ByName' {
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filters += "Name LIKE '$wqlName'"
                    } else {
                        $filters += "Name = '$Name'"
                    }
                }
            }

            # Build the query
            if ($Fast) {
                $properties = "PackageID, Name, Description, SourceSite, PkgSourcePath, PackageSize, SourceVersion, StoredPkgVersion, LastRefreshTime, Priority, PkgSourceFlag, ImagePath"
                $query = "SELECT $properties FROM SMS_SoftwareUpdatesPackage"
            } else {
                $query = "SELECT * FROM SMS_SoftwareUpdatesPackage"
            }

            if ($filters.Count -gt 0) {
                $query += " WHERE " + ($filters -join " AND ")
            }

            Write-Verbose "Executing query: $query"

            # Execute the query
            $packages = Get-CimInstance @cimParams -Query $query

            # Output results
            if ($packages) {
                foreach ($package in $packages) {
                    # Map priority
                    $priorityName = if ($priorityMap.ContainsKey([int]$package.Priority)) {
                        $priorityMap[[int]$package.Priority]
                    } else {
                        "Unknown ($($package.Priority))"
                    }

                    # Map PkgSourceFlag
                    $sourceType = switch ([int]$package.PkgSourceFlag) {
                        1 { 'StorageDirect' }
                        2 { 'StorageCompressed' }
                        3 { 'StorageNoPackage' }
                        default { "Unknown ($($package.PkgSourceFlag))" }
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName         = 'MECM7.SoftwareUpdateDeploymentPackage'
                        PackageID          = $package.PackageID
                        Name               = $package.Name
                        Description        = $package.Description
                        SourceSite         = $package.SourceSite
                        PkgSourcePath      = $package.PkgSourcePath
                        PackageSize        = [long]$package.PackageSize
                        SourceVersion      = [int]$package.SourceVersion
                        StoredPkgVersion   = [int]$package.StoredPkgVersion
                        LastRefreshTime    = $package.LastRefreshTime
                        Priority           = $priorityName
                        PkgSourceFlag      = $sourceType
                        ImagePath          = $package.ImagePath
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.SoftwareUpdateDeploymentPackage')

                    # Add all properties if not Fast mode
                    if (-not $Fast) {
                        $package.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                    }

                    Write-Output $output
                }
            } else {
                Write-Verbose "No software update deployment packages found matching the criteria."
            }
        }
        catch {
            throw $_
        }
    }
}
