# New-CM7Application

## SYNOPSIS

Creates a new application in MECM using CIM.

## DESCRIPTION

Creates a new application in MECM via the SMS_Application WMI class using CIM connectivity.
Requires an active connection established via Connect-CM7.

The function retrieves the site's AuthoringScopeId via SMS_Identification.GetSiteID(),
builds the required SDMPackageXML, and creates the application via New-CimInstance.

Note: SMS_Application requires the SDMPackageXML to be a valid AppMgmtDigest XML document
with an XML declaration header. Deletion requires first retiring the app via SetIsExpired,
then calling Remove-CimInstance.

## PARAMETERS

### Name

The display name of the application to create (mandatory).

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Publisher

The publisher / manufacturer of the application (mandatory).

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### SoftwareVersion

The version string of the application (mandatory).

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Description

A description for the application.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### AutoInstall

Whether the application may be installed automatically during a task sequence.
Defaults to $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### ReleaseDate

The release date of the application. Maps to the EffectiveDate WMI property.

- Type: DateTime
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Owner

The owner of the application (LogonName format, e.g., "domain\user" or "username").

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### SupportContact

The support contact for the application (LogonName format).

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### SupportUrl

The support URL for the application. Used as the InformativeURL if InformationUrl is not set.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### IsEnabled

Whether the application is enabled. Defaults to $true.

- Type: Boolean
- Required: false
- Default value: True
- Accept pipeline input: false
- Accept wildcard characters: false

### IsHidden

Whether the application is hidden from the Software Center. Defaults to $false.

- Type: Boolean
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

### PrivacyUrl

Privacy statement URL for the application. Stored as <PrivacyURL> in DisplayInfo/Info.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### InfoUrl

More information / help URL for the application. Takes precedence over SupportUrl as
the InformativeURL in the AppMgmtDigest XML.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### InfoUrlText

The display text for the InfoUrl link. Stored as <InfoURLText> in DisplayInfo/Info.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Icon

Reserved for future use (byte array of the icon). Not yet implemented in XML serialization.

- Type: Byte[]
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Tags



- Type: String[]
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1

```powershell
New-CM7Application -Name "MyApp" -Publisher "Contoso" -SoftwareVersion "1.0.0"
            Creates a minimal application.
```

### Example 2

```powershell
New-CM7Application -Name "MyApp" -Publisher "Contoso" -SoftwareVersion "2.0" `
                -Description "My application" -AutoInstall $true -Owner "domain\admin" `
                -SupportContact "helpdesk" -IsEnabled $true -IsHidden $false `
                -InfoUrl "https://contoso.com/myapp" -PrivacyUrl "https://contoso.com/privacy"
            Creates an application with all common metadata.
```
