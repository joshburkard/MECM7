function Get-CM7Folder {
    <#
        .SYNOPSIS
            Retrieves folder information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_ObjectContainerNode WMI class to retrieve folder information from MECM.
            Supports filtering by folder path, name, and ObjectType. Enumerates folders to resolve full path.
            CIM-based equivalent of Get-CMFolder from the ConfigurationManager module.

        .PARAMETER Path
            The path of the folder to retrieve. Supports wildcards (*, ?).

        .PARAMETER Name
            The name of the folder to retrieve. Supports wildcards (*, ?).

        .PARAMETER ContainerNodeID
            The unique ContainerNodeID of the folder to retrieve.

        .PARAMETER ObjectType
            The type of folder to enumerate. Use tab completion for allowed types.

        .PARAMETER ParentContainerNodeID
            The ContainerNodeID of the parent folder to filter by.

        .PARAMETER ParentFolder
            The parent folder object to filter by. Must have a ContainerNodeID property.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like ContainerNodeID, Name, ObjectType, and ParentContainerNodeID.

        .EXAMPLE
            Get-CM7Folder -Path "DeviceCollection\\TestCollections\\Test" -ObjectType DeviceCollection
            Retrieves the folder at the specified path for DeviceCollection type.

        .EXAMPLE
            Get-CM7Folder -Name "Test*" -ObjectType DeviceCollection
            Retrieves all folders whose names start with "Test" for DeviceCollection type.

        .EXAMPLE
            Get-CM7Folder -Fast -ObjectType DeviceCollection
            Retrieves all folders with limited properties for faster query performance for DeviceCollection type.
    #>
        [CmdletBinding(DefaultParameterSetName = 'All')]
        param(
            [Parameter(ParameterSetName = 'ByPath', Position = 0)]
            [SupportsWildcards()]
            [string]$Path,

            [Parameter(ParameterSetName = 'ByName')]
            [SupportsWildcards()]
            [string]$Name,

            [Parameter(ParameterSetName = 'ByContainerNodeID')]
            [int]$ContainerNodeID,

            [Parameter(ParameterSetName = 'ByParentId')]
            [int]$ParentContainerNodeID,

            [Parameter(ParameterSetName = 'ByParentFolder')]
            [object]$ParentFolder,

            [Parameter()]
            [ValidateSet('DeviceCollection', 'UserCollection', 'Package', 'Advertisement', 'Query', 'Report', 'MeteredProductRule', 'ConfigurationItem', 'OSInstallPackage', 'StateMigration', 'ImagePackage', 'BootImagePackage', 'TaskSequencePackage', 'DeviceSettingPackage', 'DriverPackage', 'SoftwareUpdatesPackage', 'Driver', 'Scripts', 'SoftwareUpdate', 'ConfigurationBaseline', 'AuthorizationList', 'AutoDeployment')]
            [string]$ObjectType = 'DeviceCollection',

            [Parameter()]
            [switch]$Fast
        )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    # Map ObjectType string to integer value
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
        # Split path into segments
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

    try {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $queryParams = @{ CimSession = $script:CMConnection.CimSession; Namespace = $namespace }
        $filters = @()

        if ($Path) {
            Write-Verbose "Resolving folder path: $Path for ObjectType: $ObjectType"
            $folderId = Resolve-FolderPath -Path $Path -ObjectTypeValue $typeValue -CimSession $script:CMConnection.CimSession -Namespace $namespace
            if ($folderId) {
                $filters += "ContainerNodeID = $folderId"
            } else {
                Write-Verbose "Folder path not found: $Path"
                return
            }
        }
        elseif ($ContainerNodeID -and $ContainerNodeID -ne 0) {
            Write-Verbose "Filtering by ContainerNodeID: $ContainerNodeID"
            $filters += "ContainerNodeID = $ContainerNodeID"
        }
        elseif ($ParentContainerNodeID -and $ParentContainerNodeID -ne 0) {
            Write-Verbose "Filtering by ParentContainerNodeID: $ParentContainerNodeID"
            $filters += "ParentContainerNodeID = $ParentContainerNodeID AND ObjectType = $typeValue"
        }
        elseif ($ParentFolder) {
            write-verbose "Filtering by ParentFolder object"
            if ($ParentFolder.ContainerNodeID) {
                $filters += "ParentContainerNodeID = $($ParentFolder.ContainerNodeID) AND ObjectType = $typeValue"
            } else {
                Write-Verbose "ParentFolder does not have a ContainerNodeID property."
                return
            }
        }
        elseif ($Name) {
            write-verbose "Filtering by Name: $Name with wildcards"
            $wqlName = $Name.Replace('*', '%').Replace('?', '_')
            $filters += "Name LIKE '$wqlName' AND ObjectType = $typeValue"
        }
        elseif (-not $Path -and -not $Name -and ( -not $ParentContainerNodeID -or $ParentContainerNodeID -eq 0) -and -not $ParentFolder -and -not $ContainerNodeID) {
            Write-Verbose "No specific filters provided. Returning all root folders of type $ObjectType."
            # Return all root folders for ObjectType
            $filters += "ParentContainerNodeID = 0 AND ObjectType = $typeValue"
        }
        else {
            Write-Verbose "No valid filter parameters provided. Returning all root folders of type $ObjectType."
            $filters += "ParentContainerNodeID = 0 AND ObjectType = $typeValue"
        }
        Write-Verbose "Path: $Path, Name: $Name, ContainerNodeID: $ContainerNodeID, ParentContainerNodeID: $ParentContainerNodeID, ParentFolder: $($ParentFolder -ne $null)"

        $filter = $filters -join ' AND '

        write-verbose "Constructed filter: $filter"
        if ($Fast) {
            $properties = "ContainerNodeID, Name, ObjectType, ParentContainerNodeID, ObjectPath"
            $query = "SELECT $properties FROM SMS_ObjectContainerNode"
        } else {
            $query = "SELECT * FROM SMS_ObjectContainerNode"
        }
        if ( [boolean]$filter ) {
            $query += " WHERE $filter"
        }
        Write-Verbose "Executing query: $query"
        $folders = Get-CimInstance @queryParams -Query $query
        if ($folders) {
            foreach ($folder in $folders) {
                $output = [PSCustomObject]@{
                    PSTypeName = 'MECM7.Folder'
                    ContainerNodeID = $folder.ContainerNodeID
                    Name = $folder.Name
                    ObjectType = $folder.ObjectType
                    ParentContainerNodeID = $folder.ParentContainerNodeID
                    ObjectPath = $folder.ObjectPath
                }
                if (-not $Fast) {
                    $folder.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }
                }
                Write-Output $output
            }
        } else {
            Write-Verbose "No folders found matching the criteria."
        }
    } catch {
        throw $_
    }
}
