function Get-CM7SoftwareUpdateGroup {
    <#
        .SYNOPSIS
            Retrieves software update group information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_AuthorizationList WMI class to retrieve software update group
            information from MECM. Supports filtering by CI_ID, group name,
            and retrieval of all software update groups.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMSoftwareUpdateGroup cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER Id
            The unique CI_ID of the software update group to retrieve.
            This is the CI_ID property (integer).

        .PARAMETER Name
            The name (LocalizedDisplayName) of the software update group. Supports wildcard characters (* and ?).

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            CI_ID, CI_UniqueID, LocalizedDisplayName, LocalizedDescription, IsDeployed, IsExpired,
            IsSuperseded, NumberOfUpdates, DateCreated, DateLastModified, and LocalizedCategoryInstanceNames.

        .EXAMPLE
            Get-CM7SoftwareUpdateGroup
            Retrieves all software update groups.

        .EXAMPLE
            Get-CM7SoftwareUpdateGroup -Id 12345
            Retrieves the software update group with the specified CI_ID.

        .EXAMPLE
            Get-CM7SoftwareUpdateGroup -Name "SO Servers-SecurityPatches-2024-01"
            Retrieves the software update group with the specified name.

        .EXAMPLE
            Get-CM7SoftwareUpdateGroup -Name "SO Servers*"
            Retrieves all software update groups whose names start with "SO Servers".

        .EXAMPLE
            Get-CM7SoftwareUpdateGroup -Name "*SecurityPatches*"
            Retrieves all software update groups containing "SecurityPatches" in the name.

        .EXAMPLE
            Get-CM7SoftwareUpdateGroup -Fast
            Retrieves all software update groups with limited properties for faster performance.

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$Id,

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
    }

    process {
        try {
            # Build WQL filter based on parameters
            $filters = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ById' {
                    $filters += "CI_ID = $Id"
                }
                'ByName' {
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filters += "LocalizedDisplayName LIKE '$wqlName'"
                    } else {
                        $filters += "LocalizedDisplayName = '$Name'"
                    }
                }
            }

            # Build the query
            if ($Fast) {
                $properties = "CI_ID, CI_UniqueID, LocalizedDisplayName, LocalizedDescription, IsDeployed, IsExpired, IsSuperseded, NumberOfUpdates, DateCreated, DateLastModified, LocalizedCategoryInstanceNames"
                $query = "SELECT $properties FROM SMS_AuthorizationList"
            } else {
                $query = "SELECT * FROM SMS_AuthorizationList"
            }

            if ($filters.Count -gt 0) {
                $query += " WHERE " + ($filters -join " AND ")
            }

            Write-Verbose "Executing query: $query"

            # Execute the query
            $groups = Get-CimInstance @cimParams -Query $query

            # Output results
            if ($groups) {
                foreach ($group in $groups) {
                    # If not Fast mode, retrieve lazy properties by getting the full instance
                    if (-not $Fast) {
                        try {
                            $group = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $($group.CI_ID)"
                        } catch {
                            Write-Verbose "Could not retrieve full instance for CI_ID $($group.CI_ID): $_"
                        }
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName                      = 'MECM7.SoftwareUpdateGroup'
                        CI_ID                           = [int]$group.CI_ID
                        CI_UniqueID                     = $group.CI_UniqueID
                        LocalizedDisplayName            = $group.LocalizedDisplayName
                        LocalizedDescription            = $group.LocalizedDescription
                        IsDeployed                      = [bool]$group.IsDeployed
                        IsExpired                       = [bool]$group.IsExpired
                        IsSuperseded                    = [bool]$group.IsSuperseded
                        NumberOfUpdates                 = [int]$group.NumberOfUpdates
                        DateCreated                     = $group.DateCreated
                        DateLastModified                = $group.DateLastModified
                        LocalizedCategoryInstanceNames  = $group.LocalizedCategoryInstanceNames
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.SoftwareUpdateGroup')

                    # Add all properties if not Fast mode
                    if (-not $Fast) {
                        $group.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                    }

                    Write-Output $output
                }
            } else {
                Write-Verbose "No software update groups found matching the criteria."
            }
        }
        catch {
            throw $_
        }
    }
}
