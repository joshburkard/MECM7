function Get-CM7TaskSequence {
    <#
        .SYNOPSIS
            Retrieves task sequence information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_TaskSequencePackage WMI class to retrieve task sequence
            information from MECM. Supports filtering by PackageID, task sequence name,
            and retrieval of all task sequences.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMTaskSequence cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            NOTE: SMS_TaskSequencePackage contains extremely heavy lazy properties
            (Sequence XML, References, SupportedOperatingSystems, etc.) that exceed
            WS-Management envelope size limits. SELECT * is never safe on this class
            over WinRM. This function always uses explicit column lists.

        .PARAMETER TaskSequencePackageId
            The unique PackageID of the task sequence to retrieve.
            This is the PackageID property (string), e.g. "ABC00001".

        .PARAMETER Name
            The name of the task sequence. Supports wildcard characters (* and ?).

        .PARAMETER Fast
            Returns only PackageID and Name for maximum performance.
            Use this for quick inventory or when you only need identifiers.

        .EXAMPLE
            Get-CM7TaskSequence
            Retrieves all task sequences with all non-lazy properties.

        .EXAMPLE
            Get-CM7TaskSequence -TaskSequencePackageId "ABC00001"
            Retrieves the task sequence with the specified PackageID.

        .EXAMPLE
            Get-CM7TaskSequence -Name "Install Windows Server - OS - non-PRD"
            Retrieves the task sequence with the specified name.

        .EXAMPLE
            Get-CM7TaskSequence -Name "Install Windows*"
            Retrieves all task sequences whose names start with "Install Windows".

        .EXAMPLE
            Get-CM7TaskSequence -Name "*OS*"
            Retrieves all task sequences containing "OS" in the name.

        .EXAMPLE
            Get-CM7TaskSequence -Fast
            Retrieves all task sequences with only PackageID and Name for fastest performance.

        .NOTES
            Requires an active connection established via Connect-CM7.
            Lazy properties (Sequence, References, SupportedOperatingSystems, Duration,
            PackageSize, SourceVersion, Icon, ISVData, ExtendedData, etc.) cannot be
            retrieved via WQL over WinRM and are excluded from all queries.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequencePackageId,

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

        # SMS_TaskSequencePackage property lists.
        # Lazy properties CANNOT be retrieved via WQL SELECT over WinRM (cause 0x80041001
        # or exceed WS-Management envelope size). They are excluded from all queries.
        #
        # Lazy / heavy properties (excluded):
        #   Duration, PackageSize, SourceVersion, SourceSize, Sequence, References,
        #   ReferencesCount, SupportedOperatingSystems, Icon, IconSize, ISVData,
        #   ISVDataSize, ExtendedData, ExtendedDataSize, RefreshSchedule

        # Fast mode: only identifiers
        $fastColumns = 'PackageID, Name'

        # Normal mode: only properties confirmed to work in WQL SELECT over WinRM.
        # SMS_TaskSequencePackage has many lazy properties that cause HRESULT 0x80041001
        # or exceed WS-Management envelope size when used in SELECT. Only the properties
        # below have been tested and confirmed to work.
        $fullColumns = 'PackageID, Name, Description, BootImageID, SourceDate, LastRefreshTime, SourceSite, ProgramFlags, PackageType, Version'
    }

    process {
        try {
            # Build WQL filter based on parameters
            $filters = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ById' {
                    $filters += "PackageID = '$TaskSequencePackageId'"
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

            # Choose column list based on -Fast switch
            $columns = if ($Fast) { $fastColumns } else { $fullColumns }

            $query = "SELECT $columns FROM SMS_TaskSequencePackage"
            if ($filters.Count -gt 0) {
                $query += " WHERE " + ($filters -join " AND ")
            }

            Write-Verbose "Executing query: $query"
            $taskSequences = Get-CimInstance @cimParams -Query $query

            # Output results
            if ($taskSequences) {
                foreach ($ts in $taskSequences) {
                    # Build output with essential properties (always available)
                    $output = [PSCustomObject]@{
                        PSTypeName      = 'MECM7.TaskSequence'
                        PackageID       = $ts.PackageID
                        Name            = $ts.Name
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.TaskSequence')

                    # Add all CIM properties returned by the query
                    $ts.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }

                    Write-Output $output
                }
            } else {
                Write-Verbose "No task sequences found matching the criteria."
            }
        }
        catch {
            throw $_
        }
    }
}
