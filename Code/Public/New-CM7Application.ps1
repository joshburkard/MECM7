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
