function Get-CM7SoftwareUpdateSyncStatus {
    <#
        .SYNOPSIS
            Gets the software update sync status from MECM.

        .DESCRIPTION
            This function retrieves the current software update synchronization status from the MECM server.

        .EXAMPLE
            Get-CM7SoftwareUpdateSyncStatus

            Retrieves the current software update sync status from the connected MECM server.

    #>
    [CmdletBinding()]
    param (
    )

    $function = $($MyInvocation.MyCommand.Name)
    Write-Verbose "Running $function"

    # Validate connection
    if (-not $script:CMConnection.CimSession) {
        throw "Not connected to MECM. Please run Connect-CM7 first."
    }

    $syncStatus = Get-CimInstance -CimSession $script:CMConnection.CimSession -Namespace "root/SMS/site_$($script:CMConnection.SiteCode)" -ClassName "SMS_SUPSyncStatus"

    if (-not $syncStatus) {
        Write-Verbose "No software update sync status found."
        return
    }

    $lastSyncStatus = switch ($syncStatus.LastSyncState) {
        6702 {'WSUS Synchronization done (Success)'}
        6703 {'WSUS Synchronization failed'}
        6704 {'WSUS Synchronization in progress. Current phase: Synchronizing WSUS Server'}
        6705 {'WSUS Synchronization in progress. Current phase: Synchronizing site database'}
        6706 {'WSUS Synchronization in progress. Current phase: Synchronizing Internet facing WSUS Server'}
        6707 {'Content of WSUS server is out of sync with upstream server'}
        6708 {'WSUS synchronization complete, with pending license terms downloads'}
        default {'Unknown'}
    }
    $syncStatus | Add-Member -MemberType NoteProperty -Name 'LastSyncStatus' -Value $lastSyncStatus

    # Return the sync status
    return $syncStatus
}
