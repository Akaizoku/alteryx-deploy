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
        Last modified:  2022-04-19
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
        # Log function call
        Write-Log -Type "DEBUG" -Message $MyInvocation.ScriptName
        # Clear error pipeline
        $Error.Clear()
        # Retrieve current version
        Write-Log -Type "DEBUG" -Object "Retrieving current version"
        if ($PSCmdlet.ShouldProcess("Alteryx version", "Retrieve")) {
            # Check registry for installation path to avoid issues if directory has changed
            $AlteryxVersion = Get-AlteryxVersion
            Write-Log -Type "DEBUG" -Object $AlteryxVersion
            $BackupVersion = Select-String -InputObject $AlteryxVersion -Pattern "\d+\.\d+.\d+(.\d+)?" | ForEach-Object { $PSItem.Matches.Value }
        }
        # Set upgrade activation option
        $Properties.ActivateOnInstall = $Properties.ActivateOnUpgrade
    }
    Process {
        Write-Log -Type "CHECK" -Object "Starting Alteryx Server upgrade from $BackupVersion to $($Properties.Version)"
        # Check installation path
        $InstallationPath = Get-AlteryxInstallDirectory
        if ($Properties.InstallationPath -ne $InstallationPath) {
            # If new installation directory is specified
            Write-Log -Type "WARN" -Message "New installation directory specified"
            Write-Log -Type "INFO" -Message "Old directory: $InstallationPath"
            Write-Log -Type "INFO" -Message "New directory: $($Properties.InstallationPath)"
            if ($Unattended -eq $false) {
                $Confirm = Confirm-Prompt -Prompt "Do you want to change the installation directory?"
            }
            if ($Confirm -Or $Unattended) {
                $AlteryxService = Get-AlteryxUtility -Utility "Service" -Path $InstallationPath
            } else {
                Write-Log -Type "WARN" -Message "Upgrade cancelled by user" -ExitCode 0
            }
        } else {
            # Retrieve Alteryx Service utility path
            $AlteryxService = Get-AlteryxUtility -Utility "Service" -Path $Properties.InstallationPath
        }
        # Create back-up
        $BackUpProperties = Copy-OrderedHashtable -Hashtable $Properties
        $BackUpProperties.Version           = $BackupVersion
        $BackupProperties.InstallationPath  = $InstallationPath
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