function Update-Alteryx {
    <#
        .SYNOPSIS
        Update Alteryx

        .DESCRIPTION
        Upgrade Alteryx Server and rollback if process fails
        
        .NOTES
        File name:      Update-Alteryx.ps1
        Author:         Florian Carrier
        Creation date:  2021-09-02
        Last modified:  2024-09-23
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
        Write-Log -Type "DEBUG" -Message $MyInvocation.MyCommand.Name
        # Process status
        $UninstallProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
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
        $UninstallProcess = Update-ProcessObject -ProcessObject $UninstallProcess -Status "Running"
        Write-Log -Type "CHECK" -Object "Starting Alteryx Server upgrade from $BackupVersion to $($Properties.Version)"
        # Check installation path
        $InstallDirectory = Get-AlteryxInstallDirectory
        $InstallationPath = Resolve-Path -Path "$InstallDirectory\.."
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
                Write-Log -Type "WARN" -Message "Upgrade cancelled by user"
                $UninstallProcess = Update-ProcessObject -ProcessObject $UninstallProcess -Status "Cancelled"
                return $UninstallProcess
            }
        } else {
            # Retrieve Alteryx Service utility path
            $AlteryxService = Get-AlteryxUtility -Utility "Service" -Path $Properties.InstallationPath
        }
        # ------------------------------------------------------------------------------
        # * Back-up
        # ------------------------------------------------------------------------------
        # Create back-up
        $BackUpProperties = Copy-OrderedHashtable -Hashtable $Properties
        $BackUpProperties.Version           = $BackupVersion
        $BackupProperties.InstallationPath  = $InstallationPath
        $BackupProcess = Invoke-BackupAlteryx -Properties $BackUpProperties -Unattended:$Unattended
        if ($BackupProcess.Success -eq $false) {
            if (Confirm-Prompt -Prompt "Do you still want to proceed with the upgrade?") {
                $UninstallProcess = Update-ProcessObject -ProcessObject $UninstallProcess -ErrorCount 1
            } else {
                $UninstallProcess = Update-ProcessObject -ProcessObject $UninstallProcess -Status "Cancelled" -ErrorCount 1
                return $UninstallProcess
            }
        }
        # ------------------------------------------------------------------------------
        # * Upgrade
        # ------------------------------------------------------------------------------
        $InstallProcess = Install-Alteryx -Properties $Properties -InstallationProperties $InstallationProperties -Unattended:$Unattended
        if ($InstallProcess.Success -eq $false) {
            $UninstallProcess = Update-ProcessObject -ProcessObject $UninstallProcess -Status "Failed" -ErrorCount $InstallProcess.ErrorCount -ExitCode 1
            return $UninstallProcess
        }
        # ------------------------------------------------------------------------------
        # * Rollback
        # ------------------------------------------------------------------------------
        if ($Error.Count -gt 0) {
            Write-Log -Type "ERROR" -Object "Upgrade process failed with $($Error.Count) errors"
            Write-Log -Type "WARN" -Object "Restoring previous version ($BackupVersion)"
            # Reinstall previous Alteryx version
            $InstallProcess = Install-Alteryx -Properties $Properties -InstallationProperties $BackUpProperties -Unattended:$Unattended
            if ($InstallProcess.Success -eq $false) {
                Write-Log -Type "ERROR" -Message "Rollback process failed"
                $UninstallProcess = Update-ProcessObject -ProcessObject $UninstallProcess -Status "Failed" -ErrorCount $InstallProcess.ErrorCount -ExitCode 1
                return $UninstallProcess
            } else {
                # Restore backup
                $RestoreProcess = Invoke-RestoreAlteryx -Properties $BackUpProperties -Unattended:$Unattended
                if ($RestoreProcess.Success -eq $false) {
                    Write-Log -Type "ERROR" -Message "Rollback process failed"
                    $UninstallProcess = Update-ProcessObject -ProcessObject $UninstallProcess -Status "Failed" -ErrorCount $RestoreProcess.ErrorCount -ExitCode 1
                    return $UninstallProcess
                } else {
                    Write-Log -Type "CHECK" -Object "Alteryx Server rollback completed successfully"
                    Write-Log -Type "WARN" -Message "Check the logs to troubleshoot issue with upgrade"
                    Update-ProcessObject -ProcessObject $UninstallProcess -Status "Failed" -ExitCode 1
                }
            }
        } else {
            Write-Log -Type "CHECK" -Object "Alteryx Server upgrade completed successfully"
        }
    }
    End {
        return $UninstallProcess
    }
}