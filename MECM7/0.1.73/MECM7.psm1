<#
    Generated at 03/16/2026 13:16:42 by Josua Burkard
#>
#region namespace MECM7
function Get-CM7FullCimInstance {
    <#
        .SYNOPSIS
            Retrieves full CIM instances from MECM based on the key properties of a given instances.

        .DESCRIPTION
            This is a private helper function that takes an array of CIM instances (usually with limited properties) and retrieves the full CIM instance for each one by querying MECM with the key properties (like CI_ID).
            This is useful for functions that initially query with a limited set of properties for performance reasons, but then need to retrieve the full instance for further processing.

        .PARAMETER Instance
            An array of CIM instances that contain at least the key properties (e.g., CI_ID) needed to uniquely identify the instance in MECM.
            The function will use these key properties to query MECM and retrieve the full CIM instance with all properties.

        .OUTPUTS
            An array of full CIM instances retrieved from MECM.
            Each instance will have all properties available from the SMS Provider.

        .EXAMPLE
            $partialApps = Get-CM7Application -Name "PowerShell*" -Fast
            $fullApps = Get-CM7FullCimInstance -Instance $partialApps

            This example retrieves applications with only key properties using the -Fast switch, and then gets the full CIM instances for those applications.

        .NOTES
            This is an internal helper function for the MECM7 module and is not intended to be called directly by users.
            It is used by other functions that need to retrieve full CIM instances after an initial query with limited properties.

            Ensure that you have an active connection to MECM using Connect-CM7 before calling this function, as it relies on the CIM session established by that connection.

            Perhaps you receive error messages about to small WSMAN Envelope size when running a Get-CM7 function with the -Fast switch.
            Please look then at this setup: https://docs.microsoft.com/en-us/windows/win32/winrm/installation-and-configuration-for-windows-remote-management#envelope-size-limits

            Get-Item -Path WSMan:\localhost\MaxEnvelopeSizeKb
            you can set the envelope size to 2048 KB (2MB) for example with:
            Set-Item -Path WSMan:\localhost\MaxEnvelopeSizeKb -Value 2048

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [CimInstance[]]$Instance
    )
    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        Write-Verbose "Retrieving full CIM instances for $($Instance.Count) items of class $($Instance[0].CimClass.CimClassName)."
        $fullInstances = @()
        foreach ($inst in $Instance) {
            try {
                Get-CimInstance -CimSession $Script:CMConnection.CimSession -InputObject $inst -ErrorAction Stop | ForEach-Object {
                    $fullInstances += $_
                }
            } catch {
                if ($_.Exception.Message -match 'exceeds the maximum envelope size that is allowed') {
                    $msg = @(
                        $_.Exception.Message,
                        '',
                        'Recommendation: Increase the WinRM MaxEnvelopeSizekb setting on both client and server to at least 2048 (2MB) using:',
                        '    Set-Item -Path WSMan:\\localhost\\MaxEnvelopeSizekb -Value 2048',
                        '    Set-Item -Path WSMan:\\localhost\\Client\\MaxEnvelopeSizekb -Value 2048',
                        'Then restart the powershell session and retry your operation.'
                    ) -join "`n"
                    throw $msg
                } else {
                    throw "Failed to retrieve full CIM instance for CI_ID $($inst.CI_ID): $_"
                }
            }
        }
        return $fullInstances
    }
    catch {
        throw $_
    }
}
function Invoke-CM7Connection {
    <#
        .SYNOPSIS
            Establishes a CIM session to an MECM SMS Provider and retrieves connection information.

        .DESCRIPTION
            This is a private helper function that creates a CIM session to a specified MECM/SCCM
            site server and discovers the SMS Provider location via WMI queries.

            The function:
            1. Creates a CIM session to the specified site server
            2. Queries the SMS_ProviderLocation class in root\SMS namespace
            3. Retrieves the site code and provider machine name
            4. Returns connection details for use by other MECM7 functions

            This function is called internally by Connect-CM7 and should not be called directly.

        .PARAMETER SiteServer
            The hostname or IP address of the MECM site server or SMS Provider.
            This server must have WinRM enabled and accessible.

        .PARAMETER Credential
            Optional. A PSCredential object for authentication to the site server.
            If not provided, the current user's credentials are used.

        .PARAMETER UseSsl
            Use HTTPS for WinRM communication instead of HTTP.

        .PARAMETER SkipCertificateCheck
            Skip certificate validation when using SSL. Useful for self-signed certificates.

        .OUTPUTS
            PSCustomObject with the following properties:
            - CimSession: The established CIM session object
            - SiteCode: The MECM site code (e.g., "CM1")
            - ProviderMachineName: The machine name of the SMS Provider

        .EXAMPLE
            $connection = Invoke-CM7Connection -SiteServer "mecm.contoso.local"

            Establishes a CIM session to the MECM server and returns connection details.

        .EXAMPLE
            $cred = Get-Credential
            $connection = Invoke-CM7Connection -SiteServer "mecm.contoso.local" -Credential $cred -UseSsl -SkipCertificateCheck

            Establishes a CIM session with specific credentials and SSL configuration.

        .NOTES
            This is an internal helper function for the MECM7 module.

            Error Handling:
            - If CIM session creation fails, an error is thrown with details
            - If SMS Provider location cannot be found, the CIM session is automatically closed and an error is thrown
            - The function properly cleans up resources on failure

        .LINK
            Connect-CM7
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteServer,
        [Parameter()]
        [pscredential]$Credential,
        [Parameter()]
        [switch]$UseSsl,
        [Parameter()]
        [switch]$SkipCertificateCheck
    )

    # Build CIM session parameters
    $cimParams = @{
        ComputerName = $SiteServer
    }
    if ($Credential) { $cimParams.Credential = $Credential }

    # Only create SessionOption if special options are needed
    if ($UseSsl -or $SkipCertificateCheck) {
        $sessionOptions = New-CimSessionOption -Protocol Wsman

        if ($UseSsl) {
            $sessionOptions.UseSsl = $true
        }
        if ($SkipCertificateCheck) {
            $sessionOptions.CertCACheck = $false
            $sessionOptions.CertCNCheck = $false
            $sessionOptions.CertRevocationCheck = $false
        }

        $cimParams.SessionOption = $sessionOptions
    }

    # Create CIM session - this should not have nested try/catch
    try {
        Write-Verbose "Creating CIM session to $SiteServer..."
        $cimSession = New-CimSession @cimParams
    }
    catch {
        $errorMessage = "Failed to create CIM session to $SiteServer. $($_.Exception.Message)"
        Write-Error -Message $errorMessage -ErrorAction Stop
        return
    }

    # Verify CIM session was created successfully
    if (-not $cimSession) {
        throw "Failed to create CIM session to $SiteServer. Session is null."
    }

    # Query SMS Provider location - separate from session creation
    try {
        Write-Verbose "Querying SMS Provider location..."
        $provider = Get-CimInstance -CimSession $cimSession -Namespace "root\SMS" -ClassName "SMS_ProviderLocation" -ErrorAction Stop |
            Where-Object { $_.ProviderForLocalSite -eq $true } |
            Select-Object -First 1

        if (-not $provider) {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
            throw "SMS Provider location not found in root\SMS on $SiteServer."
        }

        Write-Verbose "Connected to MECM site $($provider.SiteCode) on $($provider.Machine)"

        return [PSCustomObject]@{
            CimSession = $cimSession
            SiteCode = $provider.SiteCode
            ProviderMachineName = $provider.Machine
        }
    }
    catch {
        if ($cimSession) {
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
        }
        throw $_
    }
}
function Add-CM7BoundaryToGroup {
    <#
        .SYNOPSIS
            Assigns a boundary to a boundary group in MECM using CIM.

        .DESCRIPTION
            Assigns an existing boundary to an existing boundary group in Microsoft Endpoint
            Configuration Manager (MECM) using CIM. The boundary group and the boundary can each
            be identified by their ID, name, or by passing an object from Get-CM7BoundaryGroup /
            Get-CM7Boundary respectively.

            Internally, the function invokes the AddBoundary instance method on the
            SMS_BoundaryGroup WMI class.

            This is the CIM-based equivalent of the Add-CMBoundaryToGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER BoundaryGroupId
            The GroupID (integer) of the existing boundary group to assign the boundary to.

        .PARAMETER BoundaryGroupName
            The name of the existing boundary group to assign the boundary to.

        .PARAMETER BoundaryGroupInputObject
            A boundary group object (e.g. from Get-CM7BoundaryGroup) to assign the boundary to.
            Alias: BoundaryGroup

        .PARAMETER BoundaryId
            The BoundaryID (integer) of the boundary to assign.

        .PARAMETER BoundaryName
            The name of the boundary to assign.

        .PARAMETER InputObject
            A boundary object (e.g. from Get-CM7Boundary) to assign.
            Accepts pipeline input.
            Aliases: Boundary, BoundaryInputObject

        .PARAMETER DisableWildcardHandling
            Treats wildcard characters as literal character values.
            Cannot be combined with ForceWildcardHandling.

        .PARAMETER ForceWildcardHandling
            Forces wildcard character processing even in contexts where it is not normally
            supported. May lead to unexpected behavior (not recommended).
            Cannot be combined with DisableWildcardHandling.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Add-CM7BoundaryToGroup -BoundaryGroupId 16777219 -BoundaryName "CLBound03"
            Assigns the boundary named "CLBound03" to the boundary group with GroupID 16777219.

        .EXAMPLE
            Add-CM7BoundaryToGroup -BoundaryGroupName "MyBoundaryGroup" -BoundaryId 16777230
            Assigns the boundary with BoundaryID 16777230 to the boundary group named "MyBoundaryGroup".

        .EXAMPLE
            $group    = Get-CM7BoundaryGroup -Name "MyBoundaryGroup"
            $boundary = Get-CM7Boundary     -Name "MyBoundary"
            Add-CM7BoundaryToGroup -BoundaryGroupInputObject $group -InputObject $boundary
            Assigns the boundary to the group using objects from Get-CM7BoundaryGroup and Get-CM7Boundary.

        .EXAMPLE
            Get-CM7Boundary -Name "MyBoundary" | Add-CM7BoundaryToGroup -BoundaryGroupName "MyBoundaryGroup"
            Pipes a boundary object to the function and assigns it to the named group.

        .EXAMPLE
            Add-CM7BoundaryToGroup -BoundaryGroupName "MyBoundaryGroup" -BoundaryName "MyBoundary" -WhatIf
            Shows what would happen without actually making the assignment.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
            The AddBoundary instance method accepts an array of uint32 BoundaryIDs and adds them
            to the boundary group.

            For more information on the SMS_BoundaryGroup class and the AddBoundary method, see:
            https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class

            Related functions:
            - Get-CM7Boundary
            - Get-CM7BoundaryGroup
            - New-CM7BoundaryGroup
            - New-CM7Boundary
    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact         = 'Medium',
        DefaultParameterSetName = 'ByGroupObject_ByBoundaryObject'
    )]
    param(
        # ---- Boundary Group: by ID ----
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryId',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryName',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryObject', Mandatory = $true)]
        [int]$BoundaryGroupId,

        # ---- Boundary Group: by Name ----
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryId',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryName',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryObject', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BoundaryGroupName,

        # ---- Boundary Group: by Object ----
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryId',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryName',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryObject', Mandatory = $true)]
        [Alias('BoundaryGroup')]
        [ValidateNotNull()]
        [PSObject]$BoundaryGroupInputObject,

        # ---- Boundary: by ID ----
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryId',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryId',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryId', Mandatory = $true)]
        [int]$BoundaryId,

        # ---- Boundary: by Name ----
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryName',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryName',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BoundaryName,

        # ---- Boundary: by Object ----
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryObject',     Mandatory = $true, ValueFromPipeline = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryObject',   Mandatory = $true, ValueFromPipeline = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryObject', Mandatory = $true, ValueFromPipeline = $true)]
        [Alias('Boundary', 'BoundaryInputObject')]
        [ValidateNotNull()]
        [PSObject]$InputObject,

        # ---- Wildcard handling ----
        [Parameter()]
        [switch]$DisableWildcardHandling,

        [Parameter()]
        [switch]$ForceWildcardHandling
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        # Validate mutually exclusive wildcard parameters
        if ($DisableWildcardHandling -and $ForceWildcardHandling) {
            throw "DisableWildcardHandling and ForceWildcardHandling cannot be used together."
        }

        # Validate connection
        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            # ------------------------------------------------------------------
            # 1. Resolve Boundary Group CIM instance
            # ------------------------------------------------------------------
            $groupInstance = $null

            switch -Regex ($PSCmdlet.ParameterSetName) {
                '^ByGroupId_' {
                    Write-Verbose "Resolving boundary group by GroupID: $BoundaryGroupId"
                    $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $BoundaryGroupId"
                    if (-not $groupInstance) {
                        throw "No boundary group found with GroupID $BoundaryGroupId."
                    }
                }
                '^ByGroupName_' {
                    Write-Verbose "Resolving boundary group by Name: $BoundaryGroupName"
                    $safeName = $BoundaryGroupName -replace "'", "''"
                    $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$safeName'"
                    if (-not $groupInstance) {
                        throw "No boundary group found with name '$BoundaryGroupName'."
                    }
                }
                '^ByGroupObject_' {
                    # Resolve GroupID from the object
                    $resolvedGroupId = $null
                    if ($BoundaryGroupInputObject.PSObject.Properties['GroupID']) {
                        $resolvedGroupId = $BoundaryGroupInputObject.GroupID
                    } elseif ($BoundaryGroupInputObject.PSObject.Properties['GroupId']) {
                        $resolvedGroupId = $BoundaryGroupInputObject.GroupId
                    } else {
                        throw "BoundaryGroupInputObject does not have a GroupID property. Please provide a valid boundary group object from Get-CM7BoundaryGroup."
                    }
                    Write-Verbose "Resolving boundary group from InputObject with GroupID: $resolvedGroupId"
                    $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $resolvedGroupId"
                    if (-not $groupInstance) {
                        throw "No boundary group found with GroupID $resolvedGroupId (from BoundaryGroupInputObject)."
                    }
                }
            }

            # ------------------------------------------------------------------
            # 2. Resolve Boundary ID
            # ------------------------------------------------------------------
            $resolvedBoundaryId = $null

            switch -Regex ($PSCmdlet.ParameterSetName) {
                '_ByBoundaryId$' {
                    Write-Verbose "Using BoundaryID directly: $BoundaryId"
                    # Verify the boundary exists
                    $boundaryCheck = Get-CimInstance @cimParams -Query "SELECT BoundaryID FROM SMS_Boundary WHERE BoundaryID = $BoundaryId"
                    if (-not $boundaryCheck) {
                        throw "No boundary found with BoundaryID $BoundaryId."
                    }
                    $resolvedBoundaryId = $BoundaryId
                }
                '_ByBoundaryName$' {
                    Write-Verbose "Resolving boundary by Name: $BoundaryName"
                    $safeName = $BoundaryName -replace "'", "''"
                    $boundaryResult = Get-CimInstance @cimParams -Query "SELECT BoundaryID, DisplayName FROM SMS_Boundary WHERE DisplayName = '$safeName'"
                    if (-not $boundaryResult) {
                        throw "No boundary found with name '$BoundaryName'."
                    }
                    if (@($boundaryResult).Count -gt 1) {
                        throw "Multiple boundaries found with name '$BoundaryName'. Please use BoundaryId or InputObject to be more specific."
                    }
                    $resolvedBoundaryId = $boundaryResult.BoundaryID
                }
                '_ByBoundaryObject$' {
                    # Resolve BoundaryID from the object
                    if ($InputObject.PSObject.Properties['BoundaryID']) {
                        $resolvedBoundaryId = $InputObject.BoundaryID
                    } elseif ($InputObject.PSObject.Properties['BoundaryId']) {
                        $resolvedBoundaryId = $InputObject.BoundaryId
                    } else {
                        throw "InputObject does not have a BoundaryID property. Please provide a valid boundary object from Get-CM7Boundary."
                    }
                    Write-Verbose "Using BoundaryID from InputObject: $resolvedBoundaryId"
                    # Verify the boundary exists
                    $boundaryCheck = Get-CimInstance @cimParams -Query "SELECT BoundaryID FROM SMS_Boundary WHERE BoundaryID = $resolvedBoundaryId"
                    if (-not $boundaryCheck) {
                        throw "No boundary found with BoundaryID $resolvedBoundaryId (from InputObject)."
                    }
                }
            }

            # ------------------------------------------------------------------
            # 3. Invoke AddBoundary method on the boundary group
            # ------------------------------------------------------------------
            $groupName = $groupInstance.Name
            $groupId   = $groupInstance.GroupID

            $shouldProcessTarget  = "Boundary '$resolvedBoundaryId' to boundary group '$groupName' (GroupID: $groupId)"
            $shouldProcessAction  = "Add boundary to group"

            if ($PSCmdlet.ShouldProcess($shouldProcessTarget, $shouldProcessAction)) {
                Write-Verbose "Calling AddBoundary on boundary group '$groupName' (GroupID: $groupId) for BoundaryID $resolvedBoundaryId"

                $methodResult = Invoke-CimMethod -InputObject $groupInstance -MethodName 'AddBoundary' -Arguments @{
                    BoundaryID = [uint32[]]@($resolvedBoundaryId)
                }

                if ($methodResult.ReturnValue -ne 0) {
                    throw "AddBoundary method returned non-zero exit code $($methodResult.ReturnValue) for boundary group '$groupName' (GroupID: $groupId)."
                }

                Write-Verbose "Successfully added BoundaryID $resolvedBoundaryId to boundary group '$groupName' (GroupID: $groupId)."
            }
        } catch {
            throw $_
        }
    }
}
function Add-CM7CollectionMembershipRule {
    <#
        .SYNOPSIS
            Adds a membership rule to a MECM collection using CIM.

        .DESCRIPTION
            Adds one or more membership rules to an existing device or user collection in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. This function
            invokes the AddMembershipRule method on the SMS_Collection class via CIM.

            This is the CIM-based equivalent of the Add-CMCollectionMembershipRule and related
            cmdlets (Add-CMDeviceCollectionDirectMembershipRule, Add-CMDeviceCollectionQueryMembershipRule,
            Add-CMDeviceCollectionIncludeMembershipRule, Add-CMDeviceCollectionExcludeMembershipRule)
            from the ConfigurationManager PowerShell module.

            Supported rule types:
            - Direct: Adds a specific resource (device/user) by ResourceId
            - Query: Adds a WQL query rule that dynamically determines membership
            - Include: Adds an include collection rule (members of another collection are included)
            - Exclude: Adds an exclude collection rule (members of another collection are excluded)

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the target collection (by name or ID)
            3. Creates the appropriate membership rule CIM instance
            4. Invokes the AddMembershipRule method on the SMS_Collection instance

        .PARAMETER CollectionName
            The name of the collection to add the membership rule to.
            Mutually exclusive with CollectionId.

        .PARAMETER CollectionId
            The CollectionID of the collection to add the membership rule to.
            Mutually exclusive with CollectionName.

        .PARAMETER RuleType
            The type of membership rule to add. Valid values are:
            - 'Direct'  - Add a specific resource directly
            - 'Query'   - Add a WQL query-based rule
            - 'Include' - Include members from another collection
            - 'Exclude' - Exclude members from another collection

        .PARAMETER ResourceId
            The ResourceID of the resource to add as a direct member.
            Required when RuleType is 'Direct'. Can be an array to add multiple resources.

        .PARAMETER RuleName
            The name for the membership rule. Required for Query, Include, and Exclude rules.
            For Direct rules, this is optional and defaults to the resource name.

        .PARAMETER QueryExpression
            The WQL query expression for the rule. Required when RuleType is 'Query'.
            Example: "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'TEST-%'"

        .PARAMETER IncludeCollectionId
            The CollectionID of the collection to include. Required when RuleType is 'Include'
            and IncludeCollectionName is not specified.

        .PARAMETER IncludeCollectionName
            The name of the collection to include. Required when RuleType is 'Include'
            and IncludeCollectionId is not specified.

        .PARAMETER ExcludeCollectionId
            The CollectionID of the collection to exclude. Required when RuleType is 'Exclude'
            and ExcludeCollectionName is not specified.

        .PARAMETER ExcludeCollectionName
            The name of the collection to exclude. Required when RuleType is 'Exclude'
            and ExcludeCollectionId is not specified.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Direct -ResourceId 16777220
            Adds a direct membership rule for resource 16777220 to "My Collection".

        .EXAMPLE
            Add-CM7CollectionMembershipRule -CollectionId "CM101C04" -RuleType Direct -ResourceId 16777220, 16777221
            Adds multiple direct membership rules to the collection by ID.

        .EXAMPLE
            Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Query -RuleName "Test Servers" -QueryExpression "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'TEST-%'"
            Adds a query membership rule to "My Collection".

        .EXAMPLE
            Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Include -IncludeCollectionId "SMS00001"
            Adds an include collection membership rule referencing "All Systems".

        .EXAMPLE
            Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Include -IncludeCollectionName "All Systems"
            Adds an include collection membership rule by collection name.

        .EXAMPLE
            Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Exclude -ExcludeCollectionId "CM101C00"
            Adds an exclude collection membership rule.

        .EXAMPLE
            Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Exclude -ExcludeCollectionName "Test-Collection-Direct"
            Adds an exclude collection membership rule by collection name.

        .EXAMPLE
            Add-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Query -RuleName "Test" -QueryExpression "select * from SMS_R_System" -WhatIf
            Shows what would happen without actually adding the rule.

        .NOTES
            This function uses the SMS_Collection.AddMembershipRule WMI method via CIM.
            Requires an active connection established via Connect-CM7.

            For retrieving collection rules, see:
            - Get-CM7CollectionDirectMembershipRule
            - Get-CM7CollectionQueryMembershipRule
            - Get-CM7CollectionIncludeMembershipRule
            - Get-CM7CollectionExcludeMembershipRule
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByCollectionName')]
    param(
        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Direct', 'Query', 'Include', 'Exclude')]
        [string]$RuleType,

        [Parameter()]
        [int[]]$ResourceId,

        [Parameter()]
        [string]$RuleName,

        [Parameter()]
        [string]$QueryExpression,

        [Parameter()]
        [string]$IncludeCollectionId,

        [Parameter()]
        [string]$IncludeCollectionName,

        [Parameter()]
        [string]$ExcludeCollectionId,

        [Parameter()]
        [string]$ExcludeCollectionName
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
    }

    process {
        try {
            # ---- Validate rule-type-specific parameters ----
            switch ($RuleType) {
                'Direct' {
                    if (-not $ResourceId -or $ResourceId.Count -eq 0) {
                        throw "ResourceId is required when RuleType is 'Direct'."
                    }
                }
                'Query' {
                    if (-not $RuleName) {
                        throw "RuleName is required when RuleType is 'Query'."
                    }
                    if (-not $QueryExpression) {
                        throw "QueryExpression is required when RuleType is 'Query'."
                    }
                }
                'Include' {
                    if (-not $IncludeCollectionId -and -not $IncludeCollectionName) {
                        throw "Either IncludeCollectionId or IncludeCollectionName is required when RuleType is 'Include'."
                    }
                }
                'Exclude' {
                    if (-not $ExcludeCollectionId -and -not $ExcludeCollectionName) {
                        throw "Either ExcludeCollectionId or ExcludeCollectionName is required when RuleType is 'Exclude'."
                    }
                }
            }

            # ---- Resolve target collection ----
            $resolvedCollectionId = $null
            $resolvedCollectionName = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByCollectionName' {
                    $query = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
                    Write-Verbose "Looking up collection by name: $query"
                    $collections = @(Get-CimInstance @cimParams -Query $query)

                    if (-not $collections -or $collections.Count -eq 0) {
                        throw "Collection with name '$CollectionName' was not found."
                    }

                    if ($collections.Count -gt 1) {
                        throw "Multiple collections found with name '$CollectionName'. Please use -CollectionId instead."
                    }

                    $resolvedCollectionId = $collections[0].CollectionID
                    $resolvedCollectionName = $collections[0].Name
                }
                'ByCollectionId' {
                    $query = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$CollectionId'"
                    Write-Verbose "Looking up collection by ID: $query"
                    $collection = Get-CimInstance @cimParams -Query $query

                    if (-not $collection) {
                        throw "Collection with ID '$CollectionId' was not found."
                    }

                    $resolvedCollectionId = $collection.CollectionID
                    $resolvedCollectionName = $collection.Name
                }
            }

            Write-Verbose "Resolved target collection: '$resolvedCollectionName' ($resolvedCollectionId)"

            # ---- Build the query for method invocation ----
            $collectionQuery = "SELECT * FROM SMS_Collection WHERE CollectionID = '$resolvedCollectionId'"

            # ---- Create and add membership rule(s) based on RuleType ----
            switch ($RuleType) {
                'Direct' {
                    foreach ($resId in $ResourceId) {
                        # Look up the resource to get its name for the rule
                        $resourceQuery = "SELECT ResourceID, Name FROM SMS_R_System WHERE ResourceID = $resId"
                        Write-Verbose "Looking up resource: $resourceQuery"
                        $resource = Get-CimInstance @cimParams -Query $resourceQuery

                        if (-not $resource) {
                            Write-Warning "Resource with ID $resId was not found. Skipping."
                            continue
                        }

                        $resourceName = $resource.Name
                        $directRuleName = if ($RuleName) { $RuleName } else { $resourceName }

                        $actionDescription = "Add direct membership rule for resource '$resourceName' ($resId) to collection '$resolvedCollectionName' ($resolvedCollectionId)"
                        if ($PSCmdlet.ShouldProcess($resolvedCollectionName, $actionDescription)) {
                            Write-Verbose $actionDescription

                            # Create the SMS_CollectionRuleDirect embedded instance
                            $ruleProperties = @{
                                RuleName    = $directRuleName
                                ResourceID  = [uint32]$resId
                                ResourceClassName = 'SMS_R_System'
                            }

                            $ruleInstance = New-CimInstance -ClassName 'SMS_CollectionRuleDirect' -Namespace $namespace -Property $ruleProperties -ClientOnly

                            # Invoke the AddMembershipRule method
                            $methodParams = @{
                                collectionRule = [CimInstance]$ruleInstance
                            }

                            $result = Invoke-CimMethod @cimParams -Query $collectionQuery -MethodName 'AddMembershipRule' -Arguments $methodParams

                            if ($result.ReturnValue -ne 0) {
                                Write-Warning "Failed to add direct membership rule for resource $resId. ReturnValue: $($result.ReturnValue)"
                            } else {
                                Write-Verbose "Successfully added direct membership rule for resource '$resourceName' ($resId)"

                                [PSCustomObject]@{
                                    PSTypeName    = 'MECM7.CollectionMembershipRuleResult'
                                    CollectionId  = $resolvedCollectionId
                                    CollectionName = $resolvedCollectionName
                                    RuleType      = 'Direct'
                                    RuleName      = $directRuleName
                                    ResourceId    = $resId
                                    ResourceName  = $resourceName
                                    Status        = 'Added'
                                }
                            }
                        }
                    }
                }

                'Query' {
                    $actionDescription = "Add query membership rule '$RuleName' to collection '$resolvedCollectionName' ($resolvedCollectionId)"
                    if ($PSCmdlet.ShouldProcess($resolvedCollectionName, $actionDescription)) {
                        Write-Verbose $actionDescription

                        # Create the SMS_CollectionRuleQuery embedded instance
                        $ruleProperties = @{
                            RuleName        = $RuleName
                            QueryExpression = $QueryExpression
                            QueryID         = [uint32]0
                        }

                        $ruleInstance = New-CimInstance -ClassName 'SMS_CollectionRuleQuery' -Namespace $namespace -Property $ruleProperties -ClientOnly

                        # Invoke the AddMembershipRule method
                        $methodParams = @{
                            collectionRule = [CimInstance]$ruleInstance
                        }

                        $result = Invoke-CimMethod @cimParams -Query $collectionQuery -MethodName 'AddMembershipRule' -Arguments $methodParams

                        if ($result.ReturnValue -ne 0) {
                            Write-Warning "Failed to add query membership rule '$RuleName'. ReturnValue: $($result.ReturnValue)"
                        } else {
                            Write-Verbose "Successfully added query membership rule '$RuleName'"

                            [PSCustomObject]@{
                                PSTypeName      = 'MECM7.CollectionMembershipRuleResult'
                                CollectionId    = $resolvedCollectionId
                                CollectionName  = $resolvedCollectionName
                                RuleType        = 'Query'
                                RuleName        = $RuleName
                                QueryExpression = $QueryExpression
                                Status          = 'Added'
                            }
                        }
                    }
                }

                'Include' {
                    # Resolve include collection
                    $resolvedIncludeId = $null
                    $resolvedIncludeName = $null

                    if ($IncludeCollectionId) {
                        $includeQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$IncludeCollectionId'"
                        Write-Verbose "Looking up include collection by ID: $includeQuery"
                        $includeCollection = Get-CimInstance @cimParams -Query $includeQuery

                        if (-not $includeCollection) {
                            throw "Include collection with ID '$IncludeCollectionId' was not found."
                        }

                        $resolvedIncludeId = $includeCollection.CollectionID
                        $resolvedIncludeName = $includeCollection.Name
                    } elseif ($IncludeCollectionName) {
                        $includeQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$IncludeCollectionName'"
                        Write-Verbose "Looking up include collection by name: $includeQuery"
                        $includeCollections = @(Get-CimInstance @cimParams -Query $includeQuery)

                        if (-not $includeCollections -or $includeCollections.Count -eq 0) {
                            throw "Include collection with name '$IncludeCollectionName' was not found."
                        }

                        if ($includeCollections.Count -gt 1) {
                            throw "Multiple collections found with name '$IncludeCollectionName'. Please use -IncludeCollectionId instead."
                        }

                        $resolvedIncludeId = $includeCollections[0].CollectionID
                        $resolvedIncludeName = $includeCollections[0].Name
                    }

                    $includeRuleName = if ($RuleName) { $RuleName } else { $resolvedIncludeName }

                    $actionDescription = "Add include membership rule for collection '$resolvedIncludeName' ($resolvedIncludeId) to collection '$resolvedCollectionName' ($resolvedCollectionId)"
                    if ($PSCmdlet.ShouldProcess($resolvedCollectionName, $actionDescription)) {
                        Write-Verbose $actionDescription

                        # Create the SMS_CollectionRuleIncludeCollection embedded instance
                        $ruleProperties = @{
                            RuleName            = $includeRuleName
                            IncludeCollectionID = $resolvedIncludeId
                        }

                        $ruleInstance = New-CimInstance -ClassName 'SMS_CollectionRuleIncludeCollection' -Namespace $namespace -Property $ruleProperties -ClientOnly

                        # Invoke the AddMembershipRule method
                        $methodParams = @{
                            collectionRule = [CimInstance]$ruleInstance
                        }

                        $result = Invoke-CimMethod @cimParams -Query $collectionQuery -MethodName 'AddMembershipRule' -Arguments $methodParams

                        if ($result.ReturnValue -ne 0) {
                            Write-Warning "Failed to add include membership rule for '$resolvedIncludeName'. ReturnValue: $($result.ReturnValue)"
                        } else {
                            Write-Verbose "Successfully added include membership rule for '$resolvedIncludeName' ($resolvedIncludeId)"

                            [PSCustomObject]@{
                                PSTypeName        = 'MECM7.CollectionMembershipRuleResult'
                                CollectionId      = $resolvedCollectionId
                                CollectionName    = $resolvedCollectionName
                                RuleType          = 'Include'
                                RuleName          = $includeRuleName
                                IncludeCollectionId   = $resolvedIncludeId
                                IncludeCollectionName = $resolvedIncludeName
                                Status            = 'Added'
                            }
                        }
                    }
                }

                'Exclude' {
                    # Resolve exclude collection
                    $resolvedExcludeId = $null
                    $resolvedExcludeName = $null

                    if ($ExcludeCollectionId) {
                        $excludeQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$ExcludeCollectionId'"
                        Write-Verbose "Looking up exclude collection by ID: $excludeQuery"
                        $excludeCollection = Get-CimInstance @cimParams -Query $excludeQuery

                        if (-not $excludeCollection) {
                            throw "Exclude collection with ID '$ExcludeCollectionId' was not found."
                        }

                        $resolvedExcludeId = $excludeCollection.CollectionID
                        $resolvedExcludeName = $excludeCollection.Name
                    } elseif ($ExcludeCollectionName) {
                        $excludeQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$ExcludeCollectionName'"
                        Write-Verbose "Looking up exclude collection by name: $excludeQuery"
                        $excludeCollections = @(Get-CimInstance @cimParams -Query $excludeQuery)

                        if (-not $excludeCollections -or $excludeCollections.Count -eq 0) {
                            throw "Exclude collection with name '$ExcludeCollectionName' was not found."
                        }

                        if ($excludeCollections.Count -gt 1) {
                            throw "Multiple collections found with name '$ExcludeCollectionName'. Please use -ExcludeCollectionId instead."
                        }

                        $resolvedExcludeId = $excludeCollections[0].CollectionID
                        $resolvedExcludeName = $excludeCollections[0].Name
                    }

                    $excludeRuleName = if ($RuleName) { $RuleName } else { $resolvedExcludeName }

                    $actionDescription = "Add exclude membership rule for collection '$resolvedExcludeName' ($resolvedExcludeId) to collection '$resolvedCollectionName' ($resolvedCollectionId)"
                    if ($PSCmdlet.ShouldProcess($resolvedCollectionName, $actionDescription)) {
                        Write-Verbose $actionDescription

                        # Create the SMS_CollectionRuleExcludeCollection embedded instance
                        $ruleProperties = @{
                            RuleName            = $excludeRuleName
                            ExcludeCollectionID = $resolvedExcludeId
                        }

                        $ruleInstance = New-CimInstance -ClassName 'SMS_CollectionRuleExcludeCollection' -Namespace $namespace -Property $ruleProperties -ClientOnly

                        # Invoke the AddMembershipRule method
                        $methodParams = @{
                            collectionRule = [CimInstance]$ruleInstance
                        }

                        $result = Invoke-CimMethod @cimParams -Query $collectionQuery -MethodName 'AddMembershipRule' -Arguments $methodParams

                        if ($result.ReturnValue -ne 0) {
                            Write-Warning "Failed to add exclude membership rule for '$resolvedExcludeName'. ReturnValue: $($result.ReturnValue)"
                        } else {
                            Write-Verbose "Successfully added exclude membership rule for '$resolvedExcludeName' ($resolvedExcludeId)"

                            [PSCustomObject]@{
                                PSTypeName        = 'MECM7.CollectionMembershipRuleResult'
                                CollectionId      = $resolvedCollectionId
                                CollectionName    = $resolvedCollectionName
                                RuleType          = 'Exclude'
                                RuleName          = $excludeRuleName
                                ExcludeCollectionId   = $resolvedExcludeId
                                ExcludeCollectionName = $resolvedExcludeName
                                Status            = 'Added'
                            }
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
function Add-CM7SoftwareUpdateToGroup {
    <#
        .SYNOPSIS
            Adds one or more software updates to a software update group in MECM using CIM.

        .DESCRIPTION
            Adds software updates to an existing software update group (SMS_AuthorizationList) in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. Software updates can be
            specified by CI_ID, Article ID, name, or by passing software update objects from
            Get-CM7SoftwareUpdate.

            This is the CIM-based equivalent of the Add-CMSoftwareUpdateToGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the target software update group by name, CI_ID, or input object
            3. Resolves the software updates to add by CI_ID, Article ID, name, or input object
            4. Merges the new update CI_IDs with the existing group's Updates array (skipping duplicates)
            5. Saves the updated group via CIM
            6. Returns the updated software update group as a formatted MECM7.SoftwareUpdateGroup object

        .PARAMETER SoftwareUpdateGroupName
            The name (LocalizedDisplayName) of the software update group to add updates to.
            Mutually exclusive with SoftwareUpdateGroupId and SoftwareUpdateGroup.

        .PARAMETER SoftwareUpdateGroupId
            The CI_ID (integer) of the software update group to add updates to.
            Mutually exclusive with SoftwareUpdateGroupName and SoftwareUpdateGroup.

        .PARAMETER SoftwareUpdateGroup
            A software update group object (as returned by Get-CM7SoftwareUpdateGroup) to add updates to.
            Accepts pipeline input.
            Mutually exclusive with SoftwareUpdateGroupName and SoftwareUpdateGroupId.

        .PARAMETER SoftwareUpdate
            One or more software update objects (as returned by Get-CM7SoftwareUpdate) to add to the group.
            The CI_ID property is extracted from each object.
            Mutually exclusive with UpdateId, ArticleId, and SoftwareUpdateName.

        .PARAMETER UpdateId
            An array of software update CI_IDs (integers) to add to the group.
            Mutually exclusive with SoftwareUpdate, ArticleId, and SoftwareUpdateName.

        .PARAMETER ArticleId
            An array of software update Article IDs (KB numbers, e.g. "4038779") to add to the group.
            The function resolves these to CI_IDs by querying SMS_SoftwareUpdate.
            Mutually exclusive with SoftwareUpdate, UpdateId, and SoftwareUpdateName.

        .PARAMETER SoftwareUpdateName
            The name (LocalizedDisplayName) of the software update(s) to add. Supports wildcard characters (* and ?).
            The function resolves the name to CI_IDs by querying SMS_SoftwareUpdate.
            Mutually exclusive with SoftwareUpdate, UpdateId, and ArticleId.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -UpdateId @(16788010) -Force
            Adds a software update by CI_ID to the specified software update group.

        .EXAMPLE
            Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -ArticleId @("4038779") -Force
            Adds software updates by Article ID (KB number) to the specified software update group.

        .EXAMPLE
            $updates = Get-CM7SoftwareUpdate -ArticleId "4038779"
            Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -SoftwareUpdate $updates -Force
            Retrieves software updates and adds them to a software update group using input objects.

        .EXAMPLE
            Get-CM7SoftwareUpdateGroup -Name "Test-SUG" | Add-CM7SoftwareUpdateToGroup -UpdateId @(16788010, 16788011) -Force
            Pipes a software update group object and adds updates to it.

        .EXAMPLE
            Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupId 17164572 -ArticleId @("4038779") -Force
            Adds software updates by Article ID to a group specified by its CI_ID.

        .EXAMPLE
            Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -SoftwareUpdateName "*Cumulative*" -Force
            Adds all software updates matching a name wildcard pattern to the specified group.

        .EXAMPLE
            Add-CM7SoftwareUpdateToGroup -SoftwareUpdateGroupName "Test-SUG" -UpdateId @(16788010) -WhatIf
            Shows what would happen without actually modifying the software update group.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_AuthorizationList WMI class is used to represent software update groups in MECM.
            The Updates property contains an array of CI_IDs referencing SMS_SoftwareUpdate instances.

            Updates that are already members of the group are silently skipped (no duplicates are added).

            This function is the CIM-based equivalent of the Add-CMSoftwareUpdateToGroup cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByGroupNameAndUpdateId')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndUpdateId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndArticleId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndSoftwareUpdate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndSoftwareUpdateName')]
        [ValidateNotNullOrEmpty()]
        [string]$SoftwareUpdateGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndUpdateId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndArticleId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndSoftwareUpdate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndSoftwareUpdateName')]
        [ValidateNotNullOrEmpty()]
        [int]$SoftwareUpdateGroupId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndUpdateId', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndArticleId', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndSoftwareUpdate', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndSoftwareUpdateName', ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$SoftwareUpdateGroup,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndSoftwareUpdate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndSoftwareUpdate')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndSoftwareUpdate')]
        [ValidateNotNullOrEmpty()]
        [PSObject[]]$SoftwareUpdate,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndUpdateId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndUpdateId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndUpdateId')]
        [ValidateNotNullOrEmpty()]
        [int[]]$UpdateId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndArticleId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndArticleId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndArticleId')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ArticleId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameAndSoftwareUpdateName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdAndSoftwareUpdateName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupObjectAndSoftwareUpdateName')]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$SoftwareUpdateName,

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
    }

    process {
        try {
            # ---- Resolve the software update group ----
            $group = $null

            if ($PSBoundParameters.ContainsKey('SoftwareUpdateGroupName')) {
                $groupQuery = "SELECT * FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$SoftwareUpdateGroupName'"
                Write-Verbose "Querying software update group: $groupQuery"
                $group = Get-CimInstance @cimParams -Query $groupQuery

                if (-not $group) {
                    throw "Software update group '$SoftwareUpdateGroupName' not found."
                }
                if (@($group).Count -gt 1) {
                    throw "Multiple software update groups found with name '$SoftwareUpdateGroupName'. Use -SoftwareUpdateGroupId instead."
                }
            }
            elseif ($PSBoundParameters.ContainsKey('SoftwareUpdateGroupId')) {
                $groupQuery = "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $SoftwareUpdateGroupId"
                Write-Verbose "Querying software update group: $groupQuery"
                $group = Get-CimInstance @cimParams -Query $groupQuery

                if (-not $group) {
                    throw "Software update group with CI_ID '$SoftwareUpdateGroupId' not found."
                }
            }
            elseif ($PSBoundParameters.ContainsKey('SoftwareUpdateGroup')) {
                # Validate the input object has a CI_ID
                if (-not $SoftwareUpdateGroup.CI_ID) {
                    throw "The SoftwareUpdateGroup object does not have a valid CI_ID property."
                }

                $groupQuery = "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $($SoftwareUpdateGroup.CI_ID)"
                Write-Verbose "Querying software update group by CI_ID: $groupQuery"
                $group = Get-CimInstance @cimParams -Query $groupQuery

                if (-not $group) {
                    throw "Software update group with CI_ID '$($SoftwareUpdateGroup.CI_ID)' not found."
                }
            }

            $groupName = $group.LocalizedDisplayName
            $groupId = $group.CI_ID
            Write-Verbose "Resolved software update group: '$groupName' (CI_ID: $groupId)"

            # Re-fetch the group instance to load lazy properties (Updates is a lazy property in SMS_AuthorizationList)
            Write-Verbose "Loading lazy properties for software update group CI_ID: $groupId"
            $group = $script:CMConnection.CimSession.GetInstance($namespace, $group)

            # Get the current Updates array (may be null for empty groups)
            $currentUpdates = @()
            if ($group.Updates) {
                $currentUpdates = @($group.Updates)
            }
            Write-Verbose "Current update count in group: $($currentUpdates.Count)"

            # ---- Resolve the software updates to add ----
            $newUpdateIds = @()

            if ($PSBoundParameters.ContainsKey('UpdateId')) {
                $newUpdateIds = $UpdateId
                Write-Verbose "Using provided UpdateId(s): $($newUpdateIds -join ', ')"
            }
            elseif ($PSBoundParameters.ContainsKey('SoftwareUpdate')) {
                foreach ($su in $SoftwareUpdate) {
                    if ($su.CI_ID) {
                        $newUpdateIds += [int]$su.CI_ID
                    } else {
                        Write-Warning "Software update object does not have a CI_ID property. Skipping."
                    }
                }
                Write-Verbose "Extracted CI_ID(s) from SoftwareUpdate objects: $($newUpdateIds -join ', ')"
            }
            elseif ($PSBoundParameters.ContainsKey('ArticleId')) {
                Write-Verbose "Resolving Article IDs to CI_IDs..."
                foreach ($article in $ArticleId) {
                    $updateQuery = "SELECT CI_ID, ArticleID, LocalizedDisplayName FROM SMS_SoftwareUpdate WHERE ArticleID = '$article'"
                    Write-Verbose "  Querying: $updateQuery"
                    $updates = @(Get-CimInstance @cimParams -Query $updateQuery)

                    if ($updates.Count -eq 0) {
                        Write-Warning "No software update found for Article ID '$article'. Skipping."
                    } else {
                        foreach ($update in $updates) {
                            $newUpdateIds += [int]$update.CI_ID
                            Write-Verbose "  Resolved Article '$article' -> CI_ID $($update.CI_ID) ($($update.LocalizedDisplayName))"
                        }
                    }
                }
            }
            elseif ($PSBoundParameters.ContainsKey('SoftwareUpdateName')) {
                $wqlName = $SoftwareUpdateName.Replace('*', '%').Replace('?', '_')
                if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                    $updateQuery = "SELECT CI_ID, ArticleID, LocalizedDisplayName FROM SMS_SoftwareUpdate WHERE LocalizedDisplayName LIKE '$wqlName'"
                } else {
                    $updateQuery = "SELECT CI_ID, ArticleID, LocalizedDisplayName FROM SMS_SoftwareUpdate WHERE LocalizedDisplayName = '$SoftwareUpdateName'"
                }
                Write-Verbose "Querying software updates by name: $updateQuery"
                $updates = @(Get-CimInstance @cimParams -Query $updateQuery)

                if ($updates.Count -eq 0) {
                    Write-Warning "No software updates found matching name '$SoftwareUpdateName'."
                } else {
                    foreach ($update in $updates) {
                        $newUpdateIds += [int]$update.CI_ID
                        Write-Verbose "  Resolved '$($update.LocalizedDisplayName)' -> CI_ID $($update.CI_ID)"
                    }
                }
            }

            if ($newUpdateIds.Count -eq 0) {
                Write-Warning "No software updates to add. Operation skipped."
                return
            }

            # ---- Merge updates (skip duplicates) ----
            $existingSet = [System.Collections.Generic.HashSet[int]]::new([int[]]$currentUpdates)
            $addedIds = @()
            $skippedIds = @()

            foreach ($id in $newUpdateIds) {
                if ($existingSet.Contains($id)) {
                    $skippedIds += $id
                } else {
                    $addedIds += $id
                    $null = $existingSet.Add($id)
                }
            }

            if ($skippedIds.Count -gt 0) {
                Write-Verbose "Skipping $($skippedIds.Count) update(s) already in group: $($skippedIds -join ', ')"
            }

            if ($addedIds.Count -eq 0) {
                Write-Verbose "All specified updates are already in the group. No changes needed."
                return
            }

            $mergedUpdates = [uint32[]]@($existingSet)
            $actionDescription = "Add $($addedIds.Count) software update(s) to group '$groupName' (CI_ID: $groupId)"
            Write-Verbose "$actionDescription"

            # ---- Apply the update ----
            if ($Force -or $PSCmdlet.ShouldProcess("SoftwareUpdateToGroup: LocalizedDisplayName=`"$groupName`"", "Add")) {
                Write-Verbose "Updating software update group '$groupName' with $($mergedUpdates.Count) total updates (was $($currentUpdates.Count))"

                # Directly set the Updates property via Set-CimInstance
                $group | Set-CimInstance -Property @{
                    Updates = $mergedUpdates
                }

                Write-Verbose "Successfully added $($addedIds.Count) update(s) to software update group '$groupName'"
                Write-Verbose "Added CI_IDs: $($addedIds -join ', ')"

                # ---- Retrieve the updated software update group object to return ----
                $resultQuery = "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $groupId"
                Write-Verbose "Retrieving updated software update group: $resultQuery"
                $result = Get-CimInstance @cimParams -Query $resultQuery

                if ($result) {
                    $output = [PSCustomObject]@{
                        PSTypeName                      = 'MECM7.SoftwareUpdateGroup'
                        CI_ID                           = [int]$result.CI_ID
                        CI_UniqueID                     = $result.CI_UniqueID
                        LocalizedDisplayName            = $result.LocalizedDisplayName
                        LocalizedDescription            = $result.LocalizedDescription
                        IsDeployed                      = [bool]$result.IsDeployed
                        IsExpired                       = [bool]$result.IsExpired
                        IsSuperseded                    = [bool]$result.IsSuperseded
                        NumberOfUpdates                 = [int]$result.NumberOfUpdates
                        DateCreated                     = $result.DateCreated
                        DateLastModified                = $result.DateLastModified
                        LocalizedCategoryInstanceNames  = $result.LocalizedCategoryInstanceNames
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.SoftwareUpdateGroup')

                    # Add all extra properties
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }

                    Write-Output $output
                } else {
                    Write-Warning "Updates were added but could not retrieve the updated software update group. CI_ID: $groupId"
                }
            }
        }
        catch {
            throw $_
        }
    }
}
function Connect-CM7 {
    <#
        .SYNOPSIS
            Connects to a MECM site using CIM over WinRM.

        .DESCRIPTION
            Creates a CIM session to the target site server, discovers the SMS Provider
            location via root\SMS, and stores connection details for later commands.

        .PARAMETER SiteServer
            The hostname or IP address of the MECM site server or SMS Provider.

        .PARAMETER Credential
            Optional. A PSCredential object for authentication.

        .PARAMETER UseSsl
            Use HTTPS for WinRM.

        .PARAMETER SkipCertificateCheck
            Skip certificate checks when using SSL.

        .EXAMPLE
            Connect-CM7 -SiteServer "mecm.contoso.local"

        .EXAMPLE
            $cred = Get-Credential
            Connect-CM7 -SiteServer "mecm.contoso.local" -Credential $cred -UseSsl -SkipCertificateCheck
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteServer,

        [Parameter()]
        [pscredential]$Credential,

        [Parameter()]
        [switch]$UseSsl,

        [Parameter()]
        [switch]$SkipCertificateCheck
    )

    try {
        # Call the private function with direct parameters to avoid splatting issues with switches
        $connectionInfo = Invoke-CM7Connection -SiteServer $SiteServer -Credential:$Credential -UseSsl:$UseSsl -SkipCertificateCheck:$SkipCertificateCheck

        $script:CMConnection.SiteServer = $SiteServer
        $script:CMConnection.CimSession = $connectionInfo.CimSession
        $script:CMConnection.SiteCode = $connectionInfo.SiteCode
        $script:CMConnection.ProviderMachineName = $connectionInfo.ProviderMachineName
        $script:CMConnection.SkipCertificateCheck = [bool]$SkipCertificateCheck
        $script:CMConnection.UseSsl = [bool]$UseSsl
        $script:CMConnection.Credential = if ($Credential) { $Credential } else { $null }

        Write-Verbose "Connected to $SiteServer (SiteCode: $($script:CMConnection.SiteCode), Provider: $($script:CMConnection.ProviderMachineName))"

        return [PSCustomObject]@{
            SiteServer = $script:CMConnection.SiteServer
            SiteCode = $script:CMConnection.SiteCode
            ProviderMachineName = $script:CMConnection.ProviderMachineName
            CimSessionId = $script:CMConnection.CimSession.Id
        }
    }
    catch {
        throw $_
    }
}

# Module-scoped variables
$script:CMConnection = @{
    SiteServer = $null
    CimSession = $null
    SiteCode = $null
    ProviderMachineName = $null
    Credential = $null
    SkipCertificateCheck = $false
    UseSsl = $false
}
function Get-CM7Application {
    <#
        .SYNOPSIS
            Retrieves application information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_Application WMI class to retrieve application information from MECM.
            Supports filtering by application name, CI_ID, or other properties.
            Requires an active connection established via Connect-CM7.

        .PARAMETER Name
            The name of the application to retrieve. Supports wildcard characters (*).

        .PARAMETER ID
            The ID of the application to retrieve.

        .PARAMETER IsEnabled
            Filter applications by their enabled state.

        .PARAMETER IsLatest
            Filter to only return the latest version of each application.

        .PARAMETER ShowHidden
            Include hidden applications in the results.

        .PARAMETER Fast
            Returns only lazy properties for faster queries.

        .EXAMPLE
            Get-CM7Application -Name "Microsoft PowerShell 7.4.3"
            Retrieves the application with the exact name "Microsoft PowerShell 7.4.3".

        .EXAMPLE
            Get-CM7Application -ID 17123456
            Retrieves the application with ID 17123456.

        .EXAMPLE
            Get-CM7Application -Name "PowerShell*"
            Retrieves all applications whose names start with "PowerShell".

        .EXAMPLE
            Get-CM7Application
            Retrieves all applications (use with caution on large environments).
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByID', Mandatory = $true)]
        [int]$ID,

        [Parameter()]
        [boolean]$IsEnabled = $true,

        [Parameter()]
        [switch]$IsLatest,

        [Parameter()]
        [switch]$ShowHidden,

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
        $filter = $null
        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                if ($Name) {
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filter = "LocalizedDisplayName LIKE '$wqlName'"
                    } else {
                        $filter = "LocalizedDisplayName = '$Name'"
                    }
                }
            }
            'ByID' {
                $filter = "CI_ID = $ID"
            }
        }
        # check if IsEnabled filter is set
        if ($IsEnabled -ne $null) {
            $enabledFilter = "IsEnabled = $([int]$IsEnabled)"
            $filter = if ($filter) { "$filter AND $enabledFilter" } else { $enabledFilter }
        }
        if (-not $ShowHidden) {
            $hiddenFilter = "IsHidden = 0"
            $filter = if ($filter) { "$filter AND $hiddenFilter" } else { $hiddenFilter }
        }
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
        $query = "SELECT * FROM SMS_Application"
        if ( [boolean]$filter) {
            $query += " WHERE $filter"
        }
        if ( ( -not [boolean]$Name ) -and ( -not [boolean]$ID ) -and ( -not [boolean]$Fast ) ) {
            Write-Warning "No filter specified for Get-CM7Application. This may return a large number of results and impact performance. Consider using filters or the -Fast switch."
        }
        Write-Verbose "Executing query: $query"
        $appsFast = Get-CimInstance @queryParams -Query $query
        if ($IsLatest) {
            $appsFast = $appsFast | Sort-Object -Property LocalizedDisplayName, Version -Descending | Group-Object LocalizedDisplayName | ForEach-Object { $_.Group | Select-Object -First 1 }
        }
        if ($appsFast) {
            if ($Fast) {
                return $appsFast
            }
            else {
                $apps = Get-CM7FullCimInstance -Instance $appsFast
                return $apps
            }
        } else {
            Write-Verbose "No applications found matching the criteria."
        }
    } catch {
        throw $_
    }
}
function Get-CM7Boundary {
    <#
        .SYNOPSIS
            Retrieves boundary information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_Boundary WMI class to retrieve boundary information from MECM.
            Supports filtering by Name, BoundaryID, BoundaryType, and Value.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMBoundary cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

        .PARAMETER Name
            The name of the boundary to retrieve. Supports wildcard characters (* and ?).

        .PARAMETER BoundaryId
            The BoundaryID of the boundary to retrieve.

        .PARAMETER BoundaryType
            The type of the boundary. Valid values are: 0 (IP Subnet), 1 (Active Directory Site), 2 (IPv6 Prefix), 3 (IP Address Range).

        .PARAMETER Value
            The value of the boundary (e.g., subnet, AD site name, IP range).

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like BoundaryID, Name, BoundaryType, and Value.

        .EXAMPLE
            Get-CM7Boundary -Name "TEST GINO"
            Retrieves the boundary named "TEST GINO".

        .EXAMPLE
            Get-CM7Boundary -BoundaryId 12345678
            Retrieves the boundary with the specified BoundaryID.

        .EXAMPLE
            Get-CM7Boundary
            Retrieves all boundaries.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByBoundaryId', Mandatory = $true)]
        [int]$BoundaryId,

        [Parameter()]
        [ValidateSet(0, 1, 2, 3)]
        [int]$BoundaryType,

        [Parameter()]
        [string]$Value,

        [Parameter()]
        [switch]$Fast
    )

    # Ensure connection
    if (-not $script:CMConnection) {
        throw "Not connected. Please run Connect-CM7 first."
    }

    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

    # Build query parameters
    $queryParams = @{
        CimSession = $script:CMConnection.CimSession
        Namespace  = $namespace
    }

    $filter = @()
    if ($PSBoundParameters.ContainsKey('Name')) {
        $filter += "DisplayName LIKE '$Name'"
    }
    if ($PSBoundParameters.ContainsKey('BoundaryId')) {
        $filter += "BoundaryID = $BoundaryId"
    }
    if ($PSBoundParameters.ContainsKey('BoundaryType')) {
        $filter += "BoundaryType = $BoundaryType"
    }
    if ($PSBoundParameters.ContainsKey('Value')) {
        $filter += "Value LIKE '$Value'"
    }
    $wql = if ($filter) { "WHERE " + ($filter -join ' AND ') } else { '' }

    $query = "SELECT * FROM SMS_Boundary $wql"
    $boundaries = Get-CimInstance @queryParams -Query $query

    if ($Fast) {
        $boundaries | Select-Object BoundaryID, DisplayName, BoundaryType, Value
    } else {
        $boundaries
    }
}
function Get-CM7BoundaryGroup {
    <#
        .SYNOPSIS
            Retrieves boundary group information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_BoundaryGroup WMI class to retrieve boundary group information from MECM.
            Supports filtering by Name and GroupID.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMBoundaryGroup cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

        .PARAMETER Name
            The name of the boundary group to retrieve. Supports wildcard characters (* and ?).
            When no parameters are specified, all boundary groups are returned.

        .PARAMETER Id
            The GroupID(s) of one or more boundary groups to retrieve. Accepts an array of strings.
            Alias: GroupId

        .PARAMETER DisableWildcardHandling
            Treats wildcard characters as literal character values.
            Cannot be combined with ForceWildcardHandling.

        .PARAMETER ForceWildcardHandling
            Forces wildcard character processing even in contexts where it is not normally supported.
            May lead to unexpected behavior (not recommended).
            Cannot be combined with DisableWildcardHandling.

        .EXAMPLE
            Get-CM7BoundaryGroup
            Retrieves all boundary groups.

        .EXAMPLE
            Get-CM7BoundaryGroup -Name "Test Gino"
            Retrieves the boundary group named "Test Gino".

        .EXAMPLE
            Get-CM7BoundaryGroup -Name "Test*"
            Retrieves all boundary groups whose name starts with "Test".

        .EXAMPLE
            Get-CM7BoundaryGroup -Id "16777428"
            Retrieves the boundary group with GroupID 16777428.

        .EXAMPLE
            Get-CM7BoundaryGroup -Id "16777428", "16777429"
            Retrieves multiple boundary groups by their GroupIDs.

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
            For more information on return object properties, see SMS_BoundaryGroup server WMI class:
            https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class
    #>
    [CmdletBinding(DefaultParameterSetName = 'SearchByName')]
    param(
        [Parameter(ParameterSetName = 'SearchByName', Position = 0)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'SearchByIdMandatory', Mandatory = $true)]
        [Alias('GroupId')]
        [string[]]$Id,

        [Parameter()]
        [switch]$DisableWildcardHandling,

        [Parameter()]
        [switch]$ForceWildcardHandling
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        # Validate mutually exclusive wildcard parameters
        if ($DisableWildcardHandling -and $ForceWildcardHandling) {
            throw "DisableWildcardHandling and ForceWildcardHandling cannot be used together."
        }

        # Validate connection
        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            $query = $null

            switch ($PSCmdlet.ParameterSetName) {
                'SearchByName' {
                    if ($PSBoundParameters.ContainsKey('Name')) {
                        if ($DisableWildcardHandling) {
                            # Treat wildcard characters as literals
                            $escapedName = $Name -replace "'", "''"
                            $query = "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$escapedName'"
                        } else {
                            # Convert PowerShell wildcard pattern to WQL LIKE pattern
                            $wqlPattern = $Name -replace "'", "''" -replace '\*', '%' -replace '\?', '_'
                            $query = "SELECT * FROM SMS_BoundaryGroup WHERE Name LIKE '$wqlPattern'"
                        }
                    } else {
                        $query = "SELECT * FROM SMS_BoundaryGroup"
                    }
                }
                'SearchByIdMandatory' {
                    if ($Id.Count -eq 1) {
                        $query = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $($Id[0])"
                    } else {
                        $idInClause = $Id -join ', '
                        $query = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID IN ($idInClause)"
                    }
                }
            }

            Write-Verbose "Executing WQL query: $query"
            $results = Get-CimInstance @cimParams -Query $query

            if ($results) {
                foreach ($result in $results) {
                    $output = [PSCustomObject]@{
                        PSTypeName      = 'MECM7.BoundaryGroup'
                        GroupID         = [int]$result.GroupID
                        Name            = $result.Name
                        Description     = $result.Description
                        DefaultSiteCode = $result.DefaultSiteCode
                        MemberCount     = $result.MemberCount
                        SiteSystemCount = $result.SiteSystemCount
                    }
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.BoundaryGroup')

                    # Append any additional CIM properties not already mapped
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }

                    Write-Output $output
                }
            }
        } catch {
            throw $_
        }
    }
}
function Get-CM7Collection {
    <#
        .SYNOPSIS
            Retrieves collection information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_Collection WMI class to retrieve collection information from MECM.
            Supports filtering by collection name, CollectionId, or collection type.
            Requires an active connection established via Connect-CM7.

        .PARAMETER Name
            The name of the collection to retrieve. Supports wildcard characters (*).

        .PARAMETER CollectionId
            The CollectionID of the collection to retrieve.

        .PARAMETER CollectionType
            Filter collections by type. Valid values are 'Device', 'User', or 'Both'.
            Device collections contain device objects. User collections contain user objects.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            CollectionID, Name, CollectionType, MemberCount, and CreatedDate.

        .EXAMPLE
            Get-CM7Collection -Name "All Systems"
            Retrieves the collection with the exact name "All Systems".

        .EXAMPLE
            Get-CM7Collection -Name "TEST-*"
            Retrieves all collections whose names start with "TEST-".

        .EXAMPLE
            Get-CM7Collection -CollectionId "SMS00001"
            Retrieves the collection with CollectionID "SMS00001".

        .EXAMPLE
            Get-CM7Collection -CollectionType Device -Fast
            Retrieves all device collections with limited properties.

        .EXAMPLE
            Get-CM7Collection
            Retrieves all collections (use with caution on large environments).
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [string]$CollectionId,

        [Parameter()]
        [ValidateSet('Device', 'User', 'Both')]
        [string]$CollectionType,

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
        $filters = @()

        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                if ($Name) {
                    # Convert PowerShell wildcard to WQL LIKE pattern
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filters += "Name LIKE '$wqlName'"
                    } else {
                        $filters += "Name = '$Name'"
                    }
                }
            }
            'ByCollectionId' {
                $filters += "CollectionID = '$CollectionId'"
            }
        }

        # Add collection type filter if specified
        if ($CollectionType) {
            $typeValue = switch ($CollectionType) {
                'Device' { 2 }
                'User' { 1 }
                'Both' { $null }
            }

            if ($typeValue) {
                $filters += "CollectionType = $typeValue"
            }
        }

        if ($filters.Count -gt 0) {
            $filter = $filters -join ' AND '
        }

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Build the query
        if ($Fast) {
            $properties = "CollectionID, Name, CollectionType, MemberCount, LastRefreshTime"
            $query = "SELECT $properties FROM SMS_Collection"
        } else {
            $query = "SELECT * FROM SMS_Collection"
        }

        if ($filter) {
            $query += " WHERE $filter"
        }

        Write-Verbose "Executing query: $query"

        # Execute the query
        $collections = Get-CimInstance @queryParams -Query $query

        # Output results
        if ($collections) {
            foreach ($collection in $collections) {
                # Map collection type number to friendly name
                $typeDisplay = switch ($collection.CollectionType) {
                    1 { 'User' }
                    2 { 'Device' }
                    default { 'Unknown' }
                }

                # Create a custom object with commonly used properties
                $output = [PSCustomObject]@{
                    PSTypeName      = 'MECM7.Collection'
                    CollectionId    = $collection.CollectionID
                    Name            = $collection.Name
                    CollectionType  = $typeDisplay
                    TypeValue       = $collection.CollectionType
                    MemberCount     = $collection.MemberCount
                    LastRefreshTime = $collection.LastRefreshTime
                    LastChangeTime  = $collection.LastChangeTime
                    Comments        = $collection.Comments
                    OwnedByThisSite = $collection.OwnedByThisSite
                    RefreshType     = $collection.RefreshType
                }

                # Set the type name as well
                $output.PSObject.TypeNames.Insert(0, 'MECM7.Collection')

                # Add all properties if not Fast mode
                if (-not $Fast) {
                    $collection.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }
                }

                Write-Output $output
            }
        } else {
            Write-Verbose "No collections found matching the criteria."
        }
    }
    catch {
        throw $_
    }
}
function Get-CM7CollectionDirectMembershipRule {
    <#
        .SYNOPSIS
            Retrieves direct membership information for a MECM collection using CIM.

        .DESCRIPTION
            Queries the SMS_FullCollectionMembership WMI class to retrieve direct membership information for a MECM collection.
            Direct members are resources that have been explicitly added to a collection (as opposed to being added via
            query rules, include collections, or exclude collections). Supports filtering by collection name, CollectionId,
            resource name, or resource ID. Requires an active connection established via Connect-CM7.

        .PARAMETER CollectionName
            Specifies the name of the collection to retrieve direct members for.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to retrieve direct members for.

        .PARAMETER ResourceName
            Specifies the name of the resource to retrieve direct membership information for. Supports wildcard characters (*).

        .PARAMETER ResourceId
            Specifies the ResourceID of the resource to retrieve direct membership information for.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            ResourceID, Name, ResourceType.

        .EXAMPLE
            Get-CM7CollectionDirectMembershipRule -CollectionName "All Systems"
            Retrieves all resources that are direct members of the "All Systems" collection.

        .EXAMPLE
            Get-CM7CollectionDirectMembershipRule -CollectionName "All Systems" -ResourceName "TEST-*"
            Retrieves all resources matching the pattern "TEST-*" that are direct members of "All Systems".

        .EXAMPLE
            Get-CM7CollectionDirectMembershipRule -CollectionId "SMS00001" -ResourceId 16777220
            Retrieves direct membership information for resource 16777220 in the collection SMS00001.

        .EXAMPLE
            Get-CM7CollectionDirectMembershipRule -CollectionName "All Systems" -Fast
            Retrieves direct members with limited properties for better performance.

        .NOTES
            This function queries WMI class SMS_FullCollectionMembership which contains direct membership relationships.
            For all members (including members from rules, includes, and excludes), see Get-CM7CollectionMember.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$ResourceName,

        [Parameter()]
        [int]$ResourceId = -1,

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
        # Determine which collection identifier to use based on which was provided
        $collectionIdToUse = $null

        if ($CollectionName) {
            # Query the collection to get its ID
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $queryParams = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }

            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'"
            Write-Verbose "Resolving collection name to ID: $collectionQuery"

            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "Collection '$CollectionName' not found."
                return
            }
            $collectionIdToUse = $collection.CollectionID
        } elseif ($CollectionId) {
            $collectionIdToUse = $CollectionId
        } else {
            throw "Either CollectionName or CollectionId must be provided."
        }

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Build the filter for the query
        $filters = @("CollectionID = '$collectionIdToUse'")

        # Add resource name filter if specified
        if ($ResourceName) {
            $wqlName = $ResourceName.Replace('*', '%').Replace('?', '_')
            if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                $filters += "Name LIKE '$wqlName'"
            } else {
                $filters += "Name = '$ResourceName'"
            }
        }

        # Add resource ID filter if specified
        if ($ResourceId -ne -1) {
            $filters += "ResourceID = $ResourceId"
        }

        $filter = $filters -join ' AND '

        # Build the query
        if ($Fast) {
            $properties = "ResourceID, Name, ResourceType"
            $query = "SELECT $properties FROM SMS_FullCollectionMembership WHERE $filter"
        } else {
            $query = "SELECT * FROM SMS_FullCollectionMembership WHERE $filter"
        }

        Write-Verbose "Executing query: $query"

        # Execute the query
        $members = Get-CimInstance @queryParams -Query $query

        # Output results
        if ($members) {
            foreach ($member in $members) {
                # Map resource type number to friendly name
                # SMS_FullCollectionMembership uses: 5 = System (Device), 4 = User
                $typeDisplay = switch ($member.ResourceType) {
                    5 { 'Device' }
                    4 { 'User' }
                    default { 'Unknown' }
                }

                # Create a custom object with commonly used properties
                $output = [PSCustomObject]@{
                    PSTypeName       = 'MECM7.CollectionDirectMember'
                    ResourceId       = [int]$member.ResourceID
                    Name             = $member.Name
                    ResourceType     = $typeDisplay
                    CollectionId     = $member.CollectionID
                }

                # Add optional properties when not in Fast mode
                if (-not $Fast) {
                    if ($member.PSObject.Properties.Name -contains 'DateAdded') {
                        $output | Add-Member -MemberType NoteProperty -Name 'DateAdded' -Value $member.DateAdded
                    }
                    if ($member.PSObject.Properties.Name -contains 'IsSpecific') {
                        $output | Add-Member -MemberType NoteProperty -Name 'IsSpecific' -Value $member.IsSpecific
                    }
                    if ($member.PSObject.Properties.Name -contains 'Ordinal') {
                        $output | Add-Member -MemberType NoteProperty -Name 'Ordinal' -Value $member.Ordinal
                    }
                }

                $output
            }
        }
    }
    catch {
        throw $_
    }
}
function Get-CM7CollectionExcludeMembershipRule {
    <#
        .SYNOPSIS
            Retrieves exclude membership rules for a MECM collection using CIM.

        .DESCRIPTION
            Queries the SMS_Collection WMI class to retrieve exclude collection membership rules
            for a MECM collection. Exclude rules reference another collection whose members are
            excluded from the parent collection's effective membership. Supports filtering by
            collection name, CollectionId, excluded collection name, or excluded collection ID.
            Requires an active connection established via Connect-CM7.

        .PARAMETER CollectionName
            Specifies the name of the collection to retrieve exclude membership rules for.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to retrieve exclude membership rules for.

        .PARAMETER ExcludeCollectionName
            Specifies the name of the excluded collection to filter rules by. Supports wildcard characters (*).

        .PARAMETER ExcludeCollectionId
            Specifies the CollectionID of the excluded collection to filter rules by.

        .EXAMPLE
            Get-CM7CollectionExcludeMembershipRule -CollectionName "All Systems"
            Retrieves all exclude membership rules for the "All Systems" collection.

        .EXAMPLE
            Get-CM7CollectionExcludeMembershipRule -CollectionName "All Systems" -ExcludeCollectionName "Test*"
            Retrieves exclude membership rules matching the pattern "Test*" from the "All Systems" collection.

        .EXAMPLE
            Get-CM7CollectionExcludeMembershipRule -CollectionId "SMS00001" -ExcludeCollectionId "SMS00002"
            Retrieves the exclude membership rule for the specified excluded collection ID.

        .NOTES
            This function queries the SMS_Collection class and inspects its CollectionRules property
            for rules of type SMS_CollectionRuleExcludeCollection.
            For direct members, see Get-CM7CollectionDirectMembershipRule.
            For include rules, see Get-CM7CollectionIncludeMembershipRule.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$ExcludeCollectionName,

        [Parameter()]
        [string]$ExcludeCollectionId
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Determine which collection identifier to use based on which was provided
        $collectionIdToUse = $null

        if ($CollectionName) {
            # Query the collection to get its ID
            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'"
            Write-Verbose "Resolving collection name to ID: $collectionQuery"

            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "Collection '$CollectionName' not found."
                return
            }
            $collectionIdToUse = $collection.CollectionID
        } elseif ($CollectionId) {
            $collectionIdToUse = $CollectionId
        } else {
            throw "Either CollectionName or CollectionId must be provided."
        }

        # Get the collection with its CollectionRules (lazy property - need full instance)
        Write-Verbose "Retrieving collection '$collectionIdToUse' with CollectionRules..."
        $collectionInstance = Get-CimInstance @queryParams -ClassName SMS_Collection -Filter "CollectionID = '$collectionIdToUse'"

        if (-not $collectionInstance) {
            Write-Verbose "Collection '$collectionIdToUse' not found."
            return
        }

        # Get the full instance to load lazy properties including CollectionRules
        $fullCollection = Get-CimInstance @queryParams -ClassName SMS_Collection -Filter "CollectionID = '$collectionIdToUse'" |
            Get-CimInstance

        if (-not $fullCollection) {
            Write-Verbose "Could not retrieve full collection instance for '$collectionIdToUse'."
            return
        }

        # Get the collection rules and filter for exclude rules
        $collectionRules = $fullCollection.CollectionRules

        if (-not $collectionRules) {
            Write-Verbose "No collection rules found for collection '$collectionIdToUse'."
            return
        }

        # Filter for exclude collection rules (SMS_CollectionRuleExcludeCollection)
        $excludeRules = $collectionRules | Where-Object {
            $_.CimClass.CimClassName -eq 'SMS_CollectionRuleExcludeCollection'
        }

        if (-not $excludeRules) {
            Write-Verbose "No exclude membership rules found for collection '$collectionIdToUse'."
            return
        }

        # Apply additional filters if specified
        if ($ExcludeCollectionName) {
            $pattern = $ExcludeCollectionName.Replace('*', '.*').Replace('?', '.')
            $excludeRules = $excludeRules | Where-Object {
                $_.RuleName -match "^$pattern$"
            }
        }

        if ($ExcludeCollectionId) {
            $excludeRules = $excludeRules | Where-Object {
                $_.ExcludeCollectionID -eq $ExcludeCollectionId
            }
        }

        # Output results
        if ($excludeRules) {
            foreach ($rule in $excludeRules) {
                [PSCustomObject]@{
                    PSTypeName          = 'MECM7.CollectionExcludeMembershipRule'
                    RuleName            = $rule.RuleName
                    ExcludeCollectionId = $rule.ExcludeCollectionID
                    CollectionId        = $collectionIdToUse
                }
            }
        }
    }
    catch {
        throw $_
    }
}
function Get-CM7CollectionIncludeMembershipRule {
    <#
        .SYNOPSIS
            Retrieves include membership rules for a MECM collection using CIM.

        .DESCRIPTION
            Queries the SMS_Collection WMI class to retrieve include collection membership rules
            for a MECM collection. Include rules reference another collection whose members are
            included in the parent collection's effective membership. Supports filtering by
            collection name, CollectionId, included collection name, or included collection ID.
            Requires an active connection established via Connect-CM7.

        .PARAMETER CollectionName
            Specifies the name of the collection to retrieve include membership rules for.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to retrieve include membership rules for.

        .PARAMETER IncludeCollectionName
            Specifies the name of the included collection to filter rules by. Supports wildcard characters (*).

        .PARAMETER IncludeCollectionId
            Specifies the CollectionID of the included collection to filter rules by.

        .EXAMPLE
            Get-CM7CollectionIncludeMembershipRule -CollectionName "All Systems"
            Retrieves all include membership rules for the "All Systems" collection.

        .EXAMPLE
            Get-CM7CollectionIncludeMembershipRule -CollectionName "All Systems" -IncludeCollectionName "Test*"
            Retrieves include membership rules matching the pattern "Test*" from the "All Systems" collection.

        .EXAMPLE
            Get-CM7CollectionIncludeMembershipRule -CollectionId "SMS00001" -IncludeCollectionId "SMS00002"
            Retrieves the include membership rule for the specified included collection ID.

        .NOTES
            This function queries the SMS_Collection class and inspects its CollectionRules property
            for rules of type SMS_CollectionRuleIncludeCollection.
            For direct members, see Get-CM7CollectionDirectMembershipRule.
            For exclude rules, see Get-CM7CollectionExcludeMembershipRule.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$IncludeCollectionName,

        [Parameter()]
        [string]$IncludeCollectionId
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Determine which collection identifier to use based on which was provided
        $collectionIdToUse = $null

        if ($CollectionName) {
            # Query the collection to get its ID
            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'"
            Write-Verbose "Resolving collection name to ID: $collectionQuery"

            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "Collection '$CollectionName' not found."
                return
            }
            $collectionIdToUse = $collection.CollectionID
        } elseif ($CollectionId) {
            $collectionIdToUse = $CollectionId
        } else {
            throw "Either CollectionName or CollectionId must be provided."
        }

        # Get the collection with its CollectionRules (lazy property - need full instance)
        Write-Verbose "Retrieving collection '$collectionIdToUse' with CollectionRules..."
        $collectionInstance = Get-CimInstance @queryParams -ClassName SMS_Collection -Filter "CollectionID = '$collectionIdToUse'"

        if (-not $collectionInstance) {
            Write-Verbose "Collection '$collectionIdToUse' not found."
            return
        }

        # Get the full instance to load lazy properties including CollectionRules
        $fullCollection = Get-CimInstance @queryParams -ClassName SMS_Collection -Filter "CollectionID = '$collectionIdToUse'" |
            Get-CimInstance

        if (-not $fullCollection) {
            Write-Verbose "Could not retrieve full collection instance for '$collectionIdToUse'."
            return
        }

        # Get the collection rules and filter for include rules
        $collectionRules = $fullCollection.CollectionRules

        if (-not $collectionRules) {
            Write-Verbose "No collection rules found for collection '$collectionIdToUse'."
            return
        }

        # Filter for include collection rules (SMS_CollectionRuleIncludeCollection)
        $includeRules = $collectionRules | Where-Object {
            $_.CimClass.CimClassName -eq 'SMS_CollectionRuleIncludeCollection'
        }

        if (-not $includeRules) {
            Write-Verbose "No include membership rules found for collection '$collectionIdToUse'."
            return
        }

        # Apply additional filters if specified
        if ($IncludeCollectionName) {
            $pattern = $IncludeCollectionName.Replace('*', '.*').Replace('?', '.')
            $includeRules = $includeRules | Where-Object {
                $_.RuleName -match "^$pattern$"
            }
        }

        if ($IncludeCollectionId) {
            $includeRules = $includeRules | Where-Object {
                $_.IncludeCollectionID -eq $IncludeCollectionId
            }
        }

        # Output results
        if ($includeRules) {
            foreach ($rule in $includeRules) {
                [PSCustomObject]@{
                    PSTypeName          = 'MECM7.CollectionIncludeMembershipRule'
                    RuleName            = $rule.RuleName
                    IncludeCollectionId = $rule.IncludeCollectionID
                    CollectionId        = $collectionIdToUse
                }
            }
        }
    }
    catch {
        throw $_
    }
}
function Get-CM7CollectionMember {
    <#
        .SYNOPSIS
            Retrieves members of a MECM collection using CIM.

        .DESCRIPTION
            Queries the SMS_FullCollectionMembership WMI class to retrieve all members of a MECM collection,
            regardless of how they were added (direct rules, query rules, include rules, or exclude rules).
            Supports filtering by collection name, CollectionId, resource name, or resource ID.
            Requires an active connection established via Connect-CM7.

        .PARAMETER CollectionName
            Specifies the name of the collection to retrieve members for.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to retrieve members for.

        .PARAMETER ResourceName
            Specifies the name of the resource to filter by. Supports wildcard characters (*).

        .PARAMETER ResourceId
            Specifies the ResourceID of the resource to filter by.

        .PARAMETER SmsId
            Specifies the SMSID (GUID) of the resource to filter by.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            ResourceID, Name, ResourceType, CollectionID.

        .EXAMPLE
            Get-CM7CollectionMember -CollectionName "All Systems"
            Retrieves all members of the "All Systems" collection.

        .EXAMPLE
            Get-CM7CollectionMember -CollectionName "All Systems" -ResourceName "TEST-*"
            Retrieves all members matching the pattern "TEST-*" from the "All Systems" collection.

        .EXAMPLE
            Get-CM7CollectionMember -CollectionId "SMS00001" -ResourceId 16777220
            Retrieves the member with the specified ResourceID from the collection.

        .EXAMPLE
            Get-CM7CollectionMember -CollectionName "All Systems" -Fast
            Retrieves all members with limited properties for better performance.

        .NOTES
            This function queries WMI class SMS_FullCollectionMembership which contains all collection
            membership relationships, regardless of the membership rule type.
            For direct members only, see Get-CM7CollectionDirectMembershipRule.
            For include rules, see Get-CM7CollectionIncludeMembershipRule.
            For exclude rules, see Get-CM7CollectionExcludeMembershipRule.
            For query rules, see Get-CM7CollectionQueryMembershipRule.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$ResourceName,

        [Parameter()]
        [int]$ResourceId = -1,

        [Parameter()]
        [string]$SmsId,

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
        # Determine which collection identifier to use based on which was provided
        $collectionIdToUse = $null

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        if ($CollectionName) {
            # Query the collection to get its ID
            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'"
            Write-Verbose "Resolving collection name to ID: $collectionQuery"

            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "Collection '$CollectionName' not found."
                return
            }
            $collectionIdToUse = $collection.CollectionID
        } elseif ($CollectionId) {
            $collectionIdToUse = $CollectionId
        } else {
            throw "Either CollectionName or CollectionId must be provided."
        }

        # Build the filter for the query
        $filters = @("CollectionID = '$collectionIdToUse'")

        # Add resource name filter if specified
        if ($ResourceName) {
            $wqlName = $ResourceName.Replace('*', '%').Replace('?', '_')
            if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                $filters += "Name LIKE '$wqlName'"
            } else {
                $filters += "Name = '$ResourceName'"
            }
        }

        # Add resource ID filter if specified
        if ($ResourceId -ne -1) {
            $filters += "ResourceID = $ResourceId"
        }

        # Add SMSID filter if specified
        if ($SmsId) {
            $filters += "SMSID = '$SmsId'"
        }

        $filter = $filters -join ' AND '

        # Build the query
        if ($Fast) {
            $properties = "ResourceID, Name, ResourceType, CollectionID, SiteCode, Domain"
            $query = "SELECT $properties FROM SMS_FullCollectionMembership WHERE $filter"
        } else {
            $query = "SELECT * FROM SMS_FullCollectionMembership WHERE $filter"
        }

        Write-Verbose "Executing query: $query"

        # Execute the query
        $members = Get-CimInstance @queryParams -Query $query

        # Output results
        if ($members) {
            foreach ($member in $members) {
                # Map resource type number to friendly name
                $typeDisplay = switch ($member.ResourceType) {
                    5 { 'Device' }
                    4 { 'User' }
                    default { 'Unknown' }
                }

                # Create a custom object with commonly used properties
                $output = [PSCustomObject]@{
                    PSTypeName       = 'MECM7.CollectionMember'
                    ResourceId       = [int]$member.ResourceID
                    Name             = $member.Name
                    ResourceType     = $typeDisplay
                    CollectionId     = $member.CollectionID
                    SiteCode         = $member.SiteCode
                    Domain           = $member.Domain
                }

                # Add optional properties when not in Fast mode
                if (-not $Fast) {
                    if ($member.PSObject.Properties.Name -contains 'SMSID') {
                        $output | Add-Member -MemberType NoteProperty -Name 'SmsId' -Value $member.SMSID
                    }
                    if ($member.PSObject.Properties.Name -contains 'IsClient') {
                        $output | Add-Member -MemberType NoteProperty -Name 'IsClient' -Value $member.IsClient
                    }
                    if ($member.PSObject.Properties.Name -contains 'IsActive') {
                        $output | Add-Member -MemberType NoteProperty -Name 'IsActive' -Value $member.IsActive
                    }
                    if ($member.PSObject.Properties.Name -contains 'IsObsolete') {
                        $output | Add-Member -MemberType NoteProperty -Name 'IsObsolete' -Value $member.IsObsolete
                    }
                    if ($member.PSObject.Properties.Name -contains 'IsAssigned') {
                        $output | Add-Member -MemberType NoteProperty -Name 'IsAssigned' -Value $member.IsAssigned
                    }
                    if ($member.PSObject.Properties.Name -contains 'IsDecommissioned') {
                        $output | Add-Member -MemberType NoteProperty -Name 'IsDecommissioned' -Value $member.IsDecommissioned
                    }
                    if ($member.PSObject.Properties.Name -contains 'IsDirect') {
                        $output | Add-Member -MemberType NoteProperty -Name 'IsDirect' -Value $member.IsDirect
                    }
                    if ($member.PSObject.Properties.Name -contains 'IsBlockedClient') {
                        $output | Add-Member -MemberType NoteProperty -Name 'IsBlockedClient' -Value $member.IsBlockedClient
                    }
                    if ($member.PSObject.Properties.Name -contains 'ClientType') {
                        $output | Add-Member -MemberType NoteProperty -Name 'ClientType' -Value $member.ClientType
                    }
                    if ($member.PSObject.Properties.Name -contains 'DeviceOwner') {
                        $output | Add-Member -MemberType NoteProperty -Name 'DeviceOwner' -Value $member.DeviceOwner
                    }
                    if ($member.PSObject.Properties.Name -contains 'ClientCertType') {
                        $output | Add-Member -MemberType NoteProperty -Name 'ClientCertType' -Value $member.ClientCertType
                    }
                }

                $output
            }
        } else {
            Write-Verbose "No members found for collection '$collectionIdToUse'."
        }
    }
    catch {
        throw $_
    }
}
function Get-CM7CollectionQueryMembershipRule {
    <#
        .SYNOPSIS
            Retrieves query membership rules for a MECM collection using CIM.

        .DESCRIPTION
            Queries the SMS_Collection WMI class to retrieve query-based membership rules
            for a MECM collection. Query rules use WQL expressions to dynamically determine
            collection membership based on resource attributes. Supports filtering by
            collection name, CollectionId, or query rule name.
            Requires an active connection established via Connect-CM7.

        .PARAMETER CollectionName
            Specifies the name of the collection to retrieve query membership rules for.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to retrieve query membership rules for.

        .PARAMETER RuleName
            Specifies the name of the query rule to filter by. Supports wildcard characters (*).

        .EXAMPLE
            Get-CM7CollectionQueryMembershipRule -CollectionName "All Systems"
            Retrieves all query membership rules for the "All Systems" collection.

        .EXAMPLE
            Get-CM7CollectionQueryMembershipRule -CollectionName "All Systems" -RuleName "Test*"
            Retrieves query membership rules matching the pattern "Test*" from the "All Systems" collection.

        .EXAMPLE
            Get-CM7CollectionQueryMembershipRule -CollectionId "SMS00001"
            Retrieves all query membership rules for the collection with ID "SMS00001".

        .NOTES
            This function queries the SMS_Collection class and inspects its CollectionRules property
            for rules of type SMS_CollectionRuleQuery.
            For direct members, see Get-CM7CollectionDirectMembershipRule.
            For include rules, see Get-CM7CollectionIncludeMembershipRule.
            For exclude rules, see Get-CM7CollectionExcludeMembershipRule.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$RuleName
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Determine which collection identifier to use based on which was provided
        $collectionIdToUse = $null

        if ($CollectionName) {
            # Query the collection to get its ID
            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'"
            Write-Verbose "Resolving collection name to ID: $collectionQuery"

            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "Collection '$CollectionName' not found."
                return
            }
            $collectionIdToUse = $collection.CollectionID
        } elseif ($CollectionId) {
            $collectionIdToUse = $CollectionId
        } else {
            throw "Either CollectionName or CollectionId must be provided."
        }

        # Get the collection with its CollectionRules (lazy property - need full instance)
        Write-Verbose "Retrieving collection '$collectionIdToUse' with CollectionRules..."
        $collectionInstance = Get-CimInstance @queryParams -ClassName SMS_Collection -Filter "CollectionID = '$collectionIdToUse'"

        if (-not $collectionInstance) {
            Write-Verbose "Collection '$collectionIdToUse' not found."
            return
        }

        # Get the full instance to load lazy properties including CollectionRules
        $fullCollection = Get-CimInstance @queryParams -ClassName SMS_Collection -Filter "CollectionID = '$collectionIdToUse'" |
            Get-CimInstance

        if (-not $fullCollection) {
            Write-Verbose "Could not retrieve full collection instance for '$collectionIdToUse'."
            return
        }

        # Get the collection rules and filter for query rules
        $collectionRules = $fullCollection.CollectionRules

        if (-not $collectionRules) {
            Write-Verbose "No collection rules found for collection '$collectionIdToUse'."
            return
        }

        # Filter for query collection rules (SMS_CollectionRuleQuery)
        $queryRules = $collectionRules | Where-Object {
            $_.CimClass.CimClassName -eq 'SMS_CollectionRuleQuery'
        }

        if (-not $queryRules) {
            Write-Verbose "No query membership rules found for collection '$collectionIdToUse'."
            return
        }

        # Apply additional filters if specified
        if ($RuleName) {
            $pattern = $RuleName.Replace('*', '.*').Replace('?', '.')
            $queryRules = $queryRules | Where-Object {
                $_.RuleName -match "^$pattern$"
            }
        }

        # Output results
        if ($queryRules) {
            foreach ($rule in $queryRules) {
                [PSCustomObject]@{
                    PSTypeName      = 'MECM7.CollectionQueryMembershipRule'
                    RuleName        = $rule.RuleName
                    QueryExpression = $rule.QueryExpression
                    QueryId         = $rule.QueryID
                    CollectionId    = $collectionIdToUse
                }
            }
        }
    }
    catch {
        throw $_
    }
}
function Get-CM7CollectionVariable {
    <#
        .SYNOPSIS
            Retrieves collection variables from a MECM collection using CIM.

        .DESCRIPTION
            Queries the SMS_CollectionSettings WMI class to retrieve collection variables
            for a specified MECM collection. Collection variables are name-value pairs that
            can be used during task sequence execution and other MECM operations.
            Supports filtering by collection name, CollectionId, or variable name.
            Requires an active connection established via Connect-CM7.

        .PARAMETER CollectionName
            Specifies the name of the collection to retrieve variables for.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to retrieve variables for.

        .PARAMETER VariableName
            Specifies the name of the variable to retrieve. Supports wildcard characters (*).
            If not specified, all variables for the collection are returned.

        .EXAMPLE
            Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct"
            Retrieves all collection variables for the "Test-Collection-Direct" collection.

        .EXAMPLE
            Get-CM7CollectionVariable -CollectionId "CM101C00"
            Retrieves all collection variables for the collection with ID "CM101C00".

        .EXAMPLE
            Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "Test-Normal"
            Retrieves the variable named "Test-Normal" from the "Test-Collection-Direct" collection.

        .EXAMPLE
            Get-CM7CollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "Test-*"
            Retrieves all variables whose names start with "Test-" from the specified collection.

        .NOTES
            This function is the CIM-based equivalent of the Get-CMCollectionVariable cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The CollectionVariables property of SMS_CollectionSettings is a lazy property,
            so the function retrieves the full instance to access it.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByCollectionName')]
    param(
        [Parameter(ParameterSetName = 'ByCollectionName', Position = 0)]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [string]$CollectionId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$VariableName
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Determine which collection identifier to use
        $collectionIdToUse = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByCollectionName') {
            if (-not $CollectionName) {
                throw "CollectionName must be provided when using the ByCollectionName parameter set."
            }
            # Resolve collection name to ID
            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'"
            Write-Verbose "Resolving collection name to ID: $collectionQuery"

            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "Collection '$CollectionName' not found."
                return
            }
            $collectionIdToUse = $collection.CollectionID
        } else {
            $collectionIdToUse = $CollectionId
        }

        Write-Verbose "Using CollectionID: $collectionIdToUse"

        # Query SMS_CollectionSettings for the collection
        $settingsQuery = "SELECT * FROM SMS_CollectionSettings WHERE CollectionID = '$collectionIdToUse'"
        Write-Verbose "Executing query: $settingsQuery"

        $settings = Get-CimInstance @queryParams -Query $settingsQuery

        if (-not $settings) {
            Write-Verbose "No collection settings found for CollectionID '$collectionIdToUse'. The collection may have no variables defined."
            return
        }

        # CollectionVariables is a lazy property - re-retrieve the instance using
        # Get-CimInstance -InputObject to force loading all lazy properties
        Write-Verbose "Retrieving full instance to load lazy property CollectionVariables..."
        $fullSettings = $settings | Get-CimInstance

        if (-not $fullSettings) {
            Write-Verbose "Could not retrieve full collection settings for CollectionID '$collectionIdToUse'."
            return
        }

        # Access the CollectionVariables property
        $variables = $fullSettings.CollectionVariables

        if (-not $variables -or $variables.Count -eq 0) {
            Write-Verbose "No collection variables found for CollectionID '$collectionIdToUse'."
            return
        }

        # Filter by variable name if specified
        if ($VariableName) {
            if ($VariableName -match '[*?]') {
                # Wildcard filter
                $variables = $variables | Where-Object { $_.Name -like $VariableName }
            } else {
                # Exact match
                $variables = $variables | Where-Object { $_.Name -eq $VariableName }
            }
        }

        if (-not $variables) {
            Write-Verbose "No variables matching the filter were found."
            return
        }

        # Output results
        foreach ($variable in $variables) {
            [PSCustomObject]@{
                PSTypeName = 'MECM7.CollectionVariable'
                Name       = $variable.Name
                Value      = $variable.Value
                IsMasked   = $variable.IsMasked
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
function Get-CM7Deployment {
    <#
        .SYNOPSIS
            Retrieves deployment information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_DeploymentSummary WMI class to retrieve deployment information from MECM.
            Supports filtering by deployment ID, collection name, software name, and feature type.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMDeployment cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead
            of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER DeploymentId
            The unique identifier of the deployment to retrieve.

        .PARAMETER CollectionName
            The name of the collection targeted by the deployment. Supports wildcard characters (* and ?).

        .PARAMETER SoftwareName
            The name of the software being deployed. Supports wildcard characters (* and ?).

        .PARAMETER FeatureType
            The feature type of the deployment. Valid values are:
            - Application (1)
            - Program (2)
            - SoftwareUpdateGroup (5)
            - ConfigurationBaseline (6)
            - TaskSequence (7)

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            DeploymentID, CollectionName, SoftwareName, FeatureType, and summary counts.

        .EXAMPLE
            Get-CM7Deployment
            Retrieves all deployments.

        .EXAMPLE
            Get-CM7Deployment -DeploymentId "{12345678-1234-1234-1234-123456789012}"
            Retrieves the deployment with the specified deployment ID.

        .EXAMPLE
            Get-CM7Deployment -CollectionName "Test-Collection-Direct"
            Retrieves all deployments targeting the specified collection.

        .EXAMPLE
            Get-CM7Deployment -CollectionName "Test-*"
            Retrieves all deployments targeting collections whose names start with "Test-".

        .EXAMPLE
            Get-CM7Deployment -SoftwareName "Microsoft*"
            Retrieves all deployments for software whose names start with "Microsoft".

        .EXAMPLE
            Get-CM7Deployment -FeatureType Application
            Retrieves all application deployments.

        .EXAMPLE
            Get-CM7Deployment -CollectionName "All Systems" -FeatureType SoftwareUpdateGroup -Fast
            Retrieves software update group deployments for "All Systems" with limited properties.

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByDeploymentId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeploymentId,

        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'BySoftwareName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$SoftwareName,

        [Parameter(ParameterSetName = 'ByFeatureType', Mandatory = $true)]
        [ValidateSet('Application', 'Program', 'SoftwareUpdateGroup', 'ConfigurationBaseline', 'TaskSequence')]
        [string]$FeatureType,

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

        # Feature type mapping
        $featureTypeMap = @{
            'Application'            = 1
            'Program'                = 2
            'SoftwareUpdateGroup'    = 5
            'ConfigurationBaseline'  = 6
            'TaskSequence'           = 7
        }

        # Reverse feature type mapping for display
        $featureTypeReverse = @{
            1 = 'Application'
            2 = 'Program'
            5 = 'SoftwareUpdateGroup'
            6 = 'ConfigurationBaseline'
            7 = 'TaskSequence'
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
                'ByDeploymentId' {
                    $filters += "DeploymentID = '$DeploymentId'"
                }
                'ByCollectionName' {
                    $wqlName = $CollectionName.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filters += "CollectionName LIKE '$wqlName'"
                    } else {
                        $filters += "CollectionName = '$CollectionName'"
                    }
                }
                'BySoftwareName' {
                    $wqlName = $SoftwareName.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filters += "SoftwareName LIKE '$wqlName'"
                    } else {
                        $filters += "SoftwareName = '$SoftwareName'"
                    }
                }
                'ByFeatureType' {
                    $featureTypeValue = $featureTypeMap[$FeatureType]
                    $filters += "FeatureType = $featureTypeValue"
                }
            }

            # Build the query
            if ($Fast) {
                $properties = "DeploymentID, CollectionID, CollectionName, SoftwareName, PackageID, FeatureType, NumberTargeted, NumberSuccess, NumberInProgress, NumberErrors, NumberOther, NumberUnknown"
                $query = "SELECT $properties FROM SMS_DeploymentSummary"
            } else {
                $query = "SELECT * FROM SMS_DeploymentSummary"
            }

            if ($filters.Count -gt 0) {
                $query += " WHERE " + ($filters -join " AND ")
            }

            Write-Verbose "Executing query: $query"

            # Execute the query
            $deployments = Get-CimInstance @cimParams -Query $query

            # Output results
            if ($deployments) {
                foreach ($deployment in $deployments) {
                    # Map feature type to friendly name
                    $featureTypeName = if ($featureTypeReverse.ContainsKey([int]$deployment.FeatureType)) {
                        $featureTypeReverse[[int]$deployment.FeatureType]
                    } else {
                        "Unknown ($($deployment.FeatureType))"
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName       = 'MECM7.Deployment'
                        DeploymentID     = $deployment.DeploymentID
                        CollectionID     = $deployment.CollectionID
                        CollectionName   = $deployment.CollectionName
                        SoftwareName     = $deployment.SoftwareName
                        PackageID        = $deployment.PackageID
                        FeatureType      = $featureTypeName
                        NumberTargeted   = [int]$deployment.NumberTargeted
                        NumberSuccess    = [int]$deployment.NumberSuccess
                        NumberInProgress = [int]$deployment.NumberInProgress
                        NumberErrors     = [int]$deployment.NumberErrors
                        NumberOther      = [int]$deployment.NumberOther
                        NumberUnknown    = [int]$deployment.NumberUnknown
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.Deployment')

                    # Add all properties if not Fast mode
                    if (-not $Fast) {
                        $deployment.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                    }

                    Write-Output $output
                }
            } else {
                Write-Verbose "No deployments found matching the criteria."
            }
        }
        catch {
            throw $_
        }
    }
}
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
function Get-CM7DeviceCollection {
    <#
        .SYNOPSIS
            Retrieves device collection information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_Collection WMI class to retrieve device collection information from MECM.
            This is a convenience wrapper around Get-CM7Collection that automatically filters for
            device collections (CollectionType = Device).

            Supports filtering by collection name (with wildcard support), CollectionId, and Fast mode.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMDeviceCollection cmdlet from the
            ConfigurationManager PowerShell module.

        .PARAMETER Name
            The name of the device collection to retrieve. Supports wildcard characters (* and ?).

        .PARAMETER CollectionId
            The CollectionID of the device collection to retrieve.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            CollectionID, Name, CollectionType, MemberCount, and LastRefreshTime.

        .EXAMPLE
            Get-CM7DeviceCollection -Name "All Systems"
            Retrieves the device collection with the exact name "All Systems".

        .EXAMPLE
            Get-CM7DeviceCollection -Name "TEST-*"
            Retrieves all device collections whose names start with "TEST-".

        .EXAMPLE
            Get-CM7DeviceCollection -CollectionId "SMS00001"
            Retrieves the device collection with CollectionID "SMS00001".

        .EXAMPLE
            Get-CM7DeviceCollection -Fast
            Retrieves all device collections with limited properties for faster performance.

        .EXAMPLE
            Get-CM7DeviceCollection
            Retrieves all device collections (use with caution on large environments).
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [string]$CollectionId,

        [Parameter()]
        [switch]$Fast
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    try {
        # Build parameters to pass to Get-CM7Collection
        $params = @{
            CollectionType = 'Device'
        }

        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                if ($Name) {
                    $params.Name = $Name
                }
            }
            'ByCollectionId' {
                $params.CollectionId = $CollectionId
            }
        }

        if ($Fast) {
            $params.Fast = $true
        }

        # Pass verbose preference through
        if ($PSBoundParameters.ContainsKey('Verbose')) {
            $params.Verbose = $PSBoundParameters['Verbose']
        }

        # Delegate to Get-CM7Collection with Device filter
        Get-CM7Collection @params
    }
    catch {
        throw $_
    }
}
function Get-CM7DeviceCollectionDirectMembershipRule {
    <#
        .SYNOPSIS
            Retrieves direct membership information for a MECM device collection using CIM.

        .DESCRIPTION
            Queries the SMS_FullCollectionMembership WMI class to retrieve direct membership information for a MECM device collection.
            Direct members are resources that have been explicitly added to a collection (as opposed to being added via
            query rules, include collections, or exclude collections). Supports filtering by collection name, CollectionId,
            resource name, or resource ID. Requires an active connection established via Connect-CM7.

        .PARAMETER CollectionName
            Specifies the name of the device collection to retrieve direct members for.

        .PARAMETER CollectionId
            Specifies the CollectionID of the device collection to retrieve direct members for.

        .PARAMETER ResourceName
            Specifies the name of the resource to retrieve direct membership information for. Supports wildcard characters (*).

        .PARAMETER ResourceId
            Specifies the ResourceID of the resource to retrieve direct membership information for.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            ResourceID, Name, ResourceType.

        .EXAMPLE
            Get-CMDeviceCollectionDirectMembershipRule -CollectionName "All Systems"
            Retrieves all resources that are direct members of the "All Systems" device collection.

        .EXAMPLE
            Get-CMDeviceCollectionDirectMembershipRule -CollectionName "All Systems" -ResourceName "TEST-*"
            Retrieves all resources matching the pattern "TEST-*" that are direct members of "All Systems".

        .EXAMPLE
            Get-CMDeviceCollectionDirectMembershipRule -CollectionId "SMS00001" -ResourceId 16777220
            Retrieves direct membership information for resource 16777220 in the device collection SMS00001.

        .EXAMPLE
            Get-CMDeviceCollectionDirectMembershipRule -CollectionName "All Systems" -Fast
            Retrieves direct members with limited properties for better performance.

        .NOTES
            This function queries WMI class SMS_FullCollectionMembership which contains direct membership relationships.
            For all members (including members from rules, includes, and excludes), see Get-CM7CollectionMember.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$ResourceName,

        [Parameter()]
        [int]$ResourceId = -1,

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
        # Determine which collection identifier to use based on which was provided
        $collectionIdToUse = $null

        if ($CollectionName) {
            # Query the collection to get its ID
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $queryParams = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }

            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName' AND CollectionType = 2" # Ensure it's a device collection
            Write-Verbose "Resolving collection name to ID: $collectionQuery"

            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "Device collection '$CollectionName' not found."
                return
            }
            $collectionIdToUse = $collection.CollectionID
        } elseif ($CollectionId) {
            # validate if the collection ID exists and is a device collection
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $queryParams = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }
            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE CollectionID = '$CollectionId' AND CollectionType = 2" # Ensure it's a device collection
            Write-Verbose "Validating collection ID: $collectionQuery"
            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "Device collection with ID '$CollectionId' not found."
                return
            }
            $collectionIdToUse = $CollectionId
        } else {
            throw "Either CollectionName or CollectionId must be provided."
        }

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Build the filter for the query
        $filters = @("CollectionID = '$collectionIdToUse'")

        # Add resource name filter if specified
        if ($ResourceName) {
            $wqlName = $ResourceName.Replace('*', '%').Replace('?', '_')
            if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                $filters += "Name LIKE '$wqlName'"
            } else {
                $filters += "Name = '$ResourceName'"
            }
        }

        # Add resource ID filter if specified
        if ($ResourceId -ne -1) {
            $filters += "ResourceID = $ResourceId"
        }

        $filter = $filters -join ' AND '

        # Build the query
        if ($Fast) {
            $properties = "ResourceID, Name, ResourceType"
            $query = "SELECT $properties FROM SMS_FullCollectionMembership WHERE $filter"
        } else {
            $query = "SELECT * FROM SMS_FullCollectionMembership WHERE $filter"
        }

        Write-Verbose "Executing query: $query"

        # Execute the query
        $members = Get-CimInstance @queryParams -Query $query

        # Output results
        if ($members) {
            foreach ($member in $members) {
                # Map resource type number to friendly name
                # SMS_FullCollectionMembership uses: 5 = System (Device), 4 = User
                $typeDisplay = switch ($member.ResourceType) {
                    5 { 'Device' }
                    4 { 'User' }
                    default { 'Unknown' }
                }

                # Create a custom object with commonly used properties
                $output = [PSCustomObject]@{
                    PSTypeName       = 'MECM7.CollectionDirectMember'
                    ResourceId       = [int]$member.ResourceID
                    Name             = $member.Name
                    ResourceType     = $typeDisplay
                    CollectionId     = $member.CollectionID
                }

                # Add optional properties when not in Fast mode
                if (-not $Fast) {
                    if ($member.PSObject.Properties.Name -contains 'DateAdded') {
                        $output | Add-Member -MemberType NoteProperty -Name 'DateAdded' -Value $member.DateAdded
                    }
                    if ($member.PSObject.Properties.Name -contains 'IsSpecific') {
                        $output | Add-Member -MemberType NoteProperty -Name 'IsSpecific' -Value $member.IsSpecific
                    }
                    if ($member.PSObject.Properties.Name -contains 'Ordinal') {
                        $output | Add-Member -MemberType NoteProperty -Name 'Ordinal' -Value $member.Ordinal
                    }
                }

                $output
            }
        }
    }
    catch {
        throw $_
    }
}
function Get-CM7DeviceVariable {
    <#
        .SYNOPSIS
            Retrieves device variables from a MECM device using CIM.

        .DESCRIPTION
            Queries the SMS_MachineSettings WMI class to retrieve device-specific variables
            for a specified MECM device. Device variables are name-value pairs that
            can be used during task sequence execution and other MECM operations.
            Supports filtering by device name, ResourceId, or variable name.
            Requires an active connection established via Connect-CM7.

            This is the CIM-based equivalent of the Get-CMDeviceVariable cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER DeviceName
            Specifies the name of the device to retrieve variables for.

        .PARAMETER ResourceId
            Specifies the ResourceID of the device to retrieve variables for.

        .PARAMETER VariableName
            Specifies the name of the variable to retrieve. Supports wildcard characters (*).
            If not specified, all variables for the device are returned.

        .EXAMPLE
            Get-CM7DeviceVariable -DeviceName "Test-2016-1"
            Retrieves all device variables for the device "Test-2016-1".

        .EXAMPLE
            Get-CM7DeviceVariable -ResourceId 16893210
            Retrieves all device variables for the device with ResourceID 16893210.

        .EXAMPLE
            Get-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "TestVar"
            Retrieves the variable named "TestVar" from the device "Test-2016-1".

        .EXAMPLE
            Get-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "Test*"
            Retrieves all variables whose names start with "Test" from the specified device.

        .NOTES
            This function is the CIM-based equivalent of the Get-CMDeviceVariable cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The MachineVariables property of SMS_MachineSettings is a lazy property,
            so the function retrieves the full instance to access it.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByDeviceName')]
    param(
        [Parameter(ParameterSetName = 'ByDeviceName', Position = 0)]
        [string]$DeviceName,

        [Parameter(ParameterSetName = 'ByResourceId', Mandatory = $true)]
        [int]$ResourceId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$VariableName
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Determine which device identifier to use
        $resourceIdToUse = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByDeviceName') {
            if (-not $DeviceName) {
                throw "DeviceName must be provided when using the ByDeviceName parameter set."
            }
            # Resolve device name to ResourceID
            $deviceQuery = "SELECT ResourceID FROM SMS_R_System WHERE Name = '$DeviceName'"
            Write-Verbose "Resolving device name to ResourceID: $deviceQuery"

            $device = Get-CimInstance @queryParams -Query $deviceQuery
            if (-not $device) {
                Write-Verbose "Device '$DeviceName' not found."
                return
            }
            if (@($device).Count -gt 1) {
                Write-Warning "Multiple devices found with name '$DeviceName'. Using the first match (ResourceID: $($device[0].ResourceID))."
                $resourceIdToUse = $device[0].ResourceID
            } else {
                $resourceIdToUse = $device.ResourceID
            }
        } else {
            $resourceIdToUse = $ResourceId
        }

        Write-Verbose "Using ResourceID: $resourceIdToUse"

        # Query SMS_MachineSettings for the device
        $settingsQuery = "SELECT * FROM SMS_MachineSettings WHERE ResourceID = $resourceIdToUse"
        Write-Verbose "Executing query: $settingsQuery"

        $settings = Get-CimInstance @queryParams -Query $settingsQuery

        if (-not $settings) {
            Write-Verbose "No machine settings found for ResourceID '$resourceIdToUse'. The device may have no variables defined."
            return
        }

        # MachineVariables is a lazy property - re-retrieve the instance using
        # Get-CimInstance -InputObject to force loading all lazy properties
        Write-Verbose "Retrieving full instance to load lazy property MachineVariables..."
        $fullSettings = $settings | Get-CimInstance

        if (-not $fullSettings) {
            Write-Verbose "Could not retrieve full machine settings for ResourceID '$resourceIdToUse'."
            return
        }

        # Access the MachineVariables property
        $variables = $fullSettings.MachineVariables

        if (-not $variables -or $variables.Count -eq 0) {
            Write-Verbose "No device variables found for ResourceID '$resourceIdToUse'."
            return
        }

        # Filter by variable name if specified
        if ($VariableName) {
            if ($VariableName -match '[*?]') {
                # Wildcard filter
                $variables = $variables | Where-Object { $_.Name -like $VariableName }
            } else {
                # Exact match
                $variables = $variables | Where-Object { $_.Name -eq $VariableName }
            }
        }

        if (-not $variables) {
            Write-Verbose "No variables matching the filter were found."
            return
        }

        # Output results
        foreach ($variable in $variables) {
            [PSCustomObject]@{
                PSTypeName = 'MECM7.DeviceVariable'
                Name       = $variable.Name
                Value      = $variable.Value
                IsMasked   = $variable.IsMasked
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
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
function Get-CM7MaintenanceWindow {
    <#
        .SYNOPSIS
            Retrieves maintenance windows from a MECM collection using CIM.

        .DESCRIPTION
            Queries the SMS_ServiceWindow WMI class via the SMS_CollectionSettings class
            to retrieve maintenance windows for a specified MECM collection.
            Maintenance windows define scheduled time periods during which deployments
            and other operations can be applied to collection members.
            Supports filtering by collection name, CollectionID, or maintenance window name.
            Requires an active connection established via Connect-CM7.

        .PARAMETER CollectionName
            Specifies the name of the collection to retrieve maintenance windows for.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to retrieve maintenance windows for.

        .PARAMETER MaintenanceWindowName
            Specifies the name of the maintenance window to retrieve. Supports wildcard characters (*).
            If not specified, all maintenance windows for the collection are returned.

        .EXAMPLE
            Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct"
            Retrieves all maintenance windows for the "Test-Collection-Direct" collection.

        .EXAMPLE
            Get-CM7MaintenanceWindow -CollectionId "CM101C00"
            Retrieves all maintenance windows for the collection with ID "CM101C00".

        .EXAMPLE
            Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Daily MW"
            Retrieves the maintenance window named "Daily MW" from the "Test-Collection-Direct" collection.

        .EXAMPLE
            Get-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Test-*"
            Retrieves all maintenance windows whose names start with "Test-" from the specified collection.

        .NOTES
            This function is the CIM-based equivalent of the Get-CMMaintenanceWindow cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The ServiceWindows property of SMS_CollectionSettings is a lazy property,
            so the function retrieves the full instance to access it.

            Maintenance Window Types (ServiceWindowType):
                1 = All Deployments
                4 = Software Updates
                5 = Task Sequences
                6 = All Deployments (alias)

            Recurrence Types:
                1 = None (one-time)
                2 = Daily
                3 = Weekly
                4 = Monthly by weekday
                5 = Monthly by date
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByCollectionName')]
    param(
        [Parameter(ParameterSetName = 'ByCollectionName', Position = 0)]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [string]$CollectionId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$MaintenanceWindowName
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Determine which collection identifier to use
        $collectionIdToUse = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByCollectionName') {
            if (-not $CollectionName) {
                throw "CollectionName must be provided when using the ByCollectionName parameter set."
            }
            # Resolve collection name to ID
            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'"
            Write-Verbose "Resolving collection name to ID: $collectionQuery"

            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "Collection '$CollectionName' not found."
                return
            }
            $collectionIdToUse = $collection.CollectionID
        } else {
            $collectionIdToUse = $CollectionId
        }

        Write-Verbose "Using CollectionID: $collectionIdToUse"

        # Query SMS_CollectionSettings for the collection
        $settingsQuery = "SELECT * FROM SMS_CollectionSettings WHERE CollectionID = '$collectionIdToUse'"
        Write-Verbose "Executing query: $settingsQuery"

        $settings = Get-CimInstance @queryParams -Query $settingsQuery

        if (-not $settings) {
            Write-Verbose "No collection settings found for CollectionID '$collectionIdToUse'. The collection may have no maintenance windows defined."
            return
        }

        # ServiceWindows is a lazy property - re-retrieve the instance using
        # Get-CimInstance -InputObject to force loading all lazy properties
        Write-Verbose "Retrieving full instance to load lazy property ServiceWindows..."
        $fullSettings = $settings | Get-CimInstance

        if (-not $fullSettings) {
            Write-Verbose "Could not retrieve full collection settings for CollectionID '$collectionIdToUse'."
            return
        }

        # Access the ServiceWindows property
        $serviceWindows = $fullSettings.ServiceWindows

        if (-not $serviceWindows -or $serviceWindows.Count -eq 0) {
            Write-Verbose "No maintenance windows found for CollectionID '$collectionIdToUse'."
            return
        }

        # Filter by maintenance window name if specified
        if ($MaintenanceWindowName) {
            if ($MaintenanceWindowName -match '[*?]') {
                # Wildcard filter
                $serviceWindows = $serviceWindows | Where-Object { $_.Name -like $MaintenanceWindowName }
            } else {
                # Exact match
                $serviceWindows = $serviceWindows | Where-Object { $_.Name -eq $MaintenanceWindowName }
            }
        }

        if (-not $serviceWindows) {
            Write-Verbose "No maintenance windows matching the filter were found."
            return
        }

        # Map ServiceWindowType to friendly names
        $serviceWindowTypeMap = @{
            1 = 'General'
            4 = 'SoftwareUpdatesOnly'
            5 = 'TaskSequencesOnly'
            6 = 'General'
        }

        # Map RecurrenceType to friendly names
        $recurrenceTypeMap = @{
            1 = 'None'
            2 = 'Daily'
            3 = 'Weekly'
            4 = 'MonthlyByWeekday'
            5 = 'MonthlyByDate'
        }

        # Output results
        foreach ($window in $serviceWindows) {
            $windowType = if ($serviceWindowTypeMap.ContainsKey([int]$window.ServiceWindowType)) {
                $serviceWindowTypeMap[[int]$window.ServiceWindowType]
            } else {
                "Unknown ($($window.ServiceWindowType))"
            }

            $recurrence = if ($recurrenceTypeMap.ContainsKey([int]$window.RecurrenceType)) {
                $recurrenceTypeMap[[int]$window.RecurrenceType]
            } else {
                "Unknown ($($window.RecurrenceType))"
            }

            # Parse duration from the schedule string
            $duration = $window.Duration
            $durationMinutes = $null
            if ($duration) {
                # Duration is stored in minutes
                $durationMinutes = $duration
            }

            [PSCustomObject]@{
                PSTypeName          = 'MECM7.MaintenanceWindow'
                Name                = $window.Name
                Description         = $window.Description
                ServiceWindowID     = $window.ServiceWindowID
                IsEnabled           = $window.IsEnabled
                ServiceWindowType   = $windowType
                StartTime           = $window.StartTime
                Duration            = $durationMinutes
                RecurrenceType      = $recurrence
                IsGMT               = $window.IsGMT
                ServiceWindowSchedules = $window.ServiceWindowSchedules
                CollectionID        = $collectionIdToUse
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
function Get-CM7ScriptExecutionStatus {
    <#
        .SYNOPSIS
            Retrieves the execution status of MECM scripts using CIM.

        .DESCRIPTION
            Returns the current execution status and results of MECM scripts that have been
            invoked via Invoke-CM7Script or through the MECM console. This function is the
            CIM-based equivalent of querying SMS_ScriptsExecutionTask and SMS_ScriptsExecutionStatus
            WMI classes.

            The function supports multiple query modes:

            - **By ClientOperationId**: Retrieve detailed status and results for a specific script execution
            - **By ScriptName**: Filter executions by the script name
            - **By CollectionName**: Filter executions by the target collection name
            - **By CollectionId**: Filter executions by the target collection ID
            - **Combined filters**: Combine ScriptName with CollectionName or CollectionId
            - **No filter (list mode)**: When no parameters are specified, returns a summary list of all
              script executions with Operation ID, Script Name, Script GUID, Collection info, and Last Update Time
              but without detailed per-device results

            When a ClientOperationId is provided and completed clients exist, the function retrieves
            per-device results including script output, exit codes, and parsed output objects.

        .PARAMETER ClientOperationId
            The client operation ID returned by Invoke-CM7Script. When specified, retrieves detailed
            execution status and per-device results for that specific operation.

            This parameter is not mandatory. If omitted, a summary list of all script executions
            is returned without per-device results.

        .PARAMETER ScriptName
            Filter script executions by the script name. Can be combined with CollectionName or
            CollectionId for more specific filtering.

        .PARAMETER CollectionName
            Filter script executions by the target collection name. Can be combined with ScriptName
            for more specific filtering.

        .PARAMETER CollectionId
            Filter script executions by the target collection ID. Can be combined with ScriptName
            for more specific filtering.

        .EXAMPLE
            Get-CM7ScriptExecutionStatus

            Returns a summary list of all script executions without detailed results.

        .EXAMPLE
            Get-CM7ScriptExecutionStatus -ClientOperationId 16819576

            Retrieves detailed execution status and per-device results for operation ID 16819576.

        .EXAMPLE
            Get-CM7ScriptExecutionStatus -ScriptName "get pending reboot"

            Returns execution status for all runs of the script "get pending reboot".

        .EXAMPLE
            Get-CM7ScriptExecutionStatus -CollectionName "Test-Collection-Direct"

            Returns execution status for all scripts run against the collection "Test-Collection-Direct".

        .EXAMPLE
            Get-CM7ScriptExecutionStatus -CollectionId "CM101129" -ScriptName "get pending reboot"

            Returns execution status for the script "get pending reboot" run against collection "CM101129".

        .OUTPUTS
            PSCustomObject (MECM7.ScriptExecutionStatus) with properties:
            - OperationID: The client operation ID
            - ScriptName: The name of the executed script
            - ScriptVersion: The version of the script
            - ScriptGuid: The GUID of the script
            - CollectionID: The target collection ID
            - CollectionName: The target collection name
            - Results: Array of per-device results (only when ClientOperationId is specified and clients have completed)
            - Status: Current execution status text
            - TotalClients: Total number of targeted clients
            - CompletedClients: Number of clients that completed execution
            - FailedClients: Number of clients that failed
            - OfflineClients: Number of offline clients
            - NotApplicableClients: Number of not-applicable clients
            - UnknownClients: Number of clients with unknown status
            - LastUpdateTime: Last time the status was updated

            When no ClientOperationId is specified (list mode), returns summary objects
            (MECM7.ScriptExecutionSummary) with:
            - OperationID, ScriptName, ScriptGuid, CollectionID, CollectionName, LastUpdateTime,
              TotalClients, CompletedClients, FailedClients, OfflineClients

        .NOTES
            Requires an active MECM connection established via Connect-CM7.
            Use Invoke-CM7Script to execute scripts and obtain the ClientOperationId for tracking.

        .LINK
            Connect-CM7
            Invoke-CM7Script
    #>
    [CmdletBinding(DefaultParameterSetName = 'noFilter')]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = 'ByClientOperationId')]
        [ValidateNotNullOrEmpty()]
        [int]$ClientOperationId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByCollectionName_ScriptName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByCollectionId_ScriptName')]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionName_ScriptName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionId_ScriptName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # ── Build WMI query based on parameter set ──────────────────────
        if ($PSCmdlet.ParameterSetName -eq 'ByClientOperationId') {
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask WHERE ClientOperationId = $ClientOperationId"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByCollectionName_ScriptName') {
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask WHERE CollectionName = '$CollectionName' AND ScriptName = '$ScriptName'"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByCollectionName') {
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask WHERE CollectionName = '$CollectionName'"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByCollectionId_ScriptName') {
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask WHERE CollectionId = '$CollectionId' AND ScriptName = '$ScriptName'"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByCollectionId') {
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask WHERE CollectionId = '$CollectionId'"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByScriptName') {
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask WHERE ScriptName = '$ScriptName'"
        }
        else {
            # noFilter - list all
            $WMIQuery = "SELECT * FROM SMS_ScriptsExecutionTask"
        }

        Write-Verbose "Querying: $WMIQuery"
        $TaskStatus = Get-CimInstance @cimParams -Query $WMIQuery

        if ([string]::IsNullOrEmpty($TaskStatus)) {
            Write-Verbose "No script execution tasks found matching the query."
            $output = [PSCustomObject]@{
                PSTypeName           = 'MECM7.ScriptExecutionStatus'
                OperationID          = $null
                ScriptName           = 'Operation not found'
                ScriptVersion        = $null
                ScriptGuid           = $null
                CollectionID         = $null
                CollectionName       = $null
                Results              = $null
                Status               = 'not found'
                TotalClients         = $null
                CompletedClients     = $null
                FailedClients        = $null
                OfflineClients       = $null
                NotApplicableClients = $null
                UnknownClients       = $null
                LastUpdateTime       = $null
            }
            $output.PSObject.TypeNames.Insert(0, 'MECM7.ScriptExecutionStatus')
            Write-Output $output
            return
        }

        # ── Determine if we should include detailed results ─────────────
        # Only include per-device results when a specific ClientOperationId was requested
        $includeResults = ($PSCmdlet.ParameterSetName -eq 'ByClientOperationId')

        foreach ($ts in $TaskStatus) {
            if (-not $includeResults) {
                # Summary mode - return list without per-device results
                $output = [PSCustomObject]@{
                    PSTypeName       = 'MECM7.ScriptExecutionSummary'
                    OperationID      = $ts.ClientOperationId
                    ScriptName       = $ts.ScriptName
                    ScriptGuid       = $ts.ScriptGuid
                    CollectionID     = $ts.CollectionId
                    CollectionName   = $ts.CollectionName
                    LastUpdateTime   = $ts.LastUpdateTime
                    TotalClients     = $ts.TotalClients
                    CompletedClients = $ts.CompletedClients
                    FailedClients    = $ts.FailedClients
                    OfflineClients   = $ts.OfflineClients
                }
                $output.PSObject.TypeNames.Insert(0, 'MECM7.ScriptExecutionSummary')
                Write-Output $output
            }
            else {
                # Detail mode - include per-device results
                if ($ts.CompletedClients -gt 0) {
                    $statusQuery = "SELECT * FROM SMS_ScriptsExecutionStatus WHERE ClientOperationId = $($ts.ClientOperationId)"
                    Write-Verbose "Querying per-device results: $statusQuery"
                    $ClientStatus = Get-CimInstance @cimParams -Query $statusQuery

                    $Results = @()
                    if ($ts.CompletedClients -eq $ts.TotalClients) {
                        $Status = "all clients completed"
                    }
                    else {
                        $Status = "some clients completed"
                    }

                    foreach ($c in $ClientStatus) {
                        $ScriptOutput = $c.ScriptOutput
                        try {
                            $ScriptOutput = $ScriptOutput -replace '\\r\\n', [System.Environment]::NewLine
                            $ScriptOutput = $ScriptOutput -replace '\\"', '"'
                            $ScriptOutput = $ScriptOutput -replace '\\\\', '\'
                            $OutputObject = $ScriptOutput | ConvertFrom-Json
                        }
                        catch {
                            $OutputObject = $c.ScriptOutput
                        }

                        $Results += [PSCustomObject]@{
                            ResourceID           = $c.ResourceId
                            DeviceName           = $c.DeviceName
                            ScriptExecutionState = $c.ScriptExecutionState
                            ScriptExitCode       = $c.ScriptExitCode
                            ScriptOutput         = $c.ScriptOutput
                            OutputObject         = $OutputObject
                        }
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName           = 'MECM7.ScriptExecutionStatus'
                        OperationID          = $ts.ClientOperationId
                        ScriptName           = $ts.ScriptName
                        ScriptVersion        = $ts.ScriptVersion
                        ScriptGuid           = $ts.ScriptGuid
                        CollectionID         = $ts.CollectionId
                        CollectionName       = $ts.CollectionName
                        Results              = $Results
                        Status               = $Status
                        TotalClients         = $ts.TotalClients
                        CompletedClients     = $ts.CompletedClients
                        FailedClients        = $ts.FailedClients
                        OfflineClients       = $ts.OfflineClients
                        NotApplicableClients = $ts.NotApplicableClients
                        UnknownClients       = $ts.UnknownClients
                        LastUpdateTime       = $ts.LastUpdateTime
                    }
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.ScriptExecutionStatus')
                    Write-Output $output
                }
                else {
                    $output = [PSCustomObject]@{
                        PSTypeName           = 'MECM7.ScriptExecutionStatus'
                        OperationID          = $ts.ClientOperationId
                        ScriptName           = $ts.ScriptName
                        ScriptVersion        = $ts.ScriptVersion
                        ScriptGuid           = $ts.ScriptGuid
                        CollectionID         = $ts.CollectionId
                        CollectionName       = $ts.CollectionName
                        Results              = $null
                        Status               = 'no client completed'
                        TotalClients         = $ts.TotalClients
                        CompletedClients     = $ts.CompletedClients
                        FailedClients        = $ts.FailedClients
                        OfflineClients       = $ts.OfflineClients
                        NotApplicableClients = $ts.NotApplicableClients
                        UnknownClients       = $ts.UnknownClients
                        LastUpdateTime       = $ts.LastUpdateTime
                    }
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.ScriptExecutionStatus')
                    Write-Output $output
                }
            }
        }
    }
    catch {
        Write-Error "Failed to get script execution status: $($_.Exception.Message)"
    }
}
function Get-CM7SoftwareUpdate {
    <#
        .SYNOPSIS
            Retrieves software update information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_SoftwareUpdate WMI class to retrieve software update information
            from MECM. Supports filtering by article ID, bulletin ID, name, severity,
            deployment status, and supersedence status.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMSoftwareUpdate cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER ArticleId
            The KB article ID of the software update to retrieve (e.g. "4038779").

        .PARAMETER BulletinId
            The security bulletin ID of the software update to retrieve (e.g. "MS17-010").
            Supports wildcard characters (* and ?).

        .PARAMETER Name
            The localized display name of the software update. Supports wildcard characters (* and ?).

        .PARAMETER Severity
            The severity of the software update. Valid values are:
            None, Low, Moderate, Important, Critical.

        .PARAMETER IsDeployed
            Filter by deployment status. When $true, only returns updates that have been deployed.
            When $false, only returns updates that have not been deployed.

        .PARAMETER IsSuperseded
            Filter by supersedence status. When $true, only returns superseded updates.
            When $false, only returns non-superseded updates.

        .PARAMETER CategoryName
            Filter by update classification or product category name.
            Supports wildcard characters (* and ?).
            Note: This performs a sub-query against SMS_CIToCategory and SMS_CategoryInstance.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            CI_ID, ArticleID, BulletinID, LocalizedDisplayName, LocalizedDescription,
            DatePosted, DateRevised, IsDeployed, IsSuperseded, NumMissing, NumPresent,
            NumTotal, SeverityName, and PercentCompliant.

        .EXAMPLE
            Get-CM7SoftwareUpdate
            Retrieves all software updates.

        .EXAMPLE
            Get-CM7SoftwareUpdate -ArticleId "4038779"
            Retrieves the software update with the specified KB article ID.

        .EXAMPLE
            Get-CM7SoftwareUpdate -Name "*Cumulative*"
            Retrieves all software updates whose names contain "Cumulative".

        .EXAMPLE
            Get-CM7SoftwareUpdate -Severity Critical -IsDeployed $false
            Retrieves all critical software updates that have not yet been deployed.

        .EXAMPLE
            Get-CM7SoftwareUpdate -IsSuperseded $false -Fast
            Retrieves all non-superseded software updates with limited properties.

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByArticleId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ArticleId,

        [Parameter(ParameterSetName = 'ByBulletinId', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$BulletinId,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('None', 'Low', 'Moderate', 'Important', 'Critical')]
        [string]$Severity,

        [Parameter()]
        [Boolean]$IsDeployed,

        [Parameter()]
        [Boolean]$IsSuperseded,

        [Parameter(ParameterSetName = 'ByCategoryName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$CategoryName,

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

        # Severity name to integer mapping
        $severityMap = @{
            'None'      = 0
            'Low'       = 2
            'Moderate'  = 6
            'Important' = 8
            'Critical'  = 10
        }

        # Reverse severity map for display
        $severityReverseMap = @{
            0  = 'None'
            2  = 'Low'
            6  = 'Moderate'
            8  = 'Important'
            10 = 'Critical'
        }
    }

    process {
        try {
            # Build WQL filter based on parameters
            $filters = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ByArticleId' {
                    $filters += "ArticleID = '$ArticleId'"
                }
                'ByBulletinId' {
                    $wqlBulletinId = $BulletinId.Replace('*', '%').Replace('?', '_')
                    if ($wqlBulletinId -like '*%*' -or $wqlBulletinId -like '*_*') {
                        $filters += "BulletinID LIKE '$wqlBulletinId'"
                    } else {
                        $filters += "BulletinID = '$BulletinId'"
                    }
                }
                'ByName' {
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filters += "LocalizedDisplayName LIKE '$wqlName'"
                    } else {
                        $filters += "LocalizedDisplayName = '$Name'"
                    }
                }
                'ByCategoryName' {
                    # Resolve category name to CI_IDs through SMS_CIToCategory and SMS_CategoryInstance
                    $wqlCatName = $CategoryName.Replace('*', '%').Replace('?', '_')
                    if ($wqlCatName -like '*%*' -or $wqlCatName -like '*_*') {
                        $categoryQuery = "SELECT CategoryInstanceID FROM SMS_CategoryInstance WHERE LocalizedCategoryInstanceName LIKE '$wqlCatName'"
                    } else {
                        $categoryQuery = "SELECT CategoryInstanceID FROM SMS_CategoryInstance WHERE LocalizedCategoryInstanceName = '$CategoryName'"
                    }

                    Write-Verbose "Resolving category name: $categoryQuery"
                    $categories = Get-CimInstance @cimParams -Query $categoryQuery

                    if (-not $categories) {
                        Write-Verbose "No categories found matching '$CategoryName'."
                        return
                    }

                    $categoryIds = @($categories | ForEach-Object { $_.CategoryInstanceID })
                    Write-Verbose "Found $($categoryIds.Count) matching categories."

                    # Get CI_IDs from the category relationship class
                    $ciIds = @()
                    foreach ($catId in $categoryIds) {
                        $relQuery = "SELECT CI_ID FROM SMS_CIToCategory WHERE CategoryInstance_UniqueID IN (SELECT CategoryInstance_UniqueID FROM SMS_CategoryInstance WHERE CategoryInstanceID = $catId)"
                        # Use a simpler approach: query the category unique ID first
                        $catUniqueQuery = "SELECT CategoryInstance_UniqueID FROM SMS_CategoryInstance WHERE CategoryInstanceID = $catId"
                        $catUnique = Get-CimInstance @cimParams -Query $catUniqueQuery
                        if ($catUnique) {
                            $uniqueId = $catUnique.CategoryInstance_UniqueID
                            $ciToCategory = Get-CimInstance @cimParams -Query "SELECT CI_ID FROM SMS_CIToCategory WHERE CategoryInstance_UniqueID = '$uniqueId'"
                            if ($ciToCategory) {
                                $ciIds += @($ciToCategory | ForEach-Object { $_.CI_ID })
                            }
                        }
                    }

                    if ($ciIds.Count -eq 0) {
                        Write-Verbose "No software updates found in the specified category."
                        return
                    }

                    # Build filter with CI_IDs (batch to avoid overly long queries)
                    $ciIds = $ciIds | Select-Object -Unique
                    Write-Verbose "Found $($ciIds.Count) software update CI_IDs in the matching categories."
                    # We'll filter in post-processing if too many
                    if ($ciIds.Count -le 100) {
                        $orClauses = $ciIds | ForEach-Object { "CI_ID = $_" }
                        $filters += "(" + ($orClauses -join " OR ") + ")"
                    }
                    # If more than 100, we'll filter in post-processing
                }
            }

            # Additional filters (appended regardless of parameter set)
            if ($PSBoundParameters.ContainsKey('Severity')) {
                $filters += "SeverityName = '$Severity'"
            }

            if ($PSBoundParameters.ContainsKey('IsDeployed')) {
                $filters += "IsDeployed = $(if ($IsDeployed) { 1 } else { 0 })"
            }

            if ($PSBoundParameters.ContainsKey('IsSuperseded')) {
                $filters += "IsSuperseded = $(if ($IsSuperseded) { 1 } else { 0 })"
            }

            # Build the query
            if ($Fast) {
                $properties = "CI_ID, ArticleID, BulletinID, LocalizedDisplayName, LocalizedDescription, DatePosted, DateRevised, IsDeployed, IsSuperseded, NumMissing, NumPresent, NumTotal, SeverityName, PercentCompliant"
                $query = "SELECT $properties FROM SMS_SoftwareUpdate"
            } else {
                $query = "SELECT * FROM SMS_SoftwareUpdate"
            }

            if ($filters.Count -gt 0) {
                $query += " WHERE " + ($filters -join " AND ")
            }

            Write-Verbose "Executing query: $query"

            # Execute the query
            $updates = Get-CimInstance @cimParams -Query $query

            # Post-processing filter for large category queries
            if ($PSCmdlet.ParameterSetName -eq 'ByCategoryName' -and $ciIds.Count -gt 100) {
                $ciIdSet = [System.Collections.Generic.HashSet[int]]::new([int[]]$ciIds)
                $updates = $updates | Where-Object { $ciIdSet.Contains([int]$_.CI_ID) }
            }

            # Output results
            if ($updates) {
                foreach ($update in $updates) {
                    # SeverityName is already a friendly string in SMS_SoftwareUpdate
                    $severityName = if ($update.SeverityName) {
                        $update.SeverityName
                    } else {
                        'None'
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName           = 'MECM7.SoftwareUpdate'
                        CI_ID                = [int]$update.CI_ID
                        ArticleID            = $update.ArticleID
                        BulletinID           = $update.BulletinID
                        LocalizedDisplayName = $update.LocalizedDisplayName
                        LocalizedDescription = $update.LocalizedDescription
                        Severity             = $severityName
                        DatePosted           = $update.DatePosted
                        DateRevised          = $update.DateRevised
                        IsDeployed           = [bool]$update.IsDeployed
                        IsSuperseded         = [bool]$update.IsSuperseded
                        NumMissing           = [int]$update.NumMissing
                        NumPresent           = [int]$update.NumPresent
                        NumTotal             = [int]$update.NumTotal
                        PercentCompliant     = [int]$update.PercentCompliant
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.SoftwareUpdate')

                    # Add all properties if not Fast mode
                    if (-not $Fast) {
                        $update.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                    }

                    Write-Output $output
                }
            } else {
                Write-Verbose "No software updates found matching the criteria."
            }
        }
        catch {
            throw $_
        }
    }
}
function Get-CM7SoftwareUpdateDeployment {
    <#
        .SYNOPSIS
            Retrieves software update deployment information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_UpdatesAssignment WMI class to retrieve software update deployment
            information from MECM. Supports filtering by assignment ID, deployment name,
            and collection name.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMSoftwareUpdateDeployment cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER AssignmentId
            The unique assignment ID (integer) of the software update deployment to retrieve.

        .PARAMETER Name
            The name of the software update deployment. Supports wildcard characters (* and ?).

        .PARAMETER CollectionName
            The name of the collection targeted by the software update deployment.
            Supports wildcard characters (* and ?).

        .PARAMETER CollectionID
            The CollectionID of the collection targeted by the software update deployment.

        .PARAMETER SoftwareUpdateGroupName
            The name of the software update group associated with the deployment. Supports wildcard characters (* and ?).

        .PARAMETER SoftwareUpdateGroupID
            The CI_ID of the software update group associated with the deployment.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            AssignmentID, AssignmentName, TargetCollectionID, AssignmentDescription, StartTime,
            EnforcementDeadline, and summary flags.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment
            Retrieves all software update deployments.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -AssignmentId 16777220
            Retrieves the software update deployment with the specified assignment ID.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -Name "2024-01 Security Updates"
            Retrieves the software update deployment with the specified name.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -Name "2024*"
            Retrieves all software update deployments whose names start with "2024".

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -CollectionName "SP_ACC_2024-01-18_18:00_00:00_automatic_reboot"
            Retrieves all software update deployments targeting the specified collection.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -CollectionName "SP_ACC_*"
            Retrieves all software update deployments targeting collections whose names start with "SP_ACC_".

        .EXAMPLE
            Get-CM7SoftwareUpdateDeployment -CollectionName "All Systems" -Fast
            Retrieves software update deployments for "All Systems" with limited properties.

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(DefaultParameterSetName = 'SugNameCollectionName')]
    param(
        [Parameter(Mandatory = $false)]
        [int]$AssignmentId,

        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$SoftwareUpdateGroupName,

        [Parameter(Mandatory = $false)]
        [string]$SoftwareUpdateGroupID,

        [Parameter(Mandatory = $false)]
        [string]$CollectionName,

        [Parameter(Mandatory = $false)]
        [string]$CollectionID,

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

        # Assignment action type mapping for display
        $assignmentActionMap = @{
            0 = 'Detect'
            1 = 'Install'
        }

        # Desired config type mapping
        $desiredConfigTypeMap = @{
            1 = 'Required'
            2 = 'Optional'
        }
    }

    process {
        try {
            # Build WQL filter based on parameters
            $filters = @()

            if ($AssignmentId) {
                $filters += "AssignmentID = $AssignmentId"
            } elseif ($Name) {
                $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                    $filters += "AssignmentName LIKE '$wqlName'"
                } else {
                    $filters += "AssignmentName = '$Name'"
                }
            }
            if ( $CollectionName) {
                $wqlCollName = $CollectionName.Replace('*', '%').Replace('?', '_')
                if ($wqlCollName -like '*%*' -or $wqlCollName -like '*_*') {
                    $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name LIKE '$wqlCollName'"
                } else {
                    $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
                }

                Write-Verbose "Resolving collection name: $collectionQuery"
                $collections = Get-CimInstance @cimParams -Query $collectionQuery

                if (-not $collections) {
                    Write-Verbose "No collections found matching '$CollectionName'."
                    return
                }

                $collectionIds = @($collections | ForEach-Object { $_.CollectionID })
                if ($collectionIds.Count -eq 1) {
                    $filters += "TargetCollectionID = '$($collectionIds[0])'"
                } else {
                    $orClauses = $collectionIds | ForEach-Object { "TargetCollectionID = '$_'" }
                    $filters += "(" + ($orClauses -join " OR ") + ")"
                }
            }
            if ($CollectionID) {
                $filters += "TargetCollectionID = '$CollectionID'"
            }
            if ($SoftwareUpdateGroupName -or $SoftwareUpdateGroupID) {
                # Resolve Software Update Group first
                if ($SoftwareUpdateGroupID) {
                    $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE CI_ID = $SoftwareUpdateGroupID"
                } else {
                    $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$SoftwareUpdateGroupName'"
                }
                Write-Verbose "Resolving software update group: $groupQuery"
                $resolvedGroup = Get-CimInstance @cimParams -Query $groupQuery

                if (-not $resolvedGroup) {
                    throw "Software update group '$SoftwareUpdateGroupName' not found."
                }
                $groupCIID = [int]$resolvedGroup.CI_ID
                $SoftwareUpdateGroupName = $resolvedGroup.LocalizedDisplayName

                $assignmentID = ( Get-CimInstance @cimParams -Query "SELECT AssignmentID FROM SMS_DeploymentSummary WHERE CI_ID = $groupCIID" ).AssignmentID


                # Add filter for group
                $filters += "AssignmentID = '$assignmentID'"
            }
            if ($CollectionID) {
                $filters += "TargetCollectionID = '$CollectionID'"
            }

            <#
            switch ($PSCmdlet.ParameterSetName) {
                'ByAssignmentId' {
                    $filters += "AssignmentID = $AssignmentId"
                }
                'ByName' {
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $filters += "AssignmentName LIKE '$wqlName'"
                    } else {
                        $filters += "AssignmentName = '$Name'"
                    }
                }
                'ByCollectionName' {
                    # CollectionName is not a direct property of SMS_UpdatesAssignment.
                    # We need to resolve the collection name to a CollectionID first.
                    $wqlCollName = $CollectionName.Replace('*', '%').Replace('?', '_')
                    if ($wqlCollName -like '*%*' -or $wqlCollName -like '*_*') {
                        $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name LIKE '$wqlCollName'"
                    } else {
                        $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
                    }

                    Write-Verbose "Resolving collection name: $collectionQuery"
                    $collections = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collections) {
                        Write-Verbose "No collections found matching '$CollectionName'."
                        return
                    }

                    $collectionIds = @($collections | ForEach-Object { $_.CollectionID })
                    if ($collectionIds.Count -eq 1) {
                        $filters += "TargetCollectionID = '$($collectionIds[0])'"
                    } else {
                        $orClauses = $collectionIds | ForEach-Object { "TargetCollectionID = '$_'" }
                        $filters += "(" + ($orClauses -join " OR ") + ")"
                    }
                }
            }
            #>

            # Build the query
            if ($Fast) {
                $properties = "AssignmentID, AssignmentName, TargetCollectionID, AssignmentDescription, StartTime, EnforcementDeadline, AssignmentAction, DesiredConfigType, SuppressReboot, UseGMTTimes, NotifyUser, OverrideServiceWindows, RebootOutsideOfServiceWindows, Enabled"
                $query = "SELECT $properties FROM SMS_UpdatesAssignment"
            } else {
                $query = "SELECT * FROM SMS_UpdatesAssignment"
            }

            if ($filters.Count -gt 0) {
                $query += " WHERE " + ($filters -join " AND ")
            }

            Write-Verbose "Executing query: $query"

            # Execute the query
            $assignments = Get-CimInstance @cimParams -Query $query

            # If we searched by collection name, also build a lookup for collection names
            $collectionNameLookup = @{}
            if ($PSCmdlet.ParameterSetName -eq 'ByCollectionName' -and $collections) {
                foreach ($coll in $collections) {
                    $collectionNameLookup[$coll.CollectionID] = $coll.Name
                }
            }

            # Output results
            if ($assignments) {
                foreach ($assignment in $assignments) {
                    # Resolve collection name if not already known
                    $resolvedCollectionName = $null
                    if ($collectionNameLookup.ContainsKey($assignment.TargetCollectionID)) {
                        $resolvedCollectionName = $collectionNameLookup[$assignment.TargetCollectionID]
                    } else {
                        # Look up collection name for this assignment
                        $collLookupQuery = "SELECT Name FROM SMS_Collection WHERE CollectionID = '$($assignment.TargetCollectionID)'"
                        $collResult = Get-CimInstance @cimParams -Query $collLookupQuery
                        if ($collResult) {
                            $resolvedCollectionName = $collResult.Name
                            $collectionNameLookup[$assignment.TargetCollectionID] = $resolvedCollectionName
                        }
                    }

                    # Map action type
                    $actionName = if ($assignmentActionMap.ContainsKey([int]$assignment.AssignmentAction)) {
                        $assignmentActionMap[[int]$assignment.AssignmentAction]
                    } else {
                        "Unknown ($($assignment.AssignmentAction))"
                    }

                    # Map desired config type
                    $configTypeName = if ($desiredConfigTypeMap.ContainsKey([int]$assignment.DesiredConfigType)) {
                        $desiredConfigTypeMap[[int]$assignment.DesiredConfigType]
                    } else {
                        "Unknown ($($assignment.DesiredConfigType))"
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName                    = 'MECM7.SoftwareUpdateDeployment'
                        AssignmentID                  = [int]$assignment.AssignmentID
                        AssignmentName                = $assignment.AssignmentName
                        TargetCollectionID            = $assignment.TargetCollectionID
                        CollectionName                = $resolvedCollectionName
                        AssignmentDescription         = $assignment.AssignmentDescription
                        AssignmentAction              = $actionName
                        DesiredConfigType             = $configTypeName
                        StartTime                     = $assignment.StartTime
                        EnforcementDeadline           = $assignment.EnforcementDeadline
                        SuppressReboot                = [bool]$assignment.SuppressReboot
                        UseGMTTimes                   = [bool]$assignment.UseGMTTimes
                        NotifyUser                    = [bool]$assignment.NotifyUser
                        OverrideServiceWindows        = [bool]$assignment.OverrideServiceWindows
                        RebootOutsideOfServiceWindows = [bool]$assignment.RebootOutsideOfServiceWindows
                        Enabled                       = [bool]$assignment.Enabled
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.SoftwareUpdateDeployment')

                    # Add all properties if not Fast mode
                    if (-not $Fast) {
                        $assignment.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                    }

                    Write-Output $output
                }
            } else {
                Write-Verbose "No software update deployments found matching the criteria."
            }
        }
        catch {
            throw $_
        }
    }
}
function Get-CM7SoftwareUpdateDeploymentPackage {
    <#
        .SYNOPSIS
            Retrieves software update deployment package information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_SoftwareUpdatesPackage WMI class to retrieve software update deployment
            package information from MECM. Supports filtering by package ID, package name,
            and retrieval of all packages.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMSoftwareUpdateDeploymentPackage cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER Id
            The unique package ID of the software update deployment package to retrieve.
            This is the PackageID property (e.g., "CM100DDC").

        .PARAMETER Name
            The name of the software update deployment package. Supports wildcard characters (* and ?).

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            PackageID, Name, Description, SourceSite, PkgSourcePath, PackageSize, SourceVersion,
            LastRefreshTime, and summary flags.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeploymentPackage
            Retrieves all software update deployment packages.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeploymentPackage -Id "CM100DDC"
            Retrieves the software update deployment package with the specified package ID.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeploymentPackage -Name "SecurityPatchesPackage"
            Retrieves the software update deployment package with the specified name.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeploymentPackage -Name "Test-SUG*"
            Retrieves all software update deployment packages whose names start with "Test-SUG".

        .EXAMPLE
            Get-CM7SoftwareUpdateDeploymentPackage -Name "*SecurityPatches*"
            Retrieves all software update deployment packages containing "SecurityPatches" in the name.

        .EXAMPLE
            Get-CM7SoftwareUpdateDeploymentPackage -Fast
            Retrieves all software update deployment packages with limited properties for faster performance.

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

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

        # Package type mapping for display
        $packageTypeMap = @{
            0 = 'Standard'
            3 = 'Driver'
            4 = 'Task Sequence'
            5 = 'Software Update'
            6 = 'Device Setting'
            257 = 'Image'
            258 = 'Boot Image'
            259 = 'OS Install'
        }

        # Priority mapping for display
        $priorityMap = @{
            1 = 'High'
            2 = 'Normal'
            3 = 'Low'
        }

        # PkgFlags mapping (bitmask) for common flags
        $pkgFlagsMap = @{
            0x01000000 = 'DO_NOT_DOWNLOAD'
            0x02000000 = 'PERSIST_IN_CACHE'
            0x04000000 = 'USE_BINARY_DELTA_REP'
            0x10000000 = 'NO_PACKAGE'
            0x20000000 = 'USE_SPECIAL_MIF'
        }
    }

    process {
        try {
            # Build WQL filter based on parameters
            $filters = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ById' {
                    $filters += "PackageID = '$Id'"
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

            # Build the query
            if ($Fast) {
                $properties = "PackageID, Name, Description, SourceSite, PkgSourcePath, PackageSize, SourceVersion, StoredPkgVersion, LastRefreshTime, Priority, PkgSourceFlag, ImagePath"
                $query = "SELECT $properties FROM SMS_SoftwareUpdatesPackage"
            } else {
                $query = "SELECT * FROM SMS_SoftwareUpdatesPackage"
            }

            if ($filters.Count -gt 0) {
                $query += " WHERE " + ($filters -join " AND ")
            }

            Write-Verbose "Executing query: $query"

            # Execute the query
            $packages = Get-CimInstance @cimParams -Query $query

            # Output results
            if ($packages) {
                foreach ($package in $packages) {
                    # Map priority
                    $priorityName = if ($priorityMap.ContainsKey([int]$package.Priority)) {
                        $priorityMap[[int]$package.Priority]
                    } else {
                        "Unknown ($($package.Priority))"
                    }

                    # Map PkgSourceFlag
                    $sourceType = switch ([int]$package.PkgSourceFlag) {
                        1 { 'StorageDirect' }
                        2 { 'StorageCompressed' }
                        3 { 'StorageNoPackage' }
                        default { "Unknown ($($package.PkgSourceFlag))" }
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName         = 'MECM7.SoftwareUpdateDeploymentPackage'
                        PackageID          = $package.PackageID
                        Name               = $package.Name
                        Description        = $package.Description
                        SourceSite         = $package.SourceSite
                        PkgSourcePath      = $package.PkgSourcePath
                        PackageSize        = [long]$package.PackageSize
                        SourceVersion      = [int]$package.SourceVersion
                        StoredPkgVersion   = [int]$package.StoredPkgVersion
                        LastRefreshTime    = $package.LastRefreshTime
                        Priority           = $priorityName
                        PkgSourceFlag      = $sourceType
                        ImagePath          = $package.ImagePath
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.SoftwareUpdateDeploymentPackage')

                    # Add all properties if not Fast mode
                    if (-not $Fast) {
                        $package.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                    }

                    Write-Output $output
                }
            } else {
                Write-Verbose "No software update deployment packages found matching the criteria."
            }
        }
        catch {
            throw $_
        }
    }
}
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
            Get-CM7SoftwareUpdateGroup -Name "SecurityPatchesGroup"
            Retrieves the software update group with the specified name.

        .EXAMPLE
            Get-CM7SoftwareUpdateGroup -Name "Test-SUG*"
            Retrieves all software update groups whose names start with "Test-SUG".

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
function Get-CM7TaskSequenceDeployment {
    <#
        .SYNOPSIS
            Retrieves task sequence deployment information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_Advertisement WMI class to retrieve task sequence deployment
            information from MECM. Supports filtering by advertisement ID (deployment ID),
            task sequence name, task sequence package ID, collection name, and deployment name.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMTaskSequenceDeployment cmdlet
            from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Builds a WQL query based on the provided parameters
            3. Resolves collection names and task sequence names to their respective IDs
               via the SMS_Collection and SMS_TaskSequencePackage classes
            4. Queries SMS_DeploymentSummary (FeatureType = 7) to find task sequence deployments,
               then retrieves full details from SMS_Advertisement
            5. Returns formatted task sequence deployment objects with commonly used properties

            Key features:
            - Wildcard Support: Use * and ? in deployment names, task sequence names,
              and collection names for pattern matching
            - Collection Name Filtering: Filter by collection name (resolved to CollectionID)
            - Task Sequence Filtering: Filter by task sequence name or PackageID
            - Fast Mode: Return limited properties for faster queries on large environments
            - Flexible Querying: Query by advertisement ID, task sequence, collection, or retrieve all

        .PARAMETER AdvertisementID
            The unique advertisement ID (deployment ID) of the task sequence deployment to retrieve.
            This is the AdvertisementID property (string), e.g. "SD120BD2".

        .PARAMETER TaskSequenceName
            The name of the task sequence associated with the deployment.
            Supports wildcard characters (* and ?).

        .PARAMETER TaskSequencePackageId
            The PackageID of the task sequence associated with the deployment.

        .PARAMETER CollectionName
            The name of the collection targeted by the task sequence deployment.
            Supports wildcard characters (* and ?).

        .PARAMETER DeploymentName
            The name of the deployment (AdvertisementName). Supports wildcard characters (* and ?).

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            AdvertisementID, AdvertisementName, CollectionID, PackageID, ProgramName, and summary flags.

        .EXAMPLE
            Get-CM7TaskSequenceDeployment
            Retrieves all task sequence deployments.

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -AdvertisementID "SD120BD2"
            Retrieves the task sequence deployment with the specified advertisement ID.

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -CollectionName "SP_ACC_2025-01-30_18:00_00:00_automatic_reboot"
            Retrieves all task sequence deployments targeting the specified collection.

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -CollectionName "SP_ACC_*"
            Retrieves all task sequence deployments targeting collections whose names start with "SP_ACC_".

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -TaskSequenceName "Test Josh"
            Retrieves all deployments of the task sequence named "Test Josh".

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD"
            Retrieves all deployments of the task sequence with PackageID "SD100FAD".

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -DeploymentName "*reboot*"
            Retrieves all task sequence deployments whose names contain "reboot".

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -CollectionName "SP_ACC_2025-01-30_18:00_00:00_automatic_reboot" -Fast
            Retrieves task sequence deployments for the specified collection with limited properties.

        .EXAMPLE
            Get-CM7TaskSequenceDeployment | Select-Object AdvertisementID, AdvertisementName, CollectionID, PackageID | Format-Table -AutoSize
            Lists all task sequence deployments in a summary table.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The function first queries SMS_DeploymentSummary with FeatureType = 7 (TaskSequence)
            to identify task sequence deployments, then retrieves full details from SMS_Advertisement.

            SMS_Advertisement lazy properties (cause HRESULT 0x80041001 in WQL SELECT over WinRM):
              AssignedSchedule, AssignedScheduleEnabled, AssignedScheduleIsGMT,
              ExpirationTimeEnabled, ExpirationTimeIsGMT, PresentTimeEnabled,
              PresentTimeIsGMT, TimeFlags
            These are only available in non-Fast mode (via SELECT *).

            This is the CIM-based equivalent of the Get-CMTaskSequenceDeployment cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByAdvertisementID', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AdvertisementID,

        [Parameter(ParameterSetName = 'ByTaskSequenceName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequenceName,

        [Parameter(ParameterSetName = 'ByTaskSequencePackageId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequencePackageId,

        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByDeploymentName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$DeploymentName,

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
            $advertisementFilters = @()
            $deploymentSummaryFilters = @("FeatureType = 7")

            switch ($PSCmdlet.ParameterSetName) {
                'ByAdvertisementID' {
                    $advertisementFilters += "AdvertisementID = '$AdvertisementID'"
                }
                'ByTaskSequenceName' {
                    # Resolve task sequence name to PackageID(s)
                    $wqlTsName = $TaskSequenceName.Replace('*', '%').Replace('?', '_')
                    if ($wqlTsName -like '*%*' -or $wqlTsName -like '*_*') {
                        $tsQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE Name LIKE '$wqlTsName'"
                    } else {
                        $tsQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE Name = '$TaskSequenceName'"
                    }

                    Write-Verbose "Resolving task sequence name: $tsQuery"
                    $taskSequences = Get-CimInstance @cimParams -Query $tsQuery

                    if (-not $taskSequences) {
                        Write-Verbose "No task sequences found matching '$TaskSequenceName'."
                        return
                    }

                    $packageIds = @($taskSequences | ForEach-Object { $_.PackageID })
                    if ($packageIds.Count -eq 1) {
                        $advertisementFilters += "PackageID = '$($packageIds[0])'"
                    } else {
                        $orClauses = $packageIds | ForEach-Object { "PackageID = '$_'" }
                        $advertisementFilters += "(" + ($orClauses -join " OR ") + ")"
                    }
                }
                'ByTaskSequencePackageId' {
                    $advertisementFilters += "PackageID = '$TaskSequencePackageId'"
                }
                'ByCollectionName' {
                    # Resolve collection name to CollectionID(s)
                    $wqlCollName = $CollectionName.Replace('*', '%').Replace('?', '_')
                    if ($wqlCollName -like '*%*' -or $wqlCollName -like '*_*') {
                        $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name LIKE '$wqlCollName'"
                    } else {
                        $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
                    }

                    Write-Verbose "Resolving collection name: $collectionQuery"
                    $collections = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collections) {
                        Write-Verbose "No collections found matching '$CollectionName'."
                        return
                    }

                    $collectionIds = @($collections | ForEach-Object { $_.CollectionID })
                    if ($collectionIds.Count -eq 1) {
                        $advertisementFilters += "CollectionID = '$($collectionIds[0])'"
                        $deploymentSummaryFilters += "CollectionID = '$($collectionIds[0])'"
                    } else {
                        $orClauses = $collectionIds | ForEach-Object { "CollectionID = '$_'" }
                        $advertisementFilters += "(" + ($orClauses -join " OR ") + ")"
                        $deploymentSummaryFilters += "(" + ($orClauses -join " OR ") + ")"
                    }
                }
                'ByDeploymentName' {
                    $wqlName = $DeploymentName.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $advertisementFilters += "AdvertisementName LIKE '$wqlName'"
                    } else {
                        $advertisementFilters += "AdvertisementName = '$DeploymentName'"
                    }
                }
            }

            # Strategy: Use SMS_DeploymentSummary (FeatureType=7) to find task sequence deployments,
            # then retrieve full details from SMS_Advertisement.
            # For ByAdvertisementID, query SMS_Advertisement directly.

            $advertisementIds = @()

            if ($PSCmdlet.ParameterSetName -eq 'ByAdvertisementID') {
                # Direct query by AdvertisementID - skip DeploymentSummary lookup
                $advertisementIds = @($AdvertisementID)
            } else {
                # Query SMS_DeploymentSummary to find matching task sequence deployments
                $dsQuery = "SELECT DeploymentID FROM SMS_DeploymentSummary WHERE " + ($deploymentSummaryFilters -join " AND ")

                # Add ProgramName = '*' which is the marker for task sequence deployments in SMS_DeploymentSummary
                $dsQuery += " AND ProgramName = '*'"

                Write-Verbose "Querying deployment summary: $dsQuery"
                $deploymentSummaries = Get-CimInstance @cimParams -Query $dsQuery

                if (-not $deploymentSummaries) {
                    # If no results from deployment summary, try direct SMS_Advertisement query
                    # This handles cases where the deployment may not yet appear in DeploymentSummary
                    Write-Verbose "No task sequence deployments found in SMS_DeploymentSummary. Trying SMS_Advertisement directly."

                    # For task sequence deployments in SMS_Advertisement, ProgramName = '*'
                    $advFilters = @("ProgramName = '*'") + $advertisementFilters

                    $advQuery = if ($Fast) {
                        "SELECT AdvertisementID, AdvertisementName, CollectionID, PackageID, ProgramName, SourceSite, " +
                        "AdvertFlags, RemoteClientFlags, PresentTime, ExpirationTime " +
                        "FROM SMS_Advertisement"
                    } else {
                        "SELECT * FROM SMS_Advertisement"
                    }
                    $advQuery += " WHERE " + ($advFilters -join " AND ")

                    Write-Verbose "Executing direct SMS_Advertisement query: $advQuery"
                    $advertisements = Get-CimInstance @cimParams -Query $advQuery

                    if ($advertisements) {
                        $advertisementIds = @($advertisements | ForEach-Object { $_.AdvertisementID })
                    } else {
                        Write-Verbose "No task sequence deployments found matching the criteria."
                        return
                    }
                } else {
                    $advertisementIds = @($deploymentSummaries | ForEach-Object { $_.DeploymentID })
                }
            }

            # Now retrieve full details from SMS_Advertisement for each deployment
            # Build a lookup for collection names
            $collectionNameLookup = @{}
            if ($PSCmdlet.ParameterSetName -eq 'ByCollectionName' -and $collections) {
                foreach ($coll in $collections) {
                    $collectionNameLookup[$coll.CollectionID] = $coll.Name
                }
            }

            # Build a lookup for task sequence names
            $tsNameLookup = @{}
            if ($PSCmdlet.ParameterSetName -eq 'ByTaskSequenceName' -and $taskSequences) {
                foreach ($ts in $taskSequences) {
                    $tsNameLookup[$ts.PackageID] = $ts.Name
                }
            }

            # Filter advertisement IDs by any additional filters (e.g., PackageID for ByTaskSequenceName)
            foreach ($advId in $advertisementIds) {
                # Query the full advertisement
                if ($Fast) {
                    $advQuery = "SELECT AdvertisementID, AdvertisementName, CollectionID, PackageID, ProgramName, SourceSite, " +
                        "AdvertFlags, RemoteClientFlags, PresentTime, ExpirationTime " +
                        "FROM SMS_Advertisement WHERE AdvertisementID = '$advId'"
                } else {
                    $advQuery = "SELECT * FROM SMS_Advertisement WHERE AdvertisementID = '$advId'"
                }

                Write-Verbose "Retrieving advertisement: $advQuery"
                $advertisement = Get-CimInstance @cimParams -Query $advQuery

                if (-not $advertisement) {
                    Write-Verbose "Advertisement '$advId' not found in SMS_Advertisement."
                    continue
                }

                # Apply additional filters for parameter sets that need them
                if ($PSCmdlet.ParameterSetName -eq 'ByTaskSequenceName') {
                    $packageIds = @($taskSequences | ForEach-Object { $_.PackageID })
                    if ($advertisement.PackageID -notin $packageIds) {
                        continue
                    }
                }
                if ($PSCmdlet.ParameterSetName -eq 'ByTaskSequencePackageId') {
                    if ($advertisement.PackageID -ne $TaskSequencePackageId) {
                        continue
                    }
                }
                if ($PSCmdlet.ParameterSetName -eq 'ByDeploymentName') {
                    if ($DeploymentName -notlike '*`**' -and $DeploymentName -notlike '*`?*') {
                        # Exact match
                        if ($advertisement.AdvertisementName -ne $DeploymentName) {
                            continue
                        }
                    } else {
                        # Wildcard match
                        if ($advertisement.AdvertisementName -notlike $DeploymentName) {
                            continue
                        }
                    }
                }

                # Verify this is a task sequence deployment (ProgramName = '*')
                if ($advertisement.ProgramName -ne '*') {
                    continue
                }

                # Resolve collection name
                $resolvedCollectionName = $null
                if ($collectionNameLookup.ContainsKey($advertisement.CollectionID)) {
                    $resolvedCollectionName = $collectionNameLookup[$advertisement.CollectionID]
                } else {
                    $collLookupQuery = "SELECT Name FROM SMS_Collection WHERE CollectionID = '$($advertisement.CollectionID)'"
                    $collResult = Get-CimInstance @cimParams -Query $collLookupQuery
                    if ($collResult) {
                        $resolvedCollectionName = $collResult.Name
                        $collectionNameLookup[$advertisement.CollectionID] = $resolvedCollectionName
                    }
                }

                # Resolve task sequence name
                $resolvedTsName = $null
                if ($tsNameLookup.ContainsKey($advertisement.PackageID)) {
                    $resolvedTsName = $tsNameLookup[$advertisement.PackageID]
                } else {
                    $tsLookupQuery = "SELECT Name FROM SMS_TaskSequencePackage WHERE PackageID = '$($advertisement.PackageID)'"
                    $tsResult = Get-CimInstance @cimParams -Query $tsLookupQuery
                    if ($tsResult) {
                        $resolvedTsName = $tsResult.Name
                        $tsNameLookup[$advertisement.PackageID] = $resolvedTsName
                    }
                }

                # SMS_Advertisement lazy properties (cause HRESULT 0x80041001 in WQL SELECT over WinRM):
                #   AssignedSchedule, AssignedScheduleEnabled, AssignedScheduleIsGMT,
                #   ExpirationTimeEnabled, ExpirationTimeIsGMT, PresentTimeEnabled,
                #   PresentTimeIsGMT, TimeFlags
                # These are only available via SELECT * (non-Fast mode).
                $output = [PSCustomObject]@{
                    PSTypeName               = 'MECM7.TaskSequenceDeployment'
                    AdvertisementID          = $advertisement.AdvertisementID
                    AdvertisementName        = $advertisement.AdvertisementName
                    CollectionID             = $advertisement.CollectionID
                    CollectionName           = $resolvedCollectionName
                    PackageID                = $advertisement.PackageID
                    TaskSequenceName         = $resolvedTsName
                    ProgramName              = $advertisement.ProgramName
                    SourceSite               = $advertisement.SourceSite
                    AdvertFlags              = [int]$advertisement.AdvertFlags
                    RemoteClientFlags        = [int]$advertisement.RemoteClientFlags
                    PresentTime              = $advertisement.PresentTime
                    ExpirationTime           = $advertisement.ExpirationTime
                }

                # Set the type name
                $output.PSObject.TypeNames.Insert(0, 'MECM7.TaskSequenceDeployment')

                # Add all properties if not Fast mode
                if (-not $Fast) {
                    $advertisement.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }
                }

                Write-Output $output
            }
        }
        catch {
            throw $_
        }
    }
}
function Get-CM7User {
	<#
		.SYNOPSIS
			Retrieves user information from MECM using CIM connectivity.

		.DESCRIPTION
			Queries the SMS_R_User WMI class to retrieve user information from MECM via CIM.
			Supports filtering by Name, ResourceId, and wildcards. Equivalent to Get-CMUser in ConfigurationManager module, but uses CIM.
			Requires an active connection via Connect-CM7.

		.PARAMETER Name
			The name of the user to retrieve

        .PARAMETER AllowWildcards
            Allows using wildcards (* and ?) in the Name parameter for pattern matching.

		.PARAMETER ResourceId
			The ResourceID of the user to retrieve.

		.PARAMETER Fast
			Returns limited properties for faster queries.

		.EXAMPLE
			Get-CM7User -Name "dan001\sd221778"
			Retrieves the user with the specified name.

		.EXAMPLE
			Get-CM7User -ResourceId 2063632223
			Retrieves the user with the specified ResourceID.

		.EXAMPLE
			Get-CM7User -Name "dan001*"
			Retrieves all users whose names start with "dan001".

		.EXAMPLE
			Get-CM7User -Fast
			Retrieves all users with limited properties for faster performance.

	#>
	[CmdletBinding(DefaultParameterSetName = 'All')]
	param(
		[Parameter(ParameterSetName = 'ByName', Position = 0)]
		[string]$Name,

        [Parameter(ParameterSetName = 'ByName', Position = 1)]
		[switch]$AllowWildcards,

		[Parameter(ParameterSetName = 'ByResourceId', Mandatory = $true)]
		[int]$ResourceId,

		[Parameter()]
		[switch]$Fast
	)

	$function = $($MyInvocation.MyCommand.Name)
	Write-Verbose "Running $function"

	try {
		# Get connection info
		$conn = $script:CMConnection
		if (-not $conn) {
			throw "No active MECM connection. Run Connect-CM7 first."
		}

		$query = "SELECT * FROM SMS_R_User"
		$where = @()

		switch ($PSCmdlet.ParameterSetName) {
			'ByName' {
				if ($Name) {
                    $Name = $Name -replace '\\', '\\'
                    if ($AllowWildcards) {
                        $Name = $Name -replace '\*', '%'
                        $Name = $Name -replace '\?', '_'
                        $Name = "%$($Name)%"
                    } else {
                        $Name = $Name -replace '([%_])', '[$1]'
                    }
					$where += "UniqueUserName LIKE '$($Name)'"
				}
			}
			'ByResourceId' {
				$where += "ResourceId = $ResourceId"
			}
		}

		if ($where.Count) {
			$query += " WHERE " + ($where -join ' AND ')
		}

		$properties = if ($Fast) {
			@('ResourceId','Name','DistinguishedName','UserPrincipalName','Domain','FullDomainName')
		} else {
			$null
		}

		$result = Get-CimInstance -Query $query -Namespace "root\SMS\site_$($conn.SiteCode)" -CimSession $conn.CimSession

		if ($properties) {
			$result | Select-Object $properties
		} else {
			$result
		}
	}
	catch {
		throw $_
	}
}
function Get-CM7UserCollection {
    <#
        .SYNOPSIS
            Retrieves user collection information from MECM using CIM.

        .DESCRIPTION
            Queries the SMS_Collection WMI class to retrieve user collection information from MECM.
            This is a convenience wrapper around Get-CM7Collection that automatically filters for
            user collections (CollectionType = User).

            Supports filtering by collection name (with wildcard support), CollectionId, and Fast mode.
            Requires an active connection established via Connect-CM7.

            This function is the CIM-based equivalent of the Get-CMUserCollection cmdlet from the
            ConfigurationManager PowerShell module.

        .PARAMETER Name
            The name of the user collection to retrieve. Supports wildcard characters (* and ?).

        .PARAMETER CollectionId
            The CollectionID of the user collection to retrieve.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            CollectionID, Name, CollectionType, MemberCount, and LastRefreshTime.

        .EXAMPLE
            Get-CM7UserCollection -Name "All Users"
            Retrieves the user collection with the exact name "All Users".

        .EXAMPLE
            Get-CM7UserCollection -Name "TEST-*"
            Retrieves all user collections whose names start with "TEST-".

        .EXAMPLE
            Get-CM7UserCollection -CollectionId "SMS00002"
            Retrieves the user collection with CollectionID "SMS00002".

        .EXAMPLE
            Get-CM7UserCollection -Fast
            Retrieves all user collections with limited properties for faster performance.

        .EXAMPLE
            Get-CM7UserCollection
            Retrieves all user collections (use with caution on large environments).
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [string]$CollectionId,

        [Parameter()]
        [switch]$Fast
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    try {
        # Build parameters to pass to Get-CM7Collection
        $params = @{
            CollectionType = 'User'
        }

        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                if ($Name) {
                    $params.Name = $Name
                }
            }
            'ByCollectionId' {
                $params.CollectionId = $CollectionId
            }
        }

        if ($Fast) {
            $params.Fast = $true
        }

        # Pass verbose preference through
        if ($PSBoundParameters.ContainsKey('Verbose')) {
            $params.Verbose = $PSBoundParameters['Verbose']
        }

        # Delegate to Get-CM7Collection with User filter
        Get-CM7Collection @params
    }
    catch {
        throw $_
    }
}
function Get-CM7UserCollectionDirectMembershipRule {
    <#
        .SYNOPSIS
            Retrieves direct membership information for a MECM user collection using CIM.

        .DESCRIPTION
            Queries the SMS_FullCollectionMembership WMI class to retrieve direct membership information for a MECM user collection.
            Direct members are resources that have been explicitly added to a user collection (as opposed to being added via
            query rules, include collections, or exclude collections). Supports filtering by collection name, CollectionId,
            resource name, or resource ID. Requires an active connection established via Connect-CM7.

        .PARAMETER CollectionName
            Specifies the name of the user collection to retrieve direct members for.

        .PARAMETER CollectionId
            Specifies the CollectionID of the user collection to retrieve direct members for.

        .PARAMETER ResourceName
            Specifies the name of the resource to retrieve direct membership information for. Supports wildcard characters (*).

        .PARAMETER ResourceId
            Specifies the ResourceID of the resource to retrieve direct membership information for.

        .PARAMETER Fast
            Returns limited properties for faster queries. Only returns essential properties like
            ResourceID, Name, ResourceType.

        .EXAMPLE
            Get-CM7UserCollectionDirectMembershipRule -CollectionName "All Systems"
            Retrieves all resources that are direct members of the "All Systems" user collection.

        .EXAMPLE
            Get-CM7UserCollectionDirectMembershipRule -CollectionName "All Systems" -ResourceName "TEST-*"
            Retrieves all resources matching the pattern "TEST-*" that are direct members of the "All Systems" user collection.

        .EXAMPLE
            Get-CM7UserCollectionDirectMembershipRule -CollectionId "SMS00001" -ResourceId 16777220
            Retrieves direct membership information for resource 16777220 in the "SMS00001" user collection.

        .EXAMPLE
            Get-CM7UserCollectionDirectMembershipRule -CollectionName "All Systems" -Fast
            Retrieves direct members with limited properties for better performance.

        .NOTES
            This function queries WMI class SMS_FullCollectionMembership which contains direct membership relationships.
            For all members (including members from rules, includes, and excludes), see Get-CM7UserCollectionMember.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter()]
        [SupportsWildcards()]
        [string]$ResourceName,

        [Parameter()]
        [int]$ResourceId = -1,

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
        # Determine which collection identifier to use based on which was provided
        $collectionIdToUse = $null

        if ($CollectionName) {
            # Query the collection to get its ID
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $queryParams = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }

            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName' AND CollectionType = 1" # Ensure it's a user collection
            Write-Verbose "Resolving collection name to ID: $collectionQuery"

            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "User collection '$CollectionName' not found."
                return
            }
            $collectionIdToUse = $collection.CollectionID
        } elseif ($CollectionId) {
            # ensure the provided CollectionId is a user collection
            $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
            $queryParams = @{
                CimSession = $script:CMConnection.CimSession
                Namespace  = $namespace
            }
            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE CollectionID = '$CollectionId' AND CollectionType = 1" # Ensure it's a user collection
            Write-Verbose "Validating collection ID: $collectionQuery"
            $collection = Get-CimInstance @queryParams -Query $collectionQuery
            if (-not $collection) {
                Write-Verbose "User collection with ID '$CollectionId' not found."
                return
            }
            $collectionIdToUse = $CollectionId
        } else {
            throw "Either CollectionName or CollectionId must be provided."
        }

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build query parameters
        $queryParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Build the filter for the query
        $filters = @("CollectionID = '$collectionIdToUse'")

        # Add resource name filter if specified
        if ($ResourceName) {
            $wqlName = $ResourceName.Replace('*', '%').Replace('?', '_')
            if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                $filters += "Name LIKE '$wqlName'"
            } else {
                $filters += "Name = '$ResourceName'"
            }
        }

        # Add resource ID filter if specified
        if ($ResourceId -ne -1) {
            $filters += "ResourceID = $ResourceId"
        }

        $filter = $filters -join ' AND '

        # Build the query
        if ($Fast) {
            $properties = "ResourceID, Name, ResourceType"
            $query = "SELECT $properties FROM SMS_FullCollectionMembership WHERE $filter"
        } else {
            $query = "SELECT * FROM SMS_FullCollectionMembership WHERE $filter"
        }

        Write-Verbose "Executing query: $query"

        # Execute the query
        $members = Get-CimInstance @queryParams -Query $query

        # Output results
        if ($members) {
            foreach ($member in $members) {
                # Map resource type number to friendly name
                # SMS_FullCollectionMembership uses: 5 = System (Device), 4 = User
                $typeDisplay = switch ($member.ResourceType) {
                    5 { 'Device' }
                    4 { 'User' }
                    default { 'Unknown' }
                }

                # Create a custom object with commonly used properties
                $output = [PSCustomObject]@{
                    PSTypeName       = 'MECM7.CollectionDirectMember'
                    ResourceId       = [int]$member.ResourceID
                    Name             = $member.Name
                    ResourceType     = $typeDisplay
                    CollectionId     = $member.CollectionID
                }

                # Add optional properties when not in Fast mode
                if (-not $Fast) {
                    if ($member.PSObject.Properties.Name -contains 'DateAdded') {
                        $output | Add-Member -MemberType NoteProperty -Name 'DateAdded' -Value $member.DateAdded
                    }
                    if ($member.PSObject.Properties.Name -contains 'IsSpecific') {
                        $output | Add-Member -MemberType NoteProperty -Name 'IsSpecific' -Value $member.IsSpecific
                    }
                    if ($member.PSObject.Properties.Name -contains 'Ordinal') {
                        $output | Add-Member -MemberType NoteProperty -Name 'Ordinal' -Value $member.Ordinal
                    }
                }

                $output
            }
        }
    }
    catch {
        throw $_
    }
}
function Invoke-CM7ClientNotification {
    <#
        .SYNOPSIS
            Sends a client notification action to target devices or a collection using CIM.

        .DESCRIPTION
            Sends a client notification to MECM-managed devices, triggering actions like policy
            refresh, inventory cycles, software update scans, and more. This function is the
            CIM-based equivalent of the Invoke-CMClientNotification cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:

            1. Validates an active connection exists (established via Connect-CM7)
            2. Maps the requested ActionType to the corresponding SMS_ClientOperation type code
            3. Resolves target devices by name or collection name if needed
            4. Invokes the SMS_ClientOperation.InitiateClientOperationEx CIM method
            5. Returns the client operation result including the OperationID

            Supported notification action types:

            Client Notifications:
            - **ClientNotificationRequestMachinePolicyNow**: Machine Policy Retrieval & Evaluation Cycle
            - **ClientNotificationRequestUsersPolicyNow**: User Policy Retrieval & Evaluation Cycle
            - **ClientNotificationRequestDDRNow**: Discovery Data Collection Cycle
            - **ClientNotificationRequestHWInvNow**: Hardware Inventory Cycle
            - **ClientNotificationRequestSWInvNow**: Software Inventory Cycle
            - **ClientNotificationAppDeplEvalNow**: Application Deployment Evaluation Cycle
            - **ClientNotificationSUMDeplEvalNow**: Software Updates Deployment Evaluation Cycle
            - **ClientNotificationCheckComplianceNow**: Check Compliance Now
            - **ClientRequestSUPChangeNow**: Request SUP Change Now
            - **ClientRequestDHAChangeNow**: Request DHA Change Now
            - **ClientNotificationRebootMachine**: Restart Computer
            - **ClientNotificationWakeUpClientNow**: Wake Up Client Now

            Diagnostics:
            - **DiagnosticsEnableVerboseLogging**: Enable Verbose Logging
            - **DiagnosticsDisableVerboseLogging**: Disable Verbose Logging
            - **DiagnosticsCollectFiles**: Collect Diagnostic Files

            Endpoint Protection:
            - **EndpointProtectionFullScan**: Full Scan
            - **EndpointProtectionQuickScan**: Quick Scan
            - **EndpointProtectionDownloadDefinition**: Download Definition
            - **EndpointProtectionEvaluateSoftwareUpdate**: Evaluate Software Update
            - **EndpointProtectionExcludeScanPaths**: Exclude Scan Paths
            - **EndpointProtectionAllowThreat**: Allow Threat
            - **EndpointProtectionRestoreQuarantinedItems**: Restore Quarantined Items
            - **EndpointProtectionRestoreWithDeps**: Restore With Dependencies

        .PARAMETER ActionType
            The type of client notification action to send. Must be one of the supported
            notification action types listed in the description.

        .PARAMETER DeviceName
            The name of the target device to send the notification to. The device is resolved
            to its ResourceID via the SMS_R_System class. Cannot be used together with
            ResourceId, CollectionId, or CollectionName.

        .PARAMETER ResourceId
            The ResourceID of the target device(s) to send the notification to. Accepts a
            single integer or an array of integers for targeting multiple devices. Cannot be
            used together with DeviceName, CollectionId, or CollectionName.

        .PARAMETER CollectionId
            The CollectionID of the target collection. The notification will be sent to all
            members of the specified collection. Cannot be used together with DeviceName,
            ResourceId, or CollectionName.

        .PARAMETER CollectionName
            The name of the target collection. The collection is resolved to its CollectionID.
            The notification will be sent to all members of the specified collection. Cannot be
            used together with DeviceName, ResourceId, or CollectionId.

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType ClientNotificationRequestMachinePolicyNow -DeviceName "SERVER01"

            Sends a machine policy refresh notification to the device "SERVER01".

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType ClientNotificationRequestHWInvNow -ResourceId 16893210

            Triggers a hardware inventory cycle on the device with ResourceID 16893210.

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType ClientNotificationSUMDeplEvalNow -CollectionId "SD101C00"

            Triggers a software updates deployment evaluation cycle on all members of the collection with ID "SD101C00".

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType ClientNotificationSUMDeplEvalNow -CollectionName "Test-Collection-Direct"

            Triggers a software updates deployment evaluation cycle on all members of the collection named "Test-Collection-Direct".

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType ClientNotificationRebootMachine -DeviceName "SERVER01"

            Restarts the device "SERVER01".

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType ClientNotificationRequestMachinePolicyNow -ResourceId @(16893210, 16893465)

            Sends a machine policy refresh notification to multiple devices specified by their ResourceIDs.

        .EXAMPLE
            Invoke-CM7ClientNotification -ActionType EndpointProtectionQuickScan -DeviceName "SERVER01"

            Triggers an Endpoint Protection quick scan on the device "SERVER01".

        .OUTPUTS
            PSCustomObject (MECM7.ClientNotification) with properties:
            - OperationID: The client operation ID for tracking
            - ActionType: The notification action type that was sent
            - ReturnValue: The return value from the CIM method invocation (0 = success)

        .NOTES
            Requires an active MECM connection established via Connect-CM7.
            The device must be an active MECM client to receive the notification.
            Some actions like ClientNotificationRebootMachine require appropriate MECM permissions.
            Use -WhatIf or -Confirm for actions like ClientNotificationRebootMachine to preview or confirm before executing.

        .LINK
            Connect-CM7
            Get-CM7Device
            Get-CM7Collection
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByDeviceName', SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'ClientNotificationRequestMachinePolicyNow',
            'ClientNotificationRequestUsersPolicyNow',
            'ClientNotificationRequestDDRNow',
            'ClientNotificationRequestHWInvNow',
            'ClientNotificationRequestSWInvNow',
            'ClientNotificationAppDeplEvalNow',
            'ClientNotificationSUMDeplEvalNow',
            'ClientNotificationCheckComplianceNow',
            'ClientRequestSUPChangeNow',
            'ClientRequestDHAChangeNow',
            'ClientNotificationRebootMachine',
            'ClientNotificationWakeUpClientNow',
            'DiagnosticsEnableVerboseLogging',
            'DiagnosticsDisableVerboseLogging',
            'DiagnosticsCollectFiles',
            'EndpointProtectionFullScan',
            'EndpointProtectionQuickScan',
            'EndpointProtectionDownloadDefinition',
            'EndpointProtectionEvaluateSoftwareUpdate',
            'EndpointProtectionExcludeScanPaths',
            'EndpointProtectionAllowThreat',
            'EndpointProtectionRestoreQuarantinedItems',
            'EndpointProtectionRestoreWithDeps'
        )]
        [string]$ActionType,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByDeviceName')]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [ValidateNotNullOrEmpty()]
        [int[]]$ResourceId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # ── Map ActionType to SMS_ClientOperation Type code ─────────────
        $actionTypeMap = @{
            # Client Notifications
            'ClientNotificationRequestMachinePolicyNow'    = [UInt32]8
            'ClientNotificationRequestUsersPolicyNow'      = [UInt32]9
            'ClientNotificationRequestDDRNow'              = [UInt32]10
            'ClientNotificationRequestSWInvNow'            = [UInt32]11
            'ClientNotificationRequestHWInvNow'            = [UInt32]12
            'ClientNotificationAppDeplEvalNow'             = [UInt32]13
            'ClientNotificationSUMDeplEvalNow'             = [UInt32]14
            'ClientRequestSUPChangeNow'                    = [UInt32]15
            'ClientRequestDHAChangeNow'                    = [UInt32]16
            'ClientNotificationRebootMachine'              = [UInt32]17
            'ClientNotificationCheckComplianceNow'         = [UInt32]125
            'ClientNotificationWakeUpClientNow'            = [UInt32]0  # WOL - may require specific permissions
            # Diagnostics
            'DiagnosticsEnableVerboseLogging'              = [UInt32]20
            'DiagnosticsDisableVerboseLogging'             = [UInt32]21
            'DiagnosticsCollectFiles'                      = [UInt32]22
            # Endpoint Protection
            'EndpointProtectionFullScan'                   = [UInt32]1
            'EndpointProtectionQuickScan'                  = [UInt32]2
            'EndpointProtectionDownloadDefinition'         = [UInt32]3
            'EndpointProtectionEvaluateSoftwareUpdate'     = [UInt32]4
            'EndpointProtectionExcludeScanPaths'           = [UInt32]5
            'EndpointProtectionAllowThreat'                = [UInt32]6
            'EndpointProtectionRestoreQuarantinedItems'    = [UInt32]7
            'EndpointProtectionRestoreWithDeps'            = [UInt32]100
        }

        $operationType = $actionTypeMap[$ActionType]
        Write-Verbose "Client action type: $ActionType (Operation Type: $operationType)"

        # ── Resolve target ──────────────────────────────────────────────
        $targetCollectionID = ""
        $targetResourceIDs = @()

        if ($DeviceName) {
            Write-Verbose "Resolving device by name: $DeviceName"
            $deviceQuery = "SELECT ResourceID FROM SMS_R_System WHERE Name = '$DeviceName'"
            $device = Get-CimInstance @cimParams -Query $deviceQuery
            if (-not $device) {
                throw "Could not find device with name '$DeviceName'."
            }
            if ($device -is [array]) {
                $targetResourceIDs = @($device | ForEach-Object { [UInt32]$_.ResourceID })
            }
            else {
                $targetResourceIDs = @([UInt32]$device.ResourceID)
            }
            Write-Verbose "Resolved device '$DeviceName' to ResourceID(s): $($targetResourceIDs -join ', ')"
        }
        elseif ($ResourceId) {
            $targetResourceIDs = @($ResourceId | ForEach-Object { [UInt32]$_ })
            Write-Verbose "Targeting ResourceID(s): $($targetResourceIDs -join ', ')"
        }
        elseif ($CollectionName) {
            Write-Verbose "Resolving collection by name: $CollectionName"
            $collectionQuery = "SELECT CollectionID FROM SMS_Collection WHERE Name = '$CollectionName'"
            $collection = Get-CimInstance @cimParams -Query $collectionQuery
            if (-not $collection) {
                throw "Could not find collection with name '$CollectionName'."
            }
            if ($collection -is [array]) {
                $collection = $collection[0]
                Write-Warning "Multiple collections found with name '$CollectionName'. Using first match: $($collection.CollectionID)"
            }
            $targetCollectionID = $collection.CollectionID
            Write-Verbose "Resolved collection '$CollectionName' to CollectionID: $targetCollectionID"
        }
        elseif ($CollectionId) {
            $targetCollectionID = $CollectionId
            Write-Verbose "Targeting collection: $CollectionId"
        }

        # Validate we have a target
        if ([string]::IsNullOrEmpty($targetCollectionID) -and $targetResourceIDs.Count -eq 0) {
            throw "No valid target specified. Provide DeviceName, ResourceId, CollectionId, or CollectionName."
        }

        # ── Build target description for ShouldProcess ──────────────────
        $targetDescription = if ($DeviceName) { "Name=`"$DeviceName`"" }
            elseif ($ResourceId) { "ResourceID=$($targetResourceIDs -join ', ')" }
            elseif ($CollectionName) { "Collection=`"$CollectionName`"" }
            else { "CollectionID=`"$CollectionId`"" }

        if ($PSCmdlet.ShouldProcess("ClientAction: $targetDescription", "Invoke")) {
            # ── Invoke the CIM method ───────────────────────────────────
            $methodParams = @{
                Param              = ""
                RandomizationWindow = [UInt32]0
                TargetCollectionID = $targetCollectionID
                TargetResourceIDs  = [UInt32[]]$targetResourceIDs
                Type               = $operationType
            }

            Write-Verbose "Invoking InitiateClientOperationEx on SMS_ClientOperation (Type: $operationType)..."

            $result = Invoke-CimMethod @cimParams `
                -ClassName 'SMS_ClientOperation' `
                -MethodName 'InitiateClientOperationEx' `
                -Arguments $methodParams

            Write-Verbose "Method invocation completed. OperationID: $($result.OperationID), ReturnValue: $($result.ReturnValue)"

            # ── Return result object ────────────────────────────────────
            $output = [PSCustomObject]@{
                PSTypeName  = 'MECM7.ClientNotification'
                OperationID = $result.OperationID
                ActionType  = $ActionType
                ReturnValue = $result.ReturnValue
            }
            $output.PSObject.TypeNames.Insert(0, 'MECM7.ClientNotification')

            Write-Output $output
        }
    }
    catch {
        Write-Error "Failed to send client notification: $($_.Exception.Message)"
    }
}
function Invoke-CM7CollectionUpdate {
    <#
        .SYNOPSIS
            Triggers a collection membership evaluation (refresh) on a MECM collection using CIM.

        .DESCRIPTION
            Forces a collection to re-evaluate its membership rules by invoking the
            RequestRefresh method on the SMS_Collection WMI class. This function is the
            CIM-based equivalent of the Invoke-CMCollectionUpdate cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:

            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the target collection by Name or CollectionID
            3. Invokes the RequestRefresh method on the SMS_Collection instance
            4. Returns the result including the ReturnValue (0 = success)

            This is useful when you need to force a collection to update its membership
            immediately, for example after adding or removing membership rules, or when
            you need to ensure the collection membership is current before deploying
            software or running reports.

        .PARAMETER Name
            The name of the collection to update. The collection is resolved via the
            SMS_Collection class. Cannot be used together with CollectionId.

        .PARAMETER CollectionId
            The CollectionID of the collection to update. Cannot be used together with Name.

        .EXAMPLE
            Invoke-CM7CollectionUpdate -Name "Test-Collection-Query"

            Forces a membership evaluation on the collection named "Test-Collection-Query".

        .EXAMPLE
            Invoke-CM7CollectionUpdate -CollectionId "SMS00001"

            Forces a membership evaluation on the collection with CollectionID "SMS00001".

        .EXAMPLE
            Invoke-CM7CollectionUpdate -Name "Test-Collection-Query" -Verbose

            Forces a membership evaluation with verbose output showing the WQL query
            execution and method invocation details.

        .EXAMPLE
            Invoke-CM7CollectionUpdate -Name "Test-Collection-Query" -WhatIf

            Shows what would happen without actually triggering the collection update.

        .OUTPUTS
            PSCustomObject (MECM7.CollectionUpdate) with properties:
            - CollectionId: The CollectionID of the updated collection
            - Name: The name of the collection
            - CollectionType: The type of the collection (Device or User)
            - ReturnValue: The return value from the CIM method invocation (0 = success)

        .NOTES
            Requires an active MECM connection established via Connect-CM7.
            The collection must exist in MECM.
            The user must have appropriate permissions to trigger collection evaluation.

        .LINK
            Connect-CM7
            Get-CM7Collection
            New-CM7Collection
            Remove-CM7Collection
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # ── Resolve the collection ──────────────────────────────────────
        if ($Name) {
            Write-Verbose "Start: Execution of WQL query: SELECT * FROM SMS_Collection WHERE Name = '$Name'"
            $collectionQuery = "SELECT * FROM SMS_Collection WHERE Name = '$Name'"
            $collection = Get-CimInstance @cimParams -Query $collectionQuery
        }
        else {
            Write-Verbose "Start: Execution of WQL query: SELECT * FROM SMS_Collection WHERE CollectionID = '$CollectionId'"
            $collectionQuery = "SELECT * FROM SMS_Collection WHERE CollectionID = '$CollectionId'"
            $collection = Get-CimInstance @cimParams -Query $collectionQuery
        }

        if (-not $collection) {
            $identifier = if ($Name) { "name '$Name'" } else { "CollectionID '$CollectionId'" }
            throw "Could not find collection with $identifier."
        }

        # If multiple results, take the first
        if ($collection -is [array]) {
            $collection = $collection[0]
            if ($Name) {
                Write-Warning "Multiple collections found with name '$Name'. Using first match: $($collection.CollectionID)"
            }
        }

        # Map collection type number to friendly name
        $typeDisplay = switch ($collection.CollectionType) {
            1 { 'User' }
            2 { 'Device' }
            default { 'Unknown' }
        }

        # ── Build target description for ShouldProcess ──────────────────
        $targetDescription = "${typeDisplay}CollectionUpdate: Name=`"$($collection.Name)`""

        if ($PSCmdlet.ShouldProcess($targetDescription, "Invoke")) {
            # ── Invoke the RequestRefresh method ────────────────────────
            Write-Verbose "Performing the operation `"Invoke`" on target `"$targetDescription`"."

            $result = Invoke-CimMethod `
                -CimSession $script:CMConnection.CimSession `
                -InputObject $collection `
                -MethodName 'RequestRefresh'

            Write-Verbose "Output properties:"
            Write-Verbose "-- :: ReturnValue == $($result.ReturnValue)"

            $resultCount = if ($collection -is [array]) { $collection.Count } else { 1 }
            if ($Name) {
                Write-Verbose "Finish: Execution of WQL query: SELECT * FROM SMS_Collection WHERE Name = '$Name'. Processed $resultCount results."
            }
            else {
                Write-Verbose "Finish: Execution of WQL query: SELECT * FROM SMS_Collection WHERE CollectionID = '$CollectionId'. Processed $resultCount results."
            }

            # ── Return result object ────────────────────────────────────
            $output = [PSCustomObject]@{
                PSTypeName     = 'MECM7.CollectionUpdate'
                CollectionId   = $collection.CollectionID
                Name           = $collection.Name
                CollectionType = $typeDisplay
                ReturnValue    = $result.ReturnValue
            }
            $output.PSObject.TypeNames.Insert(0, 'MECM7.CollectionUpdate')

            Write-Output $output
        }
    }
    catch {
        Write-Error "Failed to update collection: $($_.Exception.Message)"
    }
}
function Invoke-CM7Script {
    <#
        .SYNOPSIS
            Invokes (runs) a Configuration Manager script on target devices or a collection using CIM.

        .DESCRIPTION
            Runs an approved MECM script on one or more target devices or on all members of a collection.
            This function is the CIM-based equivalent of the Invoke-CMScript cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM instead
            of requiring the ConfigMgr console or PowerShell drive.

            In addition to the origin cmdlet Invoke-CMScript, it allows passing input parameters
            to the script.

            The function performs the following actions:

            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the script by name or GUID via the SMS_Scripts WMI class
            3. Validates the script is approved (ApprovalState = 3)
            4. Resolves target devices by name if needed (via SMS_R_System)
            5. Builds the script execution XML payload with optional parameters
            6. Invokes the SMS_ClientOperation.InitiateClientOperationEx CIM method
            7. Returns the client operation result including the OperationID for status tracking

            Key features:
            - **Script by Name or GUID**: Identify the script to run by its display name or ScriptGuid
            - **Target by Device or Collection**: Run on specific devices (by name or ResourceId) or an entire collection
            - **Parameter Support**: Pass script input parameters as a hashtable
            - **Approval Validation**: Only approved scripts can be executed
            - **Hidden Parameter Handling**: Hidden parameters automatically use their default values

        .PARAMETER ScriptName
            The name of the MECM script to invoke. The script must exist and be approved.
            Either ScriptName or ScriptGuid must be specified.

        .PARAMETER ScriptGuid
            The GUID of the MECM script to invoke. The script must exist and be approved.
            Either ScriptName or ScriptGuid must be specified.

        .PARAMETER DeviceName
            The name of the target device to run the script on. The device is resolved to its ResourceID
            via the SMS_R_System class. Cannot be used together with CollectionId or ResourceId.

        .PARAMETER ResourceId
            The ResourceID of the target device to run the script on. Accepts a single integer or
            an array of integers for targeting multiple devices. Cannot be used together with
            CollectionId or DeviceName.

        .PARAMETER CollectionId
            The CollectionID of the target collection. The script will be executed on all members
            of the specified collection. Cannot be used together with DeviceName or ResourceId.

        .PARAMETER ScriptParameters
            A hashtable of parameters to pass to the script. The keys must match the script's
            parameter names. If the script has hidden parameters, their default values are used
            automatically. If the script has required (non-hidden) parameters that are not provided,
            an error is thrown.

        .EXAMPLE
            Invoke-CM7Script -ScriptName "get pending reboot" -DeviceName "SERVER01"

            Runs the script "get pending reboot" on the device "SERVER01" without any input parameters.

        .EXAMPLE
            $params = @{ Detail = "TRUE" }
            Invoke-CM7Script -ScriptName "get pending reboot" -DeviceName "SERVER01" -ScriptParameters $params

            Runs the script "get pending reboot" on "SERVER01" with the parameter Detail set to "TRUE".

        .EXAMPLE
            Invoke-CM7Script -ScriptGuid "DF90142C-1534-4A0B-B26A-6B917699A873" -ResourceId 16893210

            Runs the script identified by GUID on the device with ResourceID 16893210.

        .EXAMPLE
            Invoke-CM7Script -ScriptName "get pending reboot" -ResourceId @(16893210, 16893465)

            Runs a script on multiple devices specified by an array of ResourceIDs.

        .EXAMPLE
            Invoke-CM7Script -ScriptName "get pending reboot" -CollectionId "CM101129"

            Runs the script on all members of the collection with ID "CM101129".

        .OUTPUTS
            PSCustomObject (MECM7.ScriptInvocation) with properties:
            - OperationID: The client operation ID for tracking execution status
            - ScriptName: The name of the script that was invoked
            - ScriptGuid: The GUID of the script
            - ReturnValue: The return value from the CIM method invocation (0 = success)

        .NOTES
            Requires an active MECM connection established via Connect-CM7.
            The script must be approved (ApprovalState = 3) to be executed.
            Use Get-CM7ScriptExecutionStatus with the returned OperationID to track execution progress.

        .LINK
            Connect-CM7
            Get-CM7Script
            Get-CM7ScriptExecutionStatus
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByScriptNameAndDeviceName')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptNameAndDeviceName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptNameAndResourceId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptNameAndCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptGuidAndDeviceName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptGuidAndResourceId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptGuidAndCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptGuid,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptNameAndDeviceName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptGuidAndDeviceName')]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptNameAndResourceId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptGuidAndResourceId')]
        [ValidateNotNullOrEmpty()]
        [int[]]$ResourceId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptNameAndCollectionId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByScriptGuidAndCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter()]
        [hashtable]$ScriptParameters = @{}
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    try {
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # ── Resolve the script ──────────────────────────────────────────
        if ($ScriptName) {
            Write-Verbose "Resolving script by name: $ScriptName"
            $scriptQuery = "SELECT * FROM SMS_Scripts WHERE ScriptName = '$ScriptName'"
            $scriptObj = Get-CimInstance @cimParams -Query $scriptQuery
        }
        else {
            Write-Verbose "Resolving script by GUID: $ScriptGuid"
            $scriptQuery = "SELECT * FROM SMS_Scripts WHERE ScriptGuid = '$ScriptGuid'"
            $scriptObj = Get-CimInstance @cimParams -Query $scriptQuery
        }

        if (-not $scriptObj) {
            $identifier = if ($ScriptName) { "name '$ScriptName'" } else { "GUID '$ScriptGuid'" }
            throw "Could not find script with $identifier."
        }

        # If multiple results, take the first
        if ($scriptObj -is [array]) {
            $scriptObj = $scriptObj[0]
        }

        # Re-fetch the full instance to load lazy properties (ParamsDefinition, Script, ScriptHash, etc.)
        Write-Verbose "Retrieving full instance to load lazy properties (ParamsDefinition)..."
        $scriptObj = $scriptObj | Get-CimInstance

        if (-not $scriptObj) {
            throw "Could not retrieve full script instance for lazy property loading."
        }

        Write-Verbose "Found script: $($scriptObj.ScriptName) (GUID: $($scriptObj.ScriptGuid), ApprovalState: $($scriptObj.ApprovalState))"

        # Validate approval state (3 = Approved)
        if ($scriptObj.ApprovalState -ne 3) {
            $stateMap = @{ 0 = 'WaitingForApproval'; 1 = 'Declined'; 3 = 'Approved' }
            $stateName = if ($stateMap.ContainsKey([int]$scriptObj.ApprovalState)) { $stateMap[[int]$scriptObj.ApprovalState] } else { "Unknown ($($scriptObj.ApprovalState))" }
            throw "Script '$($scriptObj.ScriptName)' cannot be invoked because it is not approved. Current state: $stateName"
        }

        # ── Resolve target devices ──────────────────────────────────────
        $targetCollectionID = ""
        $targetResourceIDs = @()

        if ($DeviceName) {
            Write-Verbose "Resolving device by name: $DeviceName"
            $deviceQuery = "SELECT ResourceID FROM SMS_R_System WHERE Name = '$DeviceName'"
            $device = Get-CimInstance @cimParams -Query $deviceQuery
            if (-not $device) {
                throw "Could not find device with name '$DeviceName'."
            }
            if ($device -is [array]) {
                $targetResourceIDs = @($device | ForEach-Object { [UInt32]$_.ResourceID })
            }
            else {
                $targetResourceIDs = @([UInt32]$device.ResourceID)
            }
            Write-Verbose "Resolved device '$DeviceName' to ResourceID(s): $($targetResourceIDs -join ', ')"
        }
        elseif ($ResourceId) {
            $targetResourceIDs = @($ResourceId | ForEach-Object { [UInt32]$_ })
            Write-Verbose "Targeting ResourceID(s): $($targetResourceIDs -join ', ')"
        }
        elseif ($CollectionId) {
            $targetCollectionID = $CollectionId
            Write-Verbose "Targeting collection: $CollectionId"
        }

        # Validate we have a target
        if ([string]::IsNullOrEmpty($targetCollectionID) -and $targetResourceIDs.Count -eq 0) {
            throw "No valid target specified. Provide DeviceName, ResourceId, or CollectionId."
        }

        # ── Build script parameters XML ─────────────────────────────────
        $paramsDefinition = $scriptObj.ParamsDefinition
        $parametersXML = "<ScriptParameters></ScriptParameters>"
        $parametersHash = ""

        if (-not [string]::IsNullOrEmpty($paramsDefinition)) {
            # Decode the Base64 params definition
            # ParamsDefinition is Base64 of UTF-8 (single-byte) encoded XML
            # Use [string]::new() which converts byte[] to char[] (matching the WMI and Admin Service approach)
            $paramsXmlString = [string]::new([Convert]::FromBase64String($paramsDefinition))
            $paramsXml = [xml]$paramsXmlString

            if ($paramsXml.ScriptParameters -and $paramsXml.ScriptParameters.ChildNodes.Count -gt 0) {
                # Validate required parameters
                foreach ($childNode in $paramsXml.ScriptParameters.ChildNodes) {
                    if ($childNode.IsRequired -eq 'true' -and $childNode.IsHidden -ne 'true' -and $childNode.Name -notin $ScriptParameters.Keys) {
                        throw "Script '$($scriptObj.ScriptName)' has required parameter '$($childNode.Name)' but no value was provided."
                    }
                }

                # Build the parameters XML
                $parameterGroupGUID = [guid]::NewGuid().ToString()
                $innerParametersXML = ''

                foreach ($childNode in $paramsXml.ScriptParameters.ChildNodes) {
                    $paramName = $childNode.Name

                    if ($childNode.IsHidden -eq 'true') {
                        # Use default value for hidden parameters
                        $value = $childNode.DefaultValue
                    }
                    elseif ($ScriptParameters.ContainsKey($paramName)) {
                        $value = $ScriptParameters[$paramName]
                    }
                    else {
                        $value = $childNode.DefaultValue
                        if ($null -eq $value) { $value = '' }
                    }

                    # Escape XML special characters in the value
                    $escapedValue = [System.Security.SecurityElement]::Escape($value)

                    $innerParametersXML += "<ScriptParameter ParameterGroupGuid=`"$parameterGroupGUID`" ParameterGroupName=`"PG_$parameterGroupGUID`" ParameterName=`"$paramName`" ParameterDataType=`"$($childNode.Type)`" ParameterValue=`"$escapedValue`"/>"
                }

                $parametersXML = "<ScriptParameters>$innerParametersXML</ScriptParameters>"

                # Compute SHA256 hash of the parameters XML
                $sha256 = [System.Security.Cryptography.SHA256]::Create()
                $bytes = $sha256.ComputeHash([System.Text.Encoding]::Unicode.GetBytes($parametersXML))
                $parametersHash = ($bytes | ForEach-Object { $_.ToString('X2') }) -join ''
                $sha256.Dispose()
            }
        }
        elseif ($ScriptParameters.Count -gt 0) {
            Write-Warning "Script '$($scriptObj.ScriptName)' does not accept parameters, but ScriptParameters were provided. They will be ignored."
        }

        # ── Build the RunScript XML ─────────────────────────────────────
        $runScriptXMLTemplate = "<ScriptContent ScriptGuid='{0}'><ScriptVersion>{1}</ScriptVersion><ScriptType>{2}</ScriptType><ScriptHash ScriptHashAlg='SHA256'>{3}</ScriptHash>{4}<ParameterGroupHash ParameterHashAlg='SHA256'>{5}</ParameterGroupHash></ScriptContent>"
        $runScriptXML = $runScriptXMLTemplate -f $scriptObj.ScriptGuid, $scriptObj.ScriptVersion, $scriptObj.ScriptType, $scriptObj.ScriptHash, $parametersXML, $parametersHash

        Write-Verbose "RunScript XML built successfully"

        # ── Invoke the CIM method ───────────────────────────────────────
        $encodedScript = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($runScriptXML))

        $methodParams = @{
            Param              = $encodedScript
            RandomizationWindow = [UInt32]0
            TargetCollectionID = $targetCollectionID
            TargetResourceIDs  = [UInt32[]]$targetResourceIDs
            Type               = [UInt32]135  # Run Script operation type
        }

        Write-Verbose "Invoking InitiateClientOperationEx on SMS_ClientOperation..."

        $result = Invoke-CimMethod @cimParams `
            -ClassName 'SMS_ClientOperation' `
            -MethodName 'InitiateClientOperationEx' `
            -Arguments $methodParams

        Write-Verbose "Method invocation completed. ReturnValue: $($result.ReturnValue)"

        # ── Return result object ────────────────────────────────────────
        $output = [PSCustomObject]@{
            PSTypeName  = 'MECM7.ScriptInvocation'
            OperationID = $result.OperationID
            ScriptName  = $scriptObj.ScriptName
            ScriptGuid  = $scriptObj.ScriptGuid
            ReturnValue = $result.ReturnValue
        }
        $output.PSObject.TypeNames.Insert(0, 'MECM7.ScriptInvocation')

        Write-Output $output
    }
    catch {
        Write-Error "Failed to invoke script: $($_.Exception.Message)"
    }
}
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
function New-CM7Application {
    <#
        .SYNOPSIS
            Creates a new application in MECM using CIM.

        .DESCRIPTION
            Creates a new application in MECM via the SMS_Application WMI class using CIM connectivity.
            Requires an active connection established via Connect-CM7.

            The function retrieves the site's AuthoringScopeId via SMS_Identification.GetSiteID(),
            builds the required SDMPackageXML, and creates the application via New-CimInstance.

            Note: SMS_Application requires the SDMPackageXML to be a valid AppMgmtDigest XML document
            with an XML declaration header. Deletion requires first retiring the app via SetIsExpired,
            then calling Remove-CimInstance.

        .PARAMETER Name
            The display name of the application to create (mandatory).

        .PARAMETER Publisher
            The publisher / manufacturer of the application (mandatory).

        .PARAMETER SoftwareVersion
            The version string of the application (mandatory).

        .PARAMETER Description
            A description for the application.

        .PARAMETER AutoInstall
            Whether the application may be installed automatically during a task sequence.
            Defaults to $false.

        .PARAMETER ReleaseDate
            The release date of the application. Maps to the EffectiveDate WMI property.

        .PARAMETER Owner
            The owner of the application (LogonName format, e.g., "domain\user" or "username").

        .PARAMETER SupportContact
            The support contact for the application (LogonName format).

        .PARAMETER SupportUrl
            The support URL for the application. Used as the InformativeURL if InformationUrl is not set.

        .PARAMETER IsEnabled
            Whether the application is enabled. Defaults to $true.

        .PARAMETER IsHidden
            Whether the application is hidden from the Software Center. Defaults to $false.

        .PARAMETER PrivacyUrl
            Privacy statement URL for the application. Stored as <PrivacyURL> in DisplayInfo/Info.

        .PARAMETER InfoUrl
            More information / help URL for the application. Takes precedence over SupportUrl as
            the InformativeURL in the AppMgmtDigest XML.

        .PARAMETER InfoUrlText
            The display text for the InfoUrl link. Stored as <InfoURLText> in DisplayInfo/Info.

        .PARAMETER Icon
            Reserved for future use (byte array of the icon). Not yet implemented in XML serialization.

        .EXAMPLE
            New-CM7Application -Name "MyApp" -Publisher "Contoso" -SoftwareVersion "1.0.0"
            Creates a minimal application.

        .EXAMPLE
            New-CM7Application -Name "MyApp" -Publisher "Contoso" -SoftwareVersion "2.0" `
                -Description "My application" -AutoInstall $true -Owner "domain\admin" `
                -SupportContact "helpdesk" -IsEnabled $true -IsHidden $false `
                -InfoUrl "https://contoso.com/myapp" -PrivacyUrl "https://contoso.com/privacy"
            Creates an application with all common metadata.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Publisher,

        [Parameter(Mandatory = $true)]
        [string]$SoftwareVersion,

        [Parameter()]
        [string]$Description = '',

        [Parameter()]
        [boolean]$AutoInstall = $false,

        [Parameter()]
        [datetime]$ReleaseDate,

        [Parameter()]
        [string]$Owner = '',

        [Parameter()]
        [string]$SupportContact = '',

        [Parameter()]
        [string]$SupportUrl = '',

        [Parameter()]
        [boolean]$IsEnabled = $true,

        [Parameter()]
        [boolean]$IsHidden = $false,

        [Parameter()]
        [string]$PrivacyUrl = '',

        [Parameter()]
        [string]$InfoUrl = '',

        [Parameter()]
        [string]$InfoUrlText = '',

        [Parameter()]
        [byte[]]$Icon,

        [Parameter()]
        [string[]]$Tags
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    $namespace  = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $cimSession = $script:CMConnection.CimSession

    # ── Check for duplicate ──────────────────────────────────────────────────
    $existing = Get-CimInstance -CimSession $cimSession -Namespace $namespace `
        -ClassName SMS_Application -Filter "LocalizedDisplayName = '$Name' AND IsLatest = 1" -ErrorAction Stop
    if ($existing) {
        throw "An application with the name '$Name' already exists (CI_ID: $($existing.CI_ID))."
    }

    # ── Retrieve site AuthoringScopeId via SMS_Identification.GetSiteID() ───
    Write-Verbose "Retrieving site AuthoringScopeId via SMS_Identification.GetSiteID()"
    $siteIdResult = Invoke-CimMethod -CimSession $cimSession -Namespace $namespace `
        -ClassName SMS_Identification -MethodName GetSiteID -ErrorAction Stop
    if ($siteIdResult.ReturnValue -ne 0) {
        throw "SMS_Identification.GetSiteID() returned error code $($siteIdResult.ReturnValue)."
    }
    $appAuthoringScopeId = "ScopeId_$($siteIdResult.SiteID -replace '[{}]', '')"
    Write-Verbose "AuthoringScopeId: $appAuthoringScopeId"

    # ── Build unique identifiers and resource IDs ────────────────────────────
    $appLogicalName = "Application_$([guid]::NewGuid().ToString())"
    $titleResId     = "Res_$(Get-Random -Minimum 100000000 -Maximum 2147483647)"
    $descResId      = "Res_$(Get-Random -Minimum 100000000 -Maximum 2147483647)"
    $pubResId       = "Res_$(Get-Random -Minimum 100000000 -Maximum 2147483647)"
    $verResId       = "Res_$(Get-Random -Minimum 100000000 -Maximum 2147483647)"
    $releaseNoteResId   = "Res_$(Get-Random -Minimum 100000000 -Maximum 2147483647)"
    $infoUrlResId       = "Res_$(Get-Random -Minimum 100000000 -Maximum 2147483647)"
    $privacyUrlResId    = "Res_$(Get-Random -Minimum 100000000 -Maximum 2147483647)"

    Write-Verbose "Application LogicalName: $appLogicalName"

    # ── XML-encode all user-supplied strings ────────────────────────────────
    $xmlName           = [System.Security.SecurityElement]::Escape($Name)
    $xmlPublisher      = [System.Security.SecurityElement]::Escape($Publisher)
    $xmlVersion        = [System.Security.SecurityElement]::Escape($SoftwareVersion)
    $xmlDescription    = [System.Security.SecurityElement]::Escape($Description)
    $xmlOwner          = [System.Security.SecurityElement]::Escape($Owner)
    $xmlSupportContact = [System.Security.SecurityElement]::Escape($SupportContact)
    $xmlPrivacyUrl     = [System.Security.SecurityElement]::Escape($PrivacyUrl)
    foreach ($tag in $Tags) {
        $tag = [System.Security.SecurityElement]::Escape($tag)
    }

    # InformationUrl takes precedence over SupportUrl as the InformativeURL
    $xmlInfoUrl       = [System.Security.SecurityElement]::Escape($InfoUrl)
    $xmlInfoUrlText   = [System.Security.SecurityElement]::Escape($InfoUrlText)

    # ── Build optional XML blocks ────────────────────────────────────────────
    $descriptionXml  = if ($Description)       { "<Description>$xmlDescription</Description>" }         else { '' }
    $infoUrlXml      = if ($InfoUrl)           { "<InfoUrl>$xmlInfoUrl</InfoUrl>" }                     else { '' }
    $infoUrlTextXml  = if ($InfoUrlText)       { "<InfoUrlText>$xmlInfoUrlText</InfoUrlText>" }         else { '' }
    $privacyUrlXml   = if ($PrivacyUrl)        { "<PrivacyUrl>$xmlPrivacyUrl</PrivacyUrl>" }            else { '' }
    $tagsXml         = if ($Tags -and $Tags.Count -gt 0) { '<Tags>' + ($Tags | ForEach-Object { "<Tag>$_</Tag>" }) + '</Tags>' } else { '' }

    $ownersXml = if ($Owner) {
        "<Owners><User Qualifier=`"LogonName`" Id=`"$xmlOwner`"/></Owners>"
    } else {
        '<Owners />'
    }
    $contactsXml = if ($SupportContact) {
        "<Contacts><User Qualifier=`"LogonName`" Id=`"$xmlSupportContact`"/></Contacts>"
    } else {
        '<Contacts />'
    }

    $autoInstallStr = if ($AutoInstall) { 'true' } else { 'false' }

    # ── Build SDMPackageXML ──────────────────────────────────────────────────
    # IMPORTANT:
    #   - The '<?xml version="1.0" encoding="utf-16"?>' declaration is REQUIRED.
    #     Without it the SMS Provider rejects the instance (HRESULT 0x80041001).
    #   - <Publisher ResourceId=...> and <SoftwareVersion ResourceId=...> must be
    #     present as siblings of <Title ResourceId=...> inside <Application>.
    #   - <AutoInstall> is a required element (use "false" for the default).
    $sdmXml = (
        '<?xml version="1.0" encoding="utf-16"?>' +
        '<AppMgmtDigest' +
            ' xmlns="http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest"' +
            ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' +
        '<Application' +
            " AuthoringScopeId=`"$appAuthoringScopeId`"" +
            " LogicalName=`"$appLogicalName`"" +
            ' Version="1">' +
            '<DisplayInfo DefaultLanguage="en-US">' +
                '<Info Language="en-US">' +
                    "<Title>$xmlName</Title>" +
                    $descriptionXml +
                    "<Publisher>$xmlPublisher</Publisher>" +
                    "<Version>$xmlVersion</Version>" +
                    $infoUrlXml +
                    $infoUrlTextXml +
                    $privacyUrlXml +
                    $tagsXml +
                '</Info>' +
            '</DisplayInfo>' +
            '<DeploymentTypes />' +
            "<Title ResourceId=`"$titleResId`">$xmlName</Title>" +
            "<Publisher ResourceId=`"$pubResId`">$xmlPublisher</Publisher>" +
            "<SoftwareVersion ResourceId=`"$verResId`">$xmlVersion</SoftwareVersion>" +
            "<AutoInstall>$autoInstallStr</AutoInstall>" +
            $ownersXml +
            $contactsXml +
        '</Application>' +
        '</AppMgmtDigest>'
    )

    Write-Verbose "Constructed SDMPackageXML:"
    Write-Verbose $sdmXml
    Write-Verbose "SDMPackageXML length: $($sdmXml.Length) chars"

    # ── Build WMI property set ───────────────────────────────────────────────
    # SMS_Application accepts SDMPackageXML on creation.
    # IsEnabled and IsHidden are also writable at creation time.
    $appProps = @{
        SDMPackageXML = $sdmXml
    }

    # Only include IsEnabled/IsHidden when they differ from the WMI defaults (enabled=true, hidden=false)
    if (-not $IsEnabled) { $appProps['IsEnabled'] = $false }
    if ($IsHidden)        { $appProps['IsHidden']  = $true  }

    # ── Create the SMS_Application instance ─────────────────────────────────
    try {
        Write-Verbose "Creating application '$Name'"
        $newApp = New-CimInstance -CimSession $cimSession -Namespace $namespace `
            -ClassName SMS_Application -Property $appProps -ErrorAction Stop

        if (-not $newApp) {
            throw "New-CimInstance returned null. Application was not created."
        }

        $appId = $newApp.CI_ID
        Write-Verbose "Application '$Name' created with CI_ID: $appId"

        # ── Set EffectiveDate (ReleaseDate) if supplied ──────────────────────
        if ($PSBoundParameters.ContainsKey('ReleaseDate')) {
            Write-Verbose "Setting ReleaseDate (EffectiveDate) to $ReleaseDate"
            Set-CimInstance -CimSession $cimSession -Namespace $namespace `
                -Query "SELECT * FROM SMS_Application WHERE CI_ID = $appId AND IsLatest = 1" `
                -Property @{ EffectiveDate = $ReleaseDate } -ErrorAction SilentlyContinue
        }

        # ── Retrieve the full application object to return ───────────────────
        Write-Verbose "Retrieving created application (CI_ID=$appId)"
        $result = Get-CimInstance -CimSession $cimSession -Namespace $namespace `
            -Query "SELECT * FROM SMS_Application WHERE CI_ID = $appId"

        if ($result) {
            $output = [PSCustomObject]@{
                PSTypeName              = 'MECM7.Application'
                CI_ID                   = [int]$result.CI_ID
                CI_UniqueID             = $result.CI_UniqueID
                LocalizedDisplayName    = $result.LocalizedDisplayName
                LocalizedDescription    = $result.LocalizedDescription
                Manufacturer            = $result.Manufacturer
                SoftwareVersion         = $result.SoftwareVersion
                IsEnabled               = [bool]$result.IsEnabled
                IsHidden                = [bool]$result.IsHidden
                IsDeployed              = [bool]$result.IsDeployed
                IsExpired               = [bool]$result.IsExpired
                IsLatest                = [bool]$result.IsLatest
                DateCreated             = $result.DateCreated
                DateLastModified        = $result.DateLastModified
                NumberOfDeploymentTypes = [int]$result.NumberOfDeploymentTypes
                NumberOfDeployments     = [int]$result.NumberOfDeployments
            }

            $output.PSObject.TypeNames.Insert(0, 'MECM7.Application')

            # Attach any additional properties not already present
            $result.CimInstanceProperties | ForEach-Object {
                if ($_.Name -notin $output.PSObject.Properties.Name) {
                    $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                }
            }

            Write-Output $output
        } else {
            Write-Warning "Application was created (CI_ID: $appId) but could not be retrieved afterwards."
        }
    }
    catch {
        throw $_
    }
}
function New-CM7Boundary {
    <#
        .SYNOPSIS
            Creates a new boundary in MECM using CIM.

        .DESCRIPTION
            Creates a new boundary (SMS_Boundary) in Microsoft Endpoint Configuration Manager (MECM) using CIM.
            Supports creation of boundaries by Name, BoundaryType, and Value. Requires an active connection via Connect-CM7.
            This is the CIM-based equivalent of the New-CMBoundary cmdlet from the ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

        .PARAMETER Name
            The name of the boundary to create. Must be unique within the MECM environment.

        .PARAMETER BoundaryType
            The type of the boundary. Valid values are: 0 (IP Subnet), 1 (Active Directory Site), 2 (IPv6 Prefix), 3 (IP Address Range).

        .PARAMETER Value
            The value of the boundary (e.g., subnet, AD site name, IP range).

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7Boundary -Name "TestSubnet" -BoundaryType 0 -Value "192.168.1.0"
            Creates a new IP Subnet boundary named "TestSubnet".

        .EXAMPLE
            New-CM7Boundary -Name "TestRange" -BoundaryType 3 -Value "192.168.2.1-192.168.3.255"
            Creates a new IP Address Range boundary named "TestRange".

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_Boundary WMI class is used to represent boundaries in MECM.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateSet('IPSubnet', 'ADSite', 'IPv6Prefix', 'IPRange')]
        [Alias('Type')]
        [object]$BoundaryType,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]$Value,

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
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # verify Value Input based on BoundaryType
        switch ($BoundaryType) {
            'IPSubnet' {
                if ($Value -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
                    throw "Invalid Value for IPSubnet. Expected format: '192.168.1.0'"
                }
            }
            'ADSite' {
                if (-not $Value) {
                    throw "Invalid Value for ADSite. Expected a non-empty string."
                }
            }
            'IPv6Prefix' {
                if ($Value -notmatch '^[0-9a-fA-F:]+$') {
                    throw "Invalid Value for IPv6Prefix. Expected format: '2001:0db8::/32'"
                }
            }
            'IPRange' {
                if ($Value -notmatch '^\d{1,3}(\.\d{1,3}){3}-\d{1,3}(\.\d{1,3}){3}$') {
                    throw "Invalid Value for IPRange. Expected format: '192.168.1.1-192.168.1.255'"
                }
            }
        }

    }

    process {
        try {
            # Check for duplicate boundary name
            $existingQuery = "SELECT BoundaryID, DisplayName FROM SMS_Boundary WHERE DisplayName = '$Name'"
            $existingBoundary = Get-CimInstance @cimParams -Query $existingQuery
            if ($existingBoundary) {
                throw "A boundary with name '$Name' already exists (BoundaryID: $($existingBoundary.BoundaryID))."
            }

            # Map string to integer if needed
            $typeMap = @{
                'IPSubnet'   = 0
                'ADSite'     = 1
                'IPv6Prefix' = 2
                'IPRange'    = 3
            }
            $boundaryTypeInt = $typeMap."$BoundaryType" -as [int]
            if ($null -eq $boundaryTypeInt -or $boundaryTypeInt -notin 0,1,2,3) {
                throw "Invalid BoundaryType. Use one of: IPSubnet, ADSite, IPv6Prefix, IPRange, or 0-3."
            }

            $boundaryProps = @{
                DisplayName  = $Name
                BoundaryType = $boundaryTypeInt
                Value        = $Value
            }

            $actionDescription = "Create boundary '$Name' of type $boundaryTypeInt with value '$Value'"
            if ($Force -or $PSCmdlet.ShouldProcess($Name, $actionDescription)) {
                $newBoundary = New-CimInstance @cimParams -ClassName 'SMS_Boundary' -Property $boundaryProps
                if (-not $newBoundary) {
                    throw "Failed to create boundary '$Name'. New-CimInstance returned null."
                }
                $boundaryId = $newBoundary.BoundaryID
                $resultQuery = "SELECT * FROM SMS_Boundary WHERE BoundaryID = $boundaryId"
                $result = Get-CimInstance @cimParams -Query $resultQuery
                if ($result) {
                    $output = [PSCustomObject]@{
                        PSTypeName     = 'MECM7.Boundary'
                        BoundaryID     = [int]$result.BoundaryID
                        DisplayName    = $result.DisplayName
                        BoundaryType   = [int]$result.BoundaryType
                        Value          = $result.Value
                        Description    = $result.Description
                    }
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.Boundary')
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }
                    Write-Output $output
                } else {
                    Write-Warning "Boundary was created but could not retrieve the result. BoundaryID: $boundaryId"
                }
            }
        } catch {
            throw $_
        }
    }
}
function New-CM7BoundaryGroup {
    <#
        .SYNOPSIS
            Creates a new boundary group in MECM using CIM.

        .DESCRIPTION
            Creates a new boundary group (SMS_BoundaryGroup) in Microsoft Endpoint Configuration Manager
            (MECM) using CIM. Supports setting a name, description, default site code for automatic site
            assignment, and optionally associating site system servers.
            Requires an active connection via Connect-CM7.

            This is the CIM-based equivalent of the New-CMBoundaryGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

        .PARAMETER Name
            The name of the new boundary group. Must be unique within the MECM environment. (Mandatory)

        .PARAMETER Description
            An optional description for the new boundary group.

        .PARAMETER DefaultSiteCode
            The default site code to use for automatic site assignment for clients in this boundary group.

        .PARAMETER AddSiteSystemServerName
            One or more site system server fully qualified domain names (FQDNs) to associate with the
            new boundary group. These servers will be added as site system references for the group.
            Alias: AddSiteSystemServerNames

        .PARAMETER DisableWildcardHandling
            Treats wildcard characters as literal character values.
            Cannot be combined with ForceWildcardHandling.

        .PARAMETER ForceWildcardHandling
            Forces wildcard character processing even in contexts where it is not normally supported.
            May lead to unexpected behavior (not recommended).
            Cannot be combined with DisableWildcardHandling.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7BoundaryGroup -Name "Test"
            Creates a new boundary group named "Test".

        .EXAMPLE
            New-CM7BoundaryGroup -Name "BGroup05" -Description "My boundary group" -DefaultSiteCode "PS1"
            Creates a new boundary group with a description and default site code.

        .EXAMPLE
            New-CM7BoundaryGroup -Name "BGroup06" -AddSiteSystemServerName "server01.contoso.com" -Force
            Creates a boundary group and associates a site system server without prompting for confirmation.

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
            Site system server associations are stored in the SMS_BoundaryGroupSiteSystems WMI class.
            For more information on return object properties, see SMS_BoundaryGroup server WMI class:
            https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [string]$DefaultSiteCode,

        [Parameter()]
        [Alias('AddSiteSystemServerNames')]
        [string[]]$AddSiteSystemServerName,

        [Parameter()]
        [switch]$DisableWildcardHandling,

        [Parameter()]
        [switch]$ForceWildcardHandling,

        [Parameter()]
        [switch]$Force
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        # Validate mutually exclusive wildcard parameters
        if ($DisableWildcardHandling -and $ForceWildcardHandling) {
            throw "DisableWildcardHandling and ForceWildcardHandling cannot be used together."
        }

        # Validate connection
        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            # Check for duplicate boundary group name
            $existingQuery = "SELECT GroupID, Name FROM SMS_BoundaryGroup WHERE Name = '$Name'"
            $existingGroup = Get-CimInstance @cimParams -Query $existingQuery
            if ($existingGroup) {
                throw "A boundary group with name '$Name' already exists (GroupID: $($existingGroup.GroupID))."
            }

            # Build the properties hashtable for the new boundary group
            $groupProps = @{
                Name = $Name
            }

            if ($PSBoundParameters.ContainsKey('Description')) {
                $groupProps['Description'] = $Description
            }

            if ($PSBoundParameters.ContainsKey('DefaultSiteCode')) {
                $groupProps['DefaultSiteCode'] = $DefaultSiteCode
            }

            $actionDescription = "Create boundary group '$Name'"
            if ($Force -or $PSCmdlet.ShouldProcess($Name, $actionDescription)) {

                # Create the boundary group
                $newGroup = New-CimInstance @cimParams -ClassName 'SMS_BoundaryGroup' -Property $groupProps
                if (-not $newGroup) {
                    throw "Failed to create boundary group '$Name'. New-CimInstance returned null."
                }

                $groupId = $newGroup.GroupID

                # Associate site system servers if provided, using the AddSiteSystem instance method
                if ($AddSiteSystemServerName -and $AddSiteSystemServerName.Count -gt 0) {
                    try {
                        # Build parallel NAL path and Flags arrays required by AddSiteSystem
                        $nalPaths = $AddSiteSystemServerName | ForEach-Object {
                            "[`"Display=\\$_\`"]MSWNET:[`"SMS_SITE=$($script:CMConnection.SiteCode)`"]\\$_\"
                        }
                        $flags = [uint32[]](@(0) * $AddSiteSystemServerName.Count)

                        Write-Verbose "Calling AddSiteSystem on boundary group '$Name' (GroupID: $groupId) for $($AddSiteSystemServerName.Count) server(s)"

                        # Retrieve the CIM instance to invoke the method on
                        $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"
                        $methodResult  = Invoke-CimMethod -InputObject $groupInstance -MethodName 'AddSiteSystem' -Arguments @{
                            ServerNALPath = [string[]]$nalPaths
                            Flags         = $flags
                        }
                        if ($methodResult.ReturnValue -ne 0) {
                            Write-Warning "AddSiteSystem returned non-zero exit code $($methodResult.ReturnValue) for boundary group '$Name'."
                        }
                    } catch {
                        Write-Warning "Could not associate site system server(s) with boundary group '$Name': $_"
                    }
                }

                # Retrieve the created boundary group to return full object
                $resultQuery = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"
                $result = Get-CimInstance @cimParams -Query $resultQuery

                if ($result) {
                    $output = [PSCustomObject]@{
                        PSTypeName      = 'MECM7.BoundaryGroup'
                        GroupID         = [int]$result.GroupID
                        Name            = $result.Name
                        Description     = $result.Description
                        DefaultSiteCode = $result.DefaultSiteCode
                        MemberCount     = $result.MemberCount
                    }
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.BoundaryGroup')
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }
                    Write-Output $output
                } else {
                    Write-Warning "Boundary group was created but could not retrieve the result. GroupID: $groupId"
                }
            }
        } catch {
            throw $_
        }
    }
}
function New-CM7Collection {
    <#
        .SYNOPSIS
            Creates a new MECM collection using CIM.

        .DESCRIPTION
            Creates a new device or user collection in Microsoft Endpoint Configuration Manager
            (MECM) using CIM. This function creates an instance of the SMS_Collection class
            via CIM and optionally moves it to a specified folder.

            This is the CIM-based equivalent of the New-CMCollection / New-CMDeviceCollection /
            New-CMUserCollection cmdlets from the ConfigurationManager PowerShell module.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the limiting collection (by name or ID)
            3. Creates a new SMS_Collection instance via CIM
            4. Optionally moves the new collection to a specified folder path

        .PARAMETER Name
            The name of the new collection. Must be unique within the MECM environment.

        .PARAMETER CollectionType
            The type of collection to create. Valid values are 'Device' or 'User'.
            Defaults to 'Device'.

        .PARAMETER LimitingCollectionId
            The CollectionID of the limiting collection. A limiting collection defines the
            scope of devices or users that can be members of the new collection.
            Mutually exclusive with LimitingCollectionName.

        .PARAMETER LimitingCollectionName
            The name of the limiting collection. A limiting collection defines the
            scope of devices or users that can be members of the new collection.
            Mutually exclusive with LimitingCollectionId.

        .PARAMETER Comment
            An optional comment or description for the new collection.

        .PARAMETER RefreshType
            Specifies the collection membership refresh type. Valid values are:
            - 'Manual'     (1) - No automatic refresh; membership is only updated manually.
            - 'Periodic'   (2) - Membership is refreshed on a schedule.
            - 'Continuous'  (4) - Membership is updated continuously (incremental updates).
            - 'Both'       (6) - Combination of Periodic and Continuous.
            Defaults to 'Manual'.

        .PARAMETER RefreshSchedule
            A hashtable defining the periodic refresh schedule. Only applicable when RefreshType
            includes 'Periodic'. The hashtable can contain the following keys:
            - DaySpan     : Number of days between refreshes (e.g., 1 for daily)
            - HourSpan    : Number of hours between refreshes
            - MinuteSpan  : Number of minutes between refreshes
            - StartTime   : The start time for the schedule (ISO 8601 format string or DateTime)

        .PARAMETER FolderPath
            An optional folder path in MECM format to move the new collection to after creation.
            Format: SiteCode:\ObjectType\Folder[\SubFolder\...]
            For example: CM1:\DeviceCollection\TestCollections\Test
            Uses Move-CM7Object internally to perform the move.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7Collection -Name "My Device Collection" -LimitingCollectionId "SMS00001"
            Creates a new device collection named "My Device Collection" limited to "All Systems".

        .EXAMPLE
            New-CM7Collection -Name "My Device Collection" -LimitingCollectionName "All Systems"
            Creates a new device collection using the limiting collection name instead of ID.

        .EXAMPLE
            New-CM7Collection -Name "My User Collection" -CollectionType User -LimitingCollectionId "SMS00002"
            Creates a new user collection limited to "All Users".

        .EXAMPLE
            New-CM7Collection -Name "Auto-Refresh Collection" -LimitingCollectionId "SMS00001" -RefreshType Periodic -RefreshSchedule @{ DaySpan = 1 }
            Creates a device collection with a daily periodic refresh schedule.

        .EXAMPLE
            New-CM7Collection -Name "Incremental Collection" -LimitingCollectionId "SMS00001" -RefreshType Both
            Creates a device collection with both periodic and continuous (incremental) refresh.

        .EXAMPLE
            New-CM7Collection -Name "My Collection" -LimitingCollectionId "SMS00001" -Comment "Created by automation"
            Creates a device collection with a descriptive comment.

        .EXAMPLE
            New-CM7Collection -Name "My Collection" -LimitingCollectionId "SMS00001" -FolderPath "CM1:\DeviceCollection\TestCollections"
            Creates a device collection and moves it to the TestCollections folder.

        .EXAMPLE
            New-CM7Collection -Name "My Collection" -LimitingCollectionId "SMS00001" -WhatIf
            Shows what would happen without actually creating the collection.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByLimitingId')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('Device', 'User')]
        [string]$CollectionType = 'Device',

        [Parameter(ParameterSetName = 'ByLimitingId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LimitingCollectionId,

        [Parameter(ParameterSetName = 'ByLimitingName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LimitingCollectionName,

        [Parameter()]
        [string]$Comment,

        [Parameter()]
        [ValidateSet('Manual', 'Periodic', 'Continuous', 'Both')]
        [string]$RefreshType = 'Manual',

        [Parameter()]
        [hashtable]$RefreshSchedule,

        [Parameter()]
        [string]$FolderPath
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

        # RefreshType mapping
        $refreshTypeMap = @{
            'Manual'     = 1
            'Periodic'   = 2
            'Continuous' = 4
            'Both'       = 6
        }

        # CollectionType mapping
        $collectionTypeMap = @{
            'Device' = 2
            'User'   = 1
        }
    }

    process {
        try {
            # ---- Resolve Limiting Collection ----
            $resolvedLimitingCollectionId = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByLimitingId' {
                    # Validate that the limiting collection exists
                    $limitingQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$LimitingCollectionId'"
                    Write-Verbose "Validating limiting collection: $limitingQuery"
                    $limitingCollection = Get-CimInstance @cimParams -Query $limitingQuery

                    if (-not $limitingCollection) {
                        throw "Limiting collection with ID '$LimitingCollectionId' was not found."
                    }

                    $resolvedLimitingCollectionId = $LimitingCollectionId
                    Write-Verbose "Limiting collection resolved: '$($limitingCollection.Name)' ($LimitingCollectionId)"
                }
                'ByLimitingName' {
                    # Look up the limiting collection by name
                    $limitingQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$LimitingCollectionName'"
                    Write-Verbose "Looking up limiting collection: $limitingQuery"
                    $limitingCollection = Get-CimInstance @cimParams -Query $limitingQuery

                    if (-not $limitingCollection) {
                        throw "Limiting collection with name '$LimitingCollectionName' was not found."
                    }

                    if (@($limitingCollection).Count -gt 1) {
                        throw "Multiple limiting collections found with name '$LimitingCollectionName'. Please use -LimitingCollectionId instead."
                    }

                    $resolvedLimitingCollectionId = $limitingCollection.CollectionID
                    Write-Verbose "Limiting collection resolved: '$LimitingCollectionName' ($resolvedLimitingCollectionId)"
                }
            }

            # ---- Check for duplicate collection name ----
            $existingQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$Name'"
            Write-Verbose "Checking for existing collection: $existingQuery"
            $existingCollection = Get-CimInstance @cimParams -Query $existingQuery

            if ($existingCollection) {
                throw "A collection with name '$Name' already exists (CollectionID: $($existingCollection.CollectionID))."
            }

            # ---- Build the refresh schedule ----
            $refreshScheduleInstance = $null
            if ($RefreshSchedule -and $RefreshType -in @('Periodic', 'Both')) {
                Write-Verbose "Building refresh schedule"

                # Create an SMS_ST_RecurInterval embedded instance
                $scheduleProperties = @{}

                if ($RefreshSchedule.ContainsKey('DaySpan')) {
                    $scheduleProperties['DaySpan'] = [uint32]$RefreshSchedule.DaySpan
                }
                if ($RefreshSchedule.ContainsKey('HourSpan')) {
                    $scheduleProperties['HourSpan'] = [uint32]$RefreshSchedule.HourSpan
                }
                if ($RefreshSchedule.ContainsKey('MinuteSpan')) {
                    $scheduleProperties['MinuteSpan'] = [uint32]$RefreshSchedule.MinuteSpan
                }
                if ($RefreshSchedule.ContainsKey('StartTime')) {
                    $startTime = $RefreshSchedule.StartTime
                    if ($startTime -is [string]) {
                        $startTime = [datetime]::Parse($startTime)
                    }
                    $scheduleProperties['StartTime'] = $startTime
                } else {
                    $scheduleProperties['StartTime'] = [datetime]::UtcNow
                }

                # Ensure at least one interval is set
                if (-not ($scheduleProperties.ContainsKey('DaySpan') -or $scheduleProperties.ContainsKey('HourSpan') -or $scheduleProperties.ContainsKey('MinuteSpan'))) {
                    $scheduleProperties['DaySpan'] = [uint32]7  # Default to weekly
                }

                $refreshScheduleInstance = New-CimInstance @cimParams -ClassName 'SMS_ST_RecurInterval' -Property $scheduleProperties -ClientOnly
                Write-Verbose "Refresh schedule created: DaySpan=$($scheduleProperties['DaySpan']), HourSpan=$($scheduleProperties['HourSpan']), MinuteSpan=$($scheduleProperties['MinuteSpan'])"
            }

            # ---- Create the collection ----
            $collectionTypeNumeric = $collectionTypeMap[$CollectionType]
            $refreshTypeNumeric = $refreshTypeMap[$RefreshType]

            $actionDescription = "Create $CollectionType collection '$Name' (LimitingCollection: $resolvedLimitingCollectionId, RefreshType: $RefreshType)"
            if ($PSCmdlet.ShouldProcess($Name, $actionDescription)) {
                Write-Verbose "Creating collection: $actionDescription"

                # Build the properties for the new collection
                $collectionProperties = @{
                    Name                   = $Name
                    CollectionType         = [uint32]$collectionTypeNumeric
                    LimitToCollectionID    = $resolvedLimitingCollectionId
                    RefreshType            = [uint32]$refreshTypeNumeric
                }

                if ($Comment) {
                    $collectionProperties['Comment'] = $Comment
                }

                if ($refreshScheduleInstance) {
                    $collectionProperties['RefreshSchedule'] = [CimInstance[]]@($refreshScheduleInstance)
                }

                Write-Verbose "Collection properties: $($collectionProperties | ConvertTo-Json -Depth 3 -Compress)"

                # Create the collection using New-CimInstance
                $newCollection = New-CimInstance @cimParams -ClassName 'SMS_Collection' -Property $collectionProperties

                if (-not $newCollection) {
                    throw "Failed to create collection '$Name'. New-CimInstance returned null."
                }

                $collectionId = $newCollection.CollectionID
                Write-Verbose "Collection '$Name' created successfully with CollectionID: $collectionId"

                # ---- Move to folder if FolderPath specified ----
                if ($FolderPath) {
                    Write-Verbose "Moving new collection '$collectionId' to folder: $FolderPath"
                    try {
                        Move-CM7Object -ObjectId $collectionId -FolderPath $FolderPath -Force | Out-Null
                        Write-Verbose "Collection '$collectionId' moved to '$FolderPath' successfully."
                    }
                    catch {
                        Write-Warning "Collection '$Name' ($collectionId) was created successfully, but failed to move to '$FolderPath': $_"
                    }
                }

                # ---- Retrieve the full collection object to return ----
                $resultQuery = "SELECT * FROM SMS_Collection WHERE CollectionID = '$collectionId'"
                Write-Verbose "Retrieving created collection: $resultQuery"
                $result = Get-CimInstance @cimParams -Query $resultQuery

                if ($result) {
                    # Map collection type number to friendly name
                    $typeDisplay = switch ($result.CollectionType) {
                        1 { 'User' }
                        2 { 'Device' }
                        default { 'Unknown' }
                    }

                    # Create a custom object with commonly used properties
                    $output = [PSCustomObject]@{
                        PSTypeName            = 'MECM7.Collection'
                        CollectionId          = $result.CollectionID
                        Name                  = $result.Name
                        CollectionType        = $typeDisplay
                        TypeValue             = $result.CollectionType
                        LimitToCollectionID   = $result.LimitToCollectionID
                        LimitToCollectionName = $result.LimitToCollectionName
                        MemberCount           = $result.MemberCount
                        Comment               = $result.Comment
                        RefreshType           = $result.RefreshType
                        LastRefreshTime       = $result.LastRefreshTime
                        LastChangeTime        = $result.LastChangeTime
                        OwnedByThisSite       = $result.OwnedByThisSite
                    }

                    $output.PSObject.TypeNames.Insert(0, 'MECM7.Collection')

                    # Add all extra properties
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }

                    Write-Output $output
                } else {
                    Write-Warning "Collection was created but could not retrieve the result. CollectionID: $collectionId"
                }
            }
        }
        catch {
            throw $_
        }
    }
}
function New-CM7DeviceCollectionVariable {
    <#
        .SYNOPSIS
            Creates a new collection variable on a MECM device collection using CIM.

        .DESCRIPTION
            Creates a new collection variable (name-value pair) on a specified device collection in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. Collection variables are
            stored in the SMS_CollectionSettings WMI class and can be used during task sequence
            execution and other MECM operations.

            This is the CIM-based equivalent of the New-CMDeviceCollectionVariable cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the collection (by name or ID)
            3. Retrieves existing SMS_CollectionSettings (or creates new settings if none exist)
            4. If a variable with the same name already exists, it is overwritten
            5. Creates and appends (or replaces) the SMS_CollectionVariable embedded instance
            6. Writes the updated settings back via CIM

        .PARAMETER CollectionName
            Specifies the name of the device collection to add the variable to.
            Mutually exclusive with CollectionId.

        .PARAMETER CollectionId
            Specifies the CollectionID of the device collection to add the variable to.
            Mutually exclusive with CollectionName.

        .PARAMETER VariableName
            Specifies the name of the variable to create or overwrite. Variable names must not
            contain spaces. If a variable with the same name already exists, its value and
            IsMasked setting will be overwritten.

        .PARAMETER Value
            Specifies the value of the variable. Can be an empty string.

        .PARAMETER IsMasked
            Specifies whether the variable value should be masked (hidden) in the MECM console.
            When set to $true, the value is obscured in the UI. Defaults to $false.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "OSDComputerName" -Value "WKS-001"
            Creates a new collection variable named "OSDComputerName" with value "WKS-001" on the specified collection.

        .EXAMPLE
            New-CM7DeviceCollectionVariable -CollectionId "CM101C00" -VariableName "InstallSoftware" -Value "True"
            Creates a new collection variable on the collection identified by its CollectionID.

        .EXAMPLE
            New-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "SecretKey" -Value "P@ssw0rd!" -IsMasked
            Creates a masked (hidden) collection variable. The value will be obscured in the MECM console.

        .EXAMPLE
            New-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "EmptyVar" -Value ""
            Creates a collection variable with an empty value.

        .NOTES
            This function is the CIM-based equivalent of the New-CMDeviceCollectionVariable cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The CollectionVariables property of SMS_CollectionSettings is a lazy property,
            so the function retrieves the full instance to access it.

            If the collection has no existing SMS_CollectionSettings, the function creates
            a new settings instance before adding the variable.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByCollectionName')]
    param(
        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VariableName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter()]
        [switch]$IsMasked,

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

        # Validate variable name format (PowerShell 5.1-compatible custom message)
        if ($VariableName -match '\s') {
            throw "Variable name must not contain spaces."
        }

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build common CIM parameters
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            # ---- Resolve Collection ----
            $collectionIdToUse = $null
            $collectionDisplayName = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByCollectionName' {
                    $collectionQuery = "SELECT CollectionID, Name, CollectionType FROM SMS_Collection WHERE Name = '$CollectionName'"
                    Write-Verbose "Resolving collection name: $collectionQuery"
                    $collection = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collection) {
                        throw "Collection '$CollectionName' not found."
                    }

                    if (@($collection).Count -gt 1) {
                        throw "Multiple collections found with name '$CollectionName'. Please use -CollectionId instead."
                    }

                    # Verify it is a device collection (CollectionType = 2)
                    if ($collection.CollectionType -ne 2) {
                        throw "Collection '$CollectionName' is not a device collection. This function only supports device collections."
                    }

                    $collectionIdToUse = $collection.CollectionID
                    $collectionDisplayName = $CollectionName
                    Write-Verbose "Resolved collection '$CollectionName' to ID '$collectionIdToUse'"
                }
                'ByCollectionId' {
                    # Validate collection exists and is a device collection
                    $collectionQuery = "SELECT CollectionID, Name, CollectionType FROM SMS_Collection WHERE CollectionID = '$CollectionId'"
                    Write-Verbose "Validating collection: $collectionQuery"
                    $collection = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collection) {
                        throw "Collection with ID '$CollectionId' not found."
                    }

                    if ($collection.CollectionType -ne 2) {
                        throw "Collection '$CollectionId' is not a device collection. This function only supports device collections."
                    }

                    $collectionIdToUse = $CollectionId
                    $collectionDisplayName = $collection.Name
                    Write-Verbose "Collection '$collectionDisplayName' ($CollectionId) validated."
                }
            }

            # ---- Retrieve or Create SMS_CollectionSettings ----
            $settingsQuery = "SELECT * FROM SMS_CollectionSettings WHERE CollectionID = '$collectionIdToUse'"
            Write-Verbose "Querying collection settings: $settingsQuery"
            $settings = Get-CimInstance @cimParams -Query $settingsQuery

            $isNewSettings = $false

            if ($settings) {
                # Retrieve full instance to load lazy properties (CollectionVariables)
                Write-Verbose "Retrieving full instance to load lazy property CollectionVariables..."
                $fullSettings = $settings | Get-CimInstance

                if (-not $fullSettings) {
                    throw "Could not retrieve full collection settings for CollectionID '$collectionIdToUse'."
                }
            }
            else {
                Write-Verbose "No existing SMS_CollectionSettings found for CollectionID '$collectionIdToUse'. Will create new settings."
                $isNewSettings = $true
                $fullSettings = $null
            }

            # ---- Get existing variables ----
            $existingVariables = @()
            if ($fullSettings -and $fullSettings.CollectionVariables) {
                $existingVariables = @($fullSettings.CollectionVariables)
            }

            # ---- Check for duplicate variable name ----
            $duplicateVar = $existingVariables | Where-Object { $_.Name -eq $VariableName }
            if ($duplicateVar) {
                Write-Verbose "A variable named '$VariableName' already exists on collection '$collectionDisplayName' ($collectionIdToUse). It will be overwritten."
            }

            # ---- Build the new variable ----
            Write-Verbose "Creating new collection variable: Name='$VariableName', IsMasked=$($IsMasked.IsPresent)"

            $variableClass = Get-CimClass -CimSession $script:CMConnection.CimSession -Namespace $namespace -ClassName 'SMS_CollectionVariable'
            $newVariable = New-CimInstance -CimClass $variableClass -ClientOnly -Property @{
                Name     = $VariableName
                Value    = $Value
                IsMasked = [bool]$IsMasked.IsPresent
            }

            # ---- Build updated variables list (replace if duplicate, append if new) ----
            $updatedVariables = [System.Collections.Generic.List[CimInstance]]::new()
            foreach ($v in $existingVariables) {
                if ($v.Name -eq $VariableName) {
                    # Replace existing variable with new one
                    $updatedVariables.Add($newVariable)
                } else {
                    $updatedVariables.Add($v)
                }
            }
            if (-not $duplicateVar) {
                $updatedVariables.Add($newVariable)
            }

            # ---- ShouldProcess ----
            $maskedDisplay = if ($IsMasked.IsPresent) { " (masked)" } else { "" }
            $actionDescription = "Create variable '$VariableName' = '$( if ($IsMasked.IsPresent) { '********' } else { $Value } )'$maskedDisplay on collection '$collectionDisplayName' ($collectionIdToUse)"

            if ($Force -or $PSCmdlet.ShouldProcess($actionDescription, "New-CM7DeviceCollectionVariable")) {

                if ($isNewSettings) {
                    # SDK pattern: first create SMS_CollectionSettings with just CollectionID, then
                    # re-retrieve, modify CollectionVariables, and Put_ again.
                    # See: https://learn.microsoft.com/en-us/intune/configmgr/develop/osd/how-to-create-a-collection-variable
                    Write-Verbose "Creating new SMS_CollectionSettings for CollectionID '$collectionIdToUse'..."

                    $null = New-CimInstance @cimParams -ClassName 'SMS_CollectionSettings' -Property @{
                        CollectionID = $collectionIdToUse
                    }

                    # Re-retrieve the full instance (loads lazy properties)
                    Write-Verbose "Re-retrieving newly created SMS_CollectionSettings..."
                    $fullSettings = Get-CimInstance @cimParams -ClassName 'SMS_CollectionSettings' -Filter "CollectionID = '$collectionIdToUse'" |
                        Get-CimInstance

                    if (-not $fullSettings) {
                        throw "Failed to create or retrieve SMS_CollectionSettings for CollectionID '$collectionIdToUse'."
                    }
                }

                # Modify the CollectionVariables property directly on the CIM instance,
                # then call Set-CimInstance (equivalent of WMI Put_) to commit all properties.
                Write-Verbose "Updating SMS_CollectionSettings for CollectionID '$collectionIdToUse'..."
                $fullSettings.CimInstanceProperties['CollectionVariables'].Value = [CimInstance[]]$updatedVariables.ToArray()
                $fullSettings | Set-CimInstance

                Write-Verbose "Successfully saved SMS_CollectionSettings with variable '$VariableName'."

                # Return the created variable
                [PSCustomObject]@{
                    PSTypeName   = 'MECM7.CollectionVariable'
                    Name         = $VariableName
                    Value        = $Value
                    IsMasked     = $IsMasked.IsPresent
                    CollectionId = $collectionIdToUse
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
function New-CM7DeviceVariable {
    <#
        .SYNOPSIS
            Creates a new device variable on a MECM device using CIM.

        .DESCRIPTION
            Creates a new device variable (name-value pair) on a specified device in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. Device variables are
            stored in the SMS_MachineSettings WMI class and can be used during task sequence
            execution and other MECM operations.

            This is the CIM-based equivalent of the New-CMDeviceVariable cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the device (by name or ResourceId)
            3. Retrieves existing SMS_MachineSettings (or creates new settings if none exist)
            4. If a variable with the same name already exists, it is overwritten
            5. Creates and appends (or replaces) the SMS_MachineVariable embedded instance
            6. Writes the updated settings back via CIM

        .PARAMETER DeviceName
            Specifies the name of the device to add the variable to.
            Mutually exclusive with ResourceId.

        .PARAMETER ResourceId
            Specifies the ResourceID of the device to add the variable to.
            Mutually exclusive with DeviceName.

        .PARAMETER VariableName
            Specifies the name of the variable to create or overwrite. Variable names must not
            contain spaces. If a variable with the same name already exists, its value and
            IsMasked setting will be overwritten.

        .PARAMETER Value
            Specifies the value of the variable. Can be an empty string.

        .PARAMETER IsMasked
            Specifies whether the variable value should be masked (hidden) in the MECM console.
            When set to $true, the value is obscured in the UI. Defaults to $false.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "OSDComputerName" -Value "WKS-001"
            Creates a new device variable named "OSDComputerName" with value "WKS-001" on the specified device.

        .EXAMPLE
            New-CM7DeviceVariable -ResourceId 16893210 -VariableName "InstallSoftware" -Value "True"
            Creates a new device variable on the device identified by its ResourceID.

        .EXAMPLE
            New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "SecretKey" -Value "P@ssw0rd!" -IsMasked
            Creates a masked (hidden) device variable. The value will be obscured in the MECM console.

        .EXAMPLE
            New-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "EmptyVar" -Value ""
            Creates a device variable with an empty value.

        .NOTES
            This function is the CIM-based equivalent of the New-CMDeviceVariable cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The MachineVariables property of SMS_MachineSettings is a lazy property,
            so the function retrieves the full instance to access it.

            If the device has no existing SMS_MachineSettings, the function creates
            a new settings instance before adding the variable.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByDeviceName')]
    param(
        [Parameter(ParameterSetName = 'ByDeviceName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(ParameterSetName = 'ByResourceId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$ResourceId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\S+$')]
        [string]$VariableName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter()]
        [switch]$IsMasked,

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
    }

    process {
        try {
            # ---- Resolve Device ----
            $resourceIdToUse = $null
            $deviceDisplayName = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByDeviceName' {
                    $deviceQuery = "SELECT ResourceID, Name FROM SMS_R_System WHERE Name = '$DeviceName'"
                    Write-Verbose "Resolving device name: $deviceQuery"
                    $device = Get-CimInstance @cimParams -Query $deviceQuery

                    if (-not $device) {
                        throw "Device '$DeviceName' not found."
                    }

                    if (@($device).Count -gt 1) {
                        Write-Warning "Multiple devices found with name '$DeviceName'. Using the first match (ResourceID: $($device[0].ResourceID))."
                        $resourceIdToUse = $device[0].ResourceID
                    } else {
                        $resourceIdToUse = $device.ResourceID
                    }

                    $deviceDisplayName = $DeviceName
                    Write-Verbose "Resolved device '$DeviceName' to ResourceID '$resourceIdToUse'"
                }
                'ByResourceId' {
                    # Validate device exists
                    $deviceQuery = "SELECT ResourceID, Name FROM SMS_R_System WHERE ResourceID = $ResourceId"
                    Write-Verbose "Validating device: $deviceQuery"
                    $device = Get-CimInstance @cimParams -Query $deviceQuery

                    if (-not $device) {
                        throw "Device with ResourceID '$ResourceId' not found."
                    }

                    $resourceIdToUse = $ResourceId
                    $deviceDisplayName = $device.Name
                    Write-Verbose "Device '$deviceDisplayName' (ResourceID: $ResourceId) validated."
                }
            }

            # ---- Retrieve or Create SMS_MachineSettings ----
            $settingsQuery = "SELECT * FROM SMS_MachineSettings WHERE ResourceID = $resourceIdToUse"
            Write-Verbose "Querying machine settings: $settingsQuery"
            $settings = Get-CimInstance @cimParams -Query $settingsQuery

            $isNewSettings = $false

            if ($settings) {
                # Retrieve full instance to load lazy properties (MachineVariables)
                Write-Verbose "Retrieving full instance to load lazy property MachineVariables..."
                $fullSettings = $settings | Get-CimInstance

                if (-not $fullSettings) {
                    throw "Could not retrieve full machine settings for ResourceID '$resourceIdToUse'."
                }
            }
            else {
                Write-Verbose "No existing SMS_MachineSettings found for ResourceID '$resourceIdToUse'. Will create new settings."
                $isNewSettings = $true
                $fullSettings = $null
            }

            # ---- Get existing variables ----
            $existingVariables = @()
            if ($fullSettings -and $fullSettings.MachineVariables) {
                $existingVariables = @($fullSettings.MachineVariables)
            }

            # ---- Check for duplicate variable name ----
            $duplicateVar = $existingVariables | Where-Object { $_.Name -eq $VariableName }
            if ($duplicateVar) {
                Write-Verbose "A variable named '$VariableName' already exists on device '$deviceDisplayName' (ResourceID: $resourceIdToUse). It will be overwritten."
            }

            # ---- Build the new variable ----
            Write-Verbose "Creating new device variable: Name='$VariableName', IsMasked=$($IsMasked.IsPresent)"

            $variableClass = Get-CimClass -CimSession $script:CMConnection.CimSession -Namespace $namespace -ClassName 'SMS_MachineVariable'
            $newVariable = New-CimInstance -CimClass $variableClass -ClientOnly -Property @{
                Name     = $VariableName
                Value    = $Value
                IsMasked = [bool]$IsMasked.IsPresent
            }

            # ---- Build updated variables list (replace if duplicate, append if new) ----
            $updatedVariables = [System.Collections.Generic.List[CimInstance]]::new()
            foreach ($v in $existingVariables) {
                if ($v.Name -eq $VariableName) {
                    # Replace existing variable with new one
                    $updatedVariables.Add($newVariable)
                } else {
                    $updatedVariables.Add($v)
                }
            }
            if (-not $duplicateVar) {
                $updatedVariables.Add($newVariable)
            }

            # ---- ShouldProcess ----
            $maskedDisplay = if ($IsMasked.IsPresent) { " (masked)" } else { "" }
            $actionDescription = "Create variable '$VariableName' = '$( if ($IsMasked.IsPresent) { '********' } else { $Value } )'$maskedDisplay on device '$deviceDisplayName' (ResourceID: $resourceIdToUse)"

            if ($Force -or $PSCmdlet.ShouldProcess($actionDescription, "New-CM7DeviceVariable")) {

                if ($isNewSettings) {
                    # Create SMS_MachineSettings with ResourceID and SourceSite, then
                    # re-retrieve, modify MachineVariables, and Put_ again.
                    Write-Verbose "Creating new SMS_MachineSettings for ResourceID '$resourceIdToUse'..."

                    $null = New-CimInstance @cimParams -ClassName 'SMS_MachineSettings' -Property @{
                        ResourceID = [UInt32]$resourceIdToUse
                        SourceSite = $script:CMConnection.SiteCode
                        LocaleID   = [UInt32]1033
                    }

                    # Re-retrieve the full instance (loads lazy properties)
                    Write-Verbose "Re-retrieving newly created SMS_MachineSettings..."
                    $fullSettings = Get-CimInstance @cimParams -ClassName 'SMS_MachineSettings' -Filter "ResourceID = $resourceIdToUse" |
                        Get-CimInstance

                    if (-not $fullSettings) {
                        throw "Failed to create or retrieve SMS_MachineSettings for ResourceID '$resourceIdToUse'."
                    }
                }

                # Modify the MachineVariables property directly on the CIM instance,
                # then call Set-CimInstance (equivalent of WMI Put_) to commit all properties.
                Write-Verbose "Updating SMS_MachineSettings for ResourceID '$resourceIdToUse'..."
                $fullSettings.CimInstanceProperties['MachineVariables'].Value = [CimInstance[]]$updatedVariables.ToArray()
                $fullSettings | Set-CimInstance

                Write-Verbose "Successfully saved SMS_MachineSettings with variable '$VariableName'."

                # Return the created variable
                [PSCustomObject]@{
                    PSTypeName = 'MECM7.DeviceVariable'
                    Name       = $VariableName
                    Value      = $Value
                    IsMasked   = $IsMasked.IsPresent
                    ResourceId = $resourceIdToUse
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
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
function New-CM7MaintenanceWindow {
    <#
        .SYNOPSIS
            Creates a new maintenance window on a MECM collection using CIM.

        .DESCRIPTION
            Creates a new maintenance window (service window) on a specified collection in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. Maintenance windows
            define scheduled time periods during which deployments and other operations can
            be applied to collection members.

            This is the CIM-based equivalent of the New-CMMaintenanceWindow cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the collection (by name or ID)
            3. Builds a schedule token using SMS_ScheduleMethods::WriteToString
            4. Retrieves existing SMS_CollectionSettings (or creates new settings if none exist)
            5. Creates and appends the SMS_ServiceWindow embedded instance
            6. Writes the updated settings back via CIM

            Supports multiple recurrence types:
            - None (one-time window)
            - Daily (every N days)
            - Weekly (every N weeks on a specific day)
            - MonthlyByWeekday (e.g., 2nd Tuesday of every N months)
            - MonthlyByDate (e.g., 15th of every N months)

            Alternatively, a raw schedule token string can be provided for advanced scenarios.

        .PARAMETER CollectionName
            Specifies the name of the collection to add the maintenance window to.
            Mutually exclusive with CollectionId.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to add the maintenance window to.
            Mutually exclusive with CollectionName.

        .PARAMETER Name
            Specifies the name of the maintenance window. This name is displayed in the
            MECM console and used to identify the window.

        .PARAMETER Description
            Specifies an optional description for the maintenance window. Defaults to an empty string.

        .PARAMETER StartTime
            Specifies the start date and time of the maintenance window. For recurring windows,
            this is the start time of the first occurrence.

        .PARAMETER DurationMinutes
            Specifies the duration of the maintenance window in minutes.
            Valid range: 1 to 43200 (30 days).

        .PARAMETER RecurrenceType
            Specifies the recurrence type for the maintenance window.
            Valid values: None, Daily, Weekly, MonthlyByWeekday, MonthlyByDate.
            Defaults to 'None' (one-time window).

        .PARAMETER DaySpan
            Specifies the interval in days for a Daily recurrence. For example, DaySpan=2 means
            every other day. Valid range: 1 to 31. Defaults to 1.
            Only used when RecurrenceType is 'Daily'.

        .PARAMETER DayOfWeek
            Specifies the day of the week for Weekly and MonthlyByWeekday recurrences.
            Valid values: Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday.
            Required when RecurrenceType is 'Weekly' or 'MonthlyByWeekday'.

        .PARAMETER ForNumberOfWeeks
            Specifies the weekly recurrence interval. For example, ForNumberOfWeeks=2 means
            every other week. Valid range: 1 to 4. Defaults to 1.
            Only used when RecurrenceType is 'Weekly'.

        .PARAMETER WeekOrder
            Specifies which week of the month for MonthlyByWeekday recurrence.
            Valid values: First, Second, Third, Fourth, Last.
            Defaults to 'First'. Only used when RecurrenceType is 'MonthlyByWeekday'.

        .PARAMETER MonthDay
            Specifies the day of the month for MonthlyByDate recurrence.
            Valid range: 0 to 31. Use 0 for the last day of the month.
            Required when RecurrenceType is 'MonthlyByDate'.

        .PARAMETER ForNumberOfMonths
            Specifies the monthly recurrence interval. For example, ForNumberOfMonths=2 means
            every other month. Valid range: 1 to 12. Defaults to 1.
            Only used when RecurrenceType is 'MonthlyByWeekday' or 'MonthlyByDate'.

        .PARAMETER Schedule
            Specifies a raw SMS schedule token string. Use this parameter for advanced scenarios
            where you have a pre-built schedule token (e.g., copied from an existing maintenance
            window's ServiceWindowSchedules property). Mutually exclusive with StartTime,
            DurationMinutes, and RecurrenceType parameters.

        .PARAMETER ApplyTo
            Specifies the type of maintenance window. Determines which deployments can run
            during this window.
            Valid values:
            - Any: All deployments (general maintenance window)
            - SoftwareUpdatesOnly: Only software update deployments
            - TaskSequencesOnly: Only task sequence deployments
            Defaults to 'Any'.

        .PARAMETER IsEnabled
            Specifies whether the maintenance window is enabled. Defaults to $true.
            Set to $false to create a disabled maintenance window.

        .PARAMETER IsUtc
            Specifies that the maintenance window schedule uses UTC time.
            When not specified, the schedule uses local time of the site server.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "Daily MW" -StartTime "2026-02-20 22:00" -DurationMinutes 60 -RecurrenceType Daily -Force
            Creates a daily maintenance window starting at 10 PM, lasting 1 hour.

        .EXAMPLE
            New-CM7MaintenanceWindow -CollectionId "CM101C00" -Name "Weekly Updates" -StartTime "2026-02-21 02:00" -DurationMinutes 120 -RecurrenceType Weekly -DayOfWeek Saturday -ApplyTo SoftwareUpdatesOnly -Force
            Creates a weekly maintenance window for software updates only, every Saturday at 2 AM for 2 hours.

        .EXAMPLE
            New-CM7MaintenanceWindow -CollectionName "Servers" -Name "Monthly Patch Window" -StartTime "2026-03-01 01:00" -DurationMinutes 240 -RecurrenceType MonthlyByWeekday -DayOfWeek Tuesday -WeekOrder Second -ApplyTo SoftwareUpdatesOnly -Force
            Creates a monthly maintenance window on the second Tuesday of each month at 1 AM for 4 hours.

        .EXAMPLE
            New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "One-Time MW" -StartTime "2026-03-15 23:00" -DurationMinutes 30 -RecurrenceType None -Force
            Creates a one-time maintenance window on March 15 at 11 PM for 30 minutes.

        .EXAMPLE
            New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "Disabled MW" -StartTime "2026-02-20 22:00" -DurationMinutes 60 -RecurrenceType Daily -IsEnabled $false -Force
            Creates a disabled daily maintenance window. It can be enabled later.

        .EXAMPLE
            $existingMW = Get-CM7MaintenanceWindow -CollectionName "Source-Collection" -MaintenanceWindowName "Existing MW"
            New-CM7MaintenanceWindow -CollectionName "Target-Collection" -Name "Copied MW" -Schedule $existingMW.ServiceWindowSchedules -Force
            Copies a maintenance window schedule from one collection to another using the raw schedule token.

        .EXAMPLE
            New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "UTC MW" -StartTime "2026-02-20 22:00" -DurationMinutes 60 -RecurrenceType None -IsUtc -Force
            Creates a maintenance window using UTC time instead of local time.

        .NOTES
            This function is the CIM-based equivalent of the New-CMMaintenanceWindow cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The function builds SMS schedule tokens using the SMS_ScheduleMethods::WriteToString
            WMI method, which is the same method used internally by MECM. This ensures proper
            encoding of schedule information including start time, duration, and recurrence.

            Schedule Token Classes Used:
                SMS_ST_NonRecurring         - One-time schedules
                SMS_ST_RecurInterval        - Daily recurring schedules
                SMS_ST_RecurWeekly          - Weekly recurring schedules
                SMS_ST_RecurMonthlyByWeekday - Monthly by weekday schedules
                SMS_ST_RecurMonthlyByDate    - Monthly by date schedules

            Maintenance Window Types (ServiceWindowType):
                1 = All Deployments (Any)
                4 = Software Updates Only
                5 = Task Sequences Only
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByCollectionName')]
    param(
        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true, Position = 0)]
        [Parameter(ParameterSetName = 'ByCollectionNameScheduleToken', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByCollectionIdScheduleToken', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [string]$Description = '',

        # Schedule parameters (for building schedule tokens)
        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [datetime]$StartTime,

        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [ValidateRange(1, 43200)]
        [int]$DurationMinutes,

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateSet('None', 'Daily', 'Weekly', 'MonthlyByWeekday', 'MonthlyByDate')]
        [string]$RecurrenceType = 'None',

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateRange(1, 31)]
        [int]$DaySpan = 1,

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
        [string]$DayOfWeek,

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateRange(1, 4)]
        [int]$ForNumberOfWeeks = 1,

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateSet('First', 'Second', 'Third', 'Fourth', 'Last')]
        [string]$WeekOrder = 'First',

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateRange(0, 31)]
        [int]$MonthDay,

        [Parameter(ParameterSetName = 'ByCollectionName')]
        [Parameter(ParameterSetName = 'ByCollectionId')]
        [ValidateRange(1, 12)]
        [int]$ForNumberOfMonths = 1,

        # Raw schedule token or schedule object from New-CM7Schedule (alternative to building schedule)
        [Parameter(ParameterSetName = 'ByCollectionNameScheduleToken', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByCollectionIdScheduleToken', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]$Schedule,

        [Parameter()]
        [ValidateSet('Any', 'SoftwareUpdatesOnly', 'TaskSequencesOnly')]
        [string]$ApplyTo = 'Any',

        [Parameter()]
        [boolean]$IsEnabled = $true,

        [Parameter()]
        [switch]$IsUtc,

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

        # Map ApplyTo to ServiceWindowType integer
        $serviceWindowTypeMap = @{
            'Any'                 = [uint32]1
            'SoftwareUpdatesOnly' = [uint32]4
            'TaskSequencesOnly'   = [uint32]5
        }

        # Map DayOfWeek to bitmask values used by SMS schedule classes
        $dayOfWeekMap = @{
            'Sunday'    = [uint32]1
            'Monday'    = [uint32]2
            'Tuesday'   = [uint32]4
            'Wednesday' = [uint32]8
            'Thursday'  = [uint32]16
            'Friday'    = [uint32]32
            'Saturday'  = [uint32]64
        }

        # Map WeekOrder to SMS integer values
        $weekOrderMap = @{
            'Last'   = [uint32]0
            'First'  = [uint32]1
            'Second' = [uint32]2
            'Third'  = [uint32]3
            'Fourth' = [uint32]4
        }

        # Reverse maps for output
        $serviceWindowTypeMapReverse = @{
            1 = 'General'
            4 = 'SoftwareUpdatesOnly'
            5 = 'TaskSequencesOnly'
            6 = 'General'
        }

        $recurrenceTypeMapReverse = @{
            1 = 'None'
            2 = 'Daily'
            3 = 'Weekly'
            4 = 'MonthlyByWeekday'
            5 = 'MonthlyByDate'
        }
    }

    process {
        try {
            # ---- Resolve Collection ----
            $collectionIdToUse = $null
            $collectionDisplayName = $null

            switch -Wildcard ($PSCmdlet.ParameterSetName) {
                'ByCollectionName*' {
                    $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
                    Write-Verbose "Resolving collection name: $collectionQuery"
                    $collection = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collection) {
                        throw "Collection '$CollectionName' not found."
                    }

                    if (@($collection).Count -gt 1) {
                        throw "Multiple collections found with name '$CollectionName'. Please use -CollectionId instead."
                    }

                    $collectionIdToUse = $collection.CollectionID
                    $collectionDisplayName = $CollectionName
                    Write-Verbose "Resolved collection '$CollectionName' to ID '$collectionIdToUse'"
                }
                'ByCollectionId*' {
                    $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$CollectionId'"
                    Write-Verbose "Validating collection: $collectionQuery"
                    $collection = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collection) {
                        throw "Collection with ID '$CollectionId' not found."
                    }

                    $collectionIdToUse = $CollectionId
                    $collectionDisplayName = $collection.Name
                    Write-Verbose "Collection '$collectionDisplayName' ($CollectionId) validated."
                }
            }

            # ---- Build or use schedule token ----
            $scheduleString = $null

            if ($PSCmdlet.ParameterSetName -like '*ScheduleToken') {
                # Extract the schedule token string from object or use string directly
                if ($Schedule -is [string]) {
                    $scheduleString = $Schedule
                }
                elseif ($null -ne $Schedule.ScheduleString) {
                    $scheduleString = $Schedule.ScheduleString
                    # Inherit IsGMT from the schedule object when -IsUtc is not explicitly specified
                    if (-not $PSBoundParameters.ContainsKey('IsUtc') -and $null -ne $Schedule.IsGMT) {
                        $IsUtc = [switch]([bool]$Schedule.IsGMT)
                    }
                }
                else {
                    throw "The -Schedule parameter must be a schedule token string or an object with a ScheduleString property (e.g., from New-CM7Schedule)."
                }
                Write-Verbose "Using provided schedule token: $scheduleString"
            }
            else {
                # Validate recurrence-specific parameters
                if ($RecurrenceType -eq 'Weekly' -and -not $DayOfWeek) {
                    throw "The -DayOfWeek parameter is required when RecurrenceType is 'Weekly'."
                }
                if ($RecurrenceType -eq 'MonthlyByWeekday' -and -not $DayOfWeek) {
                    throw "The -DayOfWeek parameter is required when RecurrenceType is 'MonthlyByWeekday'."
                }
                if ($RecurrenceType -eq 'MonthlyByDate' -and -not $PSBoundParameters.ContainsKey('MonthDay')) {
                    throw "The -MonthDay parameter is required when RecurrenceType is 'MonthlyByDate'."
                }

                # Calculate duration components from total minutes
                $dayDuration = [uint32][Math]::Floor($DurationMinutes / 1440)
                $hourDuration = [uint32][Math]::Floor(($DurationMinutes % 1440) / 60)
                $minuteDuration = [uint32]($DurationMinutes % 60)

                # CIM cmdlets expect DateTime objects for StartTime properties.
                # The CIM layer handles DMTF datetime conversion internally.
                $startTimeFormatted = $StartTime

                Write-Verbose "Schedule: StartTime=$($StartTime.ToString('yyyy-MM-dd HH:mm:ss')), Duration=${dayDuration}d ${hourDuration}h ${minuteDuration}m, Recurrence=$RecurrenceType"

                # Build the schedule token instance based on recurrence type
                $scheduleToken = $null

                switch ($RecurrenceType) {
                    'None' {
                        $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_NonRecurring'
                        $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                            StartTime      = $startTimeFormatted
                            DayDuration    = $dayDuration
                            HourDuration   = $hourDuration
                            MinuteDuration = $minuteDuration
                            IsGMT          = [bool]$IsUtc.IsPresent
                        }
                    }
                    'Daily' {
                        $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurInterval'
                        $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                            StartTime      = $startTimeFormatted
                            DayDuration    = $dayDuration
                            HourDuration   = $hourDuration
                            MinuteDuration = $minuteDuration
                            IsGMT          = [bool]$IsUtc.IsPresent
                            DaySpan        = [uint32]$DaySpan
                            HourSpan       = [uint32]0
                            MinuteSpan     = [uint32]0
                        }
                    }
                    'Weekly' {
                        $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurWeekly'
                        $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                            StartTime        = $startTimeFormatted
                            DayDuration      = $dayDuration
                            HourDuration     = $hourDuration
                            MinuteDuration   = $minuteDuration
                            IsGMT            = [bool]$IsUtc.IsPresent
                            Day              = $dayOfWeekMap[$DayOfWeek]
                            ForNumberOfWeeks = [uint32]$ForNumberOfWeeks
                        }
                    }
                    'MonthlyByWeekday' {
                        $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurMonthlyByWeekday'
                        $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                            StartTime         = $startTimeFormatted
                            DayDuration       = $dayDuration
                            HourDuration      = $hourDuration
                            MinuteDuration    = $minuteDuration
                            IsGMT             = [bool]$IsUtc.IsPresent
                            Day               = $dayOfWeekMap[$DayOfWeek]
                            WeekOrder         = $weekOrderMap[$WeekOrder]
                            ForNumberOfMonths = [uint32]$ForNumberOfMonths
                        }
                    }
                    'MonthlyByDate' {
                        $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurMonthlyByDate'
                        $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                            StartTime         = $startTimeFormatted
                            DayDuration       = $dayDuration
                            HourDuration      = $hourDuration
                            MinuteDuration    = $minuteDuration
                            IsGMT             = [bool]$IsUtc.IsPresent
                            MonthDay          = [uint32]$MonthDay
                            ForNumberOfMonths = [uint32]$ForNumberOfMonths
                        }
                    }
                }

                # Convert schedule token to string using SMS_ScheduleMethods
                # Note: Explicitly pass -WhatIf:$false because WriteToString is a read-only
                # operation and must always execute, even when the caller uses -WhatIf.
                Write-Verbose "Converting schedule token to string via SMS_ScheduleMethods::WriteToString..."
                $writeResult = Invoke-CimMethod @cimParams -ClassName 'SMS_ScheduleMethods' -MethodName 'WriteToString' -Arguments @{
                    TokenData = [CimInstance[]]@($scheduleToken)
                } -WhatIf:$false -Confirm:$false

                if (-not $writeResult -or $writeResult.ReturnValue -ne 0) {
                    throw "SMS_ScheduleMethods::WriteToString failed with return value $($writeResult.ReturnValue)."
                }

                $scheduleString = $writeResult.StringData
                Write-Verbose "Generated schedule token: $scheduleString"
            }

            # ---- Retrieve or Create SMS_CollectionSettings ----
            $settingsQuery = "SELECT * FROM SMS_CollectionSettings WHERE CollectionID = '$collectionIdToUse'"
            Write-Verbose "Querying collection settings: $settingsQuery"
            $settings = Get-CimInstance @cimParams -Query $settingsQuery

            $isNewSettings = $false

            if ($settings) {
                # Retrieve full instance to load lazy properties (ServiceWindows)
                Write-Verbose "Retrieving full instance to load lazy property ServiceWindows..."
                $fullSettings = $settings | Get-CimInstance

                if (-not $fullSettings) {
                    throw "Could not retrieve full collection settings for CollectionID '$collectionIdToUse'."
                }
            }
            else {
                Write-Verbose "No existing SMS_CollectionSettings found for CollectionID '$collectionIdToUse'. Will create new settings."
                $isNewSettings = $true
                $fullSettings = $null
            }

            # ---- Get existing service windows ----
            $existingWindows = @()
            if ($fullSettings -and $fullSettings.ServiceWindows) {
                $existingWindows = @($fullSettings.ServiceWindows)
            }

            # ---- Check for duplicate name (warn but don't block) ----
            $duplicateWindow = $existingWindows | Where-Object { $_.Name -eq $Name }
            if ($duplicateWindow) {
                Write-Warning "A maintenance window named '$Name' already exists on collection '$collectionDisplayName' ($collectionIdToUse). A new window with the same name will be created."
            }

            # ---- Build new service window ----
            Write-Verbose "Creating new SMS_ServiceWindow: Name='$Name', Type=$ApplyTo, Enabled=$IsEnabled"
            $serviceWindowClass = Get-CimClass @cimParams -ClassName 'SMS_ServiceWindow'
            $newWindow = New-CimInstance -CimClass $serviceWindowClass -ClientOnly -Property @{
                Name                   = $Name
                Description            = $Description
                ServiceWindowType      = $serviceWindowTypeMap[$ApplyTo]
                ServiceWindowSchedules = $scheduleString
                IsEnabled              = $IsEnabled
                IsGMT                  = [bool]$IsUtc.IsPresent
            }

            # ---- Build updated windows list ----
            $updatedWindows = [System.Collections.Generic.List[CimInstance]]::new()
            foreach ($w in $existingWindows) {
                $updatedWindows.Add($w)
            }
            $updatedWindows.Add($newWindow)

            # ---- ShouldProcess ----
            $actionDescription = "Create maintenance window '$Name' (Type: $ApplyTo, Enabled: $IsEnabled) on collection '$collectionDisplayName' ($collectionIdToUse)"

            if ($Force -or $PSCmdlet.ShouldProcess($actionDescription, "New-CM7MaintenanceWindow")) {

                if ($isNewSettings) {
                    # Create new SMS_CollectionSettings, then re-retrieve to get full instance
                    Write-Verbose "Creating new SMS_CollectionSettings for CollectionID '$collectionIdToUse'..."

                    $null = New-CimInstance @cimParams -ClassName 'SMS_CollectionSettings' -Property @{
                        CollectionID = $collectionIdToUse
                    }

                    # Re-retrieve the full instance (loads lazy properties)
                    Write-Verbose "Re-retrieving newly created SMS_CollectionSettings..."
                    $fullSettings = Get-CimInstance @cimParams -ClassName 'SMS_CollectionSettings' -Filter "CollectionID = '$collectionIdToUse'" |
                        Get-CimInstance

                    if (-not $fullSettings) {
                        throw "Failed to create or retrieve SMS_CollectionSettings for CollectionID '$collectionIdToUse'."
                    }
                }

                # Update the ServiceWindows property and commit
                Write-Verbose "Updating SMS_CollectionSettings with new maintenance window..."
                $fullSettings.CimInstanceProperties['ServiceWindows'].Value = [CimInstance[]]$updatedWindows.ToArray()
                $fullSettings | Set-CimInstance -ErrorAction Stop

                Write-Verbose "Successfully created maintenance window '$Name' on collection '$collectionDisplayName' ($collectionIdToUse)."

                # Re-read to get the server-assigned properties (ServiceWindowID, parsed schedule, etc.)
                $updatedSettings = Get-CimInstance @cimParams -ClassName 'SMS_CollectionSettings' -Filter "CollectionID = '$collectionIdToUse'" |
                    Get-CimInstance

                $createdWindow = $null
                if ($updatedSettings -and $updatedSettings.ServiceWindows) {
                    # Find the newly created window (match by name, take last if duplicates)
                    $createdWindow = @($updatedSettings.ServiceWindows) | Where-Object { $_.Name -eq $Name } | Select-Object -Last 1
                }

                if ($createdWindow) {
                    $windowType = if ($serviceWindowTypeMapReverse.ContainsKey([int]$createdWindow.ServiceWindowType)) {
                        $serviceWindowTypeMapReverse[[int]$createdWindow.ServiceWindowType]
                    } else { "Unknown ($($createdWindow.ServiceWindowType))" }

                    $recurrence = if ($recurrenceTypeMapReverse.ContainsKey([int]$createdWindow.RecurrenceType)) {
                        $recurrenceTypeMapReverse[[int]$createdWindow.RecurrenceType]
                    } else { "Unknown ($($createdWindow.RecurrenceType))" }

                    [PSCustomObject]@{
                        PSTypeName             = 'MECM7.MaintenanceWindow'
                        Name                   = $createdWindow.Name
                        Description            = $createdWindow.Description
                        ServiceWindowID        = $createdWindow.ServiceWindowID
                        IsEnabled              = $createdWindow.IsEnabled
                        ServiceWindowType      = $windowType
                        StartTime              = $createdWindow.StartTime
                        Duration               = $createdWindow.Duration
                        RecurrenceType         = $recurrence
                        IsGMT                  = $createdWindow.IsGMT
                        ServiceWindowSchedules = $createdWindow.ServiceWindowSchedules
                        CollectionID           = $collectionIdToUse
                    }
                }
                else {
                    # Fallback output if re-read fails
                    Write-Warning "Could not re-read the created maintenance window. Returning basic information."
                    [PSCustomObject]@{
                        PSTypeName             = 'MECM7.MaintenanceWindow'
                        Name                   = $Name
                        Description            = $Description
                        ServiceWindowID        = $null
                        IsEnabled              = $IsEnabled
                        ServiceWindowType      = $ApplyTo
                        StartTime              = if ($PSBoundParameters.ContainsKey('StartTime')) { $StartTime } else { $null }
                        Duration               = if ($PSBoundParameters.ContainsKey('DurationMinutes')) { $DurationMinutes } else { $null }
                        RecurrenceType         = if ($PSBoundParameters.ContainsKey('RecurrenceType')) { $RecurrenceType } else { $null }
                        IsGMT                  = $IsUtc.IsPresent
                        ServiceWindowSchedules = $scheduleString
                        CollectionID           = $collectionIdToUse
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
function New-CM7Schedule {
    <#
        .SYNOPSIS
            Creates an SMS schedule token for use with MECM CIM-based functions.

        .DESCRIPTION
            Creates an SMS schedule token that can be used with other MECM7 functions
            such as New-CM7Collection, New-CM7MaintenanceWindow, and Set-CM7Collection.

            This is the CIM-based equivalent of the New-CMSchedule cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function uses the same parameters and behaviour as New-CMSchedule:
            - Nonrecurring (one-time schedule, default)
            - RecurInterval (every N days/hours/minutes)
            - RecurWeekly (every N weeks on a specific day)
            - RecurMonthlyByWeekday (e.g., 2nd Tuesday of every N months)
            - RecurMonthlyByDate (e.g., 15th of every N months)
            - RecurMonthlyLastDayOfMonth (last day of every N months)

            Duration can be specified using -DurationInterval/-DurationCount or -End.

            By default the function returns a CIM instance. Use the -ScheduleString switch
            to return the schedule as a hex-encoded token string instead.

        .PARAMETER Nonrecurring
            Indicates that the schedule does not recur. This creates an SMS_ST_NonRecurring
            schedule token. This is the default behaviour when no recurrence parameters
            are specified.

        .PARAMETER RecurInterval
            Specifies the unit of time for the interval-based recurrence. Used together
            with -RecurCount to define how often the schedule repeats.
            Valid values: Minutes, Hours, Days.

        .PARAMETER RecurCount
            Specifies the number of recurrence intervals. The meaning depends on the
            parameter set:
            - With -RecurInterval: the number of minutes, hours, or days between occurrences.
              Mandatory in this parameter set.
            - With -DayOfWeek (weekly): the number of weeks between occurrences. Default 1.
            - With -DayOfMonth or -LastDayOfMonth: the number of months between occurrences. Default 1.
            - With -DayOfWeek and -WeekOrder: the number of months between occurrences. Default 1.

        .PARAMETER DayOfWeek
            The day of the week for weekly or monthly-by-weekday schedules.
            Valid values: Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday.
            When used without -WeekOrder, creates a weekly schedule.
            When used with -WeekOrder, creates a monthly-by-weekday schedule.

        .PARAMETER WeekOrder
            Specifies which week of the month for monthly-by-weekday schedules.
            Valid values: First, Second, Third, Fourth, Last.
            Requires -DayOfWeek.

        .PARAMETER DayOfMonth
            The day of the month for monthly-by-date schedules.
            Valid range: 1 to 31.

        .PARAMETER LastDayOfMonth
            Indicates that the schedule recurs on the last day of each month.
            Creates an SMS_ST_RecurMonthlyByDate token with MonthDay set to 0.

        .PARAMETER OffsetDay
            Specifies an offset in days for monthly-by-weekday schedules.
            Valid range: 0 to 7. Default is 0.
            Only used with -DayOfWeek and -WeekOrder.

        .PARAMETER Start
            The start date and time for the schedule. Defaults to the current date and time.
            For recurring schedules, this is the start time of the first occurrence.

        .PARAMETER IsUtc
            Specifies that the schedule uses UTC time instead of local time.

        .PARAMETER ScheduleString
            Switch parameter that indicates the schedule token should be returned as a
            hex-encoded string instead of a CIM instance. When this switch is specified,
            the function returns the schedule token string directly.

        .PARAMETER DurationInterval
            Specifies the unit of time for the schedule duration. Used together with
            -DurationCount. Mutually exclusive with -End.
            Valid values: Minutes, Hours, Days.

        .PARAMETER DurationCount
            Specifies the number of duration intervals. Used together with -DurationInterval.
            Valid range: 0 to 31.

        .PARAMETER End
            Specifies the end date and time for the schedule. The duration is calculated
            from -Start to -End. Mutually exclusive with -DurationInterval/-DurationCount.

        .EXAMPLE
            New-CM7Schedule -Nonrecurring -Start "2026-03-15 22:00"
            Creates a one-time (non-recurring) schedule starting at March 15, 2026 at 10 PM.

        .EXAMPLE
            New-CM7Schedule -RecurInterval Days -RecurCount 1 -Start "2026-03-01 01:00"
            Creates a daily recurring schedule starting at March 1, 2026 at 1 AM.

        .EXAMPLE
            New-CM7Schedule -RecurInterval Hours -RecurCount 4 -Start "2026-03-01 01:00"
            Creates a schedule recurring every 4 hours.

        .EXAMPLE
            New-CM7Schedule -DayOfWeek Saturday -Start "2026-03-01 02:00"
            Creates a weekly schedule recurring every Saturday at 2 AM.

        .EXAMPLE
            New-CM7Schedule -DayOfWeek Saturday -RecurCount 2 -Start "2026-03-01 02:00"
            Creates a bi-weekly schedule recurring every other Saturday.

        .EXAMPLE
            New-CM7Schedule -DayOfWeek Tuesday -WeekOrder Second -Start "2026-03-01 01:00"
            Creates a monthly schedule on the second Tuesday of each month.

        .EXAMPLE
            New-CM7Schedule -DayOfMonth 15 -Start "2026-03-01 03:00"
            Creates a monthly schedule on the 15th of each month.

        .EXAMPLE
            New-CM7Schedule -LastDayOfMonth -Start "2026-03-01 03:00"
            Creates a monthly schedule on the last day of each month.

        .EXAMPLE
            New-CM7Schedule -RecurInterval Days -RecurCount 7 -Start "2026-03-01 22:00" -DurationInterval Hours -DurationCount 2
            Creates a weekly recurring schedule with a 2-hour duration window.

        .EXAMPLE
            New-CM7Schedule -Nonrecurring -Start "2026-03-15 22:00" -End "2026-03-16 00:00"
            Creates a non-recurring schedule with duration calculated from Start to End.

        .EXAMPLE
            $schedule = New-CM7Schedule -RecurInterval Days -RecurCount 7 -Start "2026-03-01 22:00" -ScheduleString
            New-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -Name "Weekly MW" -Schedule $schedule -Force
            Creates a recurring schedule as a token string and passes it to New-CM7MaintenanceWindow.

        .EXAMPLE
            New-CM7Schedule -Nonrecurring -Start "2026-03-15 22:00" -DurationInterval Hours -DurationCount 1 -IsUtc
            Creates a one-time schedule using UTC time with a 1-hour duration.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The function builds SMS schedule tokens using the SMS_ScheduleMethods::WriteToString
            WMI method, which is the same method used internally by MECM.

            Schedule Token Classes Used:
                SMS_ST_NonRecurring          - One-time schedules
                SMS_ST_RecurInterval         - Interval-based recurring schedules (days/hours/minutes)
                SMS_ST_RecurWeekly           - Weekly recurring schedules
                SMS_ST_RecurMonthlyByWeekday - Monthly by weekday schedules
                SMS_ST_RecurMonthlyByDate    - Monthly by date schedules (including last day of month)

            This is the CIM-based equivalent of the New-CMSchedule cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.
    #>
    [CmdletBinding(DefaultParameterSetName = 'RecurrenceNone')]
    [OutputType([Microsoft.Management.Infrastructure.CimInstance])]
    [OutputType([string])]
    param(
        # ---- Recurrence type switches/parameters ----
        [Parameter(ParameterSetName = 'RecurrenceNone')]
        [switch]$Nonrecurring,

        [Parameter(Mandatory = $true, ParameterSetName = 'RecurrenceInterval')]
        [ValidateSet('Minutes', 'Hours', 'Days')]
        [string]$RecurInterval,

        [Parameter(Mandatory = $true, ParameterSetName = 'RecurrenceInterval')]
        [Parameter(ParameterSetName = 'RecurrenceWeekly')]
        [Parameter(ParameterSetName = 'RecurMonthlyByWeekday')]
        [Parameter(ParameterSetName = 'RecurrenceMonthlyByDate')]
        [Parameter(ParameterSetName = 'RecurMonthlyLastDayOfMonth')]
        [ValidateRange(1, 31)]
        [int]$RecurCount,

        [Parameter(Mandatory = $true, ParameterSetName = 'RecurrenceWeekly')]
        [Parameter(Mandatory = $true, ParameterSetName = 'RecurMonthlyByWeekday')]
        [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
        [string]$DayOfWeek,

        [Parameter(Mandatory = $true, ParameterSetName = 'RecurMonthlyByWeekday')]
        [ValidateSet('First', 'Second', 'Third', 'Fourth', 'Last')]
        [string]$WeekOrder,

        [Parameter(ParameterSetName = 'RecurMonthlyByWeekday')]
        [ValidateRange(0, 7)]
        [int]$OffsetDay = 0,

        [Parameter(Mandatory = $true, ParameterSetName = 'RecurrenceMonthlyByDate')]
        [ValidateRange(1, 31)]
        [int]$DayOfMonth,

        [Parameter(Mandatory = $true, ParameterSetName = 'RecurMonthlyLastDayOfMonth')]
        [switch]$LastDayOfMonth,

        # ---- Common parameters ----
        [Parameter()]
        [datetime]$Start,

        [Parameter()]
        [switch]$IsUtc,

        [Parameter()]
        [switch]$ScheduleString,

        # ---- Duration parameters ----
        [Parameter()]
        [ValidateSet('Minutes', 'Hours', 'Days')]
        [string]$DurationInterval,

        [Parameter()]
        [ValidateRange(0, 31)]
        [int]$DurationCount,

        [Parameter()]
        [datetime]$End
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

        # Map DayOfWeek to bitmask values used by SMS schedule classes
        $dayOfWeekMap = @{
            'Sunday'    = [uint32]1
            'Monday'    = [uint32]2
            'Tuesday'   = [uint32]4
            'Wednesday' = [uint32]8
            'Thursday'  = [uint32]16
            'Friday'    = [uint32]32
            'Saturday'  = [uint32]64
        }

        # Map WeekOrder to SMS integer values
        $weekOrderMap = @{
            'Last'   = [uint32]0
            'First'  = [uint32]1
            'Second' = [uint32]2
            'Third'  = [uint32]3
            'Fourth' = [uint32]4
        }
    }

    process {
        try {
            # Set default Start time
            $actualStart = if ($PSBoundParameters.ContainsKey('Start')) { $Start } else { Get-Date }

            # ---- Validate duration parameters ----
            if ($PSBoundParameters.ContainsKey('End') -and ($PSBoundParameters.ContainsKey('DurationInterval') -or $PSBoundParameters.ContainsKey('DurationCount'))) {
                throw "Cannot use -End together with -DurationInterval or -DurationCount. Use one approach or the other."
            }
            if ($PSBoundParameters.ContainsKey('DurationInterval') -xor $PSBoundParameters.ContainsKey('DurationCount')) {
                throw "The -DurationInterval and -DurationCount parameters must be used together."
            }

            # Calculate duration components
            [uint32]$dayDuration = 0
            [uint32]$hourDuration = 0
            [uint32]$minuteDuration = 0

            if ($PSBoundParameters.ContainsKey('DurationInterval') -and $PSBoundParameters.ContainsKey('DurationCount')) {
                switch ($DurationInterval) {
                    'Days'    { $dayDuration = [uint32]$DurationCount }
                    'Hours'   { $hourDuration = [uint32]$DurationCount }
                    'Minutes' { $minuteDuration = [uint32]$DurationCount }
                }
            }
            elseif ($PSBoundParameters.ContainsKey('End')) {
                if ($End -le $actualStart) {
                    throw "The -End value must be later than the -Start value."
                }
                $totalMinutes = [int]($End - $actualStart).TotalMinutes
                $dayDuration = [uint32][Math]::Floor($totalMinutes / 1440)
                $hourDuration = [uint32][Math]::Floor(($totalMinutes % 1440) / 60)
                $minuteDuration = [uint32]($totalMinutes % 60)
            }

            # Set default RecurCount if not specified
            if (-not $PSBoundParameters.ContainsKey('RecurCount')) {
                $RecurCount = 1
            }

            Write-Verbose "Creating schedule: ParameterSet=$($PSCmdlet.ParameterSetName), Start=$($actualStart.ToString('yyyy-MM-dd HH:mm:ss')), Duration=${dayDuration}d ${hourDuration}h ${minuteDuration}m, IsUTC=$($IsUtc.IsPresent)"

            # Build the schedule token instance based on parameter set
            $scheduleToken = $null

            switch ($PSCmdlet.ParameterSetName) {
                'RecurrenceNone' {
                    Write-Verbose "Creating SMS_ST_NonRecurring schedule token"
                    $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_NonRecurring'
                    $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                        StartTime      = [datetime]$actualStart
                        DayDuration    = $dayDuration
                        HourDuration   = $hourDuration
                        MinuteDuration = $minuteDuration
                        IsGMT          = [bool]$IsUtc.IsPresent
                    }
                }
                'RecurrenceInterval' {
                    [uint32]$daySpan = 0
                    [uint32]$hourSpan = 0
                    [uint32]$minuteSpan = 0
                    switch ($RecurInterval) {
                        'Days'    { $daySpan = [uint32]$RecurCount }
                        'Hours'   { $hourSpan = [uint32]$RecurCount }
                        'Minutes' { $minuteSpan = [uint32]$RecurCount }
                    }
                    Write-Verbose "Creating SMS_ST_RecurInterval schedule token: DaySpan=$daySpan, HourSpan=$hourSpan, MinuteSpan=$minuteSpan"
                    $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurInterval'
                    $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                        StartTime      = [datetime]$actualStart
                        DayDuration    = $dayDuration
                        HourDuration   = $hourDuration
                        MinuteDuration = $minuteDuration
                        IsGMT          = [bool]$IsUtc.IsPresent
                        DaySpan        = $daySpan
                        HourSpan       = $hourSpan
                        MinuteSpan     = $minuteSpan
                    }
                }
                'RecurrenceWeekly' {
                    Write-Verbose "Creating SMS_ST_RecurWeekly schedule token: DayOfWeek=$DayOfWeek, ForNumberOfWeeks=$RecurCount"
                    $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurWeekly'
                    $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                        StartTime        = [datetime]$actualStart
                        DayDuration      = $dayDuration
                        HourDuration     = $hourDuration
                        MinuteDuration   = $minuteDuration
                        IsGMT            = [bool]$IsUtc.IsPresent
                        Day              = $dayOfWeekMap[$DayOfWeek]
                        ForNumberOfWeeks = [uint32]$RecurCount
                    }
                }
                'RecurMonthlyByWeekday' {
                    Write-Verbose "Creating SMS_ST_RecurMonthlyByWeekday schedule token: DayOfWeek=$DayOfWeek, WeekOrder=$WeekOrder, ForNumberOfMonths=$RecurCount, OffsetDay=$OffsetDay"
                    $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurMonthlyByWeekday'
                    $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                        StartTime         = [datetime]$actualStart
                        DayDuration       = $dayDuration
                        HourDuration      = $hourDuration
                        MinuteDuration    = $minuteDuration
                        IsGMT             = [bool]$IsUtc.IsPresent
                        Day               = $dayOfWeekMap[$DayOfWeek]
                        WeekOrder         = $weekOrderMap[$WeekOrder]
                        ForNumberOfMonths = [uint32]$RecurCount
                    }
                }
                'RecurrenceMonthlyByDate' {
                    Write-Verbose "Creating SMS_ST_RecurMonthlyByDate schedule token: DayOfMonth=$DayOfMonth, ForNumberOfMonths=$RecurCount"
                    $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurMonthlyByDate'
                    $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                        StartTime         = [datetime]$actualStart
                        DayDuration       = $dayDuration
                        HourDuration      = $hourDuration
                        MinuteDuration    = $minuteDuration
                        IsGMT             = [bool]$IsUtc.IsPresent
                        MonthDay          = [uint32]$DayOfMonth
                        ForNumberOfMonths = [uint32]$RecurCount
                    }
                }
                'RecurMonthlyLastDayOfMonth' {
                    Write-Verbose "Creating SMS_ST_RecurMonthlyByDate schedule token for last day of month: ForNumberOfMonths=$RecurCount"
                    $scheduleClass = Get-CimClass @cimParams -ClassName 'SMS_ST_RecurMonthlyByDate'
                    $scheduleToken = New-CimInstance -CimClass $scheduleClass -ClientOnly -Property @{
                        StartTime         = [datetime]$actualStart
                        DayDuration       = $dayDuration
                        HourDuration      = $hourDuration
                        MinuteDuration    = $minuteDuration
                        IsGMT             = [bool]$IsUtc.IsPresent
                        MonthDay          = [uint32]0
                        ForNumberOfMonths = [uint32]$RecurCount
                    }
                }
            }

            # Convert schedule token to string using SMS_ScheduleMethods
            Write-Verbose "Converting schedule token to string via SMS_ScheduleMethods::WriteToString..."
            $writeResult = Invoke-CimMethod @cimParams -ClassName 'SMS_ScheduleMethods' -MethodName 'WriteToString' -Arguments @{
                TokenData = [CimInstance[]]@($scheduleToken)
            }

            if (-not $writeResult -or $writeResult.ReturnValue -ne 0) {
                throw "SMS_ScheduleMethods::WriteToString failed with return value $($writeResult.ReturnValue)."
            }

            $scheduleStringResult = $writeResult.StringData
            Write-Verbose "Generated schedule token: $scheduleStringResult"

            if ($ScheduleString.IsPresent) {
                # Return the schedule token as a string
                Write-Output $scheduleStringResult
            }
            else {
                # Add ScheduleString as a NoteProperty on the CIM instance for convenience
                $scheduleToken | Add-Member -MemberType NoteProperty -Name ScheduleString -Value $scheduleStringResult -Force
                Write-Output $scheduleToken
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
function New-CM7SoftwareUpdateDeployment {
    <#
        .SYNOPSIS
            Creates a new software update deployment in MECM using CIM.

        .DESCRIPTION
            Creates a new software update deployment (SMS_UpdateGroupAssignment) in Microsoft Endpoint
            Configuration Manager (MECM) using CIM. A software update deployment assigns a software
            update group to a target collection, defining how and when the updates are installed.

            This is the CIM-based equivalent of the New-CMSoftwareUpdateDeployment cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the software update group by name or CI_ID
            3. Resolves the target collection by name or ID
            4. Creates a new SMS_UpdateGroupAssignment instance via CIM with the specified deployment settings
            5. Returns the created deployment as a formatted MECM7.SoftwareUpdateDeployment object

        .PARAMETER SoftwareUpdateGroupName
            The name of the software update group to deploy.
            Mutually exclusive with SoftwareUpdateGroupId.

        .PARAMETER SoftwareUpdateGroupId
            The CI_ID of the software update group to deploy.
            Mutually exclusive with SoftwareUpdateGroupName.

        .PARAMETER CollectionName
            The name of the target collection for the deployment.
            Mutually exclusive with CollectionId.

        .PARAMETER CollectionId
            The ID of the target collection for the deployment (e.g., "CM101C00").
            Mutually exclusive with CollectionName.

        .PARAMETER DeploymentName
            An optional name for the deployment (AssignmentName). If not specified,
            defaults to the software update group name.

        .PARAMETER Description
            An optional description for the deployment (AssignmentDescription).

        .PARAMETER DeploymentType
            The deployment type. Valid values are:
            - Required: Forces installation by the enforcement deadline.
            - Available: Makes updates available for optional installation.
            Defaults to Required.

        .PARAMETER AvailableDateTime
            The date and time when the deployment becomes available to clients.
            Defaults to the current date and time.

        .PARAMETER DeadlineDateTime
            The enforcement deadline date and time. After this time, the client will
            force installation of required deployments. Only used with DeploymentType Required.

        .PARAMETER UserNotification
            Controls user notification behavior. Valid values are:
            - DisplayAll: Show all notifications (default)
            - DisplaySoftwareCenterOnly: Show only in Software Center
            - HideAll: Hide all notifications

        .PARAMETER SoftwareInstallation
            Allows installation outside of maintenance windows. Default is $false.

        .PARAMETER AllowRestart
            Allows system restart outside of maintenance windows. Default is $false.

        .PARAMETER RestartServer
            Suppresses restart on servers when $false. Default is $true (allows restart).

        .PARAMETER RestartWorkstation
            Suppresses restart on workstations when $false. Default is $true (allows restart).

        .PARAMETER RequirePostRebootFullScan
            Requires a full scan of software updates after a restart. Default is $false.

        .PARAMETER ProtectedType
            Defines behavior for clients on protected distribution points. Valid values are:
            - NoInstall: Do not install software updates (default)
            - RemoteDistributionPoint: Install from a remote distribution point

        .PARAMETER UnprotectedType
            Defines behavior for clients on unprotected distribution points. Valid values are:
            - NoInstall: Do not install software updates
            - UnprotectedDistributionPoint: Install from an unprotected distribution point (default)

        .PARAMETER UseBranchCache
            Enables BranchCache for the deployment. Default is $false.

        .PARAMETER DownloadFromMicrosoftUpdate
            Allows clients to download from Microsoft Update if content is unavailable
            on distribution points. Default is $false.

        .PARAMETER UseGMTTimes
            Specifies whether to use UTC/GMT times. Default is $false (use local time).

        .PARAMETER VerbosityLevel
            Controls the verbosity of state messages reported by clients. Valid values are:
            - AllMessages: Report all messages
            - OnlySuccessAndErrorMessages: Report only success and error messages (default)
            - OnlyErrorMessages: Report only error messages

        .PARAMETER AcceptEula
            When $true, automatically accepts any End User License Agreements (EULAs) for software
            updates in the group that have EulaExists = $true and have not yet been accepted.
            This calls the AcceptEULA() instance method on each qualifying SMS_SoftwareUpdate object
            before the deployment is created. Default is $false.

        .PARAMETER DisableOperationsManagerAlert
            Disables Operations Manager (MOM/SCOM) alerts during the deployment. Default is $false.

        .PARAMETER PersistOnWriteFilterDevice
            Enables the write filter committal on devices that use a write filter (e.g., embedded
            devices). When $true, changes are committed to the device. Default is $true.

        .PARAMETER PreDownloadUpdateContent
            Pre-downloads update content before the deployment deadline. Default is $false.

        .PARAMETER Comment
            An alias for the Description parameter. Provides an optional comment/description
            for the deployment.

        .PARAMETER Enabled
            Whether the deployment is enabled. Default is $true.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -Force
            Creates a required software update deployment targeting the specified collection.

        .EXAMPLE
            New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -DeploymentType Available -Force
            Creates an available (optional) software update deployment.

        .EXAMPLE
            New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -DeadlineDateTime (Get-Date).AddDays(7) -Force
            Creates a required deployment with a 7-day enforcement deadline.

        .EXAMPLE
            New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupId 17129359 -CollectionId "CM101C00" -DeploymentName "Custom Deployment Name" -Description "Monthly patching" -Force
            Creates a deployment using CI_ID and collection ID with a custom name and description.

        .EXAMPLE
            New-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -WhatIf
            Shows what would happen without actually creating the deployment.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_UpdateGroupAssignment WMI class is used to represent software update deployments in MECM.

            This function is the CIM-based equivalent of the New-CMSoftwareUpdateDeployment cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByGroupNameCollectionName')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$SoftwareUpdateGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdCollectionId')]
        [ValidateNotNullOrEmpty()]
        [int]$SoftwareUpdateGroupId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdCollectionName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupNameCollectionId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByGroupIdCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter()]
        [string]$DeploymentName,

        [Parameter()]
        [Alias('Comment')]
        [string]$Description = '',

        [Parameter()]
        [ValidateSet('Required', 'Available')]
        [string]$DeploymentType = 'Required',

        [Parameter()]
        [datetime]$AvailableDateTime,

        [Parameter()]
        [datetime]$DeadlineDateTime,

        [Parameter()]
        [ValidateSet('DisplayAll', 'DisplaySoftwareCenterOnly', 'HideAll')]
        [string]$UserNotification = 'DisplayAll',

        [Parameter()]
        [Boolean]$SoftwareInstallation = $false,

        [Parameter()]
        [Boolean]$AllowRestart = $false,

        [Parameter()]
        [Boolean]$RestartServer = $true,

        [Parameter()]
        [Boolean]$RestartWorkstation = $true,

        [Parameter()]
        [Boolean]$RequirePostRebootFullScan = $false,

        [Parameter()]
        [ValidateSet('NoInstall', 'RemoteDistributionPoint')]
        [string]$ProtectedType = 'NoInstall',

        [Parameter()]
        [ValidateSet('NoInstall', 'UnprotectedDistributionPoint')]
        [string]$UnprotectedType = 'UnprotectedDistributionPoint',

        [Parameter()]
        [Boolean]$UseBranchCache = $false,

        [Parameter()]
        [Boolean]$DownloadFromMicrosoftUpdate = $false,

        [Parameter()]
        [Boolean]$UseGMTTimes = $false,

        [Parameter()]
        [Boolean]$Enabled = $true,

        [Parameter()]
        [ValidateSet('AllMessages', 'OnlySuccessAndErrorMessages', 'OnlyErrorMessages')]
        [string]$VerbosityLevel = 'OnlySuccessAndErrorMessages',

        [Parameter()]
        [Boolean]$AcceptEula = $false,

        [Parameter()]
        [Boolean]$DisableOperationsManagerAlert = $false,

        [Parameter()]
        [Boolean]$PersistOnWriteFilterDevice = $true,

        [Parameter()]
        [Boolean]$PreDownloadUpdateContent = $false,

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

        # Mapping tables
        $deploymentTypeMap = @{
            'Required'  = 1
            'Available' = 2
        }

        $userNotificationMap = @{
            'DisplayAll'                = $true
            'DisplaySoftwareCenterOnly' = $true
            'HideAll'                   = $false
        }

        $protectedTypeMap = @{
            'NoInstall'                = 0
            'RemoteDistributionPoint'  = 1
        }

        $unprotectedTypeMap = @{
            'NoInstall'                     = 0
            'UnprotectedDistributionPoint'  = 1
        }

        # Reverse maps for display
        $deploymentTypeReverse = @{
            1 = 'Required'
            2 = 'Available'
        }

        $assignmentActionMap = @{
            0 = 'Detect'
            1 = 'Apply'
            2 = 'Apply'
        }

        $verbosityLevelMap = @{
            'AllMessages'                 = [uint32]1
            'OnlySuccessAndErrorMessages' = [uint32]5
            'OnlyErrorMessages'           = [uint32]10
        }
    }

    process {
        try {
            # ---- Resolve Software Update Group ----
            $resolvedGroup = $null
            if ($PSBoundParameters.ContainsKey('SoftwareUpdateGroupName')) {
                $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$SoftwareUpdateGroupName'"
                Write-Verbose "Resolving software update group by name: $groupQuery"
                $resolvedGroup = Get-CimInstance @cimParams -Query $groupQuery

                if (-not $resolvedGroup) {
                    throw "Software update group '$SoftwareUpdateGroupName' not found."
                }
                if (@($resolvedGroup).Count -gt 1) {
                    throw "Multiple software update groups found matching '$SoftwareUpdateGroupName'. Please specify using -SoftwareUpdateGroupId."
                }
                $groupCIID = [int]$resolvedGroup.CI_ID
                $groupDisplayName = $resolvedGroup.LocalizedDisplayName
                Write-Verbose "Resolved software update group: '$groupDisplayName' (CI_ID: $groupCIID)"
            } else {
                $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE CI_ID = $SoftwareUpdateGroupId"
                Write-Verbose "Resolving software update group by ID: $groupQuery"
                $resolvedGroup = Get-CimInstance @cimParams -Query $groupQuery

                if (-not $resolvedGroup) {
                    throw "Software update group with CI_ID '$SoftwareUpdateGroupId' not found."
                }
                $groupCIID = [int]$resolvedGroup.CI_ID
                $groupDisplayName = $resolvedGroup.LocalizedDisplayName
                Write-Verbose "Resolved software update group: '$groupDisplayName' (CI_ID: $groupCIID)"
            }

            # ---- Resolve the updates in the group ----
            # The Updates property on SMS_AuthorizationList is a lazy property.
            # A direct WQL query does not load lazy properties, so we must pipe
            # through Get-CimInstance to force the provider to retrieve them.
            $groupDetailQuery = "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $groupCIID"
            Write-Verbose "Retrieving software update group details: $groupDetailQuery"
            $groupDetail = Get-CimInstance @cimParams -Query $groupDetailQuery | Get-CimInstance

            if (-not $groupDetail.Updates -or $groupDetail.Updates.Count -eq 0) {
                throw "Software update group '$groupDisplayName' (CI_ID: $groupCIID) contains no updates. Cannot create a deployment for an empty software update group."
            }

            # ---- Resolve Collection ----
            $resolvedCollectionId = $null
            $resolvedCollectionName = $null
            if ($PSBoundParameters.ContainsKey('CollectionName')) {
                $collQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
                Write-Verbose "Resolving collection by name: $collQuery"
                $resolvedCollection = Get-CimInstance @cimParams -Query $collQuery

                if (-not $resolvedCollection) {
                    throw "Collection '$CollectionName' not found."
                }
                if (@($resolvedCollection).Count -gt 1) {
                    throw "Multiple collections found matching '$CollectionName'. Please specify using -CollectionId."
                }
                $resolvedCollectionId = $resolvedCollection.CollectionID
                $resolvedCollectionName = $resolvedCollection.Name
                Write-Verbose "Resolved collection: '$resolvedCollectionName' (ID: $resolvedCollectionId)"
            } else {
                $collQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$CollectionId'"
                Write-Verbose "Resolving collection by ID: $collQuery"
                $resolvedCollection = Get-CimInstance @cimParams -Query $collQuery

                if (-not $resolvedCollection) {
                    throw "Collection '$CollectionId' not found."
                }
                $resolvedCollectionId = $resolvedCollection.CollectionID
                $resolvedCollectionName = $resolvedCollection.Name
                Write-Verbose "Resolved collection: '$resolvedCollectionName' (ID: $resolvedCollectionId)"
            }

            # ---- Determine deployment name ----
            $actualDeploymentName = if ($DeploymentName) { $DeploymentName } else { "$groupDisplayName - $resolvedCollectionName" }
            Write-Verbose "Deployment name: '$actualDeploymentName'"

            # check if deployment name already exists for this SUG and collection
            $existingDeploymentQuery = "SELECT AssignmentID FROM SMS_UpdateGroupAssignment WHERE AssignmentName = '$actualDeploymentName'"
            Write-Verbose "Checking for existing deployment with name: $existingDeploymentQuery"
            $existingDeployment = Get-CimInstance @cimParams -Query $existingDeploymentQuery
            if ($existingDeployment) {
                throw "A deployment with the name '$actualDeploymentName' already exists. Please choose a different name or remove the existing deployment first."
            }

            # ---- Set available and deadline times ----
            $now = Get-Date
            $actualAvailableDateTime = if ($PSBoundParameters.ContainsKey('AvailableDateTime')) { $AvailableDateTime } else { $now }

            # For Required deployments, set a default deadline if not specified
            $actualDeadlineDateTime = $null
            if ($DeploymentType -eq 'Required') {
                if ($PSBoundParameters.ContainsKey('DeadlineDateTime')) {
                    $actualDeadlineDateTime = $DeadlineDateTime
                } else {
                    # Default: available time (no enforcement delay - immediate)
                    $actualDeadlineDateTime = $actualAvailableDateTime
                }
            }

            # ---- Prepare datetime values ----
            # CIM cmdlets expect DateTime objects for datetime properties.
            # The CIM layer handles DMTF datetime conversion internally.
            $startTimeValue = [datetime]$actualAvailableDateTime

            # ---- Build SuppressReboot value ----
            # SuppressReboot in SMS_UpdatesAssignment: 0 = no suppress, 1 = suppress servers, 2 = suppress workstations, 3 = suppress both
            $suppressReboot = 0
            if (-not $RestartServer) { $suppressReboot = $suppressReboot -bor 1 }
            if (-not $RestartWorkstation) { $suppressReboot = $suppressReboot -bor 2 }

            # ---- Build notification behavior ----
            $notifyUser = $userNotificationMap[$UserNotification]

            # ---- Build AssignedCIs from the group updates ----
            [int32[]]$assignedCIs = @()
            if ($groupDetail.Updates -and $groupDetail.Updates.Count -gt 0) {
                $assignedCIs = [int32[]]$groupDetail.Updates
            }

            # ---- Accept EULAs if requested ----
            if ($AcceptEula -and $assignedCIs.Count -gt 0) {
                Write-Verbose "AcceptEula specified - checking for updates with pending EULAs"
                $ciIdList = $assignedCIs -join ','
                $eulaQuery = "SELECT CI_ID, LocalizedDisplayName, EulaExists, EulaAccepted FROM SMS_SoftwareUpdate WHERE CI_ID IN ($ciIdList) AND EulaExists = 1 AND EulaAccepted = 0"
                Write-Verbose "EULA query: $eulaQuery"
                $updatesWithEula = @(Get-CimInstance @cimParams -Query $eulaQuery)
                if ($updatesWithEula.Count -gt 0) {
                    Write-Verbose "Accepting EULAs for $($updatesWithEula.Count) update(s)"
                    foreach ($updateWithEula in $updatesWithEula) {
                        Write-Verbose "Accepting EULA for update: '$($updateWithEula.LocalizedDisplayName)' (CI_ID: $($updateWithEula.CI_ID))"
                        $eulaResult = Invoke-CimMethod -InputObject $updateWithEula -MethodName 'AcceptEULA' -Arguments @{ Accepted = $true }
                        if ($eulaResult.ReturnValue -ne 0) {
                            Write-Warning "AcceptEULA returned non-zero ($($eulaResult.ReturnValue)) for update '$($updateWithEula.LocalizedDisplayName)' (CI_ID: $($updateWithEula.CI_ID))"
                        }
                    }
                } else {
                    Write-Verbose "No updates with pending EULAs found"
                }
            }

            # ---- Create the deployment ----
            $actionDescription = "Create software update deployment '$actualDeploymentName' targeting collection '$resolvedCollectionName' ($resolvedCollectionId) with type '$DeploymentType'"
            if ($Force -or $PSCmdlet.ShouldProcess($actualDeploymentName, $actionDescription)) {
                Write-Verbose "Creating software update deployment: $actionDescription"

                # Build properties for SMS_UpdateGroupAssignment
                # This is the correct class for software update group deployments (confirmed via New-CMSoftwareUpdateDeployment verbose output)
                # Property types must match CIM class schema exactly
                $deploymentProperties = @{
                    AssignmentName                  = [string]$actualDeploymentName
                    AssignmentDescription           = [string]$(if ($Description) { $Description } else { '' })
                    AssignmentAction                = [int32]2   # 2 = Apply
                    AssignmentType                  = [int32]5   # 5 = Software Update Group
                    AssignedUpdateGroup             = [int32]$groupCIID
                    DesiredConfigType               = [int32]$deploymentTypeMap[$DeploymentType]
                    TargetCollectionID              = [string]$resolvedCollectionId
                    StartTime                       = [datetime]$startTimeValue
                    SuppressReboot                  = [uint32]$suppressReboot
                    UseGMTTimes                     = [bool]$UseGMTTimes
                    NotifyUser                      = [bool]$notifyUser
                    UserUIExperience                = [bool]$true
                    OverrideServiceWindows          = [bool]$SoftwareInstallation
                    RebootOutsideOfServiceWindows   = [bool]$AllowRestart
                    Enabled                         = [bool]$Enabled
                    AssignedCIs                     = [int32[]]$assignedCIs
                    StateMessagePriority            = [uint32]5
                    DPLocality                      = [uint32]16
                    UseBranchCache                  = [bool]$UseBranchCache
                    RequirePostRebootFullScan       = [bool]$RequirePostRebootFullScan
                    PreDownloadUpdateContent        = [bool]$PreDownloadUpdateContent
                    ApplyToSubTargets               = [bool]$false
                    LogComplianceToWinEvent         = [bool]$false
                    DisableMomAlerts                = [bool]$DisableOperationsManagerAlert
                    RaiseMomAlertsOnFailure         = [bool]$false
                    PersistOnWriteFilterDevices     = [bool]$PersistOnWriteFilterDevice
                    SoftDeadlineEnabled             = [bool]$false
                    WoLEnabled                      = [bool]$false
                    SendDetailedNonComplianceStatus = [bool]$false
                    LimitStateMessageVerbosity      = [bool]$true
                    StateMessageVerbosity           = [uint32]$verbosityLevelMap[$VerbosityLevel]
                }

                # Set enforcement deadline for Required deployments
                if ($DeploymentType -eq 'Required' -and $actualDeadlineDateTime) {
                    $deploymentProperties['EnforcementDeadline'] = [datetime]$actualDeadlineDateTime
                }

                Write-Verbose "Deployment properties: Name='$actualDeploymentName', Collection='$resolvedCollectionName', Type='$DeploymentType', Updates=$($assignedCIs.Count)"

                # Create the software update deployment using New-CimInstance
                $newDeployment = New-CimInstance @cimParams -ClassName 'SMS_UpdateGroupAssignment' -Property $deploymentProperties

                if (-not $newDeployment) {
                    throw "Failed to create software update deployment '$actualDeploymentName'. New-CimInstance returned null."
                }

                $assignmentId = $newDeployment.AssignmentID
                Write-Verbose "Software update deployment '$actualDeploymentName' created successfully with AssignmentID: $assignmentId"

                # ---- Retrieve the full deployment object to return ----
                $resultQuery = "SELECT * FROM SMS_UpdateGroupAssignment WHERE AssignmentID = $assignmentId"
                Write-Verbose "Retrieving created deployment: $resultQuery"
                $result = Get-CimInstance @cimParams -Query $resultQuery

                if ($result) {
                    # Map action type
                    $actionName = if ($assignmentActionMap.ContainsKey([int]$result.AssignmentAction)) {
                        $assignmentActionMap[[int]$result.AssignmentAction]
                    } else {
                        "Unknown ($($result.AssignmentAction))"
                    }

                    # Map desired config type
                    $configTypeName = if ($deploymentTypeReverse.ContainsKey([int]$result.DesiredConfigType)) {
                        $deploymentTypeReverse[[int]$result.DesiredConfigType]
                    } else {
                        "Unknown ($($result.DesiredConfigType))"
                    }

                    $output = [PSCustomObject]@{
                        PSTypeName                    = 'MECM7.SoftwareUpdateDeployment'
                        AssignmentID                  = [int]$result.AssignmentID
                        AssignmentName                = $result.AssignmentName
                        TargetCollectionID            = $result.TargetCollectionID
                        CollectionName                = $resolvedCollectionName
                        AssignmentDescription         = $result.AssignmentDescription
                        AssignmentAction              = $actionName
                        DesiredConfigType             = $configTypeName
                        StartTime                     = $result.StartTime
                        EnforcementDeadline           = $result.EnforcementDeadline
                        SuppressReboot                = [bool]$result.SuppressReboot
                        UseGMTTimes                   = [bool]$result.UseGMTTimes
                        NotifyUser                    = [bool]$result.NotifyUser
                        OverrideServiceWindows        = [bool]$result.OverrideServiceWindows
                        RebootOutsideOfServiceWindows = [bool]$result.RebootOutsideOfServiceWindows
                        Enabled                       = [bool]$result.Enabled
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.SoftwareUpdateDeployment')

                    # Add all extra properties
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }

                    Write-Output $output
                } else {
                    Write-Warning "Software update deployment was created but could not retrieve the result. AssignmentID: $assignmentId"
                }
            }
        }
        catch {
            throw $_
        }
    }
}
function New-CM7SoftwareUpdateDeploymentPackage {
    <#
        .SYNOPSIS
            Creates a new software update deployment package in MECM using CIM connectivity.

        .DESCRIPTION
            Creates a new software update deployment package (SMS_SoftwareUpdatePackage) in Microsoft Endpoint Configuration Manager (MECM) using CIM. This is the CIM-based equivalent of New-CMSoftwareUpdateDeploymentPackage from the ConfigurationManager module, but uses direct CIM queries.

            The function performs the following actions:
            1. Validates an active connection (Connect-CM7)
            2. Resolves the software update group by name
            3. Creates a new SMS_SoftwareUpdatePackage instance via CIM with the specified parameters
            4. Returns the created package as a formatted MECM7.SoftwareUpdateDeploymentPackage object

        .PARAMETER SoftwareUpdateGroupName
            The name of the software update group to package.

        .PARAMETER DeploymentPackageName
            The name for the new deployment package.

        .PARAMETER PackageSourcePath
            The UNC path for the package source (e.g., \\server\share\path).

        .PARAMETER Description
            An optional description for the deployment package.

        .EXAMPLE
            New-CM7SoftwareUpdateDeploymentPackage -SoftwareUpdateGroupName "Test-SUG" -DeploymentPackageName "Test-DeploymentPackage" -PackageSourcePath "\\mecm.yourdomain.local\Patches\Test" -Description "Test deployment package created by automated tests"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter()]
        [string]$Description
    )

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "No active MECM7 connection. Run Connect-CM7 first."
    }

    # Check for existing package with the same name
    $existingPkg = Get-CM7SoftwareUpdateDeploymentPackage -Name $Name -ErrorAction Ignore
    if ($existingPkg) {
        throw "A deployment package with the name '$Name' already exists."
    }

    # check if the unc path exists
    # Test-Path does not support UNC paths, so we will use Get-Item and check for exceptions
    if (-not ( [System.IO.Directory]::Exists($Path) )) {
        throw "The specified package source path '$Path' does not exist or is not accessible."
    }

    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $cimSession = $script:CMConnection.CimSession
    $packageProps = @{
        Name = $Name
        Description = $Description
        PkgSourcePath = $Path
        PkgSourceFlag = 2 # UNC source
    }
    $newPackage = New-CimInstance -CimSession $cimSession -Namespace $namespace -ClassName "SMS_SoftwareUpdatesPackage" -Property $packageProps

    # Return object
    $newPackage
}
function New-CM7SoftwareUpdateGroup {
    <#
        .SYNOPSIS
            Creates a new software update group in MECM using CIM.

        .DESCRIPTION
            Creates a new software update group (SMS_AuthorizationList) in Microsoft Endpoint
            Configuration Manager (MECM) using CIM. A software update group is a container for
            software updates that can be deployed to collections.

            This is the CIM-based equivalent of the New-CMSoftwareUpdateGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Optionally checks for duplicate software update group names
            3. Resolves software update CI_IDs from Article IDs if provided
            4. Creates a new SMS_AuthorizationList instance via CIM
            5. Returns the created software update group as a formatted MECM7.SoftwareUpdateGroup object

        .PARAMETER Name
            The name of the new software update group (LocalizedDisplayName).
            Must be unique within the MECM environment.

        .PARAMETER Description
            An optional description for the software update group (LocalizedDescription).

        .PARAMETER UpdateId
            An array of software update CI_IDs (integers) to include in the group.
            These correspond to the CI_ID property of SMS_SoftwareUpdate instances.
            Mutually exclusive with SoftwareUpdateId.

        .PARAMETER SoftwareUpdateId
            An array of software update CI_IDs (integers) to include in the group.
            Alias for UpdateId for compatibility with New-CMSoftwareUpdateGroup syntax.
            Mutually exclusive with UpdateId.

        .PARAMETER ArticleId
            An array of software update Article IDs (KB numbers, e.g. "5041578") to include in the group.
            The function resolves these to CI_IDs by querying SMS_SoftwareUpdate.
            Mutually exclusive with UpdateId and SoftwareUpdateId.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7SoftwareUpdateGroup -Name "Test-SUG" -Description "Test group for security patches"
            Creates an empty software update group with the specified name and description.

        .EXAMPLE
            New-CM7SoftwareUpdateGroup -Name "Patching-2026-02" -UpdateId @(16788010, 16788011)
            Creates a software update group containing the specified software updates by their CI_IDs.

        .EXAMPLE
            New-CM7SoftwareUpdateGroup -Name "KB Patches" -ArticleId @("5041578", "5041580") -Force
            Creates a software update group containing updates resolved from Article IDs (KB numbers).

        .EXAMPLE
            $updates = Get-CM7SoftwareUpdate -Name "*Cumulative*" | Select-Object -ExpandProperty CI_ID
            New-CM7SoftwareUpdateGroup -Name "Cumulative Updates" -UpdateId $updates -Force
            Creates a software update group from updates retrieved via Get-CM7SoftwareUpdate.

        .EXAMPLE
            New-CM7SoftwareUpdateGroup -Name "Test Group" -WhatIf
            Shows what would happen without actually creating the software update group.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_AuthorizationList WMI class is used to represent software update groups in MECM.
            The Updates property contains an array of CI_IDs referencing SMS_SoftwareUpdate instances.

            This function is the CIM-based equivalent of the New-CMSoftwareUpdateGroup cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByUpdateId')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [string]$Description = '',

        [Parameter(ParameterSetName = 'ByUpdateId')]
        [ValidateNotNullOrEmpty()]
        [int[]]$UpdateId,

        [Parameter(ParameterSetName = 'BySoftwareUpdateId')]
        [ValidateNotNullOrEmpty()]
        [Alias('SoftwareUpdateId')]
        [int[]]$SoftwareUpdateIds,

        [Parameter(ParameterSetName = 'ByArticleId')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ArticleId,

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
    }

    process {
        try {
            # ---- Check for duplicate software update group name ----
            $existingQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$Name'"
            Write-Verbose "Checking for existing software update group: $existingQuery"
            $existingGroup = Get-CimInstance @cimParams -Query $existingQuery

            if ($existingGroup) {
                throw "A software update group with name '$Name' already exists (CI_ID: $($existingGroup.CI_ID))."
            }

            # ---- Resolve update CI_IDs ----
            $resolvedUpdateIds = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ByUpdateId' {
                    if ($UpdateId) {
                        $resolvedUpdateIds = $UpdateId
                        Write-Verbose "Using provided UpdateId(s): $($resolvedUpdateIds -join ', ')"
                    }
                }
                'BySoftwareUpdateId' {
                    if ($SoftwareUpdateIds) {
                        $resolvedUpdateIds = $SoftwareUpdateIds
                        Write-Verbose "Using provided SoftwareUpdateId(s): $($resolvedUpdateIds -join ', ')"
                    }
                }
                'ByArticleId' {
                    if ($ArticleId) {
                        Write-Verbose "Resolving Article IDs to CI_IDs..."
                        foreach ($article in $ArticleId) {
                            $updateQuery = "SELECT CI_ID, ArticleID, LocalizedDisplayName FROM SMS_SoftwareUpdate WHERE ArticleID = '$article'"
                            Write-Verbose "  Querying: $updateQuery"
                            $updates = @(Get-CimInstance @cimParams -Query $updateQuery)

                            if ($updates.Count -eq 0) {
                                Write-Warning "No software update found for Article ID '$article'. Skipping."
                            } else {
                                foreach ($update in $updates) {
                                    $resolvedUpdateIds += [int]$update.CI_ID
                                    Write-Verbose "  Resolved Article '$article' -> CI_ID $($update.CI_ID) ($($update.LocalizedDisplayName))"
                                }
                            }
                        }
                    }
                }
            }

            # ---- Create the software update group ----
            $updateCount = $resolvedUpdateIds.Count
            $actionDescription = "Create software update group '$Name' with $updateCount update(s)"
            if ($Force -or $PSCmdlet.ShouldProcess($Name, $actionDescription)) {
                Write-Verbose "Creating software update group: $actionDescription"

                # Build the SMS_CI_LocalizedProperties embedded instance
                # SMS_AuthorizationList requires name/description via LocalizedInformation
                $localizedClass = Get-CimClass @cimParams -ClassName 'SMS_CI_LocalizedProperties'
                $localizedInstance = New-CimInstance -CimClass $localizedClass -ClientOnly -Property @{
                    DisplayName    = $Name
                    Description    = if ($Description) { $Description } else { '' }
                    LocaleID       = [uint32]0
                    InformativeURL = ''
                }

                # Build the properties for the new software update group
                $groupProperties = @{
                    LocalizedInformation = [CimInstance[]]@($localizedInstance)
                }

                if ($resolvedUpdateIds.Count -gt 0) {
                    $groupProperties['Updates'] = [int32[]]$resolvedUpdateIds
                }

                Write-Verbose "Software update group properties: Name='$Name', Description='$Description', Updates=$updateCount"

                # Create the software update group using New-CimInstance
                $newGroup = New-CimInstance @cimParams -ClassName 'SMS_AuthorizationList' -Property $groupProperties

                if (-not $newGroup) {
                    throw "Failed to create software update group '$Name'. New-CimInstance returned null."
                }

                $groupId = $newGroup.CI_ID
                Write-Verbose "Software update group '$Name' created successfully with CI_ID: $groupId"

                # ---- Retrieve the full software update group object to return ----
                $resultQuery = "SELECT * FROM SMS_AuthorizationList WHERE CI_ID = $groupId"
                Write-Verbose "Retrieving created software update group: $resultQuery"
                $result = Get-CimInstance @cimParams -Query $resultQuery

                if ($result) {
                    $output = [PSCustomObject]@{
                        PSTypeName                      = 'MECM7.SoftwareUpdateGroup'
                        CI_ID                           = [int]$result.CI_ID
                        CI_UniqueID                     = $result.CI_UniqueID
                        LocalizedDisplayName            = $result.LocalizedDisplayName
                        LocalizedDescription            = $result.LocalizedDescription
                        IsDeployed                      = [bool]$result.IsDeployed
                        IsExpired                       = [bool]$result.IsExpired
                        IsSuperseded                    = [bool]$result.IsSuperseded
                        NumberOfUpdates                 = [int]$result.NumberOfUpdates
                        DateCreated                     = $result.DateCreated
                        DateLastModified                = $result.DateLastModified
                        LocalizedCategoryInstanceNames  = $result.LocalizedCategoryInstanceNames
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.SoftwareUpdateGroup')

                    # Add all extra properties
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }

                    Write-Output $output
                } else {
                    Write-Warning "Software update group was created but could not retrieve the result. CI_ID: $groupId"
                }
            }
        }
        catch {
            throw $_
        }
    }
}
function New-CM7TaskSequenceDeployment {
    <#
        .SYNOPSIS
            Creates a new task sequence deployment in MECM using CIM.

        .DESCRIPTION
            Creates a new task sequence deployment (SMS_Advertisement) in Microsoft Endpoint
            Configuration Manager (MECM) using CIM. A task sequence deployment assigns a task
            sequence to a target collection, defining how and when the task sequence is run
            on targeted clients.

            This is the CIM-based equivalent of the New-CMTaskSequenceDeployment cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the task sequence by name or PackageID
            3. Resolves the target collection by name or ID
            4. Computes AdvertFlags and RemoteClientFlags from the specified parameters
            5. Creates a new SMS_Advertisement instance via CIM with ProgramName = '*'
            6. Returns the created deployment as a formatted MECM7.TaskSequenceDeployment object

        .PARAMETER TaskSequencePackageId
            The PackageID of the task sequence to deploy (e.g., "SD100FAD").
            Mutually exclusive with TaskSequenceName.

        .PARAMETER TaskSequenceName
            The name of the task sequence to deploy.
            Mutually exclusive with TaskSequencePackageId.

        .PARAMETER CollectionName
            The name of the target device collection for the deployment.
            Mutually exclusive with CollectionId.

        .PARAMETER CollectionId
            The ID of the target device collection for the deployment (e.g., "SD101C00").
            Mutually exclusive with CollectionName.

        .PARAMETER DeploymentName
            An optional name for the deployment (AdvertisementName). If not specified,
            defaults to "{TaskSequenceName} - {CollectionName}".

        .PARAMETER Comment
            An optional description/comment for the deployment.

        .PARAMETER DeployPurpose
            The deployment purpose. Valid values are:
            - Available: Makes the task sequence available for users to run from Software Center (default).
            - Required: Forces the task sequence to run by the deadline.

        .PARAMETER AvailableDateTime
            The date and time when the deployment becomes available to clients.
            Defaults to the current date and time.

        .PARAMETER DeadlineDateTime
            The enforcement deadline date and time for Required deployments.
            After this time, the task sequence will be forced to run.
            For Available deployments, this sets the expiration time.

        .PARAMETER UseUtcForAvailableSchedule
            Specifies whether to use UTC/GMT times for the available schedule. Default is $false.

        .PARAMETER UseUtcForExpireSchedule
            Specifies whether to use UTC/GMT times for the expiration/deadline schedule. Default is $false.

        .PARAMETER Availability
            Controls where the task sequence is available. Valid values are:
            - Clients: Only available to Configuration Manager clients (default)
            - ClientsMediaAndPxe: Available to clients, media, and PXE
            - MediaAndPxe: Available only to media and PXE
            - MediaAndPxeHidden: Available only to media and PXE (hidden)

        .PARAMETER RerunBehavior
            Controls how the task sequence behaves if it has been previously run. Valid values are:
            - NeverRerun: Never rerun the task sequence
            - AlwaysRerunProgram: Always rerun the task sequence
            - RerunIfFailedPreviousAttempt: Rerun only if the previous attempt failed (default)
            - RerunIfSucceededOnPreviousAttempt: Rerun only if the previous attempt succeeded

        .PARAMETER ShowTaskSequenceProgress
            Shows task sequence progress to the user. Default is $false.

        .PARAMETER SoftwareInstallation
            Allows task sequence installation outside of maintenance windows. Default is $true.

        .PARAMETER SystemRestart
            Allows system restart outside of maintenance windows. Default is $true.

        .PARAMETER AllowFallback
            Allows clients to use a fallback source location for content.
            Default is $false (do not fall back).

        .PARAMETER DeploymentOption
            Controls how content is accessed. Valid values are:
            - DownloadAllContent: Download all content locally before starting task sequence (default)
            - DownloadContentLocallyWhenNeededByRunningTaskSequence: Download content as needed
            - RunFromDistributionPoint: Access content directly from the distribution point

        .PARAMETER AllowSharedContent
            Allows clients to use BranchCache to share content with other clients.
            Default is $true.

        .PARAMETER SendWakeupPacket
            Sends a Wake On LAN packet to wake up computers before the deployment runs.
            Default is $false.

        .PARAMETER PersistOnWriteFilterDevice
            Allows content to persist on write filter enabled devices. Default is $false.

        .PARAMETER InternetOption
            Allows the task sequence to run on internet-based clients. Default is $true.

        .PARAMETER UseMeteredNetwork
            Allows the task sequence to run over metered network connections. Default is $true.

        .PARAMETER ScheduleEvent
            For Required deployments, controls when the task sequence is scheduled to run.
            Valid values are:
            - AsSoonAsPossible: Run as soon as possible after the available time (default)
            - LogOn: Run at next user logon
            - LogOff: Run at next user logoff

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -CollectionName "Test-Collection-Direct" -TaskSequencePackageId "SD100FAD" -AvailableDateTime (Get-Date) -Force
            Creates an available task sequence deployment targeting the specified collection.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequenceName "Test Josh" -CollectionName "Test-Collection-Direct" -Force
            Creates an available task sequence deployment using the task sequence name.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -DeployPurpose Required -Force
            Creates a required (mandatory) task sequence deployment.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionId "SD101C00" -DeploymentName "Custom Deployment Name" -Comment "Monthly OS deployment" -Force
            Creates a deployment using PackageID and collection ID with a custom name and comment.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -WhatIf
            Shows what would happen without actually creating the deployment.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -DeployPurpose Required -DeadlineDateTime (Get-Date).AddDays(7) -Force
            Creates a required deployment with a 7-day enforcement deadline.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -SoftwareInstallation $false -SystemRestart $false -Force
            Creates a deployment that does not allow installation or restart outside of maintenance windows.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -ShowTaskSequenceProgress $true -Force
            Creates a deployment with task sequence progress displayed to the user.

        .EXAMPLE
            New-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" `
                -DeployPurpose Required `
                -AvailableDateTime (Get-Date) `
                -DeadlineDateTime (Get-Date).AddDays(7) `
                -SoftwareInstallation $true `
                -SystemRestart $true `
                -AllowFallback $false `
                -RerunBehavior RerunIfFailedPreviousAttempt `
                -ShowTaskSequenceProgress $true `
                -AllowSharedContent $true `
                -UseMeteredNetwork $true `
                -Force
            Creates a fully configured required task sequence deployment.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_Advertisement WMI class is used to represent task sequence deployments in MECM.
            Task sequence deployments are distinguished from other deployments by ProgramName = '*'.

            This function is the CIM-based equivalent of the New-CMTaskSequenceDeployment cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            AdvertFlags and RemoteClientFlags are computed from the specified parameters to match
            the behavior of the native New-CMTaskSequenceDeployment cmdlet. The default parameter
            values produce the same flag values as the native cmdlet with default settings:
            AdvertFlags = 0x8b0000 (9109504), RemoteClientFlags = 0x8850 (34896).
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByTSPackageIdCollectionName')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSPackageIdCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSPackageIdCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequencePackageId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSNameCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSNameCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequenceName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSPackageIdCollectionName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSNameCollectionName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSPackageIdCollectionId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTSNameCollectionId')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter()]
        [string]$DeploymentName,

        [Parameter()]
        [string]$Comment = '',

        [Parameter()]
        [ValidateSet('Available', 'Required')]
        [string]$DeployPurpose = 'Available',

        [Parameter()]
        [datetime]$AvailableDateTime,

        [Parameter()]
        [datetime]$DeadlineDateTime,

        [Parameter()]
        [Boolean]$UseUtcForAvailableSchedule = $false,

        [Parameter()]
        [Boolean]$UseUtcForExpireSchedule = $false,

        [Parameter()]
        [ValidateSet('Clients', 'ClientsMediaAndPxe', 'MediaAndPxe', 'MediaAndPxeHidden')]
        [string]$Availability = 'Clients',

        [Parameter()]
        [ValidateSet('NeverRerun', 'AlwaysRerunProgram', 'RerunIfFailedPreviousAttempt', 'RerunIfSucceededOnPreviousAttempt')]
        [string]$RerunBehavior = 'RerunIfFailedPreviousAttempt',

        [Parameter()]
        [Boolean]$ShowTaskSequenceProgress = $false,

        [Parameter()]
        [Boolean]$SoftwareInstallation = $true,

        [Parameter()]
        [Boolean]$SystemRestart = $true,

        [Parameter()]
        [Boolean]$AllowFallback = $false,

        [Parameter()]
        [ValidateSet('DownloadAllContent', 'DownloadContentLocallyWhenNeededByRunningTaskSequence', 'RunFromDistributionPoint')]
        [string]$DeploymentOption = 'DownloadAllContent',

        [Parameter()]
        [Boolean]$AllowSharedContent = $true,

        [Parameter()]
        [Boolean]$SendWakeupPacket = $false,

        [Parameter()]
        [Boolean]$PersistOnWriteFilterDevice = $false,

        [Parameter()]
        [Boolean]$InternetOption = $true,

        [Parameter()]
        [Boolean]$UseMeteredNetwork = $true,

        [Parameter()]
        [ValidateSet('AsSoonAsPossible', 'LogOn', 'LogOff')]
        [string]$ScheduleEvent = 'AsSoonAsPossible',

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

        # ---- AdvertFlags bit definitions for SMS_Advertisement ----
        $ADVERT_IMMEDIATE                      = [uint32]0x00000020  # 32 - As soon as possible
        $ADVERT_ONSYSTEMSTARTUP                = [uint32]0x00000100  # 256
        $ADVERT_ONUSERLOGON                    = [uint32]0x00000200  # 512
        $ADVERT_ONUSERLOGOFF                   = [uint32]0x00000400  # 1024
        $ADVERT_ENABLE_TS_FROM_CD_AND_PXE      = [uint32]0x00002000  # 8192
        $ADVERT_NO_DISPLAY                     = [uint32]0x00008000  # 32768
        $ADVERT_OVERRIDE_SERVICE_WINDOWS       = [uint32]0x00010000  # 65536
        $ADVERT_REBOOT_OUTSIDE_SERVICE_WINDOWS = [uint32]0x00020000  # 131072
        $ADVERT_WAKE_ON_LAN                    = [uint32]0x00040000  # 262144
        $ADVERT_DONOT_FALLBACK                 = [uint32]0x00080000  # 524288
        $ADVERT_ENABLE_PEER_CACHING            = [uint32]0x00100000  # 1048576
        $ADVERT_SHOW_PROGRESS                  = [uint32]0x02000000  # 33554432
        $ADVERT_USE_REMOTE_DP                  = [uint32]0x00800000  # 8388608

        # ---- RemoteClientFlags bit definitions ----
        $RCF_DOWNLOAD_FROM_LOCAL_DP            = [uint32]0x00000001  # 1
        $RCF_DOWNLOAD_FROM_REMOTE_DP           = [uint32]0x00000002  # 2
        $RCF_DONT_RUN_NO_LOCAL_DP              = [uint32]0x00000004  # 4
        $RCF_DOWNLOAD_FROM_INTERNET            = [uint32]0x00000008  # 8
        $RCF_ALLOW_SHARED_CONTENT              = [uint32]0x00000010  # 16
        $RCF_ALWAYS_RERUN                      = [uint32]0x00000020  # 32
        $RCF_RERUN_IF_FAILED                   = [uint32]0x00000040  # 64
        $RCF_RERUN_IF_SUCCEEDED                = [uint32]0x00000080  # 128
        $RCF_DOWNLOAD_FROM_UNPROTECTED_DP      = [uint32]0x00000100  # 256
        $RCF_PERSIST_ON_WRITE_FILTER           = [uint32]0x00000400  # 1024
        $RCF_ALLOW_INTERNET_CLIENTS            = [uint32]0x00000800  # 2048
        $RCF_TS_SHOW_PROGRESS                  = [uint32]0x00004000  # 16384
        $RCF_USE_METERED_NETWORK               = [uint32]0x00008000  # 32768
    }

    process {
        try {
            # ---- Resolve Task Sequence ----
            $resolvedPackageId = $null
            $resolvedTSName = $null
            if ($PSBoundParameters.ContainsKey('TaskSequenceName')) {
                $tsQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE Name = '$TaskSequenceName'"
                Write-Verbose "Resolving task sequence by name: $tsQuery"
                $resolvedTS = Get-CimInstance @cimParams -Query $tsQuery

                if (-not $resolvedTS) {
                    throw "Task sequence '$TaskSequenceName' not found."
                }
                if (@($resolvedTS).Count -gt 1) {
                    throw "Multiple task sequences found matching '$TaskSequenceName'. Please specify using -TaskSequencePackageId."
                }
                $resolvedPackageId = $resolvedTS.PackageID
                $resolvedTSName = $resolvedTS.Name
                Write-Verbose "Resolved task sequence: '$resolvedTSName' (PackageID: $resolvedPackageId)"
            } else {
                $tsQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE PackageID = '$TaskSequencePackageId'"
                Write-Verbose "Resolving task sequence by PackageID: $tsQuery"
                $resolvedTS = Get-CimInstance @cimParams -Query $tsQuery

                if (-not $resolvedTS) {
                    throw "Task sequence with PackageID '$TaskSequencePackageId' not found."
                }
                $resolvedPackageId = $resolvedTS.PackageID
                $resolvedTSName = $resolvedTS.Name
                Write-Verbose "Resolved task sequence: '$resolvedTSName' (PackageID: $resolvedPackageId)"
            }

            # ---- Resolve Collection ----
            $resolvedCollectionId = $null
            $resolvedCollectionName = $null
            if ($PSBoundParameters.ContainsKey('CollectionName')) {
                $collQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionType = 2 AND Name = '$CollectionName'"
                Write-Verbose "Resolving collection by name: $collQuery"
                $resolvedCollection = Get-CimInstance @cimParams -Query $collQuery

                if (-not $resolvedCollection) {
                    throw "Device collection '$CollectionName' not found."
                }
                if (@($resolvedCollection).Count -gt 1) {
                    throw "Multiple collections found matching '$CollectionName'. Please specify using -CollectionId."
                }
                $resolvedCollectionId = $resolvedCollection.CollectionID
                $resolvedCollectionName = $resolvedCollection.Name
                Write-Verbose "Resolved collection: '$resolvedCollectionName' (ID: $resolvedCollectionId)"
            } else {
                $collQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionType = 2 AND CollectionID = '$CollectionId'"
                Write-Verbose "Resolving collection by ID: $collQuery"
                $resolvedCollection = Get-CimInstance @cimParams -Query $collQuery

                if (-not $resolvedCollection) {
                    throw "Device collection '$CollectionId' not found."
                }
                $resolvedCollectionId = $resolvedCollection.CollectionID
                $resolvedCollectionName = $resolvedCollection.Name
                Write-Verbose "Resolved collection: '$resolvedCollectionName' (ID: $resolvedCollectionId)"
            }

            # ---- Determine deployment name ----
            $actualDeploymentName = if ($DeploymentName) { $DeploymentName } else { "$resolvedTSName - $resolvedCollectionName" }
            Write-Verbose "Deployment name: '$actualDeploymentName'"

            # ---- Set available time ----
            $now = Get-Date
            $actualAvailableDateTime = if ($PSBoundParameters.ContainsKey('AvailableDateTime')) { $AvailableDateTime } else { $now }

            # ---- Compute AdvertFlags ----
            [uint32]$advertFlags = $ADVERT_USE_REMOTE_DP   # Always set for TS deployments

            # Service window and restart control
            if ($SoftwareInstallation) {
                $advertFlags = $advertFlags -bor $ADVERT_OVERRIDE_SERVICE_WINDOWS
            }
            if ($SystemRestart) {
                $advertFlags = $advertFlags -bor $ADVERT_REBOOT_OUTSIDE_SERVICE_WINDOWS
            }

            # Fallback behavior (inverted: AllowFallback=false means set DONOT_FALLBACK)
            if (-not $AllowFallback) {
                $advertFlags = $advertFlags -bor $ADVERT_DONOT_FALLBACK
            }

            # Wake On LAN
            if ($SendWakeupPacket) {
                $advertFlags = $advertFlags -bor $ADVERT_WAKE_ON_LAN
            }

            # Media/PXE availability
            if ($Availability -in @('ClientsMediaAndPxe', 'MediaAndPxe', 'MediaAndPxeHidden')) {
                $advertFlags = $advertFlags -bor $ADVERT_ENABLE_TS_FROM_CD_AND_PXE
            }
            if ($Availability -eq 'MediaAndPxeHidden') {
                $advertFlags = $advertFlags -bor $ADVERT_NO_DISPLAY
            }

            # Show task sequence progress in AdvertFlags
            if ($ShowTaskSequenceProgress) {
                $advertFlags = $advertFlags -bor $ADVERT_SHOW_PROGRESS
            }

            # Schedule event (for Required deployments)
            if ($DeployPurpose -eq 'Required') {
                switch ($ScheduleEvent) {
                    'AsSoonAsPossible' { $advertFlags = $advertFlags -bor $ADVERT_IMMEDIATE }
                    'LogOn'            { $advertFlags = $advertFlags -bor $ADVERT_ONUSERLOGON }
                    'LogOff'           { $advertFlags = $advertFlags -bor $ADVERT_ONUSERLOGOFF }
                }
            }

            Write-Verbose "AdvertFlags == 0x$($advertFlags.ToString('X')) / $advertFlags"

            # ---- Compute RemoteClientFlags ----
            [uint32]$remoteClientFlags = 0

            # Rerun behavior
            switch ($RerunBehavior) {
                'AlwaysRerunProgram'                  { $remoteClientFlags = $remoteClientFlags -bor $RCF_ALWAYS_RERUN }
                'RerunIfFailedPreviousAttempt'        { $remoteClientFlags = $remoteClientFlags -bor $RCF_RERUN_IF_FAILED }
                'RerunIfSucceededOnPreviousAttempt'   { $remoteClientFlags = $remoteClientFlags -bor $RCF_RERUN_IF_SUCCEEDED }
                # 'NeverRerun' → no bits
            }

            # Shared content (BranchCache)
            if ($AllowSharedContent) {
                $remoteClientFlags = $remoteClientFlags -bor $RCF_ALLOW_SHARED_CONTENT
            }

            # Write filter persistence
            if ($PersistOnWriteFilterDevice) {
                $remoteClientFlags = $remoteClientFlags -bor $RCF_PERSIST_ON_WRITE_FILTER
            }

            # Internet clients
            if ($InternetOption) {
                $remoteClientFlags = $remoteClientFlags -bor $RCF_ALLOW_INTERNET_CLIENTS
            }

            # Show TS progress in RemoteClientFlags
            if ($ShowTaskSequenceProgress) {
                $remoteClientFlags = $remoteClientFlags -bor $RCF_TS_SHOW_PROGRESS
            }

            # Metered network
            if ($UseMeteredNetwork) {
                $remoteClientFlags = $remoteClientFlags -bor $RCF_USE_METERED_NETWORK
            }

            # DeploymentOption
            switch ($DeploymentOption) {
                'RunFromDistributionPoint' {
                    $remoteClientFlags = $remoteClientFlags -bor $RCF_DONT_RUN_NO_LOCAL_DP
                }
                'DownloadContentLocallyWhenNeededByRunningTaskSequence' {
                    $remoteClientFlags = $remoteClientFlags -bor $RCF_DOWNLOAD_FROM_REMOTE_DP
                }
                # 'DownloadAllContent' → default, no additional bits
            }

            Write-Verbose "RemoteClientFlags == 0x$($remoteClientFlags.ToString('X')) / $remoteClientFlags"

            # ---- Compute DeviceFlags ----
            [uint32]$deviceFlags = 0
            Write-Verbose "DeviceFlags == 0x$($deviceFlags.ToString('X')) / $deviceFlags"

            # ---- Create the deployment ----
            $actionDescription = "Create task sequence deployment '$actualDeploymentName' for task sequence '$resolvedTSName' ($resolvedPackageId) targeting collection '$resolvedCollectionName' ($resolvedCollectionId) with purpose '$DeployPurpose'"
            if ($Force -or $PSCmdlet.ShouldProcess($actualDeploymentName, $actionDescription)) {
                Write-Verbose "Creating task sequence deployment: $actionDescription"

                # Build properties for SMS_Advertisement
                # ProgramName = '*' marks this as a task sequence deployment
                $deploymentProperties = @{
                    AdvertisementName  = [string]$actualDeploymentName
                    CollectionID       = [string]$resolvedCollectionId
                    PackageID          = [string]$resolvedPackageId
                    ProgramName        = [string]'*'
                    SourceSite         = [string]$script:CMConnection.SiteCode
                    AdvertFlags        = [uint32]$advertFlags
                    RemoteClientFlags  = [uint32]$remoteClientFlags
                    DeviceFlags        = [uint32]$deviceFlags
                    PresentTime        = [datetime]$actualAvailableDateTime
                    Comment            = [string]$(if ($Comment) { $Comment } else { '' })
                    Priority           = [uint32]2  # Medium priority
                    PresentTimeEnabled = [bool]$true
                    PresentTimeIsGMT   = [bool]$UseUtcForAvailableSchedule
                }

                # Set expiration/deadline time if specified
                if ($PSBoundParameters.ContainsKey('DeadlineDateTime')) {
                    $deploymentProperties['ExpirationTime'] = [datetime]$DeadlineDateTime
                    $deploymentProperties['ExpirationTimeEnabled'] = [bool]$true
                    $deploymentProperties['ExpirationTimeIsGMT'] = [bool]$UseUtcForExpireSchedule
                }

                # For Required deployments with AsSoonAsPossible, enable the assigned schedule
                if ($DeployPurpose -eq 'Required') {
                    $deploymentProperties['AssignedScheduleEnabled'] = [bool]$true
                    $deploymentProperties['AssignedScheduleIsGMT'] = [bool]$UseUtcForAvailableSchedule
                }

                Write-Verbose "Deployment properties: Name='$actualDeploymentName', PackageID='$resolvedPackageId', Collection='$resolvedCollectionName', Purpose='$DeployPurpose'"
                Write-Verbose "Creating instance of class 'SMS_Advertisement'"

                # Create the task sequence deployment using New-CimInstance
                $newDeployment = New-CimInstance @cimParams -ClassName 'SMS_Advertisement' -Property $deploymentProperties

                if (-not $newDeployment) {
                    throw "Failed to create task sequence deployment '$actualDeploymentName'. New-CimInstance returned null."
                }

                $advertisementId = $newDeployment.AdvertisementID
                Write-Verbose "Task sequence deployment '$actualDeploymentName' created successfully with AdvertisementID: $advertisementId"

                # ---- Retrieve the full deployment object to return ----
                $resultQuery = "SELECT * FROM SMS_Advertisement WHERE AdvertisementID = '$advertisementId'"
                Write-Verbose "Retrieving created deployment: $resultQuery"
                $result = Get-CimInstance @cimParams -Query $resultQuery

                if ($result) {
                    # Resolve task sequence name for output
                    $outputTsName = $resolvedTSName

                    $output = [PSCustomObject]@{
                        PSTypeName               = 'MECM7.TaskSequenceDeployment'
                        AdvertisementID          = $result.AdvertisementID
                        AdvertisementName        = $result.AdvertisementName
                        CollectionID             = $result.CollectionID
                        CollectionName           = $resolvedCollectionName
                        PackageID                = $result.PackageID
                        TaskSequenceName         = $outputTsName
                        ProgramName              = $result.ProgramName
                        SourceSite               = $result.SourceSite
                        AdvertFlags              = [int]$result.AdvertFlags
                        RemoteClientFlags        = [int]$result.RemoteClientFlags
                        DeviceFlags              = [int]$result.DeviceFlags
                        PresentTime              = $result.PresentTime
                        ExpirationTime           = $result.ExpirationTime
                        Comment                  = $result.Comment
                    }

                    # Set the type name
                    $output.PSObject.TypeNames.Insert(0, 'MECM7.TaskSequenceDeployment')

                    # Add all extra properties from the CIM instance
                    $result.CimInstanceProperties | ForEach-Object {
                        if ($_.Name -notin $output.PSObject.Properties.Name) {
                            $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }

                    Write-Output $output
                } else {
                    Write-Warning "Task sequence deployment was created but could not retrieve the result. AdvertisementID: $advertisementId"
                }
            }
        }
        catch {
            throw $_
        }
    }
}
function Remove-CM7Application {
    <#
        .SYNOPSIS
            Removes an application from MECM using CIM connectivity.

        .DESCRIPTION
            Retires and deletes an application from MECM via the SMS_Application WMI class using CIM connectivity.
            Requires an active connection established via Connect-CM7.
            You must retire the application (SetIsExpired) before deletion.

        .PARAMETER Name
            The display name of the application to remove. Supports wildcards. (Mutually exclusive with ID)

        .PARAMETER ID
            The CI_ID of the application to remove. (Mutually exclusive with Name)

        .PARAMETER InputObject
            A collection of objects representing applications to remove. Each object must have a CI_ID property. (Mutually exclusive with Name and ID)

        .PARAMETER Force
            If specified, does not prompt for confirmation.

        .EXAMPLE
            Remove-CM7Application -Name "Test"
            Retires and deletes the application named "Test".

        .EXAMPLE
            Remove-CM7Application -ID 12345678
            Retires and deletes the application with CI_ID 12345678.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByID', Mandatory = $true, Position = 0)]
        [int]$ID,

        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSObject]$InputObject,

        [Parameter()]
        [switch]$Force
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $session   = $script:CMConnection.CimSession

    # Resolve application(s)
    switch ($PSCmdlet.ParameterSetName) {
        'ByName' {
            $apps = Get-CimInstance -CimSession $session -Namespace $namespace -ClassName SMS_Application -Filter "LocalizedDisplayName = '$Name' AND IsLatest = 1"
            if (-not $apps) {
                Write-Warning "No application found with Name '$Name'."
                return $false
            }
        }
        'ByID' {
            $apps = Get-CimInstance -CimSession $session -Namespace $namespace -ClassName SMS_Application -Filter "CI_ID = $ID AND IsLatest = 1"
            if (-not $apps) {
                Write-Warning "No application found with CI_ID $ID."
                return $false
            }
        }
        'ByInputObject' {
            # Not implemented in this version
            $apps = @()
            foreach ($obj in $InputObject) {
                if ($obj.PSObject.Properties.Name -contains 'CI_ID') {
                    $id = $obj.CI_ID
                    $app = Get-CimInstance -CimSession $session -Namespace $namespace -ClassName SMS_Application -Filter "CI_ID = $id AND IsLatest = 1"
                    if ($app) {
                        $apps += $app
                    }
                }
            }
        }
    }

    foreach ($app in $apps) {
        $appId = $app.CI_ID
        $appName = $app.LocalizedDisplayName
        if ($PSCmdlet.ShouldProcess("Application '$appName' (CI_ID: $appId)", 'Remove')) {
            if (-not $Force) {
                $confirm = $PSCmdlet.ShouldContinue("Remove application '$appName' (CI_ID: $appId)? This will retire and delete the application.", 'Confirm Application Removal')
                if (-not $confirm) { continue }
            }
            try {
                # Step 1 – retire (required before WMI deletion for SMS_Application)
                Invoke-CimMethod -CimSession $session -Namespace $namespace `
                    -Query "SELECT * FROM SMS_Application WHERE CI_ID = $appId AND IsLatest = 1" `
                    -MethodName SetIsExpired -Arguments @{ Expired = $true } -ErrorAction SilentlyContinue | Out-Null
                # Step 2 – delete all versions
                Remove-CimInstance -CimSession $session -Namespace $namespace `
                    -Query "SELECT * FROM SMS_Application WHERE CI_ID = $appId" -ErrorAction SilentlyContinue
                Write-Verbose "Removed application '$appName' (CI_ID: $appId)"
                Write-Output $true
            } catch {
                Write-Warning "Failed to remove application '$appName' (CI_ID: $appId): $_"
                Write-Output $false
            }
        }
    }
}
function Remove-CM7Boundary {
    <#
        .SYNOPSIS
            Removes a boundary from MECM using CIM.

        .DESCRIPTION
            Removes (deletes) a boundary from Microsoft Endpoint Configuration Manager (MECM)
            using CIM. This function deletes an SMS_Boundary instance via CIM.

            This is the CIM-based equivalent of the Remove-CMBoundary cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

            The function supports removing boundaries by:
            - Name (DisplayName): resolves the boundary by display name
            - Id (BoundaryID):    resolves the boundary by its integer ID
            - InputObject:        accepts a boundary object from the pipeline (e.g., from Get-CM7Boundary)

        .PARAMETER Name
            The display name of the boundary to remove. Supports wildcard characters (* and ?).
            If multiple boundaries match the name, all matching boundaries are removed.

        .PARAMETER Id
            The BoundaryID (integer) of the boundary to remove. Provides unambiguous identification.

        .PARAMETER InputObject
            A boundary object (e.g., from Get-CM7Boundary) to remove.
            Accepts pipeline input. Must have a BoundaryID property.

        .PARAMETER Force
            Suppresses confirmation prompts and removes the boundary without asking.
            By default, the function prompts for confirmation before deletion.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7Boundary -Name "TestSubnet-192.168.1.0"
            Removes the boundary named "TestSubnet-192.168.1.0" after confirmation.

        .EXAMPLE
            Remove-CM7Boundary -Id 16777223 -Force
            Removes the boundary with the specified BoundaryID without prompting for confirmation.

        .EXAMPLE
            Get-CM7Boundary -BoundaryType 0 | Remove-CM7Boundary -Force
            Removes all IP Subnet boundaries via pipeline.

        .EXAMPLE
            Remove-CM7Boundary -Name "TestSubnet-*" -WhatIf
            Shows what would happen without actually removing the matching boundaries.

        .EXAMPLE
            $boundary = Get-CM7Boundary -BoundaryId 16777223
            Remove-CM7Boundary -InputObject $boundary -Force
            Removes a boundary using a previously retrieved boundary object.

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_Boundary WMI class is used to represent boundaries in MECM.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [Alias('DisplayName')]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [Alias('BoundaryId')]
        [int]$Id,

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

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            # ---- Resolve Boundary ----
            $boundaries = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    # Convert wildcard pattern to WQL LIKE pattern
                    $wqlPattern = $Name -replace '\*', '%' -replace '\?', '_'
                    $query = "SELECT * FROM SMS_Boundary WHERE DisplayName LIKE '$wqlPattern'"
                    $boundaries = @(Get-CimInstance @cimParams -Query $query)

                    if ($boundaries.Count -eq 0) {
                        Write-Warning "No boundary found with name matching '$Name'."
                        return
                    }
                }
                'ById' {
                    $query = "SELECT * FROM SMS_Boundary WHERE BoundaryID = $Id"
                    $result = Get-CimInstance @cimParams -Query $query
                    if (-not $result) {
                        Write-Warning "No boundary found with BoundaryID $Id."
                        return
                    }
                    $boundaries = @($result)
                }
                'ByInputObject' {
                    # Resolve BoundaryID from the input object
                    $boundaryId = $null
                    if ($InputObject.PSObject.Properties['BoundaryID']) {
                        $boundaryId = $InputObject.BoundaryID
                    } elseif ($InputObject.PSObject.Properties['BoundaryId']) {
                        $boundaryId = $InputObject.BoundaryId
                    } else {
                        throw "InputObject does not have a BoundaryID property. Please provide a valid boundary object from Get-CM7Boundary."
                    }

                    $query = "SELECT * FROM SMS_Boundary WHERE BoundaryID = $boundaryId"
                    $result = Get-CimInstance @cimParams -Query $query
                    if (-not $result) {
                        Write-Warning "No boundary found with BoundaryID $boundaryId (from InputObject)."
                        return
                    }
                    $boundaries = @($result)
                }
            }

            # ---- Remove each resolved boundary ----
            foreach ($boundary in $boundaries) {
                $displayName = $boundary.DisplayName
                $boundaryId  = $boundary.BoundaryID
                $actionDescription = "Remove boundary '$displayName' (BoundaryID: $boundaryId)"

                if ($Force -or $PSCmdlet.ShouldProcess("$displayName (BoundaryID: $boundaryId)", "Remove boundary")) {
                    Write-Verbose $actionDescription
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $boundary
                    Write-Verbose "Boundary '$displayName' (BoundaryID: $boundaryId) removed successfully."
                }
            }
        } catch {
            throw $_
        }
    }
}
function Remove-CM7BoundaryFromGroup {
    <#
        .SYNOPSIS
            Removes a boundary from a boundary group in MECM using CIM.

        .DESCRIPTION
            Removes an existing boundary from an existing boundary group in Microsoft Endpoint
            Configuration Manager (MECM) using CIM. The boundary group and the boundary can each
            be identified by their ID, name, or by passing an object from Get-CM7BoundaryGroup /
            Get-CM7Boundary respectively.

            Internally, the function invokes the RemoveBoundary instance method on the
            SMS_BoundaryGroup WMI class.

            This is the CIM-based equivalent of the Remove-CMBoundaryFromGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

        .PARAMETER BoundaryGroupId
            The GroupID (integer) of the boundary group to remove the boundary from.

        .PARAMETER BoundaryGroupName
            The name of the boundary group to remove the boundary from.

        .PARAMETER BoundaryGroupInputObject
            A boundary group object (e.g. from Get-CM7BoundaryGroup) to remove the boundary from.
            Alias: BoundaryGroup

        .PARAMETER BoundaryId
            The BoundaryID (integer) of the boundary to remove.

        .PARAMETER BoundaryName
            The name of the boundary to remove.

        .PARAMETER BoundaryInputObject
            A boundary object (e.g. from Get-CM7Boundary) to remove.
            Alias: Boundary

        .PARAMETER Force
            Suppresses confirmation prompts and removes the boundary from the group without asking.

        .PARAMETER DisableWildcardHandling
            Treats wildcard characters as literal character values.
            Cannot be combined with ForceWildcardHandling.

        .PARAMETER ForceWildcardHandling
            Forces wildcard character processing even in contexts where it is not normally
            supported. May lead to unexpected behavior (not recommended).
            Cannot be combined with DisableWildcardHandling.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7BoundaryFromGroup -BoundaryGroupId 16777219 -BoundaryName "CLBound03"
            Removes the boundary named "CLBound03" from the boundary group with GroupID 16777219.

        .EXAMPLE
            Remove-CM7BoundaryFromGroup -BoundaryGroupName "MyBoundaryGroup" -BoundaryId 16777230 -Force
            Removes the boundary with BoundaryID 16777230 from the named group without prompting.

        .EXAMPLE
            $group    = Get-CM7BoundaryGroup -Name "MyBoundaryGroup"
            $boundary = Get-CM7Boundary     -Name "MyBoundary"
            Remove-CM7BoundaryFromGroup -BoundaryGroupInputObject $group -BoundaryInputObject $boundary -Force
            Removes the boundary from the group using objects from Get-CM7BoundaryGroup and Get-CM7Boundary.

        .EXAMPLE
            Remove-CM7BoundaryFromGroup -BoundaryGroupName "MyBoundaryGroup" -BoundaryId 16777230 -WhatIf
            Shows what would happen without actually removing the boundary from the group.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
            The RemoveBoundary instance method accepts an array of uint32 BoundaryIDs and removes
            them from the boundary group.

            For more information on the SMS_BoundaryGroup class and the RemoveBoundary method, see:
            https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class

            Related functions:
            - Add-CM7BoundaryToGroup
            - Get-CM7Boundary
            - Get-CM7BoundaryGroup
    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact         = 'Medium',
        DefaultParameterSetName = 'ByGroupId_ByBoundaryId'
    )]
    param(
        # ---- Boundary Group: by ID ----
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryId',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryName',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryObject', Mandatory = $true)]
        [int]$BoundaryGroupId,

        # ---- Boundary Group: by Name ----
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryId',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryName',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryObject', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BoundaryGroupName,

        # ---- Boundary Group: by Object ----
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryId',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryName',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryObject', Mandatory = $true)]
        [Alias('BoundaryGroup')]
        [ValidateNotNull()]
        [PSObject]$BoundaryGroupInputObject,

        # ---- Boundary: by ID ----
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryId',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryId',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryId', Mandatory = $true)]
        [int]$BoundaryId,

        # ---- Boundary: by Name ----
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryName',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryName',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BoundaryName,

        # ---- Boundary: by Object ----
        [Parameter(ParameterSetName = 'ByGroupId_ByBoundaryObject',     Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupName_ByBoundaryObject',   Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByGroupObject_ByBoundaryObject', Mandatory = $true)]
        [Alias('Boundary')]
        [ValidateNotNull()]
        [PSObject]$BoundaryInputObject,

        # ---- Confirmation / Wildcard handling ----
        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$DisableWildcardHandling,

        [Parameter()]
        [switch]$ForceWildcardHandling
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        # Validate mutually exclusive wildcard parameters
        if ($DisableWildcardHandling -and $ForceWildcardHandling) {
            throw "DisableWildcardHandling and ForceWildcardHandling cannot be used together."
        }

        # Validate connection
        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            # ------------------------------------------------------------------
            # 1. Resolve Boundary Group CIM instance
            # ------------------------------------------------------------------
            $groupInstance = $null

            switch -Regex ($PSCmdlet.ParameterSetName) {
                '^ByGroupId_' {
                    Write-Verbose "Resolving boundary group by GroupID: $BoundaryGroupId"
                    $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $BoundaryGroupId"
                    if (-not $groupInstance) {
                        throw "No boundary group found with GroupID $BoundaryGroupId."
                    }
                }
                '^ByGroupName_' {
                    Write-Verbose "Resolving boundary group by Name: $BoundaryGroupName"
                    $safeName = $BoundaryGroupName -replace "'", "''"
                    $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$safeName'"
                    if (-not $groupInstance) {
                        throw "No boundary group found with name '$BoundaryGroupName'."
                    }
                }
                '^ByGroupObject_' {
                    $resolvedGroupId = $null
                    if ($BoundaryGroupInputObject.PSObject.Properties['GroupID']) {
                        $resolvedGroupId = $BoundaryGroupInputObject.GroupID
                    } elseif ($BoundaryGroupInputObject.PSObject.Properties['GroupId']) {
                        $resolvedGroupId = $BoundaryGroupInputObject.GroupId
                    } else {
                        throw "BoundaryGroupInputObject does not have a GroupID property. Please provide a valid boundary group object from Get-CM7BoundaryGroup."
                    }
                    Write-Verbose "Resolving boundary group from InputObject with GroupID: $resolvedGroupId"
                    $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $resolvedGroupId"
                    if (-not $groupInstance) {
                        throw "No boundary group found with GroupID $resolvedGroupId (from BoundaryGroupInputObject)."
                    }
                }
            }

            # ------------------------------------------------------------------
            # 2. Resolve Boundary ID
            # ------------------------------------------------------------------
            $resolvedBoundaryId = $null

            switch -Regex ($PSCmdlet.ParameterSetName) {
                '_ByBoundaryId$' {
                    Write-Verbose "Using BoundaryID directly: $BoundaryId"
                    $boundaryCheck = Get-CimInstance @cimParams -Query "SELECT BoundaryID FROM SMS_Boundary WHERE BoundaryID = $BoundaryId"
                    if (-not $boundaryCheck) {
                        throw "No boundary found with BoundaryID $BoundaryId."
                    }
                    $resolvedBoundaryId = $BoundaryId
                }
                '_ByBoundaryName$' {
                    Write-Verbose "Resolving boundary by Name: $BoundaryName"
                    $safeName = $BoundaryName -replace "'", "''"
                    $boundaryResult = Get-CimInstance @cimParams -Query "SELECT BoundaryID, DisplayName FROM SMS_Boundary WHERE DisplayName = '$safeName'"
                    if (-not $boundaryResult) {
                        throw "No boundary found with name '$BoundaryName'."
                    }
                    if (@($boundaryResult).Count -gt 1) {
                        throw "Multiple boundaries found with name '$BoundaryName'. Please use BoundaryId or BoundaryInputObject to be more specific."
                    }
                    $resolvedBoundaryId = $boundaryResult.BoundaryID
                }
                '_ByBoundaryObject$' {
                    if ($BoundaryInputObject.PSObject.Properties['BoundaryID']) {
                        $resolvedBoundaryId = $BoundaryInputObject.BoundaryID
                    } elseif ($BoundaryInputObject.PSObject.Properties['BoundaryId']) {
                        $resolvedBoundaryId = $BoundaryInputObject.BoundaryId
                    } else {
                        throw "BoundaryInputObject does not have a BoundaryID property. Please provide a valid boundary object from Get-CM7Boundary."
                    }
                    Write-Verbose "Using BoundaryID from BoundaryInputObject: $resolvedBoundaryId"
                    $boundaryCheck = Get-CimInstance @cimParams -Query "SELECT BoundaryID FROM SMS_Boundary WHERE BoundaryID = $resolvedBoundaryId"
                    if (-not $boundaryCheck) {
                        throw "No boundary found with BoundaryID $resolvedBoundaryId (from BoundaryInputObject)."
                    }
                }
            }

            # ------------------------------------------------------------------
            # 3. Invoke RemoveBoundary method on the boundary group
            # ------------------------------------------------------------------
            $groupName = $groupInstance.Name
            $groupId   = $groupInstance.GroupID

            $shouldProcessTarget = "Boundary '$resolvedBoundaryId' from boundary group '$groupName' (GroupID: $groupId)"
            $shouldProcessAction = "Remove boundary from group"

            if ($Force -or $PSCmdlet.ShouldProcess($shouldProcessTarget, $shouldProcessAction)) {
                Write-Verbose "Calling RemoveBoundary on boundary group '$groupName' (GroupID: $groupId) for BoundaryID $resolvedBoundaryId"

                $methodResult = Invoke-CimMethod -InputObject $groupInstance -MethodName 'RemoveBoundary' -Arguments @{
                    BoundaryID = [uint32[]]@($resolvedBoundaryId)
                }

                if ($methodResult.ReturnValue -ne 0) {
                    throw "RemoveBoundary method returned non-zero exit code $($methodResult.ReturnValue) for boundary group '$groupName' (GroupID: $groupId)."
                }

                Write-Verbose "Successfully removed BoundaryID $resolvedBoundaryId from boundary group '$groupName' (GroupID: $groupId)."
            }
        } catch {
            throw $_
        }
    }
}
function Remove-CM7BoundaryGroup {
    <#
        .SYNOPSIS
            Removes a boundary group from MECM using CIM.

        .DESCRIPTION
            Removes (deletes) a boundary group from Microsoft Endpoint Configuration Manager (MECM)
            using CIM. This function deletes an SMS_BoundaryGroup instance via CIM.

            This is the CIM-based equivalent of the Remove-CMBoundaryGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

            The function supports removing boundary groups by:
            - Name:        resolves the boundary group by name (supports wildcard characters)
            - Id (GroupID): resolves one or more boundary groups by their integer GroupID
            - InputObject:  accepts a boundary group object from the pipeline (e.g., from Get-CM7BoundaryGroup)

        .PARAMETER Name
            The name of the boundary group to remove. Supports wildcard characters (* and ?).
            If multiple boundary groups match the name pattern, all matching groups are removed.

        .PARAMETER Id
            One or more GroupIDs of boundary groups to remove.
            Alias: GroupId

        .PARAMETER InputObject
            A boundary group object (e.g., from Get-CM7BoundaryGroup) to remove.
            Accepts pipeline input. Must have a GroupID property.

        .PARAMETER Force
            Suppresses confirmation prompts and removes the boundary group without asking.
            By default the function prompts for confirmation before deletion.

        .PARAMETER DisableWildcardHandling
            Treats wildcard characters as literal character values.
            Cannot be combined with ForceWildcardHandling.

        .PARAMETER ForceWildcardHandling
            Forces wildcard character processing even in contexts where it is not normally supported.
            May lead to unexpected behavior (not recommended).
            Cannot be combined with DisableWildcardHandling.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7BoundaryGroup -Name "Test"
            Removes the boundary group named "Test" after confirmation.

        .EXAMPLE
            Remove-CM7BoundaryGroup -Id "16777219" -Force
            Removes the boundary group with GroupID 16777219 without prompting for confirmation.

        .EXAMPLE
            Remove-CM7BoundaryGroup -Id "16777219", "16777220" -Force
            Removes multiple boundary groups by their GroupIDs without prompting.

        .EXAMPLE
            Get-CM7BoundaryGroup -Name "Test*" | Remove-CM7BoundaryGroup -Force
            Removes all boundary groups whose names start with "Test" via pipeline.

        .EXAMPLE
            Remove-CM7BoundaryGroup -Name "TestGroup" -WhatIf
            Shows what would happen without actually removing the boundary group.

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
            For more information on return object properties, see SMS_BoundaryGroup server WMI class:
            https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByInputObject')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [Alias('GroupId')]
        [string[]]$Id,

        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSObject]$InputObject,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$DisableWildcardHandling,

        [Parameter()]
        [switch]$ForceWildcardHandling
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        # Validate mutually exclusive wildcard parameters
        if ($DisableWildcardHandling -and $ForceWildcardHandling) {
            throw "DisableWildcardHandling and ForceWildcardHandling cannot be used together."
        }

        # Validate connection
        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            # ---- Resolve Boundary Group(s) ----
            $groups = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    if ($DisableWildcardHandling) {
                        # Treat name as a literal string (escape single quotes for WQL safety)
                        $safeName = $Name -replace "'", "''"
                        $query = "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$safeName'"
                    } else {
                        # Convert wildcard pattern to WQL LIKE pattern
                        $wqlPattern = $Name -replace '\*', '%' -replace '\?', '_'
                        $query = "SELECT * FROM SMS_BoundaryGroup WHERE Name LIKE '$wqlPattern'"
                    }

                    $groups = @(Get-CimInstance @cimParams -Query $query)

                    if ($groups.Count -eq 0) {
                        Write-Warning "No boundary group found with name matching '$Name'."
                        return
                    }
                }

                'ById' {
                    foreach ($groupId in $Id) {
                        $query = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"
                        $result = Get-CimInstance @cimParams -Query $query
                        if (-not $result) {
                            Write-Warning "No boundary group found with GroupID $groupId."
                        } else {
                            $groups += $result
                        }
                    }

                    if ($groups.Count -eq 0) {
                        return
                    }
                }

                'ByInputObject' {
                    # Resolve GroupID from the input object
                    $groupId = $null
                    if ($InputObject.PSObject.Properties['GroupID']) {
                        $groupId = $InputObject.GroupID
                    } elseif ($InputObject.PSObject.Properties['GroupId']) {
                        $groupId = $InputObject.GroupId
                    } else {
                        throw "InputObject does not have a GroupID property. Please provide a valid boundary group object from Get-CM7BoundaryGroup."
                    }

                    $query = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"
                    $result = Get-CimInstance @cimParams -Query $query
                    if (-not $result) {
                        Write-Warning "No boundary group found with GroupID $groupId (from InputObject)."
                        return
                    }
                    $groups = @($result)
                }
            }

            # ---- Remove each resolved boundary group ----
            foreach ($group in $groups) {
                $groupName = $group.Name
                $groupId   = $group.GroupID

                if ($Force -or $PSCmdlet.ShouldProcess("$groupName (GroupID: $groupId)", "Remove boundary group")) {
                    Write-Verbose "Removing boundary group '$groupName' (GroupID: $groupId)"
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $group
                    Write-Verbose "Boundary group '$groupName' (GroupID: $groupId) removed successfully."
                }
            }
        } catch {
            throw $_
        }
    }
}
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
function Remove-CM7CollectionMembershipRule {
    <#
        .SYNOPSIS
            Removes a membership rule from a MECM collection using CIM.

        .DESCRIPTION
            Removes one or more membership rules from an existing device or user collection in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. This function
            invokes the DeleteMembershipRule method on the SMS_Collection class via CIM.

            This is the CIM-based equivalent of the Remove-CMCollectionMembershipRule and related
            cmdlets (Remove-CMDeviceCollectionDirectMembershipRule, Remove-CMDeviceCollectionQueryMembershipRule,
            Remove-CMDeviceCollectionIncludeMembershipRule, Remove-CMDeviceCollectionExcludeMembershipRule)
            from the ConfigurationManager PowerShell module.

            Supported rule types:
            - Direct: Removes a specific resource (device/user) by ResourceId or ResourceName
            - Query: Removes a WQL query rule by RuleName
            - Include: Removes an include collection rule by IncludeCollectionId or IncludeCollectionName
            - Exclude: Removes an exclude collection rule by ExcludeCollectionId or ExcludeCollectionName

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the target collection (by name or ID)
            3. Retrieves the existing membership rules of the specified type
            4. Matches the rule(s) to remove based on the provided parameters
            5. Invokes the DeleteMembershipRule method on the SMS_Collection instance

        .PARAMETER CollectionName
            The name of the collection to remove the membership rule from.
            Mutually exclusive with CollectionId.

        .PARAMETER CollectionId
            The CollectionID of the collection to remove the membership rule from.
            Mutually exclusive with CollectionName.

        .PARAMETER RuleType
            The type of membership rule to remove. Valid values are:
            - 'Direct'  - Remove a specific resource directly
            - 'Query'   - Remove a WQL query-based rule
            - 'Include' - Remove an include collection rule
            - 'Exclude' - Remove an exclude collection rule

        .PARAMETER ResourceId
            The ResourceID of the resource to remove as a direct member.
            Required when RuleType is 'Direct' and ResourceName is not specified.
            Can be an array to remove multiple resources.

        .PARAMETER ResourceName
            The name of the resource to remove as a direct member.
            Required when RuleType is 'Direct' and ResourceId is not specified.
            Supports wildcard characters (*) for batch removal.

        .PARAMETER RuleName
            The name of the query rule to remove. Required when RuleType is 'Query'.
            Supports wildcard characters (*) for batch removal.

        .PARAMETER IncludeCollectionId
            The CollectionID of the include collection rule to remove.
            Required when RuleType is 'Include' and IncludeCollectionName is not specified.

        .PARAMETER IncludeCollectionName
            The name of the include collection rule to remove.
            Required when RuleType is 'Include' and IncludeCollectionId is not specified.

        .PARAMETER ExcludeCollectionId
            The CollectionID of the exclude collection rule to remove.
            Required when RuleType is 'Exclude' and ExcludeCollectionName is not specified.

        .PARAMETER ExcludeCollectionName
            The name of the exclude collection rule to remove.
            Required when RuleType is 'Exclude' and ExcludeCollectionId is not specified.

        .PARAMETER Force
            Suppresses confirmation prompts and removes the rule without asking.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Direct -ResourceId 16777220
            Removes the direct membership rule for resource 16777220 from "My Collection".

        .EXAMPLE
            Remove-CM7CollectionMembershipRule -CollectionId "CM101C04" -RuleType Direct -ResourceId 16777220, 16777221
            Removes multiple direct membership rules from the collection by ID.

        .EXAMPLE
            Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Direct -ResourceName "TEST-2016-1"
            Removes the direct membership rule for the named resource.

        .EXAMPLE
            Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Direct -ResourceName "TEST-*"
            Removes all direct membership rules matching the wildcard pattern.

        .EXAMPLE
            Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Query -RuleName "Test Servers"
            Removes the query membership rule named "Test Servers" from "My Collection".

        .EXAMPLE
            Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Query -RuleName "*Server*"
            Removes all query rules matching the wildcard pattern.

        .EXAMPLE
            Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Include -IncludeCollectionId "SMS00001"
            Removes the include collection membership rule referencing "All Systems".

        .EXAMPLE
            Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Include -IncludeCollectionName "All Systems"
            Removes the include collection membership rule by collection name.

        .EXAMPLE
            Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Exclude -ExcludeCollectionId "CM101C00"
            Removes the exclude collection membership rule.

        .EXAMPLE
            Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Exclude -ExcludeCollectionName "Test-Collection-Direct"
            Removes the exclude collection membership rule by collection name.

        .EXAMPLE
            Remove-CM7CollectionMembershipRule -CollectionName "My Collection" -RuleType Direct -ResourceId 16777220 -WhatIf
            Shows what would happen without actually removing the rule.

        .NOTES
            This function uses the SMS_Collection.DeleteMembershipRule WMI method via CIM.
            Requires an active connection established via Connect-CM7.

            For retrieving collection rules, see:
            - Get-CM7CollectionDirectMembershipRule
            - Get-CM7CollectionQueryMembershipRule
            - Get-CM7CollectionIncludeMembershipRule
            - Get-CM7CollectionExcludeMembershipRule
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByCollectionName')]
    param(
        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Direct', 'Query', 'Include', 'Exclude')]
        [string]$RuleType,

        [Parameter()]
        [int[]]$ResourceId,

        [Parameter()]
        [string]$ResourceName,

        [Parameter()]
        [string]$RuleName,

        [Parameter()]
        [string]$IncludeCollectionId,

        [Parameter()]
        [string]$IncludeCollectionName,

        [Parameter()]
        [string]$ExcludeCollectionId,

        [Parameter()]
        [string]$ExcludeCollectionName,

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
    }

    process {
        try {
            # ---- Validate rule-type-specific parameters ----
            switch ($RuleType) {
                'Direct' {
                    if ((-not $ResourceId -or $ResourceId.Count -eq 0) -and -not $ResourceName) {
                        throw "ResourceId or ResourceName is required when RuleType is 'Direct'."
                    }
                }
                'Query' {
                    if (-not $RuleName) {
                        throw "RuleName is required when RuleType is 'Query'."
                    }
                }
                'Include' {
                    if (-not $IncludeCollectionId -and -not $IncludeCollectionName) {
                        throw "Either IncludeCollectionId or IncludeCollectionName is required when RuleType is 'Include'."
                    }
                }
                'Exclude' {
                    if (-not $ExcludeCollectionId -and -not $ExcludeCollectionName) {
                        throw "Either ExcludeCollectionId or ExcludeCollectionName is required when RuleType is 'Exclude'."
                    }
                }
            }

            # ---- Resolve target collection ----
            $resolvedCollectionId = $null
            $resolvedCollectionName = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByCollectionName' {
                    $query = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
                    Write-Verbose "Looking up collection by name: $query"
                    $collections = @(Get-CimInstance @cimParams -Query $query)

                    if (-not $collections -or $collections.Count -eq 0) {
                        throw "Collection with name '$CollectionName' was not found."
                    }

                    if ($collections.Count -gt 1) {
                        throw "Multiple collections found with name '$CollectionName'. Please use -CollectionId instead."
                    }

                    $resolvedCollectionId = $collections[0].CollectionID
                    $resolvedCollectionName = $collections[0].Name
                }
                'ByCollectionId' {
                    $query = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$CollectionId'"
                    Write-Verbose "Looking up collection by ID: $query"
                    $collection = Get-CimInstance @cimParams -Query $query

                    if (-not $collection) {
                        throw "Collection with ID '$CollectionId' was not found."
                    }

                    $resolvedCollectionId = $collection.CollectionID
                    $resolvedCollectionName = $collection.Name
                }
            }

            Write-Verbose "Resolved target collection: '$resolvedCollectionName' ($resolvedCollectionId)"

            # ---- Build the query for method invocation ----
            $collectionQuery = "SELECT * FROM SMS_Collection WHERE CollectionID = '$resolvedCollectionId'"

            # ---- Retrieve and remove membership rule(s) based on RuleType ----
            switch ($RuleType) {
                'Direct' {
                    if ($ResourceId -and $ResourceId.Count -gt 0) {
                        # Direct removal by ResourceId - look up resource in SMS_R_System directly
                        # This avoids dependency on CollectionRules lazy property propagation
                        foreach ($resId in $ResourceId) {
                            $resourceQuery = "SELECT ResourceID, Name FROM SMS_R_System WHERE ResourceID = $resId"
                            Write-Verbose "Looking up resource: $resourceQuery"
                            $resource = Get-CimInstance @cimParams -Query $resourceQuery

                            if (-not $resource) {
                                Write-Warning "Resource with ID $resId was not found. Skipping."
                                continue
                            }

                            $resourceName = $resource.Name
                            $directRuleName = if ($RuleName) { $RuleName } else { $resourceName }

                            $actionDescription = "Remove direct membership rule for resource '$resourceName' ($resId) from collection '$resolvedCollectionName' ($resolvedCollectionId)"

                            if ($Force -or $PSCmdlet.ShouldProcess($resolvedCollectionName, $actionDescription)) {
                                Write-Verbose $actionDescription

                                $ruleProperties = @{
                                    RuleName          = $directRuleName
                                    ResourceID        = [uint32]$resId
                                    ResourceClassName = 'SMS_R_System'
                                }

                                $ruleInstance = New-CimInstance -ClassName 'SMS_CollectionRuleDirect' -Namespace $namespace -Property $ruleProperties -ClientOnly

                                $methodParams = @{
                                    collectionRule = [CimInstance]$ruleInstance
                                }

                                $result = Invoke-CimMethod @cimParams -Query $collectionQuery -MethodName 'DeleteMembershipRule' -Arguments $methodParams

                                if ($result.ReturnValue -ne 0) {
                                    Write-Warning "Failed to remove direct membership rule for resource $resId. ReturnValue: $($result.ReturnValue)"
                                } else {
                                    Write-Verbose "Successfully removed direct membership rule for resource '$resourceName' ($resId)"

                                    [PSCustomObject]@{
                                        PSTypeName     = 'MECM7.CollectionMembershipRuleResult'
                                        CollectionId   = $resolvedCollectionId
                                        CollectionName = $resolvedCollectionName
                                        RuleType       = 'Direct'
                                        RuleName       = $directRuleName
                                        ResourceId     = $resId
                                        ResourceName   = $resourceName
                                        Status         = 'Removed'
                                    }
                                }
                            }
                        }
                    } elseif ($ResourceName) {
                        if ($ResourceName -match '[*?]') {
                            # Wildcard match - need to get existing rules from the collection
                            $existingRules = Get-CM7CollectionDirectMembershipRule -CollectionId $resolvedCollectionId

                            if (-not $existingRules) {
                                Write-Warning "No direct membership rules found on collection '$resolvedCollectionName' ($resolvedCollectionId)."
                                return
                            }

                            $rulesToRemove = @($existingRules | Where-Object { $_.RuleName -like $ResourceName })

                            if ($rulesToRemove.Count -eq 0) {
                                Write-Warning "No direct membership rule found matching ResourceName '$ResourceName' on collection '$resolvedCollectionName'."
                                return
                            }

                            foreach ($rule in $rulesToRemove) {
                                $ruleResId = $rule.ResourceID
                                $ruleResName = $rule.RuleName

                                $actionDescription = "Remove direct membership rule for resource '$ruleResName' ($ruleResId) from collection '$resolvedCollectionName' ($resolvedCollectionId)"

                                if ($Force -or $PSCmdlet.ShouldProcess($resolvedCollectionName, $actionDescription)) {
                                    Write-Verbose $actionDescription

                                    $ruleProperties = @{
                                        RuleName          = $ruleResName
                                        ResourceID        = [uint32]$ruleResId
                                        ResourceClassName = 'SMS_R_System'
                                    }

                                    $ruleInstance = New-CimInstance -ClassName 'SMS_CollectionRuleDirect' -Namespace $namespace -Property $ruleProperties -ClientOnly

                                    $methodParams = @{
                                        collectionRule = [CimInstance]$ruleInstance
                                    }

                                    $result = Invoke-CimMethod @cimParams -Query $collectionQuery -MethodName 'DeleteMembershipRule' -Arguments $methodParams

                                    if ($result.ReturnValue -ne 0) {
                                        Write-Warning "Failed to remove direct membership rule for resource $ruleResId. ReturnValue: $($result.ReturnValue)"
                                    } else {
                                        Write-Verbose "Successfully removed direct membership rule for resource '$ruleResName' ($ruleResId)"

                                        [PSCustomObject]@{
                                            PSTypeName     = 'MECM7.CollectionMembershipRuleResult'
                                            CollectionId   = $resolvedCollectionId
                                            CollectionName = $resolvedCollectionName
                                            RuleType       = 'Direct'
                                            RuleName       = $ruleResName
                                            ResourceId     = $ruleResId
                                            ResourceName   = $ruleResName
                                            Status         = 'Removed'
                                        }
                                    }
                                }
                            }
                        } else {
                            # Exact name match - look up resource in SMS_R_System directly
                            $resourceQuery = "SELECT ResourceID, Name FROM SMS_R_System WHERE Name = '$ResourceName'"
                            Write-Verbose "Looking up resource by name: $resourceQuery"
                            $resources = @(Get-CimInstance @cimParams -Query $resourceQuery)

                            if (-not $resources -or $resources.Count -eq 0) {
                                Write-Warning "Resource with name '$ResourceName' was not found."
                                return
                            }

                            foreach ($resource in $resources) {
                                $resId = $resource.ResourceID
                                $resName = $resource.Name

                                $actionDescription = "Remove direct membership rule for resource '$resName' ($resId) from collection '$resolvedCollectionName' ($resolvedCollectionId)"

                                if ($Force -or $PSCmdlet.ShouldProcess($resolvedCollectionName, $actionDescription)) {
                                    Write-Verbose $actionDescription

                                    $ruleProperties = @{
                                        RuleName          = $resName
                                        ResourceID        = [uint32]$resId
                                        ResourceClassName = 'SMS_R_System'
                                    }

                                    $ruleInstance = New-CimInstance -ClassName 'SMS_CollectionRuleDirect' -Namespace $namespace -Property $ruleProperties -ClientOnly

                                    $methodParams = @{
                                        collectionRule = [CimInstance]$ruleInstance
                                    }

                                    $result = Invoke-CimMethod @cimParams -Query $collectionQuery -MethodName 'DeleteMembershipRule' -Arguments $methodParams

                                    if ($result.ReturnValue -ne 0) {
                                        Write-Warning "Failed to remove direct membership rule for resource $resId. ReturnValue: $($result.ReturnValue)"
                                    } else {
                                        Write-Verbose "Successfully removed direct membership rule for resource '$resName' ($resId)"

                                        [PSCustomObject]@{
                                            PSTypeName     = 'MECM7.CollectionMembershipRuleResult'
                                            CollectionId   = $resolvedCollectionId
                                            CollectionName = $resolvedCollectionName
                                            RuleType       = 'Direct'
                                            RuleName       = $resName
                                            ResourceId     = $resId
                                            ResourceName   = $resName
                                            Status         = 'Removed'
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                'Query' {
                    # Get existing query rules from the collection
                    $existingRules = Get-CM7CollectionQueryMembershipRule -CollectionId $resolvedCollectionId

                    if (-not $existingRules) {
                        Write-Warning "No query membership rules found on collection '$resolvedCollectionName' ($resolvedCollectionId)."
                        return
                    }

                    # Determine which rules to remove
                    if ($RuleName -match '[*?]') {
                        $rulesToRemove = @($existingRules | Where-Object { $_.RuleName -like $RuleName })
                    } else {
                        $rulesToRemove = @($existingRules | Where-Object { $_.RuleName -eq $RuleName })
                    }

                    if ($rulesToRemove.Count -eq 0) {
                        Write-Warning "No query membership rule found matching RuleName '$RuleName' on collection '$resolvedCollectionName'."
                        return
                    }

                    foreach ($rule in $rulesToRemove) {
                        $queryRuleName = $rule.RuleName
                        $queryExpression = $rule.QueryExpression
                        $queryId = if ($rule.PSObject.Properties['QueryID']) { $rule.QueryID } else { 0 }

                        $actionDescription = "Remove query membership rule '$queryRuleName' from collection '$resolvedCollectionName' ($resolvedCollectionId)"

                        if ($Force -or $PSCmdlet.ShouldProcess($resolvedCollectionName, $actionDescription)) {
                            Write-Verbose $actionDescription

                            # Create the SMS_CollectionRuleQuery embedded instance for deletion
                            $ruleProperties = @{
                                RuleName        = $queryRuleName
                                QueryExpression = $queryExpression
                                QueryID         = [uint32]$queryId
                            }

                            $ruleInstance = New-CimInstance -ClassName 'SMS_CollectionRuleQuery' -Namespace $namespace -Property $ruleProperties -ClientOnly

                            # Invoke the DeleteMembershipRule method
                            $methodParams = @{
                                collectionRule = [CimInstance]$ruleInstance
                            }

                            $result = Invoke-CimMethod @cimParams -Query $collectionQuery -MethodName 'DeleteMembershipRule' -Arguments $methodParams

                            if ($result.ReturnValue -ne 0) {
                                Write-Warning "Failed to remove query membership rule '$queryRuleName'. ReturnValue: $($result.ReturnValue)"
                            } else {
                                Write-Verbose "Successfully removed query membership rule '$queryRuleName'"

                                [PSCustomObject]@{
                                    PSTypeName      = 'MECM7.CollectionMembershipRuleResult'
                                    CollectionId    = $resolvedCollectionId
                                    CollectionName  = $resolvedCollectionName
                                    RuleType        = 'Query'
                                    RuleName        = $queryRuleName
                                    QueryExpression = $queryExpression
                                    Status          = 'Removed'
                                }
                            }
                        }
                    }
                }

                'Include' {
                    # Resolve include collection if specified by name
                    $resolvedIncludeId = $null
                    $resolvedIncludeName = $null

                    if ($IncludeCollectionId) {
                        $includeQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$IncludeCollectionId'"
                        Write-Verbose "Looking up include collection by ID: $includeQuery"
                        $includeCollection = Get-CimInstance @cimParams -Query $includeQuery

                        if (-not $includeCollection) {
                            throw "Include collection with ID '$IncludeCollectionId' was not found."
                        }

                        $resolvedIncludeId = $includeCollection.CollectionID
                        $resolvedIncludeName = $includeCollection.Name
                    } elseif ($IncludeCollectionName) {
                        $includeQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$IncludeCollectionName'"
                        Write-Verbose "Looking up include collection by name: $includeQuery"
                        $includeCollections = @(Get-CimInstance @cimParams -Query $includeQuery)

                        if (-not $includeCollections -or $includeCollections.Count -eq 0) {
                            throw "Include collection with name '$IncludeCollectionName' was not found."
                        }

                        if ($includeCollections.Count -gt 1) {
                            throw "Multiple collections found with name '$IncludeCollectionName'. Please use -IncludeCollectionId instead."
                        }

                        $resolvedIncludeId = $includeCollections[0].CollectionID
                        $resolvedIncludeName = $includeCollections[0].Name
                    }

                    # Construct the rule instance directly using the resolved collection name
                    # This avoids dependency on CollectionRules lazy property propagation
                    $includeRuleName = if ($RuleName) { $RuleName } else { $resolvedIncludeName }

                    $actionDescription = "Remove include membership rule for collection '$resolvedIncludeName' ($resolvedIncludeId) from collection '$resolvedCollectionName' ($resolvedCollectionId)"

                    if ($Force -or $PSCmdlet.ShouldProcess($resolvedCollectionName, $actionDescription)) {
                        Write-Verbose $actionDescription

                        # Create the SMS_CollectionRuleIncludeCollection embedded instance for deletion
                        $ruleProperties = @{
                            RuleName            = $includeRuleName
                            IncludeCollectionID = $resolvedIncludeId
                        }

                        $ruleInstance = New-CimInstance -ClassName 'SMS_CollectionRuleIncludeCollection' -Namespace $namespace -Property $ruleProperties -ClientOnly

                        # Invoke the DeleteMembershipRule method
                        $methodParams = @{
                            collectionRule = [CimInstance]$ruleInstance
                        }

                        $result = Invoke-CimMethod @cimParams -Query $collectionQuery -MethodName 'DeleteMembershipRule' -Arguments $methodParams

                        if ($result.ReturnValue -ne 0) {
                            Write-Warning "Failed to remove include membership rule for '$resolvedIncludeName'. ReturnValue: $($result.ReturnValue)"
                        } else {
                            Write-Verbose "Successfully removed include membership rule for '$resolvedIncludeName' ($resolvedIncludeId)"

                            [PSCustomObject]@{
                                PSTypeName            = 'MECM7.CollectionMembershipRuleResult'
                                CollectionId          = $resolvedCollectionId
                                CollectionName        = $resolvedCollectionName
                                RuleType              = 'Include'
                                RuleName              = $includeRuleName
                                IncludeCollectionId   = $resolvedIncludeId
                                IncludeCollectionName = $resolvedIncludeName
                                Status                = 'Removed'
                            }
                        }
                    }
                }

                'Exclude' {
                    # Resolve exclude collection if specified by name
                    $resolvedExcludeId = $null
                    $resolvedExcludeName = $null

                    if ($ExcludeCollectionId) {
                        $excludeQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$ExcludeCollectionId'"
                        Write-Verbose "Looking up exclude collection by ID: $excludeQuery"
                        $excludeCollection = Get-CimInstance @cimParams -Query $excludeQuery

                        if (-not $excludeCollection) {
                            throw "Exclude collection with ID '$ExcludeCollectionId' was not found."
                        }

                        $resolvedExcludeId = $excludeCollection.CollectionID
                        $resolvedExcludeName = $excludeCollection.Name
                    } elseif ($ExcludeCollectionName) {
                        $excludeQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$ExcludeCollectionName'"
                        Write-Verbose "Looking up exclude collection by name: $excludeQuery"
                        $excludeCollections = @(Get-CimInstance @cimParams -Query $excludeQuery)

                        if (-not $excludeCollections -or $excludeCollections.Count -eq 0) {
                            throw "Exclude collection with name '$ExcludeCollectionName' was not found."
                        }

                        if ($excludeCollections.Count -gt 1) {
                            throw "Multiple collections found with name '$ExcludeCollectionName'. Please use -ExcludeCollectionId instead."
                        }

                        $resolvedExcludeId = $excludeCollections[0].CollectionID
                        $resolvedExcludeName = $excludeCollections[0].Name
                    }

                    # Construct the rule instance directly using the resolved collection name
                    # This avoids dependency on CollectionRules lazy property propagation
                    $excludeRuleName = if ($RuleName) { $RuleName } else { $resolvedExcludeName }

                    $actionDescription = "Remove exclude membership rule for collection '$resolvedExcludeName' ($resolvedExcludeId) from collection '$resolvedCollectionName' ($resolvedCollectionId)"

                    if ($Force -or $PSCmdlet.ShouldProcess($resolvedCollectionName, $actionDescription)) {
                        Write-Verbose $actionDescription

                        # Create the SMS_CollectionRuleExcludeCollection embedded instance for deletion
                        $ruleProperties = @{
                            RuleName            = $excludeRuleName
                            ExcludeCollectionID = $resolvedExcludeId
                        }

                        $ruleInstance = New-CimInstance -ClassName 'SMS_CollectionRuleExcludeCollection' -Namespace $namespace -Property $ruleProperties -ClientOnly

                        # Invoke the DeleteMembershipRule method
                        $methodParams = @{
                            collectionRule = [CimInstance]$ruleInstance
                        }

                        $result = Invoke-CimMethod @cimParams -Query $collectionQuery -MethodName 'DeleteMembershipRule' -Arguments $methodParams

                        if ($result.ReturnValue -ne 0) {
                            Write-Warning "Failed to remove exclude membership rule for '$resolvedExcludeName'. ReturnValue: $($result.ReturnValue)"
                        } else {
                            Write-Verbose "Successfully removed exclude membership rule for '$resolvedExcludeName' ($resolvedExcludeId)"

                            [PSCustomObject]@{
                                PSTypeName            = 'MECM7.CollectionMembershipRuleResult'
                                CollectionId          = $resolvedCollectionId
                                CollectionName        = $resolvedCollectionName
                                RuleType              = 'Exclude'
                                RuleName              = $excludeRuleName
                                ExcludeCollectionId   = $resolvedExcludeId
                                ExcludeCollectionName = $resolvedExcludeName
                                Status                = 'Removed'
                            }
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
function Remove-CM7DeviceCollectionVariable {
    <#
        .SYNOPSIS
            Removes a collection variable from a MECM device collection using CIM.

        .DESCRIPTION
            Removes one or more collection variables from a specified device collection in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. Collection variables are
            stored in the SMS_CollectionSettings WMI class and can be used during task sequence
            execution and other MECM operations.

            This is the CIM-based equivalent of the Remove-CMDeviceCollectionVariable cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the collection (by name or ID) and verifies it is a device collection
            3. Retrieves existing SMS_CollectionSettings and loads the CollectionVariables lazy property
            4. Finds the matching variable(s) by exact name or wildcard pattern
            5. Removes the matching variable(s) from the array
            6. Writes the updated settings back via CIM

        .PARAMETER CollectionName
            Specifies the name of the device collection to remove the variable from.
            Mutually exclusive with CollectionId.

        .PARAMETER CollectionId
            Specifies the CollectionID of the device collection to remove the variable from.
            Mutually exclusive with CollectionName.

        .PARAMETER VariableName
            Specifies the name of the variable to remove. Supports wildcard characters (* and ?)
            to remove multiple variables matching a pattern.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "OSDComputerName"
            Removes the collection variable named "OSDComputerName" from the specified collection.

        .EXAMPLE
            Remove-CM7DeviceCollectionVariable -CollectionId "CM101C00" -VariableName "InstallSoftware" -Force
            Removes the collection variable from the collection identified by its CollectionID without prompting for confirmation.

        .EXAMPLE
            Remove-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "Test-*"
            Removes all collection variables whose names match the wildcard pattern "Test-*".

        .EXAMPLE
            Remove-CM7DeviceCollectionVariable -CollectionName "Test-Collection-Direct" -VariableName "OldVar" -WhatIf
            Shows what would happen without actually removing the variable.

        .NOTES
            This function is the CIM-based equivalent of the Remove-CMDeviceCollectionVariable cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The CollectionVariables property of SMS_CollectionSettings is a lazy property,
            so the function retrieves the full instance to access it.

            If the variable does not exist, a warning is written but no error is thrown.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByCollectionName')]
    param(
        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$VariableName,

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
    }

    process {
        try {
            # ---- Resolve Collection ----
            $collectionIdToUse = $null
            $collectionDisplayName = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByCollectionName' {
                    $collectionQuery = "SELECT CollectionID, Name, CollectionType FROM SMS_Collection WHERE Name = '$CollectionName'"
                    Write-Verbose "Resolving collection name: $collectionQuery"
                    $collection = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collection) {
                        throw "Collection '$CollectionName' not found."
                    }

                    if (@($collection).Count -gt 1) {
                        throw "Multiple collections found with name '$CollectionName'. Please use -CollectionId instead."
                    }

                    # Verify it is a device collection (CollectionType = 2)
                    if ($collection.CollectionType -ne 2) {
                        throw "Collection '$CollectionName' is not a device collection. This function only supports device collections."
                    }

                    $collectionIdToUse = $collection.CollectionID
                    $collectionDisplayName = $CollectionName
                    Write-Verbose "Resolved collection '$CollectionName' to ID '$collectionIdToUse'"
                }
                'ByCollectionId' {
                    # Validate collection exists and is a device collection
                    $collectionQuery = "SELECT CollectionID, Name, CollectionType FROM SMS_Collection WHERE CollectionID = '$CollectionId'"
                    Write-Verbose "Validating collection: $collectionQuery"
                    $collection = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collection) {
                        throw "Collection with ID '$CollectionId' not found."
                    }

                    if ($collection.CollectionType -ne 2) {
                        throw "Collection '$CollectionId' is not a device collection. This function only supports device collections."
                    }

                    $collectionIdToUse = $CollectionId
                    $collectionDisplayName = $collection.Name
                    Write-Verbose "Collection '$collectionDisplayName' ($CollectionId) validated."
                }
            }

            # ---- Retrieve SMS_CollectionSettings ----
            $settingsQuery = "SELECT * FROM SMS_CollectionSettings WHERE CollectionID = '$collectionIdToUse'"
            Write-Verbose "Querying collection settings: $settingsQuery"
            $settings = Get-CimInstance @cimParams -Query $settingsQuery

            if (-not $settings) {
                Write-Warning "No collection settings found for collection '$collectionDisplayName' ($collectionIdToUse). The collection has no variables."
                return
            }

            # Retrieve full instance to load lazy properties (CollectionVariables)
            Write-Verbose "Retrieving full instance to load lazy property CollectionVariables..."
            $fullSettings = $settings | Get-CimInstance

            if (-not $fullSettings) {
                throw "Could not retrieve full collection settings for CollectionID '$collectionIdToUse'."
            }

            # ---- Get existing variables ----
            $existingVariables = @()
            if ($fullSettings.CollectionVariables) {
                $existingVariables = @($fullSettings.CollectionVariables)
            }

            if ($existingVariables.Count -eq 0) {
                Write-Warning "No collection variables found for collection '$collectionDisplayName' ($collectionIdToUse)."
                return
            }

            # ---- Find matching variables ----
            $isWildcard = $VariableName -match '[*?]'

            if ($isWildcard) {
                $matchingVars = @($existingVariables | Where-Object { $_.Name -like $VariableName })
            } else {
                $matchingVars = @($existingVariables | Where-Object { $_.Name -eq $VariableName })
            }

            if ($matchingVars.Count -eq 0) {
                Write-Warning "Variable '$VariableName' not found on collection '$collectionDisplayName' ($collectionIdToUse)."
                return
            }

            Write-Verbose "Found $($matchingVars.Count) variable(s) matching '$VariableName'."

            # ---- Capture match data before CIM modification ----
            # CIM embedded instances may become stale after modifying the parent
            # instance, so we store the data in plain PowerShell objects first.
            $removedVarInfo = @($matchingVars | ForEach-Object {
                @{
                    Name     = [string]$_.Name
                    Value    = [string]$_.Value
                    IsMasked = [bool]$_.IsMasked
                }
            })

            # ---- Build updated variables list (excluding matched ones) ----
            $matchingNames = $removedVarInfo | ForEach-Object { $_.Name }
            $updatedVariables = [System.Collections.Generic.List[CimInstance]]::new()

            foreach ($v in $existingVariables) {
                if ($v.Name -notin $matchingNames) {
                    $updatedVariables.Add($v)
                }
            }

            # ---- ShouldProcess ----
            $variableNameDisplay = ($matchingNames -join ', ')
            $actionDescription = "Remove variable(s) '$variableNameDisplay' from collection '$collectionDisplayName' ($collectionIdToUse)"

            if ($Force -or $PSCmdlet.ShouldProcess($actionDescription, "Remove-CM7DeviceCollectionVariable")) {

                # Modify the CollectionVariables property and commit
                Write-Verbose "Updating SMS_CollectionSettings for CollectionID '$collectionIdToUse'..."

                if ($updatedVariables.Count -eq 0) {
                    # All variables removed - set to empty array
                    $fullSettings.CimInstanceProperties['CollectionVariables'].Value = [CimInstance[]]@()
                } else {
                    $fullSettings.CimInstanceProperties['CollectionVariables'].Value = [CimInstance[]]$updatedVariables.ToArray()
                }

                $null = ($fullSettings | Set-CimInstance)

                Write-Verbose "Successfully removed variable(s) '$variableNameDisplay' from collection '$collectionDisplayName' ($collectionIdToUse)."

                # Return info about removed variables using pre-captured data
                foreach ($info in $removedVarInfo) {
                    [PSCustomObject]@{
                        PSTypeName   = 'MECM7.RemovedCollectionVariable'
                        Name         = $info.Name
                        Value        = $info.Value
                        IsMasked     = $info.IsMasked
                        CollectionId = $collectionIdToUse
                        Status       = 'Removed'
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
function Remove-CM7DeviceVariable {
    <#
        .SYNOPSIS
            Removes a device variable from a MECM device using CIM.

        .DESCRIPTION
            Removes one or more device variables from a specified device in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. Device variables are
            stored in the SMS_MachineSettings WMI class and can be used during task sequence
            execution and other MECM operations.

            This is the CIM-based equivalent of the Remove-CMDeviceVariable cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the device (by name or ResourceId)
            3. Retrieves existing SMS_MachineSettings and loads the MachineVariables lazy property
            4. Finds the matching variable(s) by exact name or wildcard pattern
            5. Removes the matching variable(s) from the array
            6. Writes the updated settings back via CIM

        .PARAMETER DeviceName
            Specifies the name of the device to remove the variable from.
            Mutually exclusive with ResourceId.

        .PARAMETER ResourceId
            Specifies the ResourceID of the device to remove the variable from.
            Mutually exclusive with DeviceName.

        .PARAMETER VariableName
            Specifies the name of the variable to remove. Supports wildcard characters (* and ?)
            to remove multiple variables matching a pattern.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "OSDComputerName"
            Removes the device variable named "OSDComputerName" from the specified device.

        .EXAMPLE
            Remove-CM7DeviceVariable -ResourceId 16893210 -VariableName "InstallSoftware" -Force
            Removes the device variable from the device identified by its ResourceID without prompting for confirmation.

        .EXAMPLE
            Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "Test*"
            Removes all device variables whose names match the wildcard pattern "Test*".

        .EXAMPLE
            Remove-CM7DeviceVariable -DeviceName "Test-2016-1" -VariableName "OldVar" -WhatIf
            Shows what would happen without actually removing the variable.

        .NOTES
            This function is the CIM-based equivalent of the Remove-CMDeviceVariable cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The MachineVariables property of SMS_MachineSettings is a lazy property,
            so the function retrieves the full instance to access it.

            If the variable does not exist, a warning is written but no error is thrown.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByDeviceName')]
    param(
        [Parameter(ParameterSetName = 'ByDeviceName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(ParameterSetName = 'ByResourceId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$ResourceId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$VariableName,

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
    }

    process {
        try {
            # ---- Resolve Device ----
            $resourceIdToUse = $null
            $deviceDisplayName = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByDeviceName' {
                    $deviceQuery = "SELECT ResourceID, Name FROM SMS_R_System WHERE Name = '$DeviceName'"
                    Write-Verbose "Resolving device name: $deviceQuery"
                    $device = Get-CimInstance @cimParams -Query $deviceQuery

                    if (-not $device) {
                        throw "Device '$DeviceName' not found."
                    }

                    if (@($device).Count -gt 1) {
                        Write-Warning "Multiple devices found with name '$DeviceName'. Using the first match (ResourceID: $($device[0].ResourceID))."
                        $resourceIdToUse = $device[0].ResourceID
                    } else {
                        $resourceIdToUse = $device.ResourceID
                    }

                    $deviceDisplayName = $DeviceName
                    Write-Verbose "Resolved device '$DeviceName' to ResourceID '$resourceIdToUse'"
                }
                'ByResourceId' {
                    # Validate device exists
                    $deviceQuery = "SELECT ResourceID, Name FROM SMS_R_System WHERE ResourceID = $ResourceId"
                    Write-Verbose "Validating device: $deviceQuery"
                    $device = Get-CimInstance @cimParams -Query $deviceQuery

                    if (-not $device) {
                        throw "Device with ResourceID '$ResourceId' not found."
                    }

                    $resourceIdToUse = $ResourceId
                    $deviceDisplayName = $device.Name
                    Write-Verbose "Device '$deviceDisplayName' (ResourceID: $ResourceId) validated."
                }
            }

            # ---- Retrieve SMS_MachineSettings ----
            $settingsQuery = "SELECT * FROM SMS_MachineSettings WHERE ResourceID = $resourceIdToUse"
            Write-Verbose "Querying machine settings: $settingsQuery"
            $settings = Get-CimInstance @cimParams -Query $settingsQuery

            if (-not $settings) {
                Write-Warning "No machine settings found for device '$deviceDisplayName' (ResourceID: $resourceIdToUse). The device has no variables."
                return
            }

            # Retrieve full instance to load lazy properties (MachineVariables)
            Write-Verbose "Retrieving full instance to load lazy property MachineVariables..."
            $fullSettings = $settings | Get-CimInstance

            if (-not $fullSettings) {
                throw "Could not retrieve full machine settings for ResourceID '$resourceIdToUse'."
            }

            # ---- Get existing variables ----
            $existingVariables = @()
            if ($fullSettings.MachineVariables) {
                $existingVariables = @($fullSettings.MachineVariables)
            }

            if ($existingVariables.Count -eq 0) {
                Write-Warning "No device variables found for device '$deviceDisplayName' (ResourceID: $resourceIdToUse)."
                return
            }

            # ---- Find matching variables ----
            $isWildcard = $VariableName -match '[*?]'

            if ($isWildcard) {
                $matchingVars = @($existingVariables | Where-Object { $_.Name -like $VariableName })
            } else {
                $matchingVars = @($existingVariables | Where-Object { $_.Name -eq $VariableName })
            }

            if ($matchingVars.Count -eq 0) {
                Write-Warning "Variable '$VariableName' not found on device '$deviceDisplayName' (ResourceID: $resourceIdToUse)."
                return
            }

            Write-Verbose "Found $($matchingVars.Count) variable(s) matching '$VariableName'."

            # ---- Capture match data before CIM modification ----
            # CIM embedded instances may become stale after modifying the parent
            # instance, so we store the data in plain PowerShell objects first.
            $removedVarInfo = @($matchingVars | ForEach-Object {
                @{
                    Name     = [string]$_.Name
                    Value    = [string]$_.Value
                    IsMasked = [bool]$_.IsMasked
                }
            })

            # ---- Build updated variables list (excluding matched ones) ----
            $matchingNames = $removedVarInfo | ForEach-Object { $_.Name }
            $updatedVariables = [System.Collections.Generic.List[CimInstance]]::new()

            foreach ($v in $existingVariables) {
                if ($v.Name -notin $matchingNames) {
                    $updatedVariables.Add($v)
                }
            }

            # ---- ShouldProcess ----
            $variableNameDisplay = ($matchingNames -join ', ')
            $actionDescription = "Remove variable(s) '$variableNameDisplay' from device '$deviceDisplayName' (ResourceID: $resourceIdToUse)"

            if ($Force -or $PSCmdlet.ShouldProcess($actionDescription, "Remove-CM7DeviceVariable")) {

                # Modify the MachineVariables property and commit
                Write-Verbose "Updating SMS_MachineSettings for ResourceID '$resourceIdToUse'..."

                if ($updatedVariables.Count -eq 0) {
                    # All variables removed - set to empty array
                    $fullSettings.CimInstanceProperties['MachineVariables'].Value = [CimInstance[]]@()
                } else {
                    $fullSettings.CimInstanceProperties['MachineVariables'].Value = [CimInstance[]]$updatedVariables.ToArray()
                }

                $null = ($fullSettings | Set-CimInstance)

                Write-Verbose "Successfully removed variable(s) '$variableNameDisplay' from device '$deviceDisplayName' (ResourceID: $resourceIdToUse)."

                # Return info about removed variables using pre-captured data
                foreach ($info in $removedVarInfo) {
                    [PSCustomObject]@{
                        PSTypeName = 'MECM7.RemovedDeviceVariable'
                        Name       = $info.Name
                        Value      = $info.Value
                        IsMasked   = $info.IsMasked
                        ResourceId = $resourceIdToUse
                        Status     = 'Removed'
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
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
function Remove-CM7MaintenanceWindow {
    <#
        .SYNOPSIS
            Removes a maintenance window from a MECM collection using CIM.

        .DESCRIPTION
            Removes one or more maintenance windows (service windows) from a specified collection in
            Microsoft Endpoint Configuration Manager (MECM) using CIM. Maintenance windows
            define scheduled time periods during which deployments and other operations can
            be applied to collection members.

            This is the CIM-based equivalent of the Remove-CMMaintenanceWindow cmdlet from the
            ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the collection (by name or ID)
            3. Retrieves existing SMS_CollectionSettings and loads the ServiceWindows lazy property
            4. Finds the matching maintenance window(s) by exact name, wildcard pattern, or ServiceWindowID
            5. Removes the matching window(s) from the array
            6. Writes the updated settings back via CIM

        .PARAMETER CollectionName
            Specifies the name of the collection to remove the maintenance window from.
            Mutually exclusive with CollectionId.

        .PARAMETER CollectionId
            Specifies the CollectionID of the collection to remove the maintenance window from.
            Mutually exclusive with CollectionName.

        .PARAMETER MaintenanceWindowName
            Specifies the name of the maintenance window to remove. Supports wildcard characters (* and ?)
            to remove multiple maintenance windows matching a pattern.
            When used together with ServiceWindowID, both criteria must match.

        .PARAMETER ServiceWindowID
            Specifies the unique ServiceWindowID (GUID) of the maintenance window to remove.
            When used together with MaintenanceWindowName, both criteria must match.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Daily MW"
            Removes the maintenance window named "Daily MW" from the specified collection.

        .EXAMPLE
            Remove-CM7MaintenanceWindow -CollectionId "CM101C00" -MaintenanceWindowName "Weekly Updates" -Force
            Removes the maintenance window from the collection identified by its CollectionID without prompting for confirmation.

        .EXAMPLE
            Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Test-*"
            Removes all maintenance windows whose names match the wildcard pattern "Test-*".

        .EXAMPLE
            Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -ServiceWindowID "a1b2c3d4-e5f6-7890-abcd-ef1234567890" -Force
            Removes the maintenance window with the specified ServiceWindowID.

        .EXAMPLE
            Remove-CM7MaintenanceWindow -CollectionName "Test-Collection-Direct" -MaintenanceWindowName "Old MW" -WhatIf
            Shows what would happen without actually removing the maintenance window.

        .NOTES
            This function is the CIM-based equivalent of the Remove-CMMaintenanceWindow cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries
            over WinRM instead of requiring the ConfigMgr console or PowerShell drive.

            The ServiceWindows property of SMS_CollectionSettings is a lazy property,
            so the function retrieves the full instance to access it.

            If the maintenance window does not exist, a warning is written but no error is thrown.

            Maintenance Window Types (ServiceWindowType):
                1 = All Deployments (Any)
                4 = Software Updates Only
                5 = Task Sequences Only
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByCollectionName')]
    param(
        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByCollectionId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$MaintenanceWindowName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ServiceWindowID,

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

        # At least one identification parameter must be provided
        if (-not $PSBoundParameters.ContainsKey('MaintenanceWindowName') -and -not $PSBoundParameters.ContainsKey('ServiceWindowID')) {
            throw "You must specify at least one of -MaintenanceWindowName or -ServiceWindowID to identify the maintenance window(s) to remove."
        }

        # Determine the namespace
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"

        # Build common CIM parameters
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Reverse maps for output
        $serviceWindowTypeMap = @{
            1 = 'General'
            4 = 'SoftwareUpdatesOnly'
            5 = 'TaskSequencesOnly'
            6 = 'General'
        }

        $recurrenceTypeMap = @{
            1 = 'None'
            2 = 'Daily'
            3 = 'Weekly'
            4 = 'MonthlyByWeekday'
            5 = 'MonthlyByDate'
        }
    }

    process {
        try {
            # ---- Resolve Collection ----
            $collectionIdToUse = $null
            $collectionDisplayName = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByCollectionName' {
                    $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
                    Write-Verbose "Resolving collection name: $collectionQuery"
                    $collection = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collection) {
                        throw "Collection '$CollectionName' not found."
                    }

                    if (@($collection).Count -gt 1) {
                        throw "Multiple collections found with name '$CollectionName'. Please use -CollectionId instead."
                    }

                    $collectionIdToUse = $collection.CollectionID
                    $collectionDisplayName = $CollectionName
                    Write-Verbose "Resolved collection '$CollectionName' to ID '$collectionIdToUse'"
                }
                'ByCollectionId' {
                    $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$CollectionId'"
                    Write-Verbose "Validating collection: $collectionQuery"
                    $collection = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collection) {
                        throw "Collection with ID '$CollectionId' not found."
                    }

                    $collectionIdToUse = $CollectionId
                    $collectionDisplayName = $collection.Name
                    Write-Verbose "Collection '$collectionDisplayName' ($CollectionId) validated."
                }
            }

            # ---- Retrieve SMS_CollectionSettings ----
            $settingsQuery = "SELECT * FROM SMS_CollectionSettings WHERE CollectionID = '$collectionIdToUse'"
            Write-Verbose "Querying collection settings: $settingsQuery"
            $settings = Get-CimInstance @cimParams -Query $settingsQuery

            if (-not $settings) {
                Write-Warning "No collection settings found for collection '$collectionDisplayName' ($collectionIdToUse). The collection has no maintenance windows."
                return
            }

            # Retrieve full instance to load lazy properties (ServiceWindows)
            Write-Verbose "Retrieving full instance to load lazy property ServiceWindows..."
            $fullSettings = $settings | Get-CimInstance

            if (-not $fullSettings) {
                throw "Could not retrieve full collection settings for CollectionID '$collectionIdToUse'."
            }

            # ---- Get existing service windows ----
            $existingWindows = @()
            if ($fullSettings.ServiceWindows) {
                $existingWindows = @($fullSettings.ServiceWindows)
            }

            if ($existingWindows.Count -eq 0) {
                Write-Warning "No maintenance windows found for collection '$collectionDisplayName' ($collectionIdToUse)."
                return
            }

            # ---- Find matching maintenance windows ----
            $matchingWindows = $existingWindows

            if ($PSBoundParameters.ContainsKey('MaintenanceWindowName')) {
                $isWildcard = $MaintenanceWindowName -match '[*?]'
                if ($isWildcard) {
                    $matchingWindows = @($matchingWindows | Where-Object { $_.Name -like $MaintenanceWindowName })
                } else {
                    $matchingWindows = @($matchingWindows | Where-Object { $_.Name -eq $MaintenanceWindowName })
                }
            }

            if ($PSBoundParameters.ContainsKey('ServiceWindowID')) {
                $matchingWindows = @($matchingWindows | Where-Object { $_.ServiceWindowID -eq $ServiceWindowID })
            }

            if ($matchingWindows.Count -eq 0) {
                $filterDesc = @()
                if ($PSBoundParameters.ContainsKey('MaintenanceWindowName')) { $filterDesc += "Name='$MaintenanceWindowName'" }
                if ($PSBoundParameters.ContainsKey('ServiceWindowID')) { $filterDesc += "ServiceWindowID='$ServiceWindowID'" }
                Write-Warning "No maintenance window matching ($($filterDesc -join ' AND ')) found on collection '$collectionDisplayName' ($collectionIdToUse)."
                return
            }

            Write-Verbose "Found $($matchingWindows.Count) maintenance window(s) matching the criteria."

            # ---- Capture match data before CIM modification ----
            # CIM embedded instances may become stale after modifying the parent
            # instance, so we store the data in plain PowerShell objects first.
            $removedWindowInfo = @($matchingWindows | ForEach-Object {
                $windowType = if ($serviceWindowTypeMap.ContainsKey([int]$_.ServiceWindowType)) {
                    $serviceWindowTypeMap[[int]$_.ServiceWindowType]
                } else { "Unknown ($($_.ServiceWindowType))" }

                $recurrence = if ($recurrenceTypeMap.ContainsKey([int]$_.RecurrenceType)) {
                    $recurrenceTypeMap[[int]$_.RecurrenceType]
                } else { "Unknown ($($_.RecurrenceType))" }

                @{
                    Name                   = [string]$_.Name
                    Description            = [string]$_.Description
                    ServiceWindowID        = [string]$_.ServiceWindowID
                    IsEnabled              = [bool]$_.IsEnabled
                    ServiceWindowType      = $windowType
                    StartTime              = $_.StartTime
                    Duration               = $_.Duration
                    RecurrenceType         = $recurrence
                    IsGMT                  = [bool]$_.IsGMT
                    ServiceWindowSchedules = [string]$_.ServiceWindowSchedules
                }
            })

            # ---- Build updated windows list (excluding matched ones) ----
            $matchingIDs = $removedWindowInfo | ForEach-Object { $_.ServiceWindowID }
            $updatedWindows = [System.Collections.Generic.List[CimInstance]]::new()

            foreach ($w in $existingWindows) {
                if ($w.ServiceWindowID -notin $matchingIDs) {
                    $updatedWindows.Add($w)
                }
            }

            # ---- ShouldProcess ----
            $windowNameDisplay = ($removedWindowInfo | ForEach-Object { $_.Name }) -join ', '
            $actionDescription = "Remove maintenance window(s) '$windowNameDisplay' from collection '$collectionDisplayName' ($collectionIdToUse)"

            if ($Force -or $PSCmdlet.ShouldProcess($actionDescription, "Remove-CM7MaintenanceWindow")) {

                # Modify the ServiceWindows property and commit
                Write-Verbose "Updating SMS_CollectionSettings for CollectionID '$collectionIdToUse'..."

                if ($updatedWindows.Count -eq 0) {
                    # All windows removed - set to empty array
                    $fullSettings.CimInstanceProperties['ServiceWindows'].Value = [CimInstance[]]@()
                } else {
                    $fullSettings.CimInstanceProperties['ServiceWindows'].Value = [CimInstance[]]$updatedWindows.ToArray()
                }

                $null = ($fullSettings | Set-CimInstance)

                Write-Verbose "Successfully removed maintenance window(s) '$windowNameDisplay' from collection '$collectionDisplayName' ($collectionIdToUse)."

                # Return info about removed maintenance windows using pre-captured data
                foreach ($info in $removedWindowInfo) {
                    [PSCustomObject]@{
                        PSTypeName             = 'MECM7.RemovedMaintenanceWindow'
                        Name                   = $info.Name
                        Description            = $info.Description
                        ServiceWindowID        = $info.ServiceWindowID
                        IsEnabled              = $info.IsEnabled
                        ServiceWindowType      = $info.ServiceWindowType
                        StartTime              = $info.StartTime
                        Duration               = $info.Duration
                        RecurrenceType         = $info.RecurrenceType
                        IsGMT                  = $info.IsGMT
                        ServiceWindowSchedules = $info.ServiceWindowSchedules
                        CollectionID           = $collectionIdToUse
                        Status                 = 'Removed'
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Remove-CM7SoftwareUpdateDeployment {
    <#
        .SYNOPSIS
            Removes a software update deployment from a collection using CIM connectivity.

        .DESCRIPTION
            Removes a deployment of a software update group from a device collection in MECM, using CIM. This is the CIM-based equivalent of Remove-CMSoftwareUpdateDeployment from the ConfigurationManager module.

        .PARAMETER SoftwareUpdateGroupName
            The name of the software update group whose deployment should be removed.

        .PARAMETER SoftwareUpdateGroupID
            The CI_ID of the software update group whose deployment should be removed.

        .PARAMETER CollectionName
            The name of the collection from which to remove the deployment.

        .PARAMETER CollectionID
            The CollectionID of the collection from which to remove the deployment.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .EXAMPLE
            Remove-CM7SoftwareUpdateDeployment -SoftwareUpdateGroupName "Test-SUG" -CollectionName "Test-Collection-Direct" -Force

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(DefaultParameterSetName='SUGNameCollectionName',SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ParameterSetName='SUGNameCollectionName', Mandatory=$true)]
        [Parameter(ParameterSetName='SUGNameCollectionID', Mandatory=$true)]
        [string]$SoftwareUpdateGroupName,

        [Parameter(ParameterSetName='SUGIDCollectionName', Mandatory=$true)]
        [Parameter(ParameterSetName='SUGIDCollectionID', Mandatory=$true)]
        [string]$SoftwareUpdateGroupID,

        [Parameter(ParameterSetName='SUGNameCollectionName', Mandatory=$true)]
        [Parameter(ParameterSetName='SUGIDCollectionName', Mandatory=$true)]
        [string]$CollectionName,

        [Parameter(ParameterSetName='SUGNameCollectionID', Mandatory=$true)]
        [Parameter(ParameterSetName='SUGIDCollectionID', Mandatory=$true)]
        [string]$CollectionID,

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

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            # Resolve Software Update Group
            if ($SoftwareUpdateGroupID) {
                $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE CI_ID = $SoftwareUpdateGroupID"
            } else {
                $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$SoftwareUpdateGroupName'"
            }
            Write-Verbose "Resolving software update group: $groupQuery"
            $resolvedGroup = Get-CimInstance @cimParams -Query $groupQuery
            if (-not $resolvedGroup) {
                throw "Software update group '$SoftwareUpdateGroupName' not found."
            }
            $groupCIID = [int]$resolvedGroup.CI_ID
            $SoftwareUpdateGroupName = $resolvedGroup.LocalizedDisplayName

            # Resolve Collection
            if ($CollectionID) {
                $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE CollectionID = '$CollectionID'"
            } else {
                $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
            }
            Write-Verbose "Resolving collection: $collectionQuery"
            $resolvedCollection = Get-CimInstance @cimParams -Query $collectionQuery
            if (-not $resolvedCollection) {
                throw "Collection '$CollectionName' not found."
            }
            $collectionID = $resolvedCollection.CollectionID
            $CollectionName = $resolvedCollection.Name

            # Find deployment
            $deploymentQuery = "SELECT * FROM SMS_UpdateGroupAssignment WHERE AssignedUpdateGroup = '${groupCIID}' AND TargetCollectionID = '${collectionID}'"
            Write-Verbose "Finding deployment: $deploymentQuery"
            $deployments = Get-CimInstance @cimParams -Query $deploymentQuery
            if (-not $deployments) {
                throw "Deployment for SUG '$SoftwareUpdateGroupName' and collection '$CollectionName' not found."
            }

            if ($PSCmdlet.ShouldProcess("Deployment for SUG '$SoftwareUpdateGroupName' in collection '$CollectionName'", "Remove")) {
                if ($WhatIf) {
                    Write-Host "WhatIf: Would remove deployment for SUG '$SoftwareUpdateGroupName' from collection '$CollectionName'"
                    return
                }
                foreach ($deployment in $deployments) {
                    $assignmentID = $deployment.AssignmentID
                    Write-Verbose "Removing deployment with AssignmentID: $assignmentID"
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $deployment
                }
                Write-Host "Removed deployment for SUG '$SoftwareUpdateGroupName' from collection '$CollectionName'"
            }
        } catch {
            Write-Error $_
            throw $_
        }
    }
}
function Remove-CM7SoftwareUpdateDeploymentPackage {
    <#
        .SYNOPSIS
            Removes a software update deployment package from MECM using CIM.

        .DESCRIPTION
            Removes (deletes) a software update deployment package (SMS_SoftwareUpdatesPackage)
            from Microsoft Endpoint Configuration Manager (MECM) using CIM.

            This is the CIM-based equivalent of Remove-CMSoftwareUpdateDeploymentPackage from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the package by name or package ID
            3. Removes the SMS_SoftwareUpdatesPackage instance via CIM (with confirmation by default)

            Key features:
            - Remove by Name or PackageID
            - Wildcard Support for Name
            - Pipeline Support (future)
            - Force Parameter: Bypass confirmation prompts for scripted scenarios
            - WhatIf/Confirm: Full ShouldProcess support for safe operations

        .PARAMETER Name
            The name of the software update deployment package to remove. Supports wildcards.

        .PARAMETER Id
            The PackageID of the software update deployment package to remove.

        .PARAMETER InputObject
            A software update deployment package object (from Get-CM7SoftwareUpdateDeploymentPackage) to remove.

        .PARAMETER Force
            Suppresses confirmation prompts and removes the package without asking.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7SoftwareUpdateDeploymentPackage -Name "Test-SUG" -Force

        .EXAMPLE
            Remove-CM7SoftwareUpdateDeploymentPackage -Id "XXX00001" -Force

        .EXAMPLE
            $pkg = Get-CM7SoftwareUpdateDeploymentPackage -Name "Test-SUG"
            Remove-CM7SoftwareUpdateDeploymentPackage -InputObject $pkg -Force

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [SupportsWildcards()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]$InputObject,

        [Parameter()]
        [switch]$Force
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            $pkgsToRemove = @()
            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    $wqlName = $Name.Replace('*', '%').Replace('?', '_')
                    $query = if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        "SELECT * FROM SMS_SoftwareUpdatesPackage WHERE Name LIKE '$wqlName'"
                    } else {
                        "SELECT * FROM SMS_SoftwareUpdatesPackage WHERE Name = '$Name'"
                    }
                    Write-Verbose "Querying for package(s) by name: $query"
                    $pkgs = @(Get-CimInstance @cimParams -Query $query)
                    if (-not $pkgs -or $pkgs.Count -eq 0) {
                        throw "No software update deployment package(s) found matching name '$Name'."
                    }
                    $pkgsToRemove = $pkgs
                }
                'ById' {
                    $query = "SELECT * FROM SMS_SoftwareUpdatesPackage WHERE PackageID = '$Id'"
                    Write-Verbose "Querying for package by ID: $query"
                    $pkg = Get-CimInstance @cimParams -Query $query
                    if (-not $pkg) {
                        throw "No software update deployment package found with PackageID '$Id'."
                    }
                    $pkgsToRemove = @($pkg)
                }
                'ByInputObject' {
                    $pkgId = $InputObject.PackageID
                    if (-not $pkgId) {
                        throw "InputObject does not have a PackageID property."
                    }
                    $query = "SELECT * FROM SMS_SoftwareUpdatesPackage WHERE PackageID = '$pkgId'"
                    Write-Verbose "Querying for package by InputObject: $query"
                    $pkg = Get-CimInstance @cimParams -Query $query
                    if (-not $pkg) {
                        throw "No software update deployment package found with PackageID '$pkgId' from InputObject."
                    }
                    $pkgsToRemove = @($pkg)
                }
            }

            foreach ($pkg in $pkgsToRemove) {
                $displayName = "$($pkg.Name) ($($pkg.PackageID))"
                $actionDescription = "Remove software update deployment package '$($pkg.Name)' ($($pkg.PackageID))"
                if ($Force -or $PSCmdlet.ShouldProcess($displayName, $actionDescription)) {
                    Write-Verbose "Removing package: $actionDescription"
                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $pkg
                    Write-Verbose "Software update deployment package '$($pkg.Name)' ($($pkg.PackageID)) removed successfully."
                    [PSCustomObject]@{
                        PSTypeName   = 'MECM7.RemovedSoftwareUpdateDeploymentPackage'
                        PackageID    = $pkg.PackageID
                        Name         = $pkg.Name
                        Status       = 'Removed'
                    }
                }
            }
        } catch {
            throw $_
        }
    }
}
function Remove-CM7SoftwareUpdateGroup {
    <#
        .SYNOPSIS
            Removes a software update group from MECM using CIM connectivity.

        .DESCRIPTION
            Removes a software update group (SMS_AuthorizationList) from Microsoft Endpoint Configuration Manager (MECM) using CIM. This is the CIM-based equivalent of Remove-CMSoftwareUpdateGroup from the ConfigurationManager module, but works via CIM.

        .PARAMETER Name
            The name of the software update group to remove.

        .PARAMETER CI_ID
            The CI_ID of the software update group to remove.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .EXAMPLE
            Remove-CM7SoftwareUpdateGroup -Name "Test-SUG-Creation" -Force

        .EXAMPLE
            Remove-CM7SoftwareUpdateGroup -CI_ID 12345678 -Force

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ParameterSetName='ByName', Mandatory=$true)]
        [string]$Name,

        [Parameter(ParameterSetName='ById', Mandatory=$true)]
        [int]$CI_ID,

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

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }
    }

    process {
        try {
            # Resolve Software Update Group
            if ($CI_ID) {
                $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE CI_ID = $CI_ID"
            } else {
                $groupQuery = "SELECT CI_ID, LocalizedDisplayName FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '$Name'"
            }
            Write-Verbose "Resolving software update group: $groupQuery"
            $resolvedGroup = Get-CimInstance @cimParams -Query $groupQuery
            if (-not $resolvedGroup) {
                throw "Software update group '$Name' not found."
            }
            $groupCIID = [int]$resolvedGroup.CI_ID
            $groupName = $resolvedGroup.LocalizedDisplayName

            if ($PSCmdlet.ShouldProcess("Software update group '$groupName' (CI_ID: $groupCIID)", "Remove")) {
                if ($WhatIf) {
                    Write-Host "WhatIf: Would remove software update group '$groupName' (CI_ID: $groupCIID)"
                    return
                }
                Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $resolvedGroup
                Write-Host "Removed software update group '$groupName' (CI_ID: $groupCIID)"
                return [PSCustomObject]@{
                    CI_ID = $groupCIID
                    Name = $groupName
                    Status = 'Removed'
                }
            }
        } catch {
            Write-Error $_
            throw $_
        }
    }
}
function Remove-CM7TaskSequenceDeployment {
    <#
        .SYNOPSIS
            Removes a task sequence deployment from MECM using CIM.

        .DESCRIPTION
            Removes (deletes) a task sequence deployment (SMS_Advertisement with ProgramName = '*')
            from Microsoft Endpoint Configuration Manager (MECM) using CIM.

            This is the CIM-based equivalent of the Remove-CMTaskSequenceDeployment cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.

            The function performs the following actions:
            1. Validates an active connection exists (established via Connect-CM7)
            2. Resolves the deployment by advertisement ID, collection name, task sequence name,
               task sequence PackageID, deployment name, or input object
            3. Verifies the advertisement is a task sequence deployment (ProgramName = '*')
            4. Removes the SMS_Advertisement instance via CIM (with confirmation by default)

            Key features:
            - Multiple Identification: Remove by AdvertisementID, collection name, task sequence,
              deployment name, or pipeline input object
            - Wildcard Support: Use * and ? in collection names, task sequence names, and
              deployment names to match multiple deployments
            - Pipeline Support: Accept deployment objects from Get-CM7TaskSequenceDeployment via pipeline
            - Force Parameter: Bypass confirmation prompts for scripted scenarios
            - WhatIf/Confirm: Full ShouldProcess support for safe operations

        .PARAMETER AdvertisementID
            The unique advertisement ID (deployment ID) of the task sequence deployment to remove.
            This is the AdvertisementID property (string), e.g. "SD120BD2".

        .PARAMETER CollectionName
            The name of the collection targeted by the task sequence deployment(s) to remove.
            Supports wildcard characters (* and ?). If multiple deployments match, all are removed.

        .PARAMETER TaskSequenceName
            The name of the task sequence associated with the deployment(s) to remove.
            Supports wildcard characters (* and ?). If multiple deployments match, all are removed.

        .PARAMETER TaskSequencePackageId
            The PackageID of the task sequence associated with the deployment(s) to remove.
            If multiple deployments match, all are removed.

        .PARAMETER DeploymentName
            The name of the deployment (AdvertisementName) to remove.
            Supports wildcard characters (* and ?). If multiple deployments match, all are removed.

        .PARAMETER InputObject
            A task sequence deployment object (e.g., from Get-CM7TaskSequenceDeployment) to remove.
            Must have an AdvertisementID property.

        .PARAMETER Force
            Suppresses confirmation prompts and removes the deployment without asking.
            By default, the function prompts for confirmation before deletion.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CM7TaskSequenceDeployment -AdvertisementID "SD120BD2" -Force
            Removes the task sequence deployment with the specified advertisement ID without confirmation.

        .EXAMPLE
            Remove-CM7TaskSequenceDeployment -CollectionName "Test-Collection-Direct" -Force
            Removes all task sequence deployments targeting the specified collection.

        .EXAMPLE
            Remove-CM7TaskSequenceDeployment -TaskSequenceName "Test Josh" -Force
            Removes all deployments of the task sequence named "Test Josh".

        .EXAMPLE
            Remove-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -Force
            Removes all deployments of the task sequence with PackageID "SD100FAD".

        .EXAMPLE
            Remove-CM7TaskSequenceDeployment -DeploymentName "Test Josh - Test-Collection-Direct" -Force
            Removes the deployment with the specified name.

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -CollectionName "Test-*" | Remove-CM7TaskSequenceDeployment -Force
            Removes all task sequence deployments targeting collections whose names start with "Test-" via pipeline.

        .EXAMPLE
            Remove-CM7TaskSequenceDeployment -DeploymentName "Test*" -WhatIf
            Shows what would happen without actually removing the deployment(s).

        .EXAMPLE
            $deployment = Get-CM7TaskSequenceDeployment -AdvertisementID "SD120BD2"
            Remove-CM7TaskSequenceDeployment -InputObject $deployment -Force
            Removes a deployment using a previously retrieved deployment object.

        .NOTES
            Requires an active connection established via Connect-CM7.

            The SMS_Advertisement WMI class is used to represent task sequence deployments in MECM.
            Task sequence deployments are distinguished from other deployments by ProgramName = '*'.

            This function is the CIM-based equivalent of the Remove-CMTaskSequenceDeployment cmdlet
            from the ConfigurationManager PowerShell module but uses direct CIM queries over WinRM
            instead of requiring the ConfigMgr console or PowerShell drive.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByAdvertisementID')]
    param(
        [Parameter(ParameterSetName = 'ByAdvertisementID', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AdvertisementID,

        [Parameter(ParameterSetName = 'ByCollectionName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(ParameterSetName = 'ByTaskSequenceName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequenceName,

        [Parameter(ParameterSetName = 'ByTaskSequencePackageId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequencePackageId,

        [Parameter(ParameterSetName = 'ByDeploymentName', Mandatory = $true)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$DeploymentName,

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

        # Namespace and CIM params
        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Lookups for resolving names
        $collectionNameLookup = @{}
        $tsNameLookup = @{}
    }

    process {
        try {
            # ---- Resolve deployments to remove ----
            $deploymentsToRemove = @()

            switch ($PSCmdlet.ParameterSetName) {
                'ByAdvertisementID' {
                    $query = "SELECT * FROM SMS_Advertisement WHERE AdvertisementID = '$AdvertisementID' AND ProgramName = '*'"
                    Write-Verbose "Looking up deployment by AdvertisementID: $query"
                    $advertisement = Get-CimInstance @cimParams -Query $query

                    if (-not $advertisement) {
                        throw "Task sequence deployment with AdvertisementID '$AdvertisementID' was not found."
                    }

                    $deploymentsToRemove = @($advertisement)
                }
                'ByCollectionName' {
                    # Resolve collection name to CollectionID(s)
                    $wqlCollName = $CollectionName.Replace('*', '%').Replace('?', '_')
                    if ($wqlCollName -like '*%*' -or $wqlCollName -like '*_*') {
                        $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name LIKE '$wqlCollName'"
                    } else {
                        $collectionQuery = "SELECT CollectionID, Name FROM SMS_Collection WHERE Name = '$CollectionName'"
                    }

                    Write-Verbose "Resolving collection name: $collectionQuery"
                    $collections = Get-CimInstance @cimParams -Query $collectionQuery

                    if (-not $collections) {
                        throw "Collection '$CollectionName' was not found."
                    }

                    foreach ($coll in @($collections)) {
                        $collectionNameLookup[$coll.CollectionID] = $coll.Name
                    }

                    $collectionIds = @($collections | ForEach-Object { $_.CollectionID })
                    foreach ($collId in $collectionIds) {
                        $advQuery = "SELECT * FROM SMS_Advertisement WHERE CollectionID = '$collId' AND ProgramName = '*'"
                        Write-Verbose "Querying deployments for collection '$collId': $advQuery"
                        $advertisements = @(Get-CimInstance @cimParams -Query $advQuery)
                        $deploymentsToRemove += $advertisements
                    }

                    if ($deploymentsToRemove.Count -eq 0) {
                        Write-Verbose "No task sequence deployments found for collection(s) matching '$CollectionName'."
                        return
                    }
                }
                'ByTaskSequenceName' {
                    # Resolve task sequence name to PackageID(s)
                    $wqlTsName = $TaskSequenceName.Replace('*', '%').Replace('?', '_')
                    if ($wqlTsName -like '*%*' -or $wqlTsName -like '*_*') {
                        $tsQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE Name LIKE '$wqlTsName'"
                    } else {
                        $tsQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE Name = '$TaskSequenceName'"
                    }

                    Write-Verbose "Resolving task sequence name: $tsQuery"
                    $taskSequences = Get-CimInstance @cimParams -Query $tsQuery

                    if (-not $taskSequences) {
                        throw "No task sequences found matching '$TaskSequenceName'."
                    }

                    foreach ($ts in @($taskSequences)) {
                        $tsNameLookup[$ts.PackageID] = $ts.Name
                    }

                    $packageIds = @($taskSequences | ForEach-Object { $_.PackageID })
                    foreach ($pkgId in $packageIds) {
                        $advQuery = "SELECT * FROM SMS_Advertisement WHERE PackageID = '$pkgId' AND ProgramName = '*'"
                        Write-Verbose "Querying deployments for PackageID '$pkgId': $advQuery"
                        $advertisements = @(Get-CimInstance @cimParams -Query $advQuery)
                        $deploymentsToRemove += $advertisements
                    }

                    if ($deploymentsToRemove.Count -eq 0) {
                        Write-Verbose "No task sequence deployments found for task sequence(s) matching '$TaskSequenceName'."
                        return
                    }
                }
                'ByTaskSequencePackageId' {
                    $advQuery = "SELECT * FROM SMS_Advertisement WHERE PackageID = '$TaskSequencePackageId' AND ProgramName = '*'"
                    Write-Verbose "Looking up deployments by TaskSequencePackageId: $advQuery"
                    $advertisements = @(Get-CimInstance @cimParams -Query $advQuery)

                    if (-not $advertisements -or $advertisements.Count -eq 0) {
                        throw "No task sequence deployments found for PackageID '$TaskSequencePackageId'."
                    }

                    $deploymentsToRemove = $advertisements
                }
                'ByDeploymentName' {
                    $wqlName = $DeploymentName.Replace('*', '%').Replace('?', '_')
                    if ($wqlName -like '*%*' -or $wqlName -like '*_*') {
                        $advQuery = "SELECT * FROM SMS_Advertisement WHERE AdvertisementName LIKE '$wqlName' AND ProgramName = '*'"
                    } else {
                        $advQuery = "SELECT * FROM SMS_Advertisement WHERE AdvertisementName = '$DeploymentName' AND ProgramName = '*'"
                    }

                    Write-Verbose "Looking up deployments by name: $advQuery"
                    $advertisements = @(Get-CimInstance @cimParams -Query $advQuery)

                    if (-not $advertisements -or $advertisements.Count -eq 0) {
                        throw "No task sequence deployments found matching name '$DeploymentName'."
                    }

                    $deploymentsToRemove = $advertisements
                }
                'ByInputObject' {
                    # Extract AdvertisementID from input object
                    $inputAdvId = $null
                    if ($InputObject.PSObject.Properties['AdvertisementID']) {
                        $inputAdvId = $InputObject.AdvertisementID
                    }

                    if (-not $inputAdvId) {
                        throw "InputObject does not have an AdvertisementID property."
                    }

                    # Re-fetch from CIM to ensure we have the actual instance
                    $query = "SELECT * FROM SMS_Advertisement WHERE AdvertisementID = '$inputAdvId' AND ProgramName = '*'"
                    Write-Verbose "Looking up deployment from InputObject: $query"
                    $advertisement = Get-CimInstance @cimParams -Query $query

                    if (-not $advertisement) {
                        throw "Task sequence deployment with AdvertisementID '$inputAdvId' from InputObject was not found in MECM."
                    }

                    $deploymentsToRemove = @($advertisement)
                }
            }

            # ---- Remove each deployment ----
            foreach ($deployment in $deploymentsToRemove) {
                # Resolve collection name for display
                $resolvedCollectionName = $null
                if ($collectionNameLookup.ContainsKey($deployment.CollectionID)) {
                    $resolvedCollectionName = $collectionNameLookup[$deployment.CollectionID]
                } else {
                    $collLookupQuery = "SELECT Name FROM SMS_Collection WHERE CollectionID = '$($deployment.CollectionID)'"
                    $collResult = Get-CimInstance @cimParams -Query $collLookupQuery
                    if ($collResult) {
                        $resolvedCollectionName = $collResult.Name
                        $collectionNameLookup[$deployment.CollectionID] = $resolvedCollectionName
                    }
                }

                # Resolve task sequence name for display
                $resolvedTsName = $null
                if ($tsNameLookup.ContainsKey($deployment.PackageID)) {
                    $resolvedTsName = $tsNameLookup[$deployment.PackageID]
                } else {
                    $tsLookupQuery = "SELECT Name FROM SMS_TaskSequencePackage WHERE PackageID = '$($deployment.PackageID)'"
                    $tsResult = Get-CimInstance @cimParams -Query $tsLookupQuery
                    if ($tsResult) {
                        $resolvedTsName = $tsResult.Name
                        $tsNameLookup[$deployment.PackageID] = $resolvedTsName
                    }
                }

                $displayName = "$($deployment.AdvertisementName) ($($deployment.AdvertisementID))"
                $actionDescription = "Remove task sequence deployment '$($deployment.AdvertisementName)' ($($deployment.AdvertisementID)) for task sequence '$resolvedTsName' ($($deployment.PackageID)) targeting collection '$resolvedCollectionName' ($($deployment.CollectionID))"

                if ($Force -or $PSCmdlet.ShouldProcess($displayName, $actionDescription)) {
                    Write-Verbose "Removing deployment: $actionDescription"

                    Remove-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $deployment

                    Write-Verbose "Task sequence deployment '$($deployment.AdvertisementName)' ($($deployment.AdvertisementID)) removed successfully."

                    # Return a result object with information about the removed deployment
                    [PSCustomObject]@{
                        PSTypeName        = 'MECM7.RemovedTaskSequenceDeployment'
                        AdvertisementID   = $deployment.AdvertisementID
                        AdvertisementName = $deployment.AdvertisementName
                        CollectionID      = $deployment.CollectionID
                        CollectionName    = $resolvedCollectionName
                        PackageID         = $deployment.PackageID
                        TaskSequenceName  = $resolvedTsName
                        Status            = 'Removed'
                    }
                }
            }
        }
        catch {
            throw $_
        }
    }
}
function Save-CM7SoftwareUpdate {
    <#
    .SYNOPSIS
        Saves one or more software updates to update groups and deployment packages using CIM connectivity.

    .DESCRIPTION
        The Save-CM7SoftwareUpdate function allows you to save software updates to update groups and deployment packages in MECM, using CIM connectivity. You can specify updates by name, ID, object, or group. Supports download location, retry logic, and language selection.

    .PARAMETER SoftwareUpdateName
        Array of software update names to save.

    .PARAMETER SoftwareUpdateId
        Array of software update IDs to save.

    .PARAMETER SoftwareUpdate
        Software update CIM instance to save.

    .PARAMETER SoftwareUpdateGroupName
        Array of software update group names to save updates from.

    .PARAMETER SoftwareUpdateGroupId
        Array of software update group IDs to save updates from.

    .PARAMETER SoftwareUpdateGroup
        Software update group CIM instance to save updates from.

    .PARAMETER DeploymentPackageName
        Name of the software update deployment package to save updates to.

    .PARAMETER Location
        Download source location for software updates.

    .PARAMETER RetryCount
        Number of times to retry downloading the update (default: 3).

    .PARAMETER RetryDelaySec
        Number of seconds to wait before retrying (default: 2).

    .PARAMETER SoftwareUpdateLanguage
        Array of software update languages.

    .PARAMETER DisableWildcardHandling
        Treats wildcard characters as literal character values.

    .PARAMETER TimeoutSec
        Timeout in seconds for each download attempt (default: 300).

    .PARAMETER ForceWildcardHandling
        Processes wildcard characters (not recommended).

    .PARAMETER DeploymentPackageID
        ID of the software update deployment package to save updates to.

    .PARAMETER DownloadOnly
        If specified, the function will only download the update content to the specified location without adding it to a deployment package.

    .EXAMPLE
        Save-CM7SoftwareUpdate -SoftwareUpdateGroupName "Test-SoftwareUpdateGroup" -DeploymentPackageName "Test-DeploymentPackage" -Location "\\mecm.yordomain.local\Patches\test"

    .EXAMPLE
        Save-CM7SoftwareUpdate -SoftwareUpdateName "Cumulative Update for Windows 10 (KB3095020)" -DeploymentPackageName "Test-DeploymentPackage" -Location "\\mecm.yourdomain.local\Patches\test"
    #>
    [CmdletBinding(DefaultParameterSetName='SaveByNamePkgName')]
    param (
        # --- Update/Group parameters ---
        [Parameter(ParameterSetName='SaveByNamePkgName', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByNamePkgID', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByName', Mandatory=$true)]
        [string[]]$SoftwareUpdateName,

        [Parameter(ParameterSetName='SaveByIdPkgName', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByIdPkgID', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyById', Mandatory=$true)]
        [string[]]$SoftwareUpdateId,

        [Parameter(ParameterSetName='SaveByObjectPkgName', Mandatory=$true, ValueFromPipeline=$true)]
        [Parameter(ParameterSetName='SaveByObjectPkgID', Mandatory=$true, ValueFromPipeline=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByObject', Mandatory=$true, ValueFromPipeline=$true)]
        [System.Management.Automation.PSObject]$SoftwareUpdate,

        [Parameter(ParameterSetName='SaveByGroupNamePkgName', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByGroupNamePkgID', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByGroupName', Mandatory=$true)]
        [string[]]$SoftwareUpdateGroupName,

        [Parameter(ParameterSetName='SaveByGroupIdPkgName', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByGroupIdPkgID', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByGroupId', Mandatory=$true)]
        [string[]]$SoftwareUpdateGroupId,

        [Parameter(ParameterSetName='SaveByGroupObjectPkgName', Mandatory=$true, ValueFromPipeline=$true)]
        [Parameter(ParameterSetName='SaveByGroupObjectPkgID', Mandatory=$true, ValueFromPipeline=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByGroupObject', Mandatory=$true, ValueFromPipeline=$true)]
        [System.Management.Automation.PSObject]$SoftwareUpdateGroup,

        # --- DeploymentPackageName (only for Save) ---
        [Parameter(ParameterSetName='SaveByNamePkgName', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByIdPkgName', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByObjectPkgName', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByGroupNamePkgName', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByGroupIdPkgName', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByGroupObjectPkgName', Mandatory=$true)]
        [string]$DeploymentPackageName,

        [Parameter(ParameterSetName='SaveByNamePkgID', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByIdPkgID', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByObjectPkgID', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByGroupNamePkgID', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByGroupIdPkgID', Mandatory=$true)]
        [Parameter(ParameterSetName='SaveByGroupObjectPkgID', Mandatory=$true)]
        [string]$DeploymentPackageID,

        # --- DownloadOnly (only for DownloadOnly sets) ---
        [Parameter(ParameterSetName='DownloadOnlyByName', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyById', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByObject', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByGroupName', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByGroupId', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByGroupObject', Mandatory=$true)]
        [switch]$DownloadOnly,

        # --- Common parameters ---
        [Parameter(ParameterSetName='DownloadOnlyByName', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyById', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByObject', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByGroupName', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByGroupId', Mandatory=$true)]
        [Parameter(ParameterSetName='DownloadOnlyByGroupObject', Mandatory=$true)]
        [string]$Location,

        [uint32]$RetryCount = 3,
        [uint32]$RetryDelaySec = 2,
        [string[]]$SoftwareUpdateLanguage,
        [switch]$DisableWildcardHandling,
        [switch]$ForceWildcardHandling,
        [int]$TimeoutSec = 300
    )

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    #region Establish CIM session
    $SiteCode = $script:CMConnection.SiteCode
    $CimSession = $Script:CMConnection.CimSession

    $summary = [PSCustomObject]@{
        Status = 'Success'
        UpdatesProcessed = 0
        UpdatesSucceeded = 0
        UpdatesFailed = 0
        UpdateResults = @()
        Errors = @()
    }
    try {
        #region Resolve Software Updates
        $Updates = @()
        if ($PSCmdlet.ParameterSetName -in @('SaveByNamePkgName', 'SaveByNamePkgID', 'DownloadOnlyByName')) {
            foreach ($name in $SoftwareUpdateName) {
                $Updates += Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -ClassName SMS_SoftwareUpdate -Filter "LocalizedDisplayName='$name'"
            }
        } elseif ($PSCmdlet.ParameterSetName -in @('SaveByIdPkgName', 'SaveByIdPkgID', 'DownloadOnlyById')) {
            foreach ($id in $SoftwareUpdateId) {
                $Updates += Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -ClassName SMS_SoftwareUpdate -Filter "ArticleID='$id'"
            }
        } elseif ($PSCmdlet.ParameterSetName -in @('SaveByObjectPkgName', 'SaveByObjectPkgID', 'DownloadOnlyByObject')) {
            # $Updates += $SoftwareUpdate
            $Updates += Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -Query "SELECT * FROM SMS_SoftwareUpdate WHERE CI_ID='$($SoftwareUpdate.CI_ID)'"
        } elseif ($PSCmdlet.ParameterSetName -in @('SaveByGroupNamePkgName', 'SaveByGroupNamePkgID', 'DownloadOnlyByGroupName')) {
            foreach ($groupName in $SoftwareUpdateGroupName) {

                $group = Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -ClassName SMS_AuthorizationList -Filter "LocalizedDisplayName='$groupName'"
                if ($null -eq $group) {
                    $summary.Status = 'Error'
                    $summary.Errors += "SoftwareUpdateGroup '$groupName' not found."
                    continue
                }
                # get lazy loading of updates in group
                $group = $group | Get-CimInstance

                $Updates += Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -Query "SELECT * FROM SMS_SoftwareUpdate WHERE CI_ID IN ($( $group.Updates -join ',' ))"
            }
        } elseif ($PSCmdlet.ParameterSetName -in @('SaveByGroupIdPkgName', 'SaveByGroupIdPkgID', 'DownloadOnlyByGroupId')) {
            foreach ($groupId in $SoftwareUpdateGroupId) {
                $group = Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -ClassName SMS_AuthorizationList -Filter "CI_ID='$groupId'"
                if ($null -eq $group) {
                    $summary.Status = 'Error'
                    $summary.Errors += "SoftwareUpdateGroup CI_ID '$groupId' not found."
                    continue
                }
                $Updates += Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -Query "SELECT * FROM SMS_AuthorizationList WHERE CI_ID IN ($($group.CI_ID))"
            }
        } elseif ($PSCmdlet.ParameterSetName -in @('SaveByGroupObjectPkgName', 'SaveByGroupObjectPkgID', 'DownloadOnlyByGroupObject')) {
            $group = $SoftwareUpdateGroup
            if ($null -eq $group) {
                $summary.Status = 'Error'
                $summary.Errors += "SoftwareUpdateGroup object not provided."
            } else {
                $Updates += Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -Query "SELECT * FROM SMS_AuthorizationList WHERE CI_ID IN ($($group.CI_ID))"
            }
        }
        #endregion

        #region Get Deployment Package
        if ($DownloadOnly) {
            # If we're only downloading, we don't actually need to validate the deployment package exists, since we're not adding content to it
            $DeploymentPackage = $null
        } else {
            if ( [boolean]$DeploymentPackageName ) {
                $DeploymentPackage = Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -ClassName SMS_SoftwareUpdatesPackage -Filter "Name='$DeploymentPackageName'"
            } else {
                $DeploymentPackage = Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -ClassName SMS_SoftwareUpdatesPackage -Filter "PackageID='$DeploymentPackageID'"
            }
            if (-not $DeploymentPackage) {
                $summary.Status = 'Error'
                $summary.Errors += "Deployment package '$DeploymentPackageName' not found."
                return $summary
            }
        }
        #endregion

        # If no updates found, return summary immediately
        if (-not $Updates -or $Updates.Count -eq 0) {
            $summary.Status = 'Error'
            $summary.Errors += "No software updates found for the specified criteria."
            return $summary
        }

        #region Download Content
        foreach ($Update in $Updates) {
            $updateResult = [PSCustomObject]@{
                CI_ID = $Update.CI_ID
                Name = $Update.LocalizedDisplayName
                Status = 'Success'
                Errors = @()
            }
            $summary.UpdatesProcessed++
            $Query = "SELECT * FROM SMS_CIToContent WHERE CI_ID='$($Update.CI_ID)'"
            $UpdateContents = Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -Query $Query

            $ContentIDs = ($UpdateContents | Select-Object -ExpandProperty ContentID -Unique) -join ','
            $Query = "SELECT * FROM SMS_CIContentFiles WHERE ContentID IN ($ContentIDs)"
            $UpdateContents = Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -Query $Query

            foreach ($UpdateContent in $UpdateContents) {
                $FileName = Split-Path -Leaf $UpdateContent.SourceURL
                if ( [string]::IsNullOrEmpty($Location)) {
                    $FilePath = Join-Path -Path $DeploymentPackage.PkgSourcePath -ChildPath $FileName
                } else {
                    $FilePath = Join-Path -Path $Location -ChildPath $FileName
                }

                $DownloadSuccess = $false
                $DownloadAttempts = 0

                do {
                    $DownloadAttempts++
                    try {
                        $Directory = Split-Path -Path $FilePath -Parent
                        if (-not ([System.IO.Directory]::Exists( $Directory ) ) ) {
                            New-Item -Path $Directory -ItemType Directory -Force | Out-Null
                        }
                        $ProgressPreference = 'SilentlyContinue'
                        Invoke-WebRequest -Uri $UpdateContent.SourceURL -OutFile $FilePath -TimeoutSec $TimeoutSec -ErrorAction Stop
                        if ( [System.IO.File]::Exists($FilePath) -and (Get-Item -Path $FilePath).Length -gt 0) {
                            $DownloadSuccess = $true
                        } else {
                            throw "Downloaded file is empty or doesn't exist"
                        }
                    } catch {
                        $updateResult.Status = 'Error'
                        $errMsg = "Download attempt $DownloadAttempts failed for $FileName : $($_.Exception.Message)"
                        $updateResult.Errors += $errMsg
                        $summary.Errors += $errMsg
                        if ( [System.IO.File]::Exists($FilePath) ) {
                            Remove-Item -Path $FilePath -Force -ErrorAction SilentlyContinue
                        }
                        if ($DownloadAttempts -lt $RetryCount) {
                            Start-Sleep -Seconds $RetryDelaySec
                        }
                    }
                } while (-not $DownloadSuccess -and $DownloadAttempts -lt $RetryCount)

                if (-not $DownloadSuccess) {
                    $updateResult.Status = 'Error'
                    $errMsg = "Failed to download $FileName after $RetryCount attempts"
                    $updateResult.Errors += $errMsg
                    $summary.Errors += $errMsg
                    continue
                }
            }

            # Add ContentID to package

            if ( [boolean]$DownloadOnly ) {
                # If we're only downloading, we skip adding content to the package
                $updateResult.Status = 'Downloaded'

                $ContentIDs = $UpdateContents | Select-Object -ExpandProperty ContentID -Unique
                $summary.UpdatesSucceeded += $ContentIDs.Count
                continue
            }
            else {
                # If we successfully downloaded the content, we can add it to the deployment package
                $ContentIDs = $UpdateContents | Select-Object -ExpandProperty ContentID -Unique
                foreach ($cid in $ContentIDs) {
                    $ContentIDArray   = @([uint32]$cid)
                    $SourcePathArray  = @([string]$DeploymentPackage.PkgSourcePath)
                    $Arguments = @{
                        bRefreshDPs       = $false
                        ContentIDs        = $ContentIDArray
                        ContentSourcePath = $SourcePathArray
                    }
                    $Result = Invoke-CimMethod -CimSession $CimSession -InputObject $DeploymentPackage -MethodName 'AddUpdateContent' -Arguments $Arguments
                    if ($Result.ReturnValue -eq 0) {
                        $summary.UpdatesSucceeded++
                    } else {
                        $updateResult.Status = 'Error'
                        $errMsg = "Failed to add ContentID $cid (error $($Result.ReturnValue))"
                        $updateResult.Errors += $errMsg
                        $summary.Errors += $errMsg
                        $summary.UpdatesFailed++
                    }
                }
            }
            if ($updateResult.Status -eq 'Error') {
                $summary.UpdatesFailed++
            }
            $summary.UpdateResults += $updateResult
        }
        if ($summary.Errors.Count -gt 0) {
            $summary.Status = 'Error'
        }
        return $summary
    }
    catch {
        $summary.Status = 'Error'
        $summary.Errors += "An error occurred: $($_.Exception.Message)"
        return $summary
    }
    #endregion
}
function Set-CM7Application {
    <#
        .SYNOPSIS
            Modifies an existing application in MECM using CIM connectivity.

        .DESCRIPTION
            Updates properties of an existing application in MECM via the SMS_Application WMI class using CIM connectivity.
            Requires an active connection established via Connect-CM7.
            Supports updating properties such as Description, Owner, SupportContact, SupportUrl, InfoUrl, PrivacyUrl, IsEnabled, IsHidden, and AutoInstall.

        .PARAMETER Name
            The display name of the application to modify. (Mutually exclusive with ID)

        .PARAMETER ID
            The CI_ID of the application to modify. (Mutually exclusive with Name)

        .PARAMETER Description
            The new description for the application.

        .PARAMETER Owner
            The new owner of the application.

        .PARAMETER SupportContact
            The new support contact for the application.

        .PARAMETER SupportUrl
            The new support URL for the application.

        .PARAMETER InfoUrl
            The new information/help URL for the application.

        .PARAMETER PrivacyUrl
            The new privacy statement URL for the application.

        .PARAMETER IsEnabled
            Whether the application is enabled.

        .PARAMETER IsHidden
            Whether the application is hidden from the Software Center.

        .PARAMETER AutoInstall
            Whether the application may be installed automatically during a task sequence.

        .EXAMPLE
            Set-CM7Application -Name "Test" -Description "Updated description"
            Updates the description of the application named "Test".
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByID', Mandatory = $true, Position = 0)]
        [int]$ID,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [string]$Owner,

        [Parameter()]
        [string]$SupportContact,

        [Parameter()]
        [string]$SupportUrl,

        [Parameter()]
        [string]$InfoUrl,

        [Parameter()]
        [string]$PrivacyUrl,

        [Parameter()]
        [boolean]$IsEnabled,

        [Parameter()]
        [boolean]$IsHidden,

        [Parameter()]
        [boolean]$AutoInstall
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
    $session   = $script:CMConnection.CimSession

    # Resolve application
    if ($Name) {
        $app = Get-CimInstance -CimSession $session -Namespace $namespace -ClassName SMS_Application -Filter "LocalizedDisplayName = '$Name' AND IsLatest = 1"
        if (-not $app) { throw "No application found with Name '$Name'." }
    } else {
        $app = Get-CimInstance -CimSession $session -Namespace $namespace -ClassName SMS_Application -Filter "CI_ID = $ID AND IsLatest = 1"
        if (-not $app) { throw "No application found with CI_ID $ID." }
    }

    $appId   = $app.CI_ID
    $appName = $app.LocalizedDisplayName

    if ($PSCmdlet.ShouldProcess("Application '$appName' (CI_ID: $appId)", 'Update')) {
        # ── XML-based property changes (Description, Owner, etc.) ──
        # SDMPackageXML is a lazy property that cannot be modified via Set-CimInstance
        # over WS-Management (WinRM). The WMI CREATE operation (New-CimInstance) works,
        # but the MODIFY/PUT operation does not for lazy properties on SMS_Application.
        # Solution: use a temporary DCOM CIM session for which native WMI RPC supports
        # modifying lazy properties.
        $xmlParams = @('Description','Owner','SupportContact','SupportUrl','InfoUrl','PrivacyUrl','AutoInstall')
        $needsXmlUpdate = $false
        foreach ($p in $xmlParams) {
            if ($PSBoundParameters.ContainsKey($p)) { $needsXmlUpdate = $true; break }
        }

        if ($needsXmlUpdate) {
            Write-Verbose "Creating temporary DCOM session to modify SDMPackageXML"

            # Get full instance (lazy properties are returned)
            $app = Get-CimInstance -CimSession $Script:CMConnection.CimSession -Namespace $namespace  -ClassName SMS_Application -Filter "CI_ID = $appId"
            # Re-query to load lazy properties
            $appFull = $app | Get-CimInstance

            $sdmXml = $appFull.SDMPackageXML
            if (-not $sdmXml) {
                throw "Failed to retrieve SDMPackageXML for application '$appName' (CI_ID: $appId)."
            }

            [xml]$xmlDoc = $sdmXml
            $nsMgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
            $nsMgr.AddNamespace('a', 'http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest')
            $infoNode = $xmlDoc.SelectSingleNode('//a:Application/a:DisplayInfo/a:Info', $nsMgr)
            $appNode  = $xmlDoc.SelectSingleNode('//a:Application', $nsMgr)

            if ($PSBoundParameters.ContainsKey('Description')) {
                $descNode = $infoNode.SelectSingleNode('a:Description', $nsMgr)
                if ($descNode) {
                    $descNode.InnerText = $Description
                } else {
                    $elem = $xmlDoc.CreateElement('Description', 'http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest')
                    $elem.InnerText = $Description
                    $infoNode.AppendChild($elem) | Out-Null
                }
            }
            if ($PSBoundParameters.ContainsKey('Owner')) {
                $ownersNode = $appNode.SelectSingleNode('a:Owners', $nsMgr)
                if (-not $ownersNode) {
                    $ownersNode = $xmlDoc.CreateElement('Owners', 'http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest')
                    $appNode.AppendChild($ownersNode) | Out-Null
                }
                $ownersNode.RemoveAll()
                $userNode = $xmlDoc.CreateElement('User', 'http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest')
                $userNode.SetAttribute('Qualifier', 'LogonName')
                $userNode.SetAttribute('Id', [System.Security.SecurityElement]::Escape($Owner))
                $ownersNode.AppendChild($userNode) | Out-Null
            }
            if ($PSBoundParameters.ContainsKey('SupportContact')) {
                $contactsNode = $appNode.SelectSingleNode('a:Contacts', $nsMgr)
                if (-not $contactsNode) {
                    $contactsNode = $xmlDoc.CreateElement('Contacts', 'http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest')
                    $appNode.AppendChild($contactsNode) | Out-Null
                }
                $contactsNode.RemoveAll()
                $userNode = $xmlDoc.CreateElement('User', 'http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest')
                $userNode.SetAttribute('Qualifier', 'LogonName')
                $userNode.SetAttribute('Id', [System.Security.SecurityElement]::Escape($SupportContact))
                $contactsNode.AppendChild($userNode) | Out-Null
            }
            if ($PSBoundParameters.ContainsKey('SupportUrl')) {
                $node = $infoNode.SelectSingleNode('a:SupportUrl', $nsMgr)
                if ($node) { $node.InnerText = $SupportUrl }
                else {
                    $elem = $xmlDoc.CreateElement('SupportUrl', 'http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest')
                    $elem.InnerText = $SupportUrl
                    $infoNode.AppendChild($elem) | Out-Null
                }
            }
            if ($PSBoundParameters.ContainsKey('InfoUrl')) {
                $node = $infoNode.SelectSingleNode('a:InfoUrl', $nsMgr)
                if ($node) { $node.InnerText = $InfoUrl }
                else {
                    $elem = $xmlDoc.CreateElement('InfoUrl', 'http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest')
                    $elem.InnerText = $InfoUrl
                    $infoNode.AppendChild($elem) | Out-Null
                }
            }
            if ($PSBoundParameters.ContainsKey('PrivacyUrl')) {
                $node = $infoNode.SelectSingleNode('a:PrivacyUrl', $nsMgr)
                if ($node) { $node.InnerText = $PrivacyUrl }
                else {
                    $elem = $xmlDoc.CreateElement('PrivacyUrl', 'http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest')
                    $elem.InnerText = $PrivacyUrl
                    $infoNode.AppendChild($elem) | Out-Null
                }
            }
            if ($PSBoundParameters.ContainsKey('AutoInstall')) {
                $aiNode = $appNode.SelectSingleNode('a:AutoInstall', $nsMgr)
                $aiValue = if ($AutoInstall) { 'true' } else { 'false' }
                if ($aiNode) { $aiNode.InnerText = $aiValue }
                else {
                    $elem = $xmlDoc.CreateElement('AutoInstall', 'http://schemas.microsoft.com/SystemCenterConfigurationManager/2009/AppMgmtDigest')
                    $elem.InnerText = $aiValue
                    $appNode.AppendChild($elem) | Out-Null
                }
            }

            $xmlDoc.AppMgmtDigest.Application.Version += 1 # Increment version to ensure update is detected
            $newXml = $xmlDoc.OuterXml
            Write-Verbose "Updating SDMPackageXML for application '$appName' (CI_ID: $appId)"

            $session = New-PSSession -ComputerName $script:CMConnection.SiteServer -Credential $script:CMConnection.Credential -Authentication Default
            Invoke-Command -Session $session -ScriptBlock {
                param($namespace, $appId, $newXml)
                # Set-CimInstance over WinRM session to update SDMPackageXML (lazy property) - this requires a full instance with lazy properties loaded
                # Re-query application within session to ensure we have the correct instance for modification
                $app = Get-CimInstance -Namespace $namespace -ClassName SMS_Application -Filter "CI_ID = $appId AND IsLatest = 1"
                $dcomAppFull = $app | Get-CimInstance -Property * # Load all properties, including lazy ones
                if ($app) {
                    Set-CimInstance -InputObject $dcomAppFull -Property @{ SDMPackageXML = $newXml ; SDMPackageVersion = [int]$dcomAppFull.SDMPackageVersion + 1  }
                } else {
                    throw "Application with CI_ID $appId not found during SDMPackageXML update."
                }
            } -ArgumentList $namespace, $appId, $newXml
            Remove-PSSession -Session $session
        }

        # ── Direct WMI property changes (non-lazy, work fine over WinRM) ──
        $props = @{}
        if ($PSBoundParameters.ContainsKey('IsEnabled')) { $props['IsEnabled'] = $IsEnabled }
        if ($PSBoundParameters.ContainsKey('IsHidden'))  { $props['IsHidden']  = $IsHidden  }
        if ($props.Count -gt 0) {
            Set-CimInstance -CimSession $Script:CMConnection.CimSession -InputObject $app -Property $props | Out-Null
        }

        Write-Verbose "Updated application '$appName' (CI_ID: $appId)"
        return Get-CimInstance -CimSession $Script:CMConnection.CimSession -Namespace $namespace -ClassName SMS_Application -Filter "CI_ID = $appId AND IsLatest = 1"
    }
}
function Set-CM7Boundary {
    <#
        .SYNOPSIS
            Modifies an existing boundary in MECM using CIM.

        .DESCRIPTION
            Updates the properties of an existing SMS_Boundary instance in Microsoft Endpoint
            Configuration Manager (MECM) using CIM over WinRM.

            Supports modifying boundaries by:
            - InputObject: a boundary object piped in or retrieved via Get-CM7Boundary
            - Id:          unambiguous identification by integer BoundaryID
            - Type+Value:  locate the boundary by its current type and value combination

            Any combination of -NewName, -NewType, -NewValue, and -ValueStartsWith can be
            supplied to update the corresponding properties.

            This is the CIM-based equivalent of the Set-CMBoundary cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

        .PARAMETER InputObject
            A boundary object (e.g., from Get-CM7Boundary) whose properties are to be updated.
            Accepts pipeline input. Must have a BoundaryID property.

        .PARAMETER Id
            The BoundaryID (integer) of the boundary to modify. Alias: BoundaryId.

        .PARAMETER Type
            The current boundary type used to locate the boundary (combined with -Value).
            Valid values: IPSubnet, ADSite, IPv6Prefix, IPRange, Vpn.
            Alias: BoundaryType.

        .PARAMETER Value
            The current value of the boundary used to locate it (combined with -Type).

        .PARAMETER NewName
            A new display name to assign to the boundary. Aliases: DisplayName, Name.

        .PARAMETER NewType
            The new boundary type to assign. Accepted values: IPSubnet, ADSite, IPv6Prefix, IPRange, Vpn.
            Alias: NewBoundaryType.

        .PARAMETER NewValue
            The new value to assign to the boundary (e.g., a new subnet address or IP range).

        .PARAMETER ValueStartsWith
            When set to $true, the VPN boundary is matched by the start of the connection name
            rather than an exact match. Relevant only for VPN boundary types.

        .PARAMETER PassThru
            Returns the updated boundary object. By default this cmdlet returns no output.

        .PARAMETER Force
            Suppresses confirmation prompts.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs without actually running it.

        .PARAMETER Confirm
            Prompts for confirmation before performing the update.

        .EXAMPLE
            Set-CM7Boundary -Id 16777223 -NewName "Renamed-TestSubnet"
            Renames the boundary with BoundaryID 16777223.

        .EXAMPLE
            Set-CM7Boundary -Id 16777223 -NewType IPRange -NewValue "192.168.1.1-192.168.1.255" -PassThru
            Changes the type and value of a boundary and returns the updated object.

        .EXAMPLE
            Set-CM7Boundary -Type IPSubnet -Value "192.168.1.0" -NewName "Updated-Subnet" -NewValue "192.168.10.0"
            Locates the IP Subnet boundary with value "192.168.1.0" and updates its name and value.

        .EXAMPLE
            Get-CM7Boundary -Name "TestSubnet-192.168.1.0" | Set-CM7Boundary -NewName "UpdatedSubnet" -Force
            Uses pipeline input to rename a boundary.

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_Boundary WMI class is used to represent boundaries in MECM.
            BoundaryType integer mapping: 0=IPSubnet, 1=ADSite, 2=IPv6Prefix, 3=IPRange, 4=Vpn.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'SetByValue')]
    param(
        # ---- Identification ----
        [Parameter(ParameterSetName = 'SetByValue', Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSObject]$InputObject,

        [Parameter(ParameterSetName = 'SetById', Mandatory = $true)]
        [Alias('BoundaryId')]
        [int]$Id,

        [Parameter(ParameterSetName = 'SetByName', Mandatory = $true)]
        [ValidateSet('IPSubnet', 'ADSite', 'IPv6Prefix', 'IPRange', 'Vpn')]
        [Alias('BoundaryType')]
        [string]$Type,

        [Parameter(ParameterSetName = 'SetByName', Mandatory = $true)]
        [string]$Value,

        # ---- What to change ----
        [Parameter()]
        [Alias('DisplayName', 'Name')]
        [string]$NewName,

        [Parameter()]
        [ValidateSet('IPSubnet', 'ADSite', 'IPv6Prefix', 'IPRange', 'Vpn')]
        [Alias('NewBoundaryType')]
        [string]$NewType,

        [Parameter()]
        [string]$NewValue,

        [Parameter()]
        [boolean]$ValueStartsWith,

        [Parameter()]
        [switch]$PassThru,

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

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # BoundaryType string-to-int mapping
        $typeMap = @{
            'IPSubnet'   = 0
            'ADSite'     = 1
            'IPv6Prefix' = 2
            'IPRange'    = 3
            'Vpn'        = 4
        }

        # Reverse mapping for display/lookup
        $typeReverseMap = @{
            0 = 'IPSubnet'
            1 = 'ADSite'
            2 = 'IPv6Prefix'
            3 = 'IPRange'
            4 = 'Vpn'
        }
    }

    process {
        try {
            # ---- Step 1: Resolve the target boundary ----
            $cimBoundary = $null

            switch ($PSCmdlet.ParameterSetName) {

                'SetByValue' {
                    $boundaryId = $InputObject.BoundaryID
                    if (-not $boundaryId) {
                        throw "InputObject does not have a valid BoundaryID property."
                    }
                    $cimBoundary = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_Boundary WHERE BoundaryID = $boundaryId"
                    if (-not $cimBoundary) {
                        throw "No boundary found with BoundaryID $boundaryId (from InputObject)."
                    }
                }

                'SetById' {
                    $cimBoundary = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_Boundary WHERE BoundaryID = $Id"
                    if (-not $cimBoundary) {
                        throw "No boundary found with BoundaryID $Id."
                    }
                }

                'SetByName' {
                    $typeInt = $typeMap[$Type]
                    # Escape single quotes in Value for WQL
                    $wqlValue = $Value -replace "'", "''"
                    $cimBoundary = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_Boundary WHERE BoundaryType = $typeInt AND Value = '$wqlValue'"
                    if (-not $cimBoundary) {
                        throw "No boundary found with Type '$Type' and Value '$Value'."
                    }
                    # If multiple are returned (edge case), take the first and warn
                    if (@($cimBoundary).Count -gt 1) {
                        Write-Warning "Multiple boundaries found with Type '$Type' and Value '$Value'. Modifying the first one (BoundaryID: $($cimBoundary[0].BoundaryID))."
                        $cimBoundary = $cimBoundary[0]
                    }
                }
            }

            # ---- Step 2: Build the set of property changes ----
            $updateProps = @{}

            if ($PSBoundParameters.ContainsKey('NewName')) {
                $updateProps['DisplayName'] = $NewName
            }
            if ($PSBoundParameters.ContainsKey('NewType')) {
                $updateProps['BoundaryType'] = [int]$typeMap[$NewType]
            }
            if ($PSBoundParameters.ContainsKey('NewValue')) {
                # Validate NewValue format against the target type (use NewType if provided, else current type)
                $targetTypeStr = if ($PSBoundParameters.ContainsKey('NewType')) { $NewType } else { $typeReverseMap[[int]$cimBoundary.BoundaryType] }
                switch ($targetTypeStr) {
                    'IPSubnet' {
                        if ($NewValue -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
                            throw "Invalid NewValue for IPSubnet. Expected format: '192.168.1.0'"
                        }
                    }
                    'ADSite' {
                        if ([string]::IsNullOrEmpty($NewValue)) {
                            throw "Invalid NewValue for ADSite. Expected a non-empty string."
                        }
                    }
                    'IPv6Prefix' {
                        if ($NewValue -notmatch '^[0-9a-fA-F:]+(/\d+)?$') {
                            throw "Invalid NewValue for IPv6Prefix. Expected format: '2001:db8::' or '2001:db8::/32'"
                        }
                    }
                    'IPRange' {
                        if ($NewValue -notmatch '^\d{1,3}(\.\d{1,3}){3}-\d{1,3}(\.\d{1,3}){3}$') {
                            throw "Invalid NewValue for IPRange. Expected format: '192.168.1.1-192.168.1.255'"
                        }
                    }
                    'Vpn' {
                        if ([string]::IsNullOrEmpty($NewValue)) {
                            throw "Invalid NewValue for Vpn. Expected a non-empty string."
                        }
                    }
                }
                $updateProps['Value'] = $NewValue
            }
            if ($PSBoundParameters.ContainsKey('ValueStartsWith')) {
                $updateProps['ValueStartsWith'] = $ValueStartsWith
            }

            if ($updateProps.Count -eq 0) {
                Write-Warning "No changes specified for boundary '$($cimBoundary.DisplayName)' (BoundaryID: $($cimBoundary.BoundaryID)). Nothing to do."
                return
            }

            # ---- Step 3: Apply changes ----
            $displayName = $cimBoundary.DisplayName
            $boundaryIdStr = $cimBoundary.BoundaryID
            $changeDesc = ($updateProps.Keys | ForEach-Object { "$_ -> $($updateProps[$_])" }) -join '; '
            $actionDescription = "Update boundary '$displayName' (BoundaryID: $boundaryIdStr): $changeDesc"

            if ($Force -or $PSCmdlet.ShouldProcess("Boundary '$displayName' (BoundaryID: $boundaryIdStr)", $actionDescription)) {
                Set-CimInstance -CimSession $Script:CMConnection.CimSession -InputObject $cimBoundary -Property $updateProps

                if ($PassThru) {
                    # Re-query to return the updated state
                    $updated = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_Boundary WHERE BoundaryID = $boundaryIdStr"
                    if ($updated) {
                        $output = [PSCustomObject]@{
                            PSTypeName   = 'MECM7.Boundary'
                            BoundaryID   = [int]$updated.BoundaryID
                            DisplayName  = $updated.DisplayName
                            BoundaryType = [int]$updated.BoundaryType
                            Value        = $updated.Value
                            Description  = $updated.Description
                        }
                        $output.PSObject.TypeNames.Insert(0, 'MECM7.Boundary')
                        $updated.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                        Write-Output $output
                    } else {
                        Write-Warning "Boundary was updated but could not retrieve the result. BoundaryID: $boundaryIdStr"
                    }
                }
            }
        } catch {
            throw $_
        }
    }
}
function Set-CM7BoundaryGroup {
    <#
        .SYNOPSIS
            Modifies the properties of a boundary group in MECM using CIM.

        .DESCRIPTION
            Modifies properties of an existing boundary group (SMS_BoundaryGroup) in Microsoft Endpoint
            Configuration Manager (MECM) using CIM.
            Supports renaming, updating description, assigning a default site code, managing site system
            server associations, and configuring peer download options.
            Requires an active connection via Connect-CM7.

            This is the CIM-based equivalent of the Set-CMBoundaryGroup cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

            The function supports identifying boundary groups by:
            - Name:        looks up the boundary group by name
            - Id (GroupID): looks up the boundary group by its integer GroupID
            - InputObject:  accepts a boundary group object from the pipeline (e.g., from Get-CM7BoundaryGroup)

        .PARAMETER Name
            The name of the boundary group to modify.

        .PARAMETER Id
            The GroupID of the boundary group to modify.
            Alias: GroupId

        .PARAMETER InputObject
            A boundary group object (e.g., from Get-CM7BoundaryGroup) to modify.
            Accepts pipeline input. Must have a GroupID property.

        .PARAMETER NewName
            A new name to rename the boundary group to.

        .PARAMETER Description
            A new description for the boundary group.

        .PARAMETER DefaultSiteCode
            The site code to set for automatic site assignment. Set to $null or empty string to disable
            site assignment for this boundary group.

        .PARAMETER AddSiteSystemServerName
            One or more site system server fully qualified domain names (FQDNs) to add to the
            boundary group. Alias: AddSiteSystemServerNames

        .PARAMETER RemoveSiteSystemServerName
            One or more site system server fully qualified domain names (FQDNs) to remove from the
            boundary group. Alias: RemoveSiteSystemServerNames

        .PARAMETER ClearSiteSystemServer
            Remove all site system server associations from the boundary group.
            Alias: ClearSiteSystemServers

        .PARAMETER AllowPeerDownload
            Configure whether peer downloads are enabled in this boundary group.
            Corresponds to bit 0x0002 in the Flags property of SMS_BoundaryGroup.

        .PARAMETER SubnetPeerDownloadOnly
            Configure whether only peers within the same subnet are used for peer downloads.
            Requires AllowPeerDownload to be enabled.
            Corresponds to bit 0x0004 in the Flags property of SMS_BoundaryGroup.
            Alias: PeerWithinSameSubnetOnly

        .PARAMETER PreferDPOverPeer
            Configure whether distribution points are preferred over peers within the same subnet.
            Requires AllowPeerDownload to be enabled.
            Corresponds to bit 0x0008 in the Flags property of SMS_BoundaryGroup.
            Alias: PreferDistributionPointOverPeerInSubnet

        .PARAMETER PreferCloudDPOverDP
            Configure whether cloud-based sources are preferred over on-CM7mises distribution points.
            Corresponds to bit 0x0010 in the Flags property of SMS_BoundaryGroup.
            Alias: PreferCloudDistributionPointOverDistributionPoint

        .PARAMETER PassThru
            Returns the modified boundary group object. By default this cmdlet does not generate output.

        .PARAMETER DisableWildcardHandling
            Treats wildcard characters as literal character values.
            Cannot be combined with ForceWildcardHandling.

        .PARAMETER ForceWildcardHandling
            Forces wildcard character processing even in contexts where it is not normally supported.
            May lead to unexpected behavior (not recommended).
            Cannot be combined with DisableWildcardHandling.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Set-CM7BoundaryGroup -Name "BGroup01" -NewName "BGroup00"
            Renames the boundary group "BGroup01" to "BGroup00".

        .EXAMPLE
            Set-CM7BoundaryGroup -Name "Test" -Description "Updated description" -DefaultSiteCode "PS1"
            Updates the description and default site code of the boundary group named "Test".

        .EXAMPLE
            Set-CM7BoundaryGroup -Name "Remote BG" -AddSiteSystemServerName "server01.contoso.com"
            Adds a site system server to the boundary group.

        .EXAMPLE
            Set-CM7BoundaryGroup -Name "Remote BG" -ClearSiteSystemServer
            Removes all site system server associations from the boundary group.

        .EXAMPLE
            Set-CM7BoundaryGroup -Name "Test" -AllowPeerDownload $true -SubnetPeerDownloadOnly $true
            Enables peer downloads and restricts them to same-subnet peers.

        .EXAMPLE
            Get-CM7BoundaryGroup -Name "BGroup01" | Set-CM7BoundaryGroup -NewName "BGroup00"
            Renames a boundary group using the pipeline.

        .EXAMPLE
            Set-CM7BoundaryGroup -Id "16777219" -Description "Updated via ID" -PassThru
            Updates the description of the boundary group with GroupID 16777219 and returns the modified object.

        .NOTES
            Requires an active connection established via Connect-CM7.
            The SMS_BoundaryGroup WMI class is used to represent boundary groups in MECM.
            Site system server associations are managed via the AddSiteSystem / RemoveSiteSystem CIM methods.
            Peer download options are stored as bit flags in the Flags property of SMS_BoundaryGroup:
                0x0002 = AllowPeerDownload
                0x0004 = SubnetPeerDownloadOnly
                0x0008 = PreferDPOverPeer
                0x0010 = PreferCloudDPOverDP
            For more information, see:
            https://learn.microsoft.com/en-us/mem/configmgr/develop/reference/core/servers/configure/sms_boundarygroup-server-wmi-class
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [Alias('GroupId')]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [PSObject]$InputObject,

        [Parameter()]
        [string]$NewName,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$DefaultSiteCode,

        [Parameter()]
        [Alias('AddSiteSystemServerNames')]
        [string[]]$AddSiteSystemServerName,

        [Parameter()]
        [Alias('RemoveSiteSystemServerNames')]
        [string[]]$RemoveSiteSystemServerName,

        [Parameter()]
        [Alias('ClearSiteSystemServers')]
        [switch]$ClearSiteSystemServer,

        [Parameter()]
        [System.Boolean]$AllowPeerDownload,

        [Parameter()]
        [Alias('PeerWithinSameSubnetOnly')]
        [System.Boolean]$SubnetPeerDownloadOnly,

        [Parameter()]
        [Alias('PreferDistributionPointOverPeerInSubnet')]
        [System.Boolean]$PreferDPOverPeer,

        [Parameter()]
        [Alias('PreferCloudDistributionPointOverDistributionPoint')]
        [System.Boolean]$PreferCloudDPOverDP,

        [Parameter()]
        [switch]$PassThru,

        [Parameter()]
        [switch]$DisableWildcardHandling,

        [Parameter()]
        [switch]$ForceWildcardHandling
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        # Validate mutually exclusive wildcard parameters
        if ($DisableWildcardHandling -and $ForceWildcardHandling) {
            throw "DisableWildcardHandling and ForceWildcardHandling cannot be used together."
        }

        # Validate connection
        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        # Flags bit flags for peer download settings (SMS_BoundaryGroup.Flags property)
        $optionBitAllowPeerDownload    = [uint32]0x0002
        $optionBitSubnetPeerOnly       = [uint32]0x0004
        $optionBitPreferDPOverPeer     = [uint32]0x0008
        $optionBitPreferCloudDPOverDP  = [uint32]0x0010
    }

    process {
        try {
            # ---- Resolve Boundary Group ----
            $group = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    $safeName = $Name -replace "'", "''"
                    $query = "SELECT * FROM SMS_BoundaryGroup WHERE Name = '$safeName'"
                    $group = Get-CimInstance @cimParams -Query $query

                    if (-not $group) {
                        throw "No boundary group found with name '$Name'."
                    }
                    if (@($group).Count -gt 1) {
                        throw "Multiple boundary groups found matching name '$Name'. Use a more specific name or use -Id."
                    }
                }

                'ById' {
                    $query = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $Id"
                    $group = Get-CimInstance @cimParams -Query $query

                    if (-not $group) {
                        throw "No boundary group found with GroupID $Id."
                    }
                }

                'ByInputObject' {
                    $groupId = $null
                    if ($InputObject.PSObject.Properties['GroupID']) {
                        $groupId = $InputObject.GroupID
                    } elseif ($InputObject.PSObject.Properties['GroupId']) {
                        $groupId = $InputObject.GroupId
                    } else {
                        throw "InputObject does not have a GroupID property. Please provide a valid boundary group object from Get-CM7BoundaryGroup."
                    }

                    $query = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"
                    $group = Get-CimInstance @cimParams -Query $query

                    if (-not $group) {
                        throw "No boundary group found with GroupID $groupId (from InputObject)."
                    }
                }
            }

            $groupName = $group.Name
            $groupId   = $group.GroupID

            if ($PSCmdlet.ShouldProcess("$groupName (GroupID: $groupId)", "Modify boundary group")) {

                # ---- Build the property update hashtable ----
                $propertyUpdate = @{}
                $hasPropertyChange = $false

                if ($PSBoundParameters.ContainsKey('NewName')) {
                    $propertyUpdate['Name'] = $NewName
                    $hasPropertyChange = $true
                }

                if ($PSBoundParameters.ContainsKey('Description')) {
                    $propertyUpdate['Description'] = $Description
                    $hasPropertyChange = $true
                }

                if ($PSBoundParameters.ContainsKey('DefaultSiteCode')) {
                    $propertyUpdate['DefaultSiteCode'] = if ([string]::IsNullOrEmpty($DefaultSiteCode)) { '' } else { $DefaultSiteCode }
                    $hasPropertyChange = $true
                }

                # ---- Handle Flags bit flags (SMS_BoundaryGroup.Flags property) ----
                $optionsChanged = $PSBoundParameters.ContainsKey('AllowPeerDownload') -or
                                  $PSBoundParameters.ContainsKey('SubnetPeerDownloadOnly') -or
                                  $PSBoundParameters.ContainsKey('PreferDPOverPeer') -or
                                  $PSBoundParameters.ContainsKey('PreferCloudDPOverDP')

                if ($optionsChanged) {
                    $currentOptions = [uint32]$group.Flags

                    if ($PSBoundParameters.ContainsKey('AllowPeerDownload')) {
                        if ($AllowPeerDownload) { $currentOptions = $currentOptions -bor $optionBitAllowPeerDownload }
                        else                    { $currentOptions = $currentOptions -band (-bnot $optionBitAllowPeerDownload) }
                    }

                    if ($PSBoundParameters.ContainsKey('SubnetPeerDownloadOnly')) {
                        if ($SubnetPeerDownloadOnly) { $currentOptions = $currentOptions -bor $optionBitSubnetPeerOnly }
                        else                         { $currentOptions = $currentOptions -band (-bnot $optionBitSubnetPeerOnly) }
                    }

                    if ($PSBoundParameters.ContainsKey('PreferDPOverPeer')) {
                        if ($PreferDPOverPeer) { $currentOptions = $currentOptions -bor $optionBitPreferDPOverPeer }
                        else                   { $currentOptions = $currentOptions -band (-bnot $optionBitPreferDPOverPeer) }
                    }

                    if ($PSBoundParameters.ContainsKey('PreferCloudDPOverDP')) {
                        if ($PreferCloudDPOverDP) { $currentOptions = $currentOptions -bor $optionBitPreferCloudDPOverDP }
                        else                      { $currentOptions = $currentOptions -band (-bnot $optionBitPreferCloudDPOverDP) }
                    }

                    $propertyUpdate['Flags'] = $currentOptions
                    $hasPropertyChange = $true
                }

                # ---- Apply property changes via Set-CimInstance ----
                if ($hasPropertyChange) {
                    Write-Verbose "Updating properties for boundary group '$groupName' (GroupID: $groupId)"
                    Set-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $group -Property $propertyUpdate
                }

                # ---- Site system server management ----
                # Re-fetch the group instance after property changes for method invocation
                $groupInstance = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"

                # Clear all site system servers
                if ($ClearSiteSystemServer) {
                    try {
                        $existingServers = Get-CimInstance @cimParams -Query "SELECT * FROM SMS_BoundaryGroupSiteSystems WHERE GroupID = $groupId" -ErrorAction SilentlyContinue
                        if ($existingServers) {
                            $nalPathsToRemove = @($existingServers | ForEach-Object { $_.ServerNALPath })
                            Write-Verbose "Clearing $($nalPathsToRemove.Count) site system server(s) from boundary group '$groupName'"
                            $methodResult = Invoke-CimMethod -InputObject $groupInstance -MethodName 'RemoveSiteSystem' -Arguments @{
                                ServerNALPath = [string[]]$nalPathsToRemove
                            }
                            if ($methodResult.ReturnValue -ne 0) {
                                Write-Warning "RemoveSiteSystem (ClearAll) returned non-zero exit code $($methodResult.ReturnValue) for boundary group '$groupName'."
                            }
                        } else {
                            Write-Verbose "No site system servers to clear for boundary group '$groupName'."
                        }
                    } catch {
                        Write-Warning "Could not clear site system servers from boundary group '$groupName': $_"
                    }
                }

                # Remove specified site system servers
                if ($RemoveSiteSystemServerName -and $RemoveSiteSystemServerName.Count -gt 0) {
                    try {
                        $nalPathsToRemove = $RemoveSiteSystemServerName | ForEach-Object {
                            "[`"Display=\\$_\`"]MSWNET:[`"SMS_SITE=$($script:CMConnection.SiteCode)`"]\\$_\"
                        }
                        Write-Verbose "Removing $($RemoveSiteSystemServerName.Count) site system server(s) from boundary group '$groupName'"
                        $methodResult = Invoke-CimMethod -InputObject $groupInstance -MethodName 'RemoveSiteSystem' -Arguments @{
                            ServerNALPath = [string[]]$nalPathsToRemove
                        }
                        if ($methodResult.ReturnValue -ne 0) {
                            Write-Warning "RemoveSiteSystem returned non-zero exit code $($methodResult.ReturnValue) for boundary group '$groupName'."
                        }
                    } catch {
                        Write-Warning "Could not remove site system server(s) from boundary group '$groupName': $_"
                    }
                }

                # Add specified site system servers
                if ($AddSiteSystemServerName -and $AddSiteSystemServerName.Count -gt 0) {
                    try {
                        $nalPathsToAdd = $AddSiteSystemServerName | ForEach-Object {
                            "[`"Display=\\$_\`"]MSWNET:[`"SMS_SITE=$($script:CMConnection.SiteCode)`"]\\$_\"
                        }
                        $flags = [uint32[]](@(0) * $AddSiteSystemServerName.Count)
                        Write-Verbose "Adding $($AddSiteSystemServerName.Count) site system server(s) to boundary group '$groupName'"
                        $methodResult = Invoke-CimMethod -InputObject $groupInstance -MethodName 'AddSiteSystem' -Arguments @{
                            ServerNALPath = [string[]]$nalPathsToAdd
                            Flags         = $flags
                        }
                        if ($methodResult.ReturnValue -ne 0) {
                            Write-Warning "AddSiteSystem returned non-zero exit code $($methodResult.ReturnValue) for boundary group '$groupName'."
                        }
                    } catch {
                        Write-Warning "Could not add site system server(s) to boundary group '$groupName': $_"
                    }
                }

                # ---- PassThru: return updated object ----
                if ($PassThru) {
                    $effectiveName = if ($PSBoundParameters.ContainsKey('NewName')) { $NewName } else { $groupName }
                    $resultQuery = "SELECT * FROM SMS_BoundaryGroup WHERE GroupID = $groupId"
                    $result = Get-CimInstance @cimParams -Query $resultQuery

                    if ($result) {
                        $output = [PSCustomObject]@{
                            PSTypeName                      = 'MECM7.BoundaryGroup'
                            GroupID                         = [int]$result.GroupID
                            Name                            = $result.Name
                            Description                     = $result.Description
                            DefaultSiteCode                 = $result.DefaultSiteCode
                            MemberCount                     = $result.MemberCount
                            Flags           = $result.Flags
                        }
                        $output.PSObject.TypeNames.Insert(0, 'MECM7.BoundaryGroup')
                        $result.CimInstanceProperties | ForEach-Object {
                            if ($_.Name -notin $output.PSObject.Properties.Name) {
                                $output | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                            }
                        }
                        Write-Output $output
                    } else {
                        Write-Warning "Could not retrieve boundary group after modification. GroupID: $groupId"
                    }
                }
            }
        } catch {
            throw $_
        }
    }
}
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
function Set-CM7TaskSequenceDeployment {
    <#
        .SYNOPSIS
            Configures an existing task sequence deployment in MECM using CIM.

        .DESCRIPTION
            Updates one or more existing task sequence deployments (SMS_Advertisement with ProgramName = '*')
            in Microsoft Endpoint Configuration Manager (MECM) using CIM.

            This is the CIM-based equivalent of the Set-CMTaskSequenceDeployment cmdlet from the
            ConfigurationManager PowerShell module, but uses direct CIM queries over WinRM.

            Supported update scenarios:
            - Update by deployment ID
            - Update by deployment input object (including pipeline)
            - Update by task sequence name/package ID with optional collection targeting
            - Update deployment flags and common scheduling/time settings

            Parameters related to full schedule-token manipulation (AddSchedule/RemoveSchedule/Schedule/ClearSchedule)
            are declared for compatibility but are currently not supported in this CIM implementation.

        .PARAMETER InputObject
            Task sequence deployment object to update. Must contain AdvertisementID.

        .PARAMETER TaskSequenceDeploymentId
            AdvertisementID (deployment ID) of the task sequence deployment to update.

        .PARAMETER TaskSequenceName
            Task sequence name used to locate deployments to update.

        .PARAMETER TaskSequencePackageId
            Task sequence package ID used to locate deployments to update.

        .PARAMETER Collection
            Collection object used to target deployments and/or set target collection.

        .PARAMETER CollectionId
            Collection ID used to target deployments and/or set target collection.

        .PARAMETER CollectionName
            Collection name used to target deployments and/or set target collection.

        .PARAMETER AlertDateTime
            Alert date time. Best-effort property mapping in CIM.

        .PARAMETER AllowFallback
            Allow fallback source location for content.

        .PARAMETER AllowSharedContent
            Allow shared content (peer cache/BranchCache equivalent behavior).

        .PARAMETER AllowUsersRunIndependently
            Allow users to run independently. Best-effort property mapping in CIM.

        .PARAMETER Comment
            Deployment comment.

        .PARAMETER CreateAlertOnFailure
            Create alert on failure. Best-effort property mapping in CIM.

        .PARAMETER CreateAlertOnSuccess
            Create alert on success. Best-effort property mapping in CIM.

        .PARAMETER DeploymentAvailableDateTime
            Deployment available date/time.

        .PARAMETER DeploymentExpireDateTime
            Deployment expiration date/time.

        .PARAMETER DeploymentOption
            Content download behavior.

        .PARAMETER InternetOption
            Allow internet clients.

        .PARAMETER MakeAvailableTo
            Controls deployment availability target (clients/media/pxe).

        .PARAMETER PercentFailure
            Failure alert threshold percentage. Best-effort property mapping in CIM.

        .PARAMETER PercentSuccess
            Success alert threshold percentage. Best-effort property mapping in CIM.

        .PARAMETER PersistOnWriteFilterDevice
            Persist content on write filter devices.

        .PARAMETER RerunBehavior
            Rerun behavior for the task sequence deployment.

        .PARAMETER ClearSchedule
            Declared for compatibility. Not supported in this CIM implementation.

        .PARAMETER RemoveSchedule
            Declared for compatibility. Not supported in this CIM implementation.

        .PARAMETER AddSchedule
            Declared for compatibility. Not supported in this CIM implementation.

        .PARAMETER Schedule
            Declared for compatibility. Not supported in this CIM implementation.

        .PARAMETER ClearScheduleEvent
            Clear all schedule event flags (AsSoonAsPossible, LogOn, LogOff).

        .PARAMETER RemoveScheduleEvent
            Remove one or more schedule events.

        .PARAMETER AddScheduleEvent
            Add one or more schedule events.

        .PARAMETER ScheduleEvent
            Set schedule event flags exactly to the specified values.

        .PARAMETER SendWakeupPacket
            Send wake-up packet before deployment.

        .PARAMETER ShowTaskSequenceProgress
            Show task sequence progress.

        .PARAMETER SoftwareInstallation
            Allow software installation outside maintenance windows.

        .PARAMETER SystemRestart
            Allow system restart outside maintenance windows.

        .PARAMETER UseMeteredNetwork
            Allow use on metered network.

        .PARAMETER UseUtcForAvailableSchedule
            Use UTC for available schedule.

        .PARAMETER UseUtcForExpireSchedule
            Use UTC for expire schedule.

        .PARAMETER PassThru
            Return updated deployment object(s).

        .PARAMETER DisableWildcardHandling
            Treat wildcard characters as literals in CollectionName filtering.

        .PARAMETER ForceWildcardHandling
            Force wildcard handling for CollectionName filtering.

        .PARAMETER Force
            Suppress confirmation prompts.

        .EXAMPLE
            Set-CM7TaskSequenceDeployment -TaskSequenceDeploymentId "SD120BD2" -Comment "Updated by automation" -ShowTaskSequenceProgress $true -PassThru

        .EXAMPLE
            Get-CM7TaskSequenceDeployment -AdvertisementID "SD120BD2" | Set-CM7TaskSequenceDeployment -UseMeteredNetwork $false -PassThru

        .EXAMPLE
            Set-CM7TaskSequenceDeployment -TaskSequencePackageId "SD100FAD" -CollectionName "Test-Collection-Direct" -AllowFallback $true -DeploymentOption RunFromDistributionPoint

        .NOTES
            Requires an active connection established via Connect-CM7.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByDeploymentId')]
    param(
        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true)]
        [Alias('Deployment', 'DeploymentSummary', 'TaskSequence', 'Advertisement')]
        [ValidateNotNull()]
        [PSObject]$InputObject,

        [Parameter(ParameterSetName = 'ByDeploymentId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequenceDeploymentId,

        [Parameter(ParameterSetName = 'ByTaskSequenceName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequenceName,

        [Parameter(ParameterSetName = 'ByTaskSequencePackageId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TaskSequencePackageId,

        [Parameter()]
        [PSObject]$Collection,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter()]
        [datetime]$AlertDateTime,

        [Parameter()]
        [Boolean]$AllowFallback,

        [Parameter()]
        [Boolean]$AllowSharedContent,

        [Parameter()]
        [Boolean]$AllowUsersRunIndependently,

        [Parameter()]
        [string]$Comment,

        [Parameter()]
        [Boolean]$CreateAlertOnFailure,

        [Parameter()]
        [Boolean]$CreateAlertOnSuccess,

        [Parameter()]
        [datetime]$DeploymentAvailableDateTime,

        [Parameter()]
        [datetime]$DeploymentExpireDateTime,

        [Parameter()]
        [ValidateSet('DownloadContentLocallyWhenNeededByRunningTaskSequence', 'DownloadAllContentLocallyBeforeStartingTaskSequence', 'RunFromDistributionPoint')]
        [string]$DeploymentOption,

        [Parameter()]
        [Boolean]$InternetOption,

        [Parameter()]
        [ValidateSet('Clients', 'ClientsMediaAndPxe', 'MediaAndPxe', 'MediaAndPxeHidden')]
        [string]$MakeAvailableTo,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$PercentFailure,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$PercentSuccess,

        [Parameter()]
        [Boolean]$PersistOnWriteFilterDevice,

        [Parameter()]
        [ValidateSet('NeverRerunDeployedProgram', 'AlwaysRerunProgram', 'RerunIfFailedPreviousAttempt', 'RerunIfSucceededOnPreviousAttempt')]
        [string]$RerunBehavior,

        [Parameter()]
        [switch]$ClearSchedule,

        [Parameter()]
        [PSObject[]]$RemoveSchedule,

        [Parameter()]
        [PSObject[]]$AddSchedule,

        [Parameter()]
        [PSObject[]]$Schedule,

        [Parameter()]
        [switch]$ClearScheduleEvent,

        [Parameter()]
        [ValidateSet('AsSoonAsPossible', 'LogOn', 'LogOff')]
        [string[]]$RemoveScheduleEvent,

        [Parameter()]
        [ValidateSet('AsSoonAsPossible', 'LogOn', 'LogOff')]
        [string[]]$AddScheduleEvent,

        [Parameter()]
        [ValidateSet('AsSoonAsPossible', 'LogOn', 'LogOff')]
        [string[]]$ScheduleEvent,

        [Parameter()]
        [Boolean]$SendWakeupPacket,

        [Parameter()]
        [Boolean]$ShowTaskSequenceProgress,

        [Parameter()]
        [Boolean]$SoftwareInstallation,

        [Parameter()]
        [Boolean]$SystemRestart,

        [Parameter()]
        [Boolean]$UseMeteredNetwork,

        [Parameter()]
        [Boolean]$UseUtcForAvailableSchedule,

        [Parameter()]
        [Boolean]$UseUtcForExpireSchedule,

        [Parameter()]
        [switch]$PassThru,

        [Parameter()]
        [switch]$DisableWildcardHandling,

        [Parameter()]
        [switch]$ForceWildcardHandling,

        [Parameter()]
        [switch]$Force
    )

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "Running $function"

        if (-not $script:CMConnection.CimSession) {
            throw "Not connected to MECM. Please run Connect-CM7 first."
        }

        if ($DisableWildcardHandling -and $ForceWildcardHandling) {
            throw "DisableWildcardHandling and ForceWildcardHandling cannot be used together."
        }

        if ($ClearSchedule -or $Schedule -or $AddSchedule -or $RemoveSchedule) {
            throw "Schedule token manipulation parameters (ClearSchedule, Schedule, AddSchedule, RemoveSchedule) are currently not supported in this CIM implementation."
        }

        $namespace = "root/SMS/site_$($script:CMConnection.SiteCode)"
        $cimParams = @{
            CimSession = $script:CMConnection.CimSession
            Namespace  = $namespace
        }

        $ADVERT_IMMEDIATE                      = [uint32]0x00000020
        $ADVERT_ONUSERLOGON                    = [uint32]0x00000200
        $ADVERT_ONUSERLOGOFF                   = [uint32]0x00000400
        $ADVERT_ENABLE_TS_FROM_CD_AND_PXE      = [uint32]0x00002000
        $ADVERT_NO_DISPLAY                     = [uint32]0x00008000
        $ADVERT_OVERRIDE_SERVICE_WINDOWS       = [uint32]0x00010000
        $ADVERT_REBOOT_OUTSIDE_SERVICE_WINDOWS = [uint32]0x00020000
        $ADVERT_WAKE_ON_LAN                    = [uint32]0x00040000
        $ADVERT_DONOT_FALLBACK                 = [uint32]0x00080000
        $ADVERT_SHOW_PROGRESS                  = [uint32]0x02000000

        $RCF_DOWNLOAD_FROM_REMOTE_DP           = [uint32]0x00000002
        $RCF_DONT_RUN_NO_LOCAL_DP              = [uint32]0x00000004
        $RCF_ALLOW_SHARED_CONTENT              = [uint32]0x00000010
        $RCF_ALWAYS_RERUN                      = [uint32]0x00000020
        $RCF_RERUN_IF_FAILED                   = [uint32]0x00000040
        $RCF_RERUN_IF_SUCCEEDED                = [uint32]0x00000080
        $RCF_PERSIST_ON_WRITE_FILTER           = [uint32]0x00000400
        $RCF_ALLOW_INTERNET_CLIENTS            = [uint32]0x00000800
        $RCF_TS_SHOW_PROGRESS                  = [uint32]0x00004000
        $RCF_USE_METERED_NETWORK               = [uint32]0x00008000

        $collectionLookup = @{}
        $deploymentIdList = New-Object System.Collections.Generic.List[string]
    }

    process {
        try {
            $resolvedCollections = @()

            if ($Collection) {
                $collectionObjectId = $null
                if ($Collection.PSObject.Properties['CollectionID']) {
                    $collectionObjectId = [string]$Collection.CollectionID
                }
                elseif ($Collection.PSObject.Properties['CollectionId']) {
                    $collectionObjectId = [string]$Collection.CollectionId
                }

                if ($collectionObjectId) {
                    $resolvedCollections = @(Get-CM7Collection -CollectionId $collectionObjectId -CollectionType Device)
                }
                elseif ($Collection.PSObject.Properties['Name']) {
                    $CollectionName = [string]$Collection.Name
                }
                else {
                    throw "Collection object must have CollectionID/CollectionId or Name property."
                }
            }

            if (-not $resolvedCollections -and $CollectionId) {
                $resolvedCollections = @(Get-CM7Collection -CollectionId $CollectionId -CollectionType Device)
            }

            if (-not $resolvedCollections -and $CollectionName) {
                if ($DisableWildcardHandling) {
                    $resolvedCollections = @(Get-CM7Collection -Name $CollectionName -CollectionType Device | Where-Object { $_.Name -eq $CollectionName })
                }
                elseif ($ForceWildcardHandling) {
                    $collectionPattern = if ($CollectionName -match '[\*\?]') { $CollectionName } else { "*$CollectionName*" }
                    $resolvedCollections = @(Get-CM7Collection -Name $collectionPattern -CollectionType Device)
                }
                else {
                    $resolvedCollections = @(Get-CM7Collection -Name $CollectionName -CollectionType Device)
                }
            }

            if (($Collection -or $CollectionId -or $CollectionName) -and (-not $resolvedCollections -or $resolvedCollections.Count -eq 0)) {
                $collectionIdentifier = if ($CollectionName) { $CollectionName } elseif ($CollectionId) { $CollectionId } else { '<collection object>' }
                throw "Device collection '$collectionIdentifier' not found."
            }

            foreach ($c in $resolvedCollections) {
                $resolvedCollectionId = if ($c.PSObject.Properties['CollectionID']) { $c.CollectionID } else { $c.CollectionId }
                $collectionLookup[[string]$resolvedCollectionId] = $c.Name
            }

            switch ($PSCmdlet.ParameterSetName) {
                'ByInputObject' {
                    $id = $null
                    if ($InputObject.PSObject.Properties['AdvertisementID']) {
                        $id = [string]$InputObject.AdvertisementID
                    }
                    if (-not $id) {
                        throw "InputObject does not have an AdvertisementID property."
                    }
                    $deploymentIdList.Add($id)
                }

                'ByDeploymentId' {
                    $deploymentIdList.Add($TaskSequenceDeploymentId)
                }

                'ByTaskSequenceName' {
                    $tsQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE Name = '$TaskSequenceName'"
                    $tsRows = @(Get-CimInstance @cimParams -Query $tsQuery)
                    if (-not $tsRows) {
                        throw "Task sequence '$TaskSequenceName' not found."
                    }
                    if ($tsRows.Count -gt 1) {
                        throw "Multiple task sequences found matching '$TaskSequenceName'. Please use -TaskSequencePackageId."
                    }

                    $resolvedPkgId = [string]$tsRows[0].PackageID
                    $advFilter = @("ProgramName = '*'", "PackageID = '$resolvedPkgId'")
                    if ($resolvedCollections.Count -gt 0) {
                        $orClauses = $resolvedCollections | ForEach-Object {
                            $resolvedCollectionId = if ($_.PSObject.Properties['CollectionID']) { $_.CollectionID } else { $_.CollectionId }
                            "CollectionID = '$resolvedCollectionId'"
                        }
                        $advFilter += "(" + ($orClauses -join ' OR ') + ")"
                    }

                    $advQuery = "SELECT AdvertisementID FROM SMS_Advertisement WHERE " + ($advFilter -join ' AND ')
                    $advRows = @(Get-CimInstance @cimParams -Query $advQuery)
                    if (-not $advRows) {
                        throw "No task sequence deployments found for task sequence '$TaskSequenceName'."
                    }
                    foreach ($r in $advRows) {
                        $deploymentIdList.Add([string]$r.AdvertisementID)
                    }
                }

                'ByTaskSequencePackageId' {
                    $tsCheckQuery = "SELECT PackageID, Name FROM SMS_TaskSequencePackage WHERE PackageID = '$TaskSequencePackageId'"
                    $tsCheck = @(Get-CimInstance @cimParams -Query $tsCheckQuery)
                    if (-not $tsCheck) {
                        throw "Task sequence with PackageID '$TaskSequencePackageId' not found."
                    }
                    $advFilter = @("ProgramName = '*'", "PackageID = '$TaskSequencePackageId'")
                    if ($resolvedCollections.Count -gt 0) {
                        $orClauses = $resolvedCollections | ForEach-Object {
                            $resolvedCollectionId = if ($_.PSObject.Properties['CollectionID']) { $_.CollectionID } else { $_.CollectionId }
                            "CollectionID = '$resolvedCollectionId'"
                        }
                        $advFilter += "(" + ($orClauses -join ' OR ') + ")"
                    }

                    $advQuery = "SELECT AdvertisementID FROM SMS_Advertisement WHERE " + ($advFilter -join ' AND ')
                    $advRows = @(Get-CimInstance @cimParams -Query $advQuery)
                    if (-not $advRows) {
                        throw "No task sequence deployments found for PackageID '$TaskSequencePackageId'."
                    }
                    foreach ($r in $advRows) {
                        $deploymentIdList.Add([string]$r.AdvertisementID)
                    }
                }
            }

            $targetIds = @($deploymentIdList | Select-Object -Unique)
            if (-not $targetIds -or $targetIds.Count -eq 0) {
                throw "No task sequence deployment targets were resolved."
            }

            foreach ($advId in $targetIds) {
                # Explicit non-lazy property list avoids HRESULT 0x80041001 from Set-CimInstance.
                # SMS_Advertisement lazy properties (AssignedSchedule*, PresentTimeEnabled,
                # PresentTimeIsGMT, ExpirationTimeEnabled, ExpirationTimeIsGMT, TimeFlags) cause
                # the provider to reject ModifyInstance when the full instance is sent back.
                # Use SELECT * so the CimInstance contains all properties (including lazy ones) with their
                # real values. This is required for Required deployments: the provider validates that
                # AssignedSchedule/AssignedScheduleEnabled are non-null on any ModifyInstance call, and
                # a partial SELECT would leave those as null, causing HRESULT 0x80041001.
                $getAdvQuery = "SELECT * FROM SMS_Advertisement WHERE AdvertisementID = '$advId' AND ProgramName = '*'"
                $deployment = @(Get-CimInstance @cimParams -Query $getAdvQuery)[0]
                if (-not $deployment) {
                    throw "Task sequence deployment with AdvertisementID '$advId' was not found."
                }

                $displayName = "$($deployment.AdvertisementName) ($($deployment.AdvertisementID))"
                $actionDescription = "Update task sequence deployment '$($deployment.AdvertisementName)' ($($deployment.AdvertisementID))"

                if (-not ($Force -or $PSCmdlet.ShouldProcess($displayName, $actionDescription))) {
                    continue
                }

                [uint32]$advertFlags = [uint32]$deployment.AdvertFlags
                [uint32]$remoteClientFlags = [uint32]$deployment.RemoteClientFlags
                [uint32]$origAdvertFlags = $advertFlags
                [uint32]$origRemoteClientFlags = $remoteClientFlags

                if ($PSBoundParameters.ContainsKey('AllowFallback')) {
                    if ($AllowFallback) {
                        $advertFlags = $advertFlags -band (-bnot $ADVERT_DONOT_FALLBACK)
                    } else {
                        $advertFlags = $advertFlags -bor $ADVERT_DONOT_FALLBACK
                    }
                }

                if ($PSBoundParameters.ContainsKey('SoftwareInstallation')) {
                    if ($SoftwareInstallation) {
                        $advertFlags = $advertFlags -bor $ADVERT_OVERRIDE_SERVICE_WINDOWS
                    } else {
                        $advertFlags = $advertFlags -band (-bnot $ADVERT_OVERRIDE_SERVICE_WINDOWS)
                    }
                }

                if ($PSBoundParameters.ContainsKey('SystemRestart')) {
                    if ($SystemRestart) {
                        $advertFlags = $advertFlags -bor $ADVERT_REBOOT_OUTSIDE_SERVICE_WINDOWS
                    } else {
                        $advertFlags = $advertFlags -band (-bnot $ADVERT_REBOOT_OUTSIDE_SERVICE_WINDOWS)
                    }
                }

                if ($PSBoundParameters.ContainsKey('SendWakeupPacket')) {
                    if ($SendWakeupPacket) {
                        $advertFlags = $advertFlags -bor $ADVERT_WAKE_ON_LAN
                    } else {
                        $advertFlags = $advertFlags -band (-bnot $ADVERT_WAKE_ON_LAN)
                    }
                }

                if ($PSBoundParameters.ContainsKey('ShowTaskSequenceProgress')) {
                    if ($ShowTaskSequenceProgress) {
                        $advertFlags = $advertFlags -bor $ADVERT_SHOW_PROGRESS
                        $remoteClientFlags = $remoteClientFlags -bor $RCF_TS_SHOW_PROGRESS
                    } else {
                        $advertFlags = $advertFlags -band (-bnot $ADVERT_SHOW_PROGRESS)
                        $remoteClientFlags = $remoteClientFlags -band (-bnot $RCF_TS_SHOW_PROGRESS)
                    }
                }

                if ($PSBoundParameters.ContainsKey('MakeAvailableTo')) {
                    $advertFlags = $advertFlags -band (-bnot ($ADVERT_ENABLE_TS_FROM_CD_AND_PXE -bor $ADVERT_NO_DISPLAY))
                    switch ($MakeAvailableTo) {
                        'Clients' { }
                        'ClientsMediaAndPxe' { $advertFlags = $advertFlags -bor $ADVERT_ENABLE_TS_FROM_CD_AND_PXE }
                        'MediaAndPxe' { $advertFlags = $advertFlags -bor $ADVERT_ENABLE_TS_FROM_CD_AND_PXE }
                        'MediaAndPxeHidden' {
                            $advertFlags = $advertFlags -bor $ADVERT_ENABLE_TS_FROM_CD_AND_PXE
                            $advertFlags = $advertFlags -bor $ADVERT_NO_DISPLAY
                        }
                    }
                }

                $eventMask = ($ADVERT_IMMEDIATE -bor $ADVERT_ONUSERLOGON -bor $ADVERT_ONUSERLOGOFF)
                if ($ClearScheduleEvent) {
                    $advertFlags = $advertFlags -band (-bnot $eventMask)
                    # For Required deployments, clearing all schedule events is not allowed
                    $isRequired = ($deployment.PSObject.Properties['Mandatory'] -and $deployment.Mandatory) -or ($deployment.PSObject.Properties['AdvertFlags'] -and ($advertFlags -band $ADVERT_IMMEDIATE))
                    $hasSchedule = ($advertFlags -band $eventMask) -ne 0
                    if ($isRequired -and -not $hasSchedule) {
                        throw "Required deployments must have at least one schedule event or schedule. Clearing all schedule events is not allowed."
                    }
                }

                if ($PSBoundParameters.ContainsKey('ScheduleEvent')) {
                    $advertFlags = $advertFlags -band (-bnot $eventMask)
                    foreach ($ev in $ScheduleEvent) {
                        switch ($ev) {
                            'AsSoonAsPossible' { $advertFlags = $advertFlags -bor $ADVERT_IMMEDIATE }
                            'LogOn' { $advertFlags = $advertFlags -bor $ADVERT_ONUSERLOGON }
                            'LogOff' { $advertFlags = $advertFlags -bor $ADVERT_ONUSERLOGOFF }
                        }
                    }
                }

                if ($PSBoundParameters.ContainsKey('AddScheduleEvent')) {
                    foreach ($ev in $AddScheduleEvent) {
                        switch ($ev) {
                            'AsSoonAsPossible' { $advertFlags = $advertFlags -bor $ADVERT_IMMEDIATE }
                            'LogOn' { $advertFlags = $advertFlags -bor $ADVERT_ONUSERLOGON }
                            'LogOff' { $advertFlags = $advertFlags -bor $ADVERT_ONUSERLOGOFF }
                        }
                    }
                }

                if ($PSBoundParameters.ContainsKey('RemoveScheduleEvent')) {
                    foreach ($ev in $RemoveScheduleEvent) {
                        switch ($ev) {
                            'AsSoonAsPossible' { $advertFlags = $advertFlags -band (-bnot $ADVERT_IMMEDIATE) }
                            'LogOn' { $advertFlags = $advertFlags -band (-bnot $ADVERT_ONUSERLOGON) }
                            'LogOff' { $advertFlags = $advertFlags -band (-bnot $ADVERT_ONUSERLOGOFF) }
                        }
                    }
                }

                if ($PSBoundParameters.ContainsKey('AllowSharedContent')) {
                    if ($AllowSharedContent) {
                        $remoteClientFlags = $remoteClientFlags -bor $RCF_ALLOW_SHARED_CONTENT
                    } else {
                        $remoteClientFlags = $remoteClientFlags -band (-bnot $RCF_ALLOW_SHARED_CONTENT)
                    }
                }

                if ($PSBoundParameters.ContainsKey('PersistOnWriteFilterDevice')) {
                    if ($PersistOnWriteFilterDevice) {
                        $remoteClientFlags = $remoteClientFlags -bor $RCF_PERSIST_ON_WRITE_FILTER
                    } else {
                        $remoteClientFlags = $remoteClientFlags -band (-bnot $RCF_PERSIST_ON_WRITE_FILTER)
                    }
                }

                if ($PSBoundParameters.ContainsKey('InternetOption')) {
                    if ($InternetOption) {
                        $remoteClientFlags = $remoteClientFlags -bor $RCF_ALLOW_INTERNET_CLIENTS
                    } else {
                        $remoteClientFlags = $remoteClientFlags -band (-bnot $RCF_ALLOW_INTERNET_CLIENTS)
                    }
                }

                if ($PSBoundParameters.ContainsKey('UseMeteredNetwork')) {
                    if ($UseMeteredNetwork) {
                        $remoteClientFlags = $remoteClientFlags -bor $RCF_USE_METERED_NETWORK
                    } else {
                        $remoteClientFlags = $remoteClientFlags -band (-bnot $RCF_USE_METERED_NETWORK)
                    }
                }

                if ($PSBoundParameters.ContainsKey('RerunBehavior')) {
                    $remoteClientFlags = $remoteClientFlags -band (-bnot ($RCF_ALWAYS_RERUN -bor $RCF_RERUN_IF_FAILED -bor $RCF_RERUN_IF_SUCCEEDED))
                    switch ($RerunBehavior) {
                        'NeverRerunDeployedProgram' { }
                        'AlwaysRerunProgram' { $remoteClientFlags = $remoteClientFlags -bor $RCF_ALWAYS_RERUN }
                        'RerunIfFailedPreviousAttempt' { $remoteClientFlags = $remoteClientFlags -bor $RCF_RERUN_IF_FAILED }
                        'RerunIfSucceededOnPreviousAttempt' { $remoteClientFlags = $remoteClientFlags -bor $RCF_RERUN_IF_SUCCEEDED }
                    }
                }

                if ($PSBoundParameters.ContainsKey('DeploymentOption')) {
                    $remoteClientFlags = $remoteClientFlags -band (-bnot ($RCF_DONT_RUN_NO_LOCAL_DP -bor $RCF_DOWNLOAD_FROM_REMOTE_DP))
                    switch ($DeploymentOption) {
                        'DownloadAllContentLocallyBeforeStartingTaskSequence' { }
                        'DownloadContentLocallyWhenNeededByRunningTaskSequence' { $remoteClientFlags = $remoteClientFlags -bor $RCF_DOWNLOAD_FROM_REMOTE_DP }
                        'RunFromDistributionPoint' { $remoteClientFlags = $remoteClientFlags -bor $RCF_DONT_RUN_NO_LOCAL_DP }
                    }
                }

                $setProps = @{}
                if ($advertFlags -ne $origAdvertFlags) {
                    $setProps['AdvertFlags'] = [uint32]$advertFlags
                }
                if ($remoteClientFlags -ne $origRemoteClientFlags) {
                    $setProps['RemoteClientFlags'] = [uint32]$remoteClientFlags
                }

                if ($PSBoundParameters.ContainsKey('Comment')) {
                    $setProps['Comment'] = [string]$Comment
                }

                if ($PSBoundParameters.ContainsKey('DeploymentAvailableDateTime')) {
                    # PresentTimeEnabled and PresentTimeIsGMT are lazy SMS_Advertisement properties
                    # and cannot be set via Set-CimInstance (HRESULT 0x80041001). Only set the datetime value.
                    $setProps['PresentTime'] = [datetime]$DeploymentAvailableDateTime
                }

                if ($PSBoundParameters.ContainsKey('DeploymentExpireDateTime')) {
                    # ExpirationTimeEnabled and ExpirationTimeIsGMT are lazy SMS_Advertisement properties
                    # and cannot be set via Set-CimInstance (HRESULT 0x80041001). Only set the datetime value.
                    $setProps['ExpirationTime'] = [datetime]$DeploymentExpireDateTime
                }

                if ($resolvedCollections.Count -gt 0) {
                    if ($resolvedCollections.Count -gt 1) {
                        throw "CollectionName resolved to multiple collections. Please use a single collection name/id/object when updating target collection."
                    }

                    $resolvedCollectionId = if ($resolvedCollections[0].PSObject.Properties['CollectionID']) { $resolvedCollections[0].CollectionID } else { $resolvedCollections[0].CollectionId }
                    $setProps['CollectionID'] = [string]$resolvedCollectionId
                }

                if ($PSBoundParameters.ContainsKey('AlertDateTime')) {
                    $mapped = $false
                    foreach ($candidate in @('AlertTime', 'AlertDateTime')) {
                        if ($deployment.CimInstanceProperties[$candidate]) {
                            $setProps[$candidate] = [datetime]$AlertDateTime
                            $mapped = $true
                            break
                        }
                    }
                    if (-not $mapped) {
                        Write-Verbose "Could not map parameter 'AlertDateTime' to a known SMS_Advertisement property in this environment."
                    }
                }

                if ($PSBoundParameters.ContainsKey('CreateAlertOnFailure')) {
                    $mapped = $false
                    foreach ($candidate in @('CreateAlertOnFailure', 'RaiseMomAlertsOnFailure', 'CreateAlertBaseOnPercentFailure')) {
                        if ($deployment.CimInstanceProperties[$candidate]) {
                            $setProps[$candidate] = [bool]$CreateAlertOnFailure
                            $mapped = $true
                            break
                        }
                    }
                    if (-not $mapped) {
                        Write-Verbose "Could not map parameter 'CreateAlertOnFailure' to a known SMS_Advertisement property in this environment."
                    }
                }

                if ($PSBoundParameters.ContainsKey('CreateAlertOnSuccess')) {
                    $mapped = $false
                    foreach ($candidate in @('CreateAlertOnSuccess', 'RaiseMomAlertsOnSuccess', 'CreateAlertBaseOnPercentSuccess')) {
                        if ($deployment.CimInstanceProperties[$candidate]) {
                            $setProps[$candidate] = [bool]$CreateAlertOnSuccess
                            $mapped = $true
                            break
                        }
                    }
                    if (-not $mapped) {
                        Write-Verbose "Could not map parameter 'CreateAlertOnSuccess' to a known SMS_Advertisement property in this environment."
                    }
                }

                if ($PSBoundParameters.ContainsKey('PercentFailure')) {
                    $mapped = $false
                    foreach ($candidate in @('PercentFailure')) {
                        if ($deployment.CimInstanceProperties[$candidate]) {
                            $setProps[$candidate] = [int]$PercentFailure
                            $mapped = $true
                            break
                        }
                    }
                    if (-not $mapped) {
                        Write-Verbose "Could not map parameter 'PercentFailure' to a known SMS_Advertisement property in this environment."
                    }
                }

                if ($PSBoundParameters.ContainsKey('PercentSuccess')) {
                    $mapped = $false
                    foreach ($candidate in @('PercentSuccess')) {
                        if ($deployment.CimInstanceProperties[$candidate]) {
                            $setProps[$candidate] = [int]$PercentSuccess
                            $mapped = $true
                            break
                        }
                    }
                    if (-not $mapped) {
                        Write-Verbose "Could not map parameter 'PercentSuccess' to a known SMS_Advertisement property in this environment."
                    }
                }

                if ($PSBoundParameters.ContainsKey('AllowUsersRunIndependently')) {
                    $mapped = $false
                    foreach ($candidate in @('AllowUsersRunIndependently', 'PresentUsers')) {
                        if ($deployment.CimInstanceProperties[$candidate]) {
                            $setProps[$candidate] = [bool]$AllowUsersRunIndependently
                            $mapped = $true
                            break
                        }
                    }
                    if (-not $mapped) {
                        Write-Verbose "Could not map parameter 'AllowUsersRunIndependently' to a known SMS_Advertisement property in this environment."
                    }
                }

                if ($setProps.Count -eq 0) {
                    Write-Verbose "No properties to update for deployment '$($deployment.AdvertisementName)' ($($deployment.AdvertisementID))"
                } else {
                    Write-Verbose "Updating deployment '$($deployment.AdvertisementName)' ($($deployment.AdvertisementID)) via CIM"
                    try {
                        Set-CimInstance -CimSession $script:CMConnection.CimSession -InputObject $deployment -Property $setProps -ErrorAction Stop | Out-Null
                    } catch {
                        $errMsg = $_.Exception.Message
                        if (-not $errMsg) { $errMsg = $_.Message }
                        if ($ClearScheduleEvent -and $isRequired -and -not $hasSchedule -and $errMsg -match "HRESULT 0x80041001|Generic failure") {
                            throw "Required deployments must have at least one schedule event or schedule. Clearing all schedule events is not allowed."
                        } else {
                            throw $_
                        }
                    }
                }

                if ($PassThru) {
                    Get-CM7TaskSequenceDeployment -AdvertisementID $deployment.AdvertisementID
                }
            }
        }
        catch {
            throw $_
        }
    }
}
function Sync-CM7SoftwareUpdate {
    <#
        .SYNOPSIS
            Synchronizes software updates in Configuration Manager

        .DESCRIPTION
            This function performs a synchronization of software updates in Configuration Manager. It can perform either a full sync or a delta sync based on the parameters provided.

        .PARAMETER FullSync
            If set to $true, a full synchronization will be performed. If $false or not provided, a delta synchronization will be performed.

        .EXAMPLE
            Sync-CM7SoftwareUpdate -FullSync $true
            This example performs a full synchronization of software updates.

        .EXAMPLE
            Sync-CM7SoftwareUpdate -FullSync $false
            This example performs a delta synchronization of software updates.

    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $false)]
        [System.Boolean]$FullSync = $false
    )

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    #region Establish CIM session
    $SiteCode = $script:CMConnection.SiteCode
    $CimSession = $Script:CMConnection.CimSession
    $SiteServer = $script:CMConnection.SiteServer
    #endregion

    if ($PSCmdlet.ShouldProcess("Software Update Sync on $siteServer", "Sync")) {
        # Build CIM query or method invocation
        $syncParams = @{
            FullSync = $FullSync
        }
        # Example CIM call (replace with actual CIM class/method for sync)
        try {
            $result = Invoke-CimMethod -CimSession $CimSession -Namespace "root\SMS\site_$SiteCode" -ClassName "SMS_SoftwareUpdate" -MethodName "SyncNow" -Arguments $syncParams
            return $result
        } catch {
            Write-Error $_
        }
    }
}
#endregion
