<#
    Generated at 02/18/2026 15:31:36 by Josua Burkard
#>
#region namespace MECM7
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
    SkipCertificateCheck = $false
    UseSsl = $false
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
        [ValidatePattern('^\S+$', ErrorMessage = 'Variable name must not contain spaces.')]
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
        [ValidatePattern('^\S+$', ErrorMessage = 'Variable name must not contain spaces.')]
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

        # Raw schedule token (alternative to building schedule)
        [Parameter(ParameterSetName = 'ByCollectionNameScheduleToken', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ByCollectionIdScheduleToken', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Schedule,

        [Parameter()]
        [ValidateSet('Any', 'SoftwareUpdatesOnly', 'TaskSequencesOnly')]
        [string]$ApplyTo = 'Any',

        [Parameter()]
        [bool]$IsEnabled = $true,

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
                # Use the provided raw schedule token
                $scheduleString = $Schedule
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
                $fullSettings | Set-CimInstance

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
#endregion
