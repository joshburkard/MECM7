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
