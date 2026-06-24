function New-CM7Folder {
    <#
        .SYNOPSIS
            Creates a new folder in MECM using CIM.

        .DESCRIPTION
            Creates a new folder under a specified parent folder path or parent folder object in Microsoft Endpoint Configuration Manager (MECM) using CIM. This is the CIM-based equivalent of New-CMFolder from the ConfigurationManager module.

        .PARAMETER Name
            The name of the new folder to create.

        .PARAMETER ParentFolderPath
            The path of the parent folder (e.g., 'DeviceCollection\\TestCollections\\Test').

        .PARAMETER InputObject
            The parent folder object (from Get-CM7Folder) to create the new folder under.

        .PARAMETER ObjectType
            The type of folder to create (e.g., 'DeviceCollection').

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7Folder -ParentFolderPath 'TestCollections\\Test' -Name 'ChildTestFolder'
            Creates a new folder named 'ChildTestFolder' under 'DeviceCollection\\TestCollections\\Test'.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByParentPath')]
    param(
        [Parameter(ParameterSetName = 'ByParentPath', Mandatory = $true)]
        [string]$ParentFolderPath,

        [Parameter(ParameterSetName = 'ByParentObject', Mandatory = $true)]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name,

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
        $parentId = $null
        if ($PSCmdlet.ParameterSetName -eq 'ByParentPath') {
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
            $parentId = Resolve-FolderPath -Path $ParentFolderPath -ObjectTypeValue $typeValue -CimSession $script:CMConnection.CimSession -Namespace $namespace
            if (-not $parentId) {
                throw "Parent folder path '$ParentFolderPath' not found."
            }
        } elseif ($PSCmdlet.ParameterSetName -eq 'ByParentObject') {
            if ($InputObject.ContainerNodeID) {
                $parentId = $InputObject.ContainerNodeID
            } else {
                throw "InputObject does not have a ContainerNodeID property."
            }
        }

        $dupQuery = "SELECT * FROM SMS_ObjectContainerNode WHERE ParentContainerNodeID = $parentId AND ObjectType = $typeValue AND Name = '$Name'"
        $dupResult = Get-CimInstance @cimParams -Query $dupQuery
        if ($dupResult) {
            throw "A folder named '$Name' already exists under the specified parent."
        }

        $actionDescription = "Create folder '$Name' under parent ID $parentId (ObjectType: $ObjectType)"
        if ($PSCmdlet.ShouldProcess($Name, $actionDescription)) {
            $folderProps = @{
                Name = $Name
                ObjectType = [int]$typeValue
                ParentContainerNodeID = [int]$parentId
            }
            $newFolder = New-CimInstance @cimParams -ClassName 'SMS_ObjectContainerNode' -Property $folderProps
            if (-not $newFolder) {
                throw "Failed to create folder '$Name'. New-CimInstance returned null."
            }
            $output = [PSCustomObject]@{
                PSTypeName = 'MECM7.Folder'
                ContainerNodeID = $newFolder.ContainerNodeID
                Name = $newFolder.Name
                ObjectType = $newFolder.ObjectType
                ParentContainerNodeID = $newFolder.ParentContainerNodeID
            }
            $output.PSObject.TypeNames.Insert(0, 'MECM7.Folder')
            $newFolder.CimInstanceProperties | ForEach-Object {
                if ($_.Name -notin $output.PSObject.Properties.Name) {
                    $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                }
            }
            Write-Output $output
        }
    } catch {
        throw $_
    }
}
