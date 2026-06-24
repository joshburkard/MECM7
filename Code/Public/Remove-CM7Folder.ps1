function Remove-CM7Folder {
    <#
        .SYNOPSIS
            Removes a folder in MECM using CIM.

        .DESCRIPTION
            Removes a folder by path, name, ContainerNodeID, or input object from Microsoft Endpoint Configuration Manager (MECM) using CIM. This is the CIM-based equivalent of Remove-CMFolder from the ConfigurationManager module.

        .PARAMETER Path
            The path of the folder to remove (e.g., 'DeviceCollection\\TestCollections\\Test').

        .PARAMETER Name
            The name of the folder to remove. Used with ParentContainerNodeID or ParentFolder.

        .PARAMETER ContainerNodeID
            The unique ContainerNodeID of the folder to remove.

        .PARAMETER InputObject
            The folder object (from Get-CM7Folder) to remove.

        .PARAMETER ObjectType
            The type of folder to remove (e.g., 'DeviceCollection').

        .PARAMETER ParentContainerNodeID
            The ContainerNodeID of the parent folder.

        .PARAMETER ParentFolder
            The parent folder object (from Get-CM7Folder).

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7Folder -Path 'DeviceCollection\\TestCollections\\Test' -ObjectType DeviceCollection
            Removes the folder at the specified path for DeviceCollection type.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByPath')]
    param(
        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true, Position = 0)]
        [string]$Path,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByParentFolder', Mandatory = $true)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [int]$ParentContainerNodeID,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [int]$ContainerNodeID,

        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject,

        [Parameter(ParameterSetName = 'ByParentFolder', Mandatory = $true)]
        [object]$ParentFolder,

        [Parameter()]
        [ValidateSet('DeviceCollection', 'UserCollection', 'Package', 'Advertisement', 'Query', 'Report', 'MeteredProductRule', 'ConfigurationItem', 'OSInstallPackage', 'StateMigration', 'ImagePackage', 'BootImagePackage', 'TaskSequencePackage', 'DeviceSettingPackage', 'DriverPackage', 'SoftwareUpdatesPackage', 'Driver', 'Scripts', 'SoftwareUpdate', 'ConfigurationBaseline', 'AuthorizationList', 'AutoDeployment')]
        [string]$ObjectType = 'DeviceCollection'
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }
    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $cimParams = @{ CimSession = $script:CMConnection.CimSession; Namespace = $namespace }
    $objectTypeMap = @{
        DeviceCollection = 5000
        Package = 2
        Advertisement = 3
        Query = 7
        Report = 8
        MeteredProductRule = 9
        ConfigurationItem = 11
        OSInstallPackage = 14
        StateMigration = 17
        ImagePackage = 18
        BootImagePackage = 19
        TaskSequencePackage = 20
        DeviceSettingPackage = 21
        DriverPackage = 23
        SoftwareUpdatesPackage = 24
        Driver = 25
        Scripts = 213
        SoftwareUpdate = 1011
        ConfigurationBaseline = 2011
        AuthorizationList = 5011
        ApplicationLatest = 6000
        ConfigurationItemLatest = 6001
        AutoDeployment = 6011
        UserCollection = 5001
    }
    $typeValue = $objectTypeMap[$ObjectType]
    try {
        $folder = $null
        switch ($PSCmdlet.ParameterSetName) {
            'ByPath' {
                function Resolve-FolderPath {
                    param(
                        [string]$Path,
                        [int]$ObjectTypeValue,
                        [object]$CimSession,
                        [string]$Namespace
                    )
                    $segments = $Path -split '\\'
                    $parentId = 0
                    $resolved = $null
                    foreach ($segment in $segments) {
                        $query = "SELECT * FROM SMS_ObjectContainerNode WHERE ParentContainerNodeID = $parentId AND ObjectType = $ObjectTypeValue AND Name = '$segment'"
                        Write-Verbose "Resolving segment '$segment' with query: $query"
                        $result = Get-CimInstance @cimParams -Query $query
                        if ($result) {
                            $parentId = $result.ContainerNodeID
                            $resolved = $result
                        } else {
                            return $null
                        }
                    }
                    return $resolved
                }
                $folder = Resolve-FolderPath -Path $Path -ObjectTypeValue $typeValue -CimSession $script:CMConnection.CimSession -Namespace $namespace
                if (-not $folder) { throw "Folder path '$Path' not found." }
            }
            'ByName' {
                $query = "SELECT * FROM SMS_ObjectContainerNode WHERE ParentContainerNodeID = $ParentContainerNodeID AND ObjectType = $typeValue AND Name = '$Name'"
                $folder = Get-CimInstance @cimParams -Query $query
                if (-not $folder) { throw "Folder '$Name' not found under parent ID $ParentContainerNodeID." }
            }
            'ById' {
                $query = "SELECT * FROM SMS_ObjectContainerNode WHERE ContainerNodeID = $ContainerNodeID AND ObjectType = $typeValue"
                $folder = Get-CimInstance @cimParams -Query $query
                if (-not $folder) { throw "Folder with ContainerNodeID $ContainerNodeID not found." }
            }
            'ByInputObject' {
                if ($InputObject.ContainerNodeID) {
                    $folder = $InputObject
                } else {
                    throw "InputObject does not have a ContainerNodeID property."
                }
            }
            'ByParentFolder' {
                if ($ParentFolder.ContainerNodeID) {
                    $query = "SELECT * FROM SMS_ObjectContainerNode WHERE ParentContainerNodeID = $($ParentFolder.ContainerNodeID) AND ObjectType = $typeValue AND Name = '$Name'"
                    $folder = Get-CimInstance @cimParams -Query $query
                    if (-not $folder) { throw "Folder '$Name' not found under specified parent folder." }
                } else {
                    throw "ParentFolder does not have a ContainerNodeID property."
                }
            }
        }

        if ($folder) {
            # If $folder is an array, throw if multiple, else use the first
            if ($folder -is [System.Array]) {
                if ($folder.Count -gt 1) {
                    throw "Multiple folders matched. Please specify a unique folder."
                }
                $folder = $folder[0]
            }
            # If not a CIM instance, try to re-query by ContainerNodeID
            if ($folder -isnot [Microsoft.Management.Infrastructure.CimInstance]) {
                if ($folder.PSObject.Properties["ContainerNodeID"]) {
                    $query = "SELECT * FROM SMS_ObjectContainerNode WHERE ContainerNodeID = $($folder.ContainerNodeID) AND ObjectType = $typeValue"
                    $folder = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query $query
                    if ($folder -is [System.Array]) {
                        if ($folder.Count -gt 1) {
                            throw "Multiple folders matched by ContainerNodeID. Please specify a unique folder."
                        }
                        $folder = $folder[0]
                    }
                } else {
                    throw "Resolved folder is not a CIM instance and has no ContainerNodeID. Cannot remove."
                }
            }
            if ($folder -isnot [Microsoft.Management.Infrastructure.CimInstance]) {
                throw "Resolved folder is not a CIM instance. Cannot remove."
            }
            $actionDescription = "Remove folder '$($folder.Name)' (ID: $($folder.ContainerNodeID))"
            if ($PSCmdlet.ShouldProcess($folder.Name, $actionDescription)) {
                Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $folder
                Write-Verbose "Folder '$($folder.Name)' removed."
            }
        }
    } catch {
        throw $_
    }
}
