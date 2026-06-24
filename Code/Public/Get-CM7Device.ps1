function Get-CM7Device {
    <#
        .SYNOPSIS
            Retrieves device information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_R_System WMI class to retrieve device information from MECM.
            Supports filtering by device name, ResourceId, or collection membership.
            Requires an active connection established via Connect-CM7.

        .PARAMETER Name
            The name of the device to retrieve. Supports wildcard characters (*).

        .PARAMETER ResourceId
            The ResourceID of the device to retrieve.

        .PARAMETER CollectionId
            Filter devices by Collection ID. Returns only devices that are members of the specified collection.

        .PARAMETER CollectionName
            Filter devices by Collection Name. Returns only devices that are members of the specified collection.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like Name, ResourceID, and LastLogonTimestamp.

        .EXAMPLE
            Get-CM7Device -Name "COMPUTER01"
            Retrieves the device with the exact name "COMPUTER01".

        .EXAMPLE
            Get-CM7Device -Name "TEST-*"
            Retrieves all devices whose names start with "TEST-".

        .EXAMPLE
            Get-CM7Device -ResourceId 16777220
            Retrieves the device with ResourceID 16777220.

        .EXAMPLE
            Get-CM7Device -CollectionName "All Systems" -Fast
            Retrieves all devices in the "All Systems" collection with limited properties.

        .EXAMPLE
            Get-CM7Device
            Retrieves all devices (use with caution on large environments).
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByResourceId', Mandatory = $true)]
        [int]$ResourceId,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [string]$CollectionId,

        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true)]
        [string]$CollectionName,

        [Parameter()]
        [switch]$Fast
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        # Build the WQL filter based on parameters
        $filter = $null

        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                if ($Name) {
                    # Convert PowerShell wildcard to WQL LIKE pattern
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filter = "Name LIKE '$wqlName'"
                    } else {
                        $filter = "Name = '$Name'"
                    }
                }
            }
            'ByResourceId' {
                $filter = "ResourceID = $ResourceId"
            }
            'ByCollectionId' {
                # For collection-based queries, we need to join with SMS_CollectionMember_a
                Write-Verbose "Filtering by CollectionId: $CollectionId"
            }
            'ByCollectionName' {
                # First, resolve the collection name to collection ID
                Write-Verbose "Filtering by CollectionName: $CollectionName"
            }
        }

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Handle collection-based queries
        if ($PSCmdlet.ParameterSetName -in 'ByCollectionId', 'ByCollectionName') {
            $collectionIdToUse = $CollectionId

            # Resolve collection name to ID if needed
            if ($CollectionName) {
                $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'"
                $collection = Get-CimInstance @queryParams -Query $collectionQuery
                if (-not $collection) {
                    Write-Warning "Collection '$CollectionName' not found."
                    return
                }
                $collectionIdToUse = $collection.CollectionID
            }

            Write-Verbose "Querying devices in collection: $collectionIdToUse"

            # Query collection members - get resource IDs first
            try {
                $memberQuery = "SELECT ResourceID FROM SMS_FullCollectionMembership WHERE CollectionID = '$collectionIdToUse'"
                Write-Verbose "Executing query: $memberQuery"
                $members = Get-CimInstance @queryParams -Query $memberQuery
            }
            catch {
                Write-Verbose "Failed to query with SMS_FullCollectionMembership, trying alternative query"
                # Try alternative approach using SMS_Collection and its properties
                try {
                    $memberQuery = "SELECT ResourceID FROM SMS_CollectionMember WHERE CollectionID = '$collectionIdToUse'"
                    Write-Verbose "Executing alternate query: $memberQuery"
                    $members = Get-CimInstance @queryParams -Query $memberQuery
                }
                catch {
                    Write-Warning "Unable to query collection members: $_"
                    return
                }
            }

            # Convert to array for consistency
            $resourceIds = @($members | ForEach-Object { $_.ResourceID })
            Write-Verbose "Found $($resourceIds.Count) members in collection"

            # Build ID list for device query (limit to 100 at a time to avoid WQL size limits)
            $batchSize = 100
            $allDevices = @()

            for ($i = 0; $i -lt $resourceIds.Count; $i += $batchSize) {
                $batch = $resourceIds | Select-Object -Skip $i -First $batchSize

                if ($batch.Count -eq 1) {
                    $idFilter = "ResourceID = $($batch[0])"
                } else {
                    $idList = ($batch | ForEach-Object { "$_" }) -join ','
                    $idFilter = "ResourceID IN ($idList)"
                }

                # Query devices in this batch
                $deviceQuery = if ($Fast) {
                    "SELECT ResourceID, Name, LastLogonTimestamp, LastLogonUserName, OperatingSystemNameandVersion, MACAddresses, IPAddresses FROM SMS_R_System WHERE $idFilter"
                } else {
                    "SELECT * FROM SMS_R_System WHERE $idFilter"
                }

                Write-Verbose "Executing batch query: processing $($batch.Count) devices"
                $batchDevices = Get-CimInstance @queryParams -Query $deviceQuery

                if ($batchDevices) {
                    $allDevices += $batchDevices
                }
            }

            # Output results
            if ($allDevices) {
                foreach ($device in $allDevices) {
                    $output = [PSCustomObject]@{
                        PSTypeName               = 'MECM7.Device'
                        ResourceId               = [int]$device.ResourceId
                        Name                     = $device.Name
                        NetbiosName              = $device.NetbiosName
                        OperatingSystem          = $device.OperatingSystemNameandVersion
                        LastLogonUser            = $device.LastLogonUserName
                        LastLogonTimestamp       = $device.LastLogonTimestamp
                        MACAddresses             = $device.MACAddresses
                        IPAddresses              = $device.IPAddresses
                        Domain                   = $device.ResourceDomainORWorkgroup
                        Client                   = $device.Client
                        ClientVersion            = $device.ClientVersion
                        Active                   = $device.Active
                        Obsolete                 = $device.Obsolete
                        ADSiteName               = $device.ADSiteName
                        SiteCode                 = $device.SMSSiteCode
                    }

                    # Set the type name as well
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.Device')

                    if (-not $Fast) {
                        $device.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                    }

                    Write-Output $output
                }
            }
            return
        }

        # if no filters are defined or the only filters are CollectionName = 'All Systems' or CollectionId = 'SMS00001', we will add parameter Fast to the query to improve performance
        if (-not $filter -or ($filter -match "CollectionName\s*=\s'All Systems\'") -or ($filter -match "CollectionID\s*=\s*'SMS00001'")) {
            Write-Verbose "No specific filters provided or filtering by 'All Systems' collection, enabling Fast mode for better performance."
            $Fast = $true
        }

        # Build the main query
        if ($Fast) {
            $properties = "ResourceID, Name, LastLogonTimestamp, LastLogonUserName, OperatingSystemNameandVersion, MACAddresses, IPAddresses"
            $query = "SELECT $properties FROM SMS_R_System"
        } else {
            $query = "SELECT * FROM SMS_R_System"
        }

        if ($filter) {
            $query += " WHERE $filter"
        }

        Write-Verbose "Executing query: $query"

        # Execute the query
        $devices = Get-CimInstance @queryParams -Query $query

        # Output results
        if ($devices) {
            foreach ($device in $devices) {
                # Create a custom object with commonly used properties
                $output = [PSCustomObject]@{
                    PSTypeName               = 'MECM7.Device'
                    ResourceId               = [int]$device.ResourceId
                    Name                     = $device.Name
                    NetbiosName              = $device.NetbiosName
                    OperatingSystem          = $device.OperatingSystemNameandVersion
                    LastLogonUser            = $device.LastLogonUserName
                    LastLogonTimestamp       = $device.LastLogonTimestamp
                    MACAddresses             = $device.MACAddresses
                    IPAddresses              = $device.IPAddresses
                    Domain                   = $device.ResourceDomainORWorkgroup
                    Client                   = $device.Client
                    ClientVersion            = $device.ClientVersion
                    Active                   = $device.Active
                    Obsolete                 = $device.Obsolete
                    ADSiteName               = $device.ADSiteName
                    SiteCode                 = $device.SMSSiteCode
                }

                # Set the type name as well
                $output.PSObject.TypeNames.Insert(0, 'MECM7.Device')

                # Add all properties if not Fast mode
                if (-not $Fast) {
                    $device.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }
                }

                Write-Output $output
            }
        } else {
            Write-Verbose "No devices found matching the criteria."
        }
    }
    catch {
        throw $_
    }
}
