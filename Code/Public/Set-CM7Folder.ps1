function Set-CM7Folder {
    <#
        .SYNOPSIS
            Modifies an existing folder in MECM using CIM (rename, move, change parent).

        .DESCRIPTION
            Updates folder properties in MECM via CIM, including renaming and moving folders. CIM-based equivalent of Set-CMFolder from the ConfigurationManager module.

        .PARAMETER Name
            The name of the folder to modify (used with Path).

        .PARAMETER Path
            The path of the folder to modify (e.g., 'DeviceCollection\TestCollections\Test').

        .PARAMETER ContainerNodeID
            The unique ContainerNodeID of the folder to modify.

        .PARAMETER NewName
            The new name for the folder.

        .PARAMETER NewParentPath
            The path of the new parent folder.

        .PARAMETER ObjectType
            The type of folder (e.g., 'DeviceCollection').

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Set-CM7Folder -Path 'TestCollections\Test' -Name 'ChildTestFolder' -NewName 'RenamedChildFolder'
            Renames the folder 'ChildTestFolder' to 'RenamedChildFolder'.

        .EXAMPLE
            Set-CM7Folder -ContainerNodeID 12345 -NewParentPath 'TestCollections\MovedHere'
            Moves the folder to a new parent folder.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByPath')]
    param(
        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true)]
        [string]$Path,
        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true)]
        [string]$Name,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [int]$ContainerNodeID,
        [Parameter()]
        [string]$NewName,
        [Parameter()]
        [string]$NewParentPath,
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

    function Resolve-FolderPath {
        param(
            [string]$Path,
            [int]$ObjectTypeValue,
            [object]$CimSession,
            [string]$Namespace
        )
        $segments = $Path -split '\\'
        $parentId = 0
        $resolvedId = $null
        foreach ($segment in $segments) {
            $query = "SELECT * FROM SMS_ObjectContainerNode WHERE ParentContainerNodeID = $parentId AND ObjectType = $ObjectTypeValue AND Name = '$segment'"
            $result = Get-CimInstance -CimSession $CimSession -Namespace $Namespace -Query $query
            if ($result) {
                $parentId = $result.ContainerNodeID
                $resolvedId = $parentId
            } else {
                return $null
            }
        }
        return $resolvedId
    }

    if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
        $parentId = Resolve-FolderPath -Path $Path -ObjectTypeValue $typeValue -CimSession $script:CMConnection.CimSession -Namespace $namespace
        if (-not $parentId) {
            throw "Parent folder path not found: $Path"
        }
        $query = "SELECT * FROM SMS_ObjectContainerNode WHERE ParentContainerNodeID = $parentId AND ObjectType = $typeValue AND Name = '$Name'"
        $folder = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query $query
        if (-not $folder) {
            throw "Folder not found: $Path\$Name"
        }
        $ContainerNodeID = $folder.ContainerNodeID
    } else {
        $folder = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query "SELECT * FROM SMS_ObjectContainerNode WHERE ContainerNodeID = $ContainerNodeID AND ObjectType = $typeValue"
        if (-not $folder) {
            throw "Folder not found: ContainerNodeID $ContainerNodeID"
        }
    }

    $updateParams = @{}
    if ($NewName) {
        $updateParams['Name'] = $NewName
    }
    if ($NewParentPath) {
        $newParentId = Resolve-FolderPath -Path $NewParentPath -ObjectTypeValue $typeValue -CimSession $script:CMConnection.CimSession -Namespace $namespace
        if (-not $newParentId) {
            throw "New parent folder path not found: $NewParentPath"
        }
        $updateParams['ParentContainerNodeID'] = $newParentId
    }
    if ($updateParams.Count -eq 0) {
        throw "No changes specified. Provide -NewName and/or -NewParentPath."
    }

    if ($PSCmdlet.ShouldProcess("Folder $($folder.Name) (ID: $ContainerNodeID)", "Update properties: $($updateParams | Out-String)")) {
        Set-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $folder -Property $updateParams
        Write-Verbose "Folder updated: $($folder.Name)"
        return Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace $namespace -Query "SELECT * FROM SMS_ObjectContainerNode WHERE ContainerNodeID = $ContainerNodeID AND ObjectType = $typeValue"
    } else {
        Write-Verbose "WhatIf: Folder would be updated: $($folder.Name)"
    }
}
