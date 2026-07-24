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
                $Updates += Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" -Query "SELECT * FROM SMS_SoftwareUpdate WHERE CI_ID='$($id)' OR ArticleID='$($id)'"
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
        # If the target path is a UNC path and we have stored credentials, establish an SMB
        # session so that New-Item / Invoke-WebRequest -OutFile work with the correct identity.
        $targetBasePath = if (-not [string]::IsNullOrEmpty($Location)) { $Location } else { $DeploymentPackage.PkgSourcePath }
        $tempDrive = $null
        if ($targetBasePath -and $targetBasePath.StartsWith('\\') -and $script:CMConnection.Credential) {
            $uncParts = $targetBasePath.TrimStart('\').Split('\')
            $uncRoot  = "\\$($uncParts[0])\$($uncParts[1])"
            $driveName = "CM7T$(Get-Random -Maximum 9999)"
            try {
                $tempDrive = New-PSDrive -Name $driveName -PSProvider FileSystem -Root $uncRoot `
                    -Credential $script:CMConnection.Credential -Scope Global -ErrorAction Stop
                Write-Verbose "Established SMB session to '$uncRoot' for file operations."
            } catch {
                Write-Verbose "Could not establish PSDrive for '$uncRoot': $($_.Exception.Message)"
            }
        }

        # AddUpdateContent must run on the MECM server itself:
        #   1. The SMS Provider reads content from ContentSourcePath.
        #   2. It then writes (creates directories + copies files) into PkgSourcePath.
        #   3. If PkgSourcePath is a loopback UNC (\\sccm01\share on sccm01 itself), the
        #      SMS service account hits the Windows loopback check and cannot create the
        #      destination directory → "Generic failure".
        # Solution: run via PSSession; inside, resolve both paths to local filesystem paths
        # via Win32_Share, temporarily set PkgSourcePath to the local equivalent, call
        # AddUpdateContent, then restore the original UNC path.
        $addContentSession = $null
        $psSessionParams = @{
            ComputerName = $script:CMConnection.SiteServer
            ErrorAction  = 'Stop'
        }
        if ($script:CMConnection.Credential)        { $psSessionParams.Credential    = $script:CMConnection.Credential }
        if ($script:CMConnection.UseSsl)             { $psSessionParams.UseSSL        = $true }
        if ($script:CMConnection.SkipCertificateCheck) {
            $psSessionParams.SessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
        }
        try {
            $addContentSession = New-PSSession @psSessionParams
            Write-Verbose "Established PSSession on MECM server for AddUpdateContent calls."
        } catch {
            Write-Verbose "Could not establish PSSession: $($_.Exception.Message)"
        }

        try {
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
                # Content must be in a per-ContentID subdirectory; AddUpdateContent passes that
                # subdirectory as ContentSourcePath so the Provider can hash-verify the files.
                $FilePath = Join-Path -Path (Join-Path -Path $targetBasePath -ChildPath ([string]$UpdateContent.ContentID)) -ChildPath $FileName

                $DownloadSuccess = $false
                $DownloadAttempts = 0

                do {
                    $DownloadAttempts++
                    try {
                        $Directory = Split-Path -Path $FilePath -Parent
                        if (-not ([System.IO.Directory]::Exists($Directory))) {
                            New-Item -Path $Directory -ItemType Directory -Force | Out-Null
                        }
                        $ProgressPreference = 'SilentlyContinue'
                        Invoke-WebRequest -Uri $UpdateContent.SourceURL -OutFile $FilePath -TimeoutSec $TimeoutSec -ErrorAction Stop
                        if ([System.IO.File]::Exists($FilePath) -and (Get-Item -Path $FilePath).Length -gt 0) {
                            $DownloadSuccess = $true
                        } else {
                            throw "Downloaded file is empty or doesn't exist"
                        }
                    } catch {
                        $updateResult.Status = 'Error'
                        $errMsg = "Download attempt $DownloadAttempts failed for $FileName : $($_.Exception.Message)"
                        $updateResult.Errors += $errMsg
                        $summary.Errors += $errMsg
                        if ([System.IO.File]::Exists($FilePath)) {
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
            if ([boolean]$DownloadOnly) {
                $updateResult.Status = 'Downloaded'
                $ContentIDs = $UpdateContents | Select-Object -ExpandProperty ContentID -Unique
                $summary.UpdatesSucceeded += $ContentIDs.Count
                continue
            } else {
                $ContentIDs = $UpdateContents | Select-Object -ExpandProperty ContentID -Unique
                foreach ($cid in $ContentIDs) {
                    if ($addContentSession) {
                        $ns         = "root/SMS/site_$SiteCode"
                        $pkgId      = $DeploymentPackage.PackageID
                        $srcPath    = Join-Path -Path $targetBasePath -ChildPath ([string]$cid)
                        $pkgSrcPath = [string]$DeploymentPackage.PkgSourcePath

                        $Result = Invoke-Command -Session $addContentSession -ScriptBlock {
                            param($ns, $pkgId, $cid, $srcPath, $pkgSrcPath)

                            function Resolve-LocalPath {
                                param([string]$Path)
                                if (-not $Path.StartsWith('\\')) { return $Path }
                                $parts = $Path.TrimStart('\').Split('\')
                                if ($parts.Length -lt 2) { return $Path }
                                $share = Get-CimInstance -ClassName Win32_Share -Filter "Name='$($parts[1])'" -ErrorAction SilentlyContinue
                                if (-not $share) { return $Path }
                                $sub = if ($parts.Length -gt 2) { $parts[2..($parts.Length-1)] -join '\' } else { '' }
                                if ($sub) { Join-Path $share.Path $sub } else { $share.Path }
                            }

                            $resolvedSrc    = Resolve-LocalPath $srcPath
                            $resolvedPkgSrc = Resolve-LocalPath $pkgSrcPath
                            Write-Verbose "  [AddContent] ContentSourcePath='$resolvedSrc'  PkgSourcePath='$resolvedPkgSrc'"

                            $pkg = Get-CimInstance -Namespace $ns -ClassName SMS_SoftwareUpdatesPackage -Filter "PackageID='$pkgId'"

                            # The SMS Provider writes content to PkgSourcePath. If that is a loopback
                            # UNC (server accessing its own share), Windows blocks the directory creation.
                            # Temporarily switch to the local path so the Provider writes locally.
                            $pathChanged = $false
                            if ($resolvedPkgSrc -ne $pkgSrcPath) {
                                Set-CimInstance -InputObject $pkg -Property @{ PkgSourcePath = $resolvedPkgSrc } -ErrorAction Stop
                                $pkg         = Get-CimInstance -Namespace $ns -ClassName SMS_SoftwareUpdatesPackage -Filter "PackageID='$pkgId'"
                                $pathChanged = $true
                            }
                            try {
                                $Arguments = @{
                                    bRefreshDPs       = [bool]$false
                                    ContentIDs        = [uint32[]]@([uint32]$cid)
                                    ContentSourcePath = [string[]]@([string]$resolvedSrc)
                                }
                                Invoke-CimMethod -InputObject $pkg -MethodName 'AddUpdateContent' -Arguments $Arguments -ErrorAction Stop
                            } finally {
                                if ($pathChanged) {
                                    $pkg = Get-CimInstance -Namespace $ns -ClassName SMS_SoftwareUpdatesPackage -Filter "PackageID='$pkgId'"
                                    Set-CimInstance -InputObject $pkg -Property @{ PkgSourcePath = $pkgSrcPath } -ErrorAction SilentlyContinue
                                }
                            }
                        } -ArgumentList $ns, $pkgId, $cid, $srcPath, $pkgSrcPath
                    } else {
                        # Fallback: direct CIM call (may fail on loopback UNC environments)
                        $pkg = Get-CimInstance -CimSession $CimSession -Namespace "root/SMS/site_$SiteCode" `
                            -ClassName SMS_SoftwareUpdatesPackage -Filter "PackageID='$($DeploymentPackage.PackageID)'"
                        $Arguments = @{
                            bRefreshDPs       = [bool]$false
                            ContentIDs        = [uint32[]]@([uint32]$cid)
                            ContentSourcePath = [string[]]@(Join-Path -Path $targetBasePath -ChildPath ([string]$cid))
                        }
                        $Result = Invoke-CimMethod -InputObject $pkg -MethodName 'AddUpdateContent' -Arguments $Arguments
                    }
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
        } finally {
            if ($tempDrive) {
                Remove-PSDrive -Name $tempDrive.Name -Force -ErrorAction SilentlyContinue
                Write-Verbose "Removed temporary SMB session drive '$($tempDrive.Name)'."
            }
            if ($addContentSession) {
                Remove-PSSession $addContentSession -ErrorAction SilentlyContinue
                Write-Verbose "Removed PSSession for AddUpdateContent."
            }
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
