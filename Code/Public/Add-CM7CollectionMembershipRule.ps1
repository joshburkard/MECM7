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
