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
