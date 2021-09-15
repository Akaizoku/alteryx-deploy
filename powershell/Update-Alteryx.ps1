function Update-Alteryx {
    <#
        .SYNOPSIS
        Update Alteryx

        .DESCRIPTION
        Upgrade Alteryx Server
        
        .NOTES
        File name:      Update-Alteryx.ps1
        Author:         Florian Carrier
        Creation date:  2021-09-02
        Last modified:  2021-09-10
    #>
    [CmdletBinding (
        SupportsShouldProcess = $true
    )]
    Param (
        [Parameter (
            Position    = 1,
            Mandatory   = $true,
            HelpMessage = "Properties"
        )]
        [ValidateNotNullOrEmpty ()]
        [System.Collections.Specialized.OrderedDictionary]
        $Properties,
        [Parameter (
            Position    = 2,
            Mandatory   = $true,
            HelpMessage = "Installation properties"
        )]
        [ValidateNotNullOrEmpty ()]
        [System.Collections.Specialized.OrderedDictionary]
        $InstallationProperties,
        [Parameter (
            HelpMessage = "Non-interactive mode"
        )]
        [Switch]
        $Unattended
    )
    Begin {
        # Get global preference vrariables
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        # Retrieve Alteryx Service utility path
        $AlteryxService = Get-AlteryxServerProcess -Process "Service" -InstallDirectory $Properties.InstallationPath
        # Define error counter
    }
    Process {
        Write-Log -Type "CHECK" -Object "Starting Alteryx Server upgrade to $($Properties.Version)"
        # Retrieve current version
        Write-Log -Type "INFO" -Object "Retrieving current version"
        if ($PSCmdlet.ShouldProcess("Alteryx version", "Retrieve")) {
            $BackupVersion = Get-AlteryxVersion -Path $AlteryxService
        }
        Write-Log -Type "DEBUG" -Object $BackupVersion
        # Create back-up
        Invoke-BackupAlteryx -Properties $Properties -Unattended:$Unattended
        # Upgrade
        Install-Alteryx -Properties $Properties -InstallationProperties $InstallationProperties -Unattended:$Unattended
        # Check for errors
        if ($Error.Count -gt 0) {
            Write-Log -Type "ERROR" -Object "Upgrade process failed with $($Errors.Count) errors"
            Write-Log -Type "WARN" -Object "Restoring previous version ($BackupVersion)"
            # Overwrite target version
            $Properties.Version = $BackupVersion
            # Reinstall Alteryx
            Install-Alteryx -Properties $Properties -Unattended:$Unattended
            # Restore backup
            Invoke-RestoreAlteryx -Properties $Properties -Unattended:$Unattended
        } else {
            Write-Log -Type "CHECK" -Object "Alteryx Server upgrade completed successfully"
        }
    }
}