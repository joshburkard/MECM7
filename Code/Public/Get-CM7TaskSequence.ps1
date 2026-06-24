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
            $columns = $fastColumns

            $query = "SELECT $columns FROM SMS_TaskSequencePackage"
            if ($filters.Count -gt 0) {
                $query += " WHERE " + ($filters -join " AND ")
            }

            Write-Verbose "Executing query: $query"
            $taskSequences = Get-CimInstance @cimParams -Query $query

            $results = @()

            # Output results
            if ([boolean]$taskSequences) {
                foreach ($ts in $taskSequences) {
                    # Build output with essential properties (always available)

                    $result = [PSCustomObject]@{
                        PSTypeName      = 'MECM7.TaskSequence'
                        PackageID       = $ts.PackageID
                        Name            = $ts.Name
                    }

                    # Set the type name
                    $result.PSObject.TypeNames.Insert(0, 'MECM7.TaskSequence')

                    if ( -not [boolean]$Fast) {
                        try {
                            $tsf = $ts | Get-CimInstance -ErrorAction SilentlyContinue
                            if ($tsf) {
                                foreach ($prop in @( $tsf.CimInstanceProperties) ) {
                                    Write-Verbose "Property: $($prop.Name) = $($prop.Value)"
                                    if ($result.PSObject.Properties.Name -notcontains $prop.Name) {
                                        $result | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $tsf.$($prop.Name) -Force
                                    }
                                }
                            }
                        }
                        catch {
                            Write-Verbose "Failed to retrieve full instance for task sequence '$($ts.PackageID)'. This may be due to lazy properties that cannot be retrieved via WQL over WinRM. Error: $_"
                        }

                        if ($filters.Count -gt 0) {
                            foreach ($prop in @( $ts.CimInstanceProperties) ) {
                                Write-Verbose "Property: $($prop.Name) = $($prop.Value)"
                                try {
                                    $inst = Get-CimInstance @cimParams -Query "SELECT $( $prop.Name ) FROM SMS_TaskSequencePackage WHERE PackageID = '$($ts.PackageID)'" -ErrorAction SilentlyContinue
                                    if ($inst) {
                                        if ($result.PSObject.Properties.Name -notcontains $prop.Name) {
                                            $result | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $inst.$($prop.Name) -Force
                                        }
                                        elseif ($result.$($prop.Name) -ne $inst.$($prop.Name)) {
                                            Write-Verbose "Property '$($prop.Name)' for task sequence '$($ts.PackageID)' already exists in result with a different value. Existing: '$($result.$($prop.Name))', New: '$($inst.$($prop.Name))'. This may indicate inconsistent data or a lazy property that cannot be reliably retrieved via WQL over WinRM."
                                            # setting property tio new value anyway to ensure we get the correct value for this property, even if it means overwriting an existing value that may be incorrect due to lazy loading issues.
                                            $result | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $inst.$($prop.Name) -Force
                                        }
                                    }
                                    $result | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $inst.$($prop.Name) -Force
                                }
                                catch {
                                    Write-Verbose "Failed to retrieve property '$($prop.Name)' for task sequence '$($ts.PackageID)'. This property may be lazy and cannot be retrieved via WQL over WinRM. Error: $_"
                                }
                            }
                        }
                    }

                    $results += $result
                }
            } else {
                Write-Verbose "No task sequences found matching the criteria."
            }
            return $results
        }
        catch {
            throw $_
        }
    }
}
