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
