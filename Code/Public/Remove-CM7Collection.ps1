function Remove-CM7Collection {
    <#
        .SYNOPSIS
            Removes a collection from MECM using CIM.

        .DESCRIPTION
            Removes (deletes) a device or user collection from Microsoft Endpoint Configuration
            Manager (MECM) using CIM. This function deletes an SMS_Collection instance
            via CIM.

            This is the CIM-based equivalent of the Remove-CMCollection / Remove-CMDeviceCollection /
            Remove-CMUserCollection cmdlets from the ConfigurationManager PowerShell module.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the collection (by name, ID, or input object)
            3. Validates the collection is not a built-in protected collection
            4. Optionally warns about member count before removal
            5. Removes the SMS_Collection instance via CIM

        .PARAMETER Name
            The name of the collection to remove. If multiple collections match the name,
            an error is thrown. Use -CollectionId for unambiguous removal.

        .PARAMETER CollectionId
            The CollectionID of the collection to remove. Provides unambiguous identification.

        .PARAMETER InputObject
            A collection object (e.g., from Get-CM7Collection) to remove.
            Must have a CollectionId or CollectionID property.

        .PARAMETER Force
            Suppresses confirmation prompts and removes the collection without asking.
            By default, the function prompts for confirmation before deletion.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7Collection -Name "Old Test Collection"
            Removes the collection named "Old Test Collection" after confirmation.

        .EXAMPLE
            Remove-CM7Collection -CollectionId "CM101C99" -Force
            Removes the collection with the specified ID without prompting for confirmation.

        .EXAMPLE
            Get-CM7Collection -Name "Test-*" | Remove-CM7Collection -Force
            Removes all collections matching the wildcard pattern via pipeline.

        .EXAMPLE
            Remove-CM7Collection -Name "Temp Collection" -WhatIf
            Shows what would happen without actually removing the collection.

        .EXAMPLE
            $coll = Get-CM7Collection -CollectionId "CM101C50"
            Remove-CM7Collection -InputObject $coll -Force
            Removes a collection using a previously retrieved collection object.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSObject]$InputObject,

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

        # Built-in protected collections that should never be deleted
        $protectedCollectionIds = @(
            'SMS00001'  # All Systems
            'SMS00002'  # All Users and User Groups
            'SMS00003'  # All User Groups
            'SMS00004'  # All Users
            'SMS00005'  # All Unknown Computers (if exists)
            'SMSDM001'  # All Mobile Devices
            'SMSDM003'  # All Desktop and Server Clients
        )
    }

    process {
        try {
            # ---- Resolve Collection ----
            $resolvedCollectionId = $null
            $resolvedCollectionName = $null
            $collectionInstance = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    $query = "SELECT * FROM SMS_Collection WHERE Name = '$Name'"
                    Write-Verbose "Looking up collection by name: $query"
                    $collections = @(Get-CimInstance @cimParams -Query $query)

                    if (-not $collections -or $collections.Count -eq 0) {
                        throw "Collection with name '$Name' was not found."
                    }

                    if ($collections.Count -gt 1) {
                        throw "Multiple collections found with name '$Name'. Please use -CollectionId for unambiguous removal."
                    }

                    $collectionInstance = $collections[0]
                    $resolvedCollectionId = $collectionInstance.CollectionID
                    $resolvedCollectionName = $collectionInstance.Name
                }
                'ById' {
                    $query = "SELECT * FROM SMS_Collection WHERE CollectionID = '$CollectionId'"
                    Write-Verbose "Looking up collection by ID: $query"
                    $collectionInstance = Get-CimInstance @cimParams -Query $query

                    if (-not $collectionInstance) {
                        throw "Collection with ID '$CollectionId' was not found."
                    }

                    $resolvedCollectionId = $collectionInstance.CollectionID
                    $resolvedCollectionName = $collectionInstance.Name
                }
                'ByInputObject' {
                    # Extract CollectionId from input object
                    $inputId = $null
                    if ($InputObject.PSObject.Properties['CollectionId']) {
                        $inputId = $InputObject.CollectionId
                    } elseif ($InputObject.PSObject.Properties['CollectionID']) {
                        $inputId = $InputObject.CollectionID
                    }

                    if (-not $inputId) {
                        throw "InputObject does not have a CollectionId or CollectionID property."
                    }

                    # Re-fetch from CIM to ensure we have the actual instance
                    $query = "SELECT * FROM SMS_Collection WHERE CollectionID = '$inputId'"
                    Write-Verbose "Looking up collection from InputObject: $query"
                    $collectionInstance = Get-CimInstance @cimParams -Query $query

                    if (-not $collectionInstance) {
                        throw "Collection with ID '$inputId' from InputObject was not found in MECM."
                    }

                    $resolvedCollectionId = $collectionInstance.CollectionID
                    $resolvedCollectionName = $collectionInstance.Name
                }
            }

            Write-Verbose "Resolved collection: '$resolvedCollectionName' ($resolvedCollectionId)"

            # ---- Check for protected collections ----
            if ($resolvedCollectionId -in $protectedCollectionIds) {
                throw "Cannot remove built-in collection '$resolvedCollectionName' ($resolvedCollectionId). This is a protected system collection."
            }

            # ---- Get member count for information ----
            $memberCount = $collectionInstance.MemberCount
            if ($memberCount -gt 0) {
                Write-Warning "Collection '$resolvedCollectionName' ($resolvedCollectionId) has $memberCount member(s)."
            }

            # ---- Get collection type for display ----
            $typeDisplay = switch ($collectionInstance.CollectionType) {
                1 { 'User' }
                2 { 'Device' }
                default { 'Unknown' }
            }

            # ---- Remove the collection ----
            $actionDescription = "Remove $typeDisplay collection '$resolvedCollectionName' ($resolvedCollectionId)"
            if ($memberCount -gt 0) {
                $actionDescription += " with $memberCount member(s)"
            }

            if ($Force -or $PSCmdlet.ShouldProcess($resolvedCollectionName, $actionDescription)) {
                Write-Verbose "Removing collection: $actionDescription"

                Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $collectionInstance

                Write-Verbose "Collection '$resolvedCollectionName' ($resolvedCollectionId) removed successfully."

                # Return a result object with information about the removed collection
                [PSCustomObject]@{
                    PSTypeName     = 'MECM7.RemovedCollection'
                    CollectionId   = $resolvedCollectionId
                    Name           = $resolvedCollectionName
                    CollectionType = $typeDisplay
                    MemberCount    = $memberCount
                    Status         = 'Removed'
                }
            }
        }
        catch {
            throw $_
        }
    }
}
