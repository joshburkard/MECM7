function Move-CM7Object {
    <#
        .SYNOPSIS
            Moves one or more MECM objects to a specified folder using CIM.

        .DESCRIPTION
            Moves MECM objects (such as collections, packages, applications, etc.) from their
            current folder location to a specified destination folder. This function uses the
            SMS_ObjectContainerItem WMI class and MoveMembers method via CIM.

            This is the CIM-based equivalent of the Move-CMObject cmdlet from the
            ConfigurationManager PowerShell module.

            Supported object types:
            - Package (2)
            - Query (7)
            - Metering Rule (9)
            - Operating System Install Package (14)
            - State Migration (17)
            - Image Package (18)
            - Boot Image Package (19)
            - Task Sequence Package (20)
            - Driver Package (23)
            - Driver (25)
            - Software Update Group (1011)
            - Configuration Baseline (2011)
            - Device Collection (5000)
            - User Collection (5001)
            - Application (6000)
            - Configuration Item (6001)

        .PARAMETER FolderId
            The ID of the destination folder. Use 0 to move the object to the root folder.
            Mutually exclusive with FolderPath.

        .PARAMETER FolderPath
            The folder path in MECM format: SiteCode:\ObjectType\Folder\SubFolder
            For example: CM1:\DeviceCollection\TestCollections\Test
            The path is resolved by walking the SMS_ObjectContainerNode hierarchy.
            The ObjectType is automatically derived from the path category.
            Mutually exclusive with FolderId.

        .PARAMETER ObjectId
            An array of object IDs to move. These are the instance keys (e.g., CollectionID
            for collections, PackageID for packages).

        .PARAMETER ObjectType
            The type of object being moved. Valid values are:
            Package, Query, MeteringRule, OSInstallPackage, StateMigration,
            ImagePackage, BootImagePackage, TaskSequencePackage, DriverPackage,
            Driver, SoftwareUpdateGroup, ConfigurationBaseline, DeviceCollection,
            UserCollection, Application, ConfigurationItem.
            When using -FolderPath, this is automatically derived from the path.

        .PARAMETER InputObject
            One or more CIM instances to move. These must contain ObjectType and InstanceKey
            information (typically SMS_ObjectContainerItem objects or objects containing
            ContainerNodeID information).

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Move-CM7Object -ObjectId "CM100001" -ObjectType DeviceCollection -FolderId 3
            Moves the device collection with ID "CM100001" to folder ID 3.

        .EXAMPLE
            Move-CM7Object -ObjectId "CM100001" -FolderPath "CM1:\DeviceCollection\TestCollections\Test"
            Moves the device collection to the TestCollections\Test folder, resolving the path automatically.

        .EXAMPLE
            Move-CM7Object -ObjectId "CM100001", "CM100002" -ObjectType DeviceCollection -FolderId 0
            Moves two device collections to the root folder.

        .EXAMPLE
            Move-CM7Object -ObjectId "CM100001" -ObjectType DeviceCollection -FolderId 5 -WhatIf
            Shows what would happen without actually performing the move.

        .EXAMPLE
            $collections = Get-CM7Collection -Name "Test-*"
            $objectIds = $collections | ForEach-Object { $_.CollectionID }
            Move-CM7Object -ObjectId $objectIds -FolderPath "CM1:\DeviceCollection\Archive"
            Moves all collections matching "Test-*" to the Archive folder.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByObjectIdFolderId')]
    param(
        [Parameter(ParameterSetName = 'ByObjectIdFolderId', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByInputObjectFolderId', Mandatory = $true)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$FolderId,

        [Parameter(ParameterSetName = 'ByObjectIdFolderPath', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByInputObjectFolderPath', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FolderPath,

        [Parameter(ParameterSetName = 'ByObjectIdFolderId', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByObjectIdFolderPath', Mandatory = $true)]
        [string[]]$ObjectId,

        [Parameter(ParameterSetName = 'ByObjectIdFolderId', Mandatory = $true)]
        [ValidateSet(
            'Package',
            'Query',
            'MeteringRule',
            'OSInstallPackage',
            'StateMigration',
            'ImagePackage',
            'BootImagePackage',
            'TaskSequencePackage',
            'DriverPackage',
            'Driver',
            'SoftwareUpdateGroup',
            'ConfigurationBaseline',
            'DeviceCollection',
            'UserCollection',
            'Application',
            'ConfigurationItem'
        )]
        [string]$ObjectType,

        [Parameter(ParameterSetName = 'ByInputObjectFolderId', Mandatory = $true, ValueFromPipeline = $true)]
        [Parameter(ParameterSetName = 'ByInputObjectFolderPath', Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$InputObject,

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

        # ObjectType to numeric mapping
        $objectTypeMap = @{
            'Package'                = 2
            'Query'                  = 7
            'MeteringRule'           = 9
            'OSInstallPackage'       = 14
            'StateMigration'         = 17
            'ImagePackage'           = 18
            'BootImagePackage'       = 19
            'TaskSequencePackage'    = 20
            'DriverPackage'          = 23
            'Driver'                 = 25
            'SoftwareUpdateGroup'    = 1011
            'ConfigurationBaseline'  = 2011
            'DeviceCollection'       = 5000
            'UserCollection'         = 5001
            'Application'            = 6000
            'ConfigurationItem'      = 6001
        }

        # Folder category to SMS ObjectTypeName mapping (used for folder path resolution)
        $folderCategoryMap = @{
            'DeviceCollection'       = @{ ObjectTypeName = 'SMS_Collection_Device';                ObjectType = 5000 }
            'UserCollection'         = @{ ObjectTypeName = 'SMS_Collection_User';                  ObjectType = 5001 }
            'Package'                = @{ ObjectTypeName = 'SMS_Package';                          ObjectType = 2 }
            'Application'            = @{ ObjectTypeName = 'SMS_ApplicationLatest';                ObjectType = 6000 }
            'BootImagePackage'       = @{ ObjectTypeName = 'SMS_BootImagePackage';                 ObjectType = 19 }
            'DriverPackage'          = @{ ObjectTypeName = 'SMS_DriverPackage';                    ObjectType = 23 }
            'Driver'                 = @{ ObjectTypeName = 'SMS_Driver';                           ObjectType = 25 }
            'ImagePackage'           = @{ ObjectTypeName = 'SMS_ImagePackage';                     ObjectType = 18 }
            'OSInstallPackage'       = @{ ObjectTypeName = 'SMS_OperatingSystemInstallPackage';    ObjectType = 14 }
            'TaskSequencePackage'    = @{ ObjectTypeName = 'SMS_TaskSequencePackage';              ObjectType = 20 }
            'SoftwareUpdateGroup'    = @{ ObjectTypeName = 'SMS_AuthorizationList';                ObjectType = 1011 }
            'ConfigurationBaseline'  = @{ ObjectTypeName = 'SMS_ConfigurationBaselineInfo';        ObjectType = 2011 }
            'ConfigurationItem'      = @{ ObjectTypeName = 'SMS_ConfigurationItemLatest';          ObjectType = 6001 }
            'Query'                  = @{ ObjectTypeName = 'SMS_Query';                            ObjectType = 7 }
            'MeteringRule'           = @{ ObjectTypeName = 'SMS_MeteredProductRule';                ObjectType = 9 }
            'StateMigration'         = @{ ObjectTypeName = 'SMS_MigrationEntity';                  ObjectType = 17 }
        }

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build common CIM parameters
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Collect InputObjects from pipeline
        $collectedInputObjects = @()
    }

    process {
        if ($PSCmdlet.ParameterSetName -in 'ByInputObjectFolderId', 'ByInputObjectFolderPath') {
            $collectedInputObjects += $InputObject
        }
    }

    end {
        try {
            # ---- Resolve FolderPath to FolderId if specified ----
            $resolvedObjectTypeName = $null
            $resolvedObjectTypeNumeric = $null

            if ($PSBoundParameters.ContainsKey('FolderPath')) {
                Write-Verbose "Resolving FolderPath: $FolderPath"

                # Parse the path: SiteCode:\Category\Folder1\Folder2\...
                # Also support paths without the SiteCode:\ prefix
                $pathToResolve = $FolderPath

                # Strip site code prefix if present (e.g., "CM1:\DeviceCollection\..." -> "DeviceCollection\...")
                if ($pathToResolve -match '^[A-Za-z0-9]{1,3}:\\(.+)$') {
                    $pathToResolve = $Matches[1]
                }

                # Split into segments (wrap in @() to ensure array even for a single segment)
                $segments = @($pathToResolve -split '[/\\]' | Where-Object { $_ -ne '' })

                if ($segments.Count -lt 1) {
                    throw "Invalid FolderPath '$FolderPath'. Expected format: SiteCode:\ObjectType\Folder[\SubFolder\...]"
                }

                # First segment is the object type category
                $category = $segments[0]
                if (-not $folderCategoryMap.ContainsKey($category)) {
                    $validCategories = ($folderCategoryMap.Keys | Sort-Object) -join ', '
                    throw "Invalid object type category '$category' in FolderPath. Valid categories are: $validCategories"
                }

                $resolvedObjectTypeName = $folderCategoryMap[$category].ObjectTypeName
                $resolvedObjectTypeNumeric = $folderCategoryMap[$category].ObjectType
                Write-Verbose "FolderPath category '$category' maps to ObjectTypeName '$resolvedObjectTypeName' (ObjectType $resolvedObjectTypeNumeric)"

                # If only the category is specified (no sub-folders), target is root (0)
                if ($segments.Count -eq 1) {
                    $FolderId = 0
                    Write-Verbose "FolderPath points to root for category '$category'. FolderId = 0"
                } else {
                    # Walk the folder hierarchy starting from the root (ParentContainerNodeId = 0)
                    $parentNodeId = 0
                    $currentFolderId = $null

                    for ($i = 1; $i -lt $segments.Count; $i++) {
                        $folderName = $segments[$i]
                        $folderQuery = "SELECT * FROM SMS_ObjectContainerNode WHERE ObjectTypeName = '$resolvedObjectTypeName' AND ParentContainerNodeID = $parentNodeId AND SearchFolder = 0 AND Name = '$folderName'"
                        Write-Verbose "Resolving folder segment: $folderQuery"

                        $folderNode = Get-CimInstance @cimParams -Query $folderQuery

                        if (-not $folderNode) {
                            $resolvedSoFar = ($segments[0..$($i-1)]) -join '\'
                            throw "Folder '$folderName' was not found under '$resolvedSoFar'. Verify the folder path exists in MECM."
                        }

                        $currentFolderId = $folderNode.ContainerNodeID
                        $parentNodeId = $currentFolderId
                        Write-Verbose "Resolved '$folderName' to ContainerNodeID $currentFolderId"
                    }

                    $FolderId = $currentFolderId
                    Write-Verbose "FolderPath '$FolderPath' resolved to FolderId $FolderId"
                }
            }

            # Determine object IDs and type based on parameter set
            $instanceKeys = @()
            $objectTypeNumeric = $null

            switch -Wildcard ($PSCmdlet.ParameterSetName) {
                'ByObjectId*' {
                    $instanceKeys = $ObjectId
                    # Use explicit ObjectType if provided, otherwise use the one resolved from FolderPath
                    if ($PSBoundParameters.ContainsKey('ObjectType')) {
                        $objectTypeNumeric = $objectTypeMap[$ObjectType]
                    } elseif ($resolvedObjectTypeNumeric) {
                        $objectTypeNumeric = $resolvedObjectTypeNumeric
                    } else {
                        throw "ObjectType must be specified when using -FolderId. Use -FolderPath to auto-detect the object type."
                    }
                    Write-Verbose "Moving $($instanceKeys.Count) object(s) of type $objectTypeNumeric to folder $FolderId"
                }
                'ByInputObject*' {
                    foreach ($obj in $collectedInputObjects) {
                        # Try to extract instance key and object type from the input object
                        if ($obj.CollectionID) {
                            $instanceKeys += $obj.CollectionID
                            # Determine collection type
                            if ($null -eq $objectTypeNumeric) {
                                if ($resolvedObjectTypeNumeric) {
                                    $objectTypeNumeric = $resolvedObjectTypeNumeric
                                } elseif ($obj.CollectionType -eq 2) {
                                    $objectTypeNumeric = 5000  # Device Collection
                                } elseif ($obj.CollectionType -eq 1) {
                                    $objectTypeNumeric = 5001  # User Collection
                                } else {
                                    $objectTypeNumeric = 5000  # Default to Device Collection
                                }
                            }
                        } elseif ($obj.PackageID) {
                            $instanceKeys += $obj.PackageID
                            if ($null -eq $objectTypeNumeric) { $objectTypeNumeric = 2 }
                        } elseif ($obj.CI_ID) {
                            $instanceKeys += [string]$obj.CI_ID
                            if ($null -eq $objectTypeNumeric) { $objectTypeNumeric = 6000 }
                        } elseif ($obj.InstanceKey) {
                            $instanceKeys += $obj.InstanceKey
                            if ($null -eq $objectTypeNumeric -and $obj.ObjectType) {
                                $objectTypeNumeric = [int]$obj.ObjectType
                            }
                        } else {
                            Write-Warning "Unable to determine instance key for input object: $($obj | Out-String)"
                            continue
                        }
                    }

                    if ($instanceKeys.Count -eq 0) {
                        throw "No valid instance keys could be determined from the input objects."
                    }

                    if ($null -eq $objectTypeNumeric) {
                        throw "Unable to determine the object type from the input objects. Please use the -ObjectId and -ObjectType parameters instead."
                    }

                    Write-Verbose "Moving $($instanceKeys.Count) object(s) of type $objectTypeNumeric to folder $FolderId"
                }
            }

            # Validate the destination folder exists (unless moving to root = 0)
            if ($FolderId -ne 0) {
                $folderQuery = "SELECT * FROM SMS_ObjectContainerNode WHERE ContainerNodeID = $FolderId"
                Write-Verbose "Validating destination folder: $folderQuery"
                $folder = Get-CimInstance @cimParams -Query $folderQuery

                if (-not $folder) {
                    throw "Destination folder with ID $FolderId was not found."
                }

                # Validate that folder type matches object type
                if ($folder.ObjectType -ne $objectTypeNumeric) {
                    Write-Warning "Destination folder type ($($folder.ObjectType)) does not match object type ($objectTypeNumeric). The move may fail."
                }

                Write-Verbose "Destination folder: '$($folder.Name)' (ID: $FolderId, Type: $($folder.ObjectType))"
            }

            # For each object, find its current container
            foreach ($instanceKey in $instanceKeys) {
                # Find the current container item
                $containerQuery = "SELECT * FROM SMS_ObjectContainerItem WHERE InstanceKey = '$instanceKey' AND ObjectType = $objectTypeNumeric"
                Write-Verbose "Looking up current location: $containerQuery"
                $currentItem = Get-CimInstance @cimParams -Query $containerQuery

                $sourceContainerId = 0
                if ($currentItem) {
                    $sourceContainerId = $currentItem.ContainerNodeID
                    Write-Verbose "Object '$instanceKey' is currently in folder $sourceContainerId"
                } else {
                    Write-Verbose "Object '$instanceKey' is currently in the root folder (no container item found)"
                }

                # Skip if already in the target folder
                if ($sourceContainerId -eq $FolderId) {
                    Write-Verbose "Object '$instanceKey' is already in folder $FolderId. Skipping."
                    continue
                }

                # Perform the move using MoveMembers method on SMS_ObjectContainerItem
                $actionDescription = "Move object '$instanceKey' from folder $sourceContainerId to folder $FolderId"
                if ($Force -or $PSCmdlet.ShouldProcess($instanceKey, $actionDescription)) {
                    Write-Verbose "Executing: $actionDescription"

                    $moveParams = @{
                        InstanceKeys          = [string[]]@($instanceKey)
                        ContainerNodeID       = [uint32]$sourceContainerId
                        TargetContainerNodeID = [uint32]$FolderId
                        ObjectType            = [uint32]$objectTypeNumeric
                    }

                    $result = Invoke-CimMethod @cimParams -ClassName 'SMS_ObjectContainerItem' -MethodName 'MoveMembers' -Arguments $moveParams

                    if ($result.ReturnValue -eq 0) {
                        Write-Verbose "Successfully moved object '$instanceKey' to folder $FolderId"

                        # Output result object
                        [PSCustomObject]@{
                            PSTypeName  = 'MECM7.MoveResult'
                            InstanceKey = $instanceKey
                            ObjectType  = $objectTypeNumeric
                            SourceFolder = $sourceContainerId
                            TargetFolder = $FolderId
                            Success     = $true
                            Message     = "Object moved successfully"
                        }
                    } else {
                        Write-Warning "Failed to move object '$instanceKey'. Return value: $($result.ReturnValue)"

                        [PSCustomObject]@{
                            PSTypeName  = 'MECM7.MoveResult'
                            InstanceKey = $instanceKey
                            ObjectType  = $objectTypeNumeric
                            SourceFolder = $sourceContainerId
                            TargetFolder = $FolderId
                            Success     = $false
                            Message     = "Move failed with return value: $($result.ReturnValue)"
                        }
                    }
                }
            }
        }
        catch {
            throw $_
        }
    }
}
