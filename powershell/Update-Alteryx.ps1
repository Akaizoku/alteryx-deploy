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
        Last modified:  2021-12-08
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
        $AlteryxService = Get-AlteryxUtility -Utility "Service" -Path $Properties.InstallationPath
        # Clear error pipeline
        $Error.Clear()
        # Retrieve current version
        Write-Log -Type "DEBUG" -Object "Retrieving current version"
        if ($PSCmdlet.ShouldProcess("Alteryx version", "Retrieve")) {
            $AlteryxVersion = Get-AlteryxVersion -Path $AlteryxService
            Write-Log -Type "DEBUG" -Object $AlteryxVersion
            $BackupVersion = Select-String -InputObject $AlteryxVersion -Pattern "\d+\.\d+.\d+(.\d+)?" | ForEach-Object { $PSItem.Matches.Value }
        }
        # Set upgrade activation option
        $Properties.ActivateOnInstall = $Properties.ActivateOnUpgrade
    }
    Process {
        Write-Log -Type "CHECK" -Object "Starting Alteryx Server upgrade from $BackupVersion to $($Properties.Version)"
        # Create back-up
        $BackUpProperties = Copy-OrderedHashtable -Hashtable $Properties
        $BackUpProperties.Version = $BackupVersion
        Invoke-BackupAlteryx -Properties $BackUpProperties -Unattended:$Unattended
        # Upgrade
        Install-Alteryx -Properties $Properties -InstallationProperties $InstallationProperties -Unattended:$Unattended
        # Check for errors
        if ($Error.Count -gt 0) {
            # Rollback
            Write-Log -Type "ERROR" -Object "Upgrade process failed with $($Error.Count) errors"
            Write-Log -Type "WARN" -Object "Restoring previous version ($BackupVersion)"
            # Reinstall Alteryx
            Install-Alteryx -Properties $BackUpProperties -Unattended:$Unattended
            # Restore backup
            Invoke-RestoreAlteryx -Properties $BackUpProperties -Unattended:$Unattended
        } else {
            Write-Log -Type "CHECK" -Object "Alteryx Server upgrade completed successfully"
        }
    }
}