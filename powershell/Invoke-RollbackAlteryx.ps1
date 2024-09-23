function Invoke-RollbackAlteryx {
    <#
        .SYNOPSIS
        Rollback Alteryx

        .DESCRIPTION
        Rollback Alteryx Server to a previous (stable) known state
        
        .NOTES
        File name:      Invoke-RollbackAlteryx.ps1
        Author:         Florian Carrier
        Creation date:  2024-09-23
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
        $RollbackProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Clear error pipeline
        $Error.Clear()
        # Retrieve current version
        Write-Log -Type "DEBUG" -Object "Retrieving current version"
        if ($PSCmdlet.ShouldProcess("Alteryx version", "Retrieve")) {
            # Check registry for installation path to avoid issues if directory has changed
            $AlteryxVersion = Get-AlteryxVersion
            Write-Log -Type "DEBUG" -Object $AlteryxVersion
            $RollbackVersion = Select-String -InputObject $AlteryxVersion -Pattern "\d+\.\d+.\d+(.\d+)?" | ForEach-Object { $PSItem.Matches.Value }
        }
    }
    Process {
        $RollbackProcess = Update-ProcessObject -ProcessObject $RollbackProcess -Status "Running"
        Write-Log -Type "CHECK" -Object "Starting Alteryx Server rollback from $RollbackVersion to $($Properties.Version)"
        # ------------------------------------------------------------------------------
        # * Checks
        # ------------------------------------------------------------------------------
        if ($Unattended -eq $false) {
            # Ask for confirmation to uninstall
            $ConfirmUninstall = Confirm-Prompt -Prompt "Are you sure that you want to rollback to version $($Properties.Version)?"
            if ($ConfirmUninstall -eq $false) {
                Write-Log -Type "WARN" -Message "Cancelling rollback"
                $Uninstallprocess = Update-ProcessObject -ProcessObject $Uninstallprocess -Status "Cancelled"
                return $Uninstallprocess
            }
        }
        # ------------------------------------------------------------------------------
        # * Uninstall
        # ------------------------------------------------------------------------------
        $UninstallProperties = Copy-OrderedHashtable -Hashtable $Properties -Deep
        $UninstallProperties.Version = $RollbackVersion
        # Unistall existing Alteryx version
        $UninstallProcess = Uninstall-Alteryx -Properties $UninstallProperties -InstallationProperties $InstallationProperties -Unattended:$Unattended
        if ($UninstallProcess.Success -eq $false) {
            Write-Log -Type "ERROR" -Message "Rollback process failed"
            $RollbackProcess = Update-ProcessObject -ProcessObject $RollbackProcess -Status "Failed" -ErrorCount $UninstallProcess.ErrorCount -ExitCode $UninstallProcess.ExitCode
            return $RollbackProcess
        }
        # ------------------------------------------------------------------------------
        # * Reinstall
        # ------------------------------------------------------------------------------
        # Reinstall previous Alteryx version
        $InstallProcess = Install-Alteryx -Properties $Properties -InstallationProperties $InstallationProperties -Unattended:$Unattended
        if ($InstallProcess.Success -eq $false) {
            Write-Log -Type "ERROR" -Message "Rollback process failed"
            $RollbackProcess = Update-ProcessObject -ProcessObject $RollbackProcess -Status "Failed" -ErrorCount $InstallProcess.ErrorCount -ExitCode $InstallProcess.ExitCode
            return $RollbackProcess
        }
        # ------------------------------------------------------------------------------
        # * Restore
        # ------------------------------------------------------------------------------
        # Restore backup
        $RestoreProcess = Invoke-RestoreAlteryx -Properties $Properties -Unattended:$Unattended
        if ($RestoreProcess.Success -eq $false) {
            Write-Log -Type "ERROR" -Message "Rollback process failed"
            $RollbackProcess = Update-ProcessObject -ProcessObject $RollbackProcess -Status "Failed" -ErrorCount $RestoreProcess.ErrorCount -ExitCode 1
            return $RollbackProcess
        } else {
            Write-Log -Type "CHECK" -Object "Alteryx Server rollback completed successfully"
            Write-Log -Type "WARN" -Message "Check the logs to troubleshoot issue with upgrade"
            Update-ProcessObject -ProcessObject $RollbackProcess -Status "Failed" -ExitCode 1
        }
        # ------------------------------------------------------------------------------
        # * Restart
        # ------------------------------------------------------------------------------
        $StartProcess = Invoke-StartAlteryx -Properties $Properties -Unattended:$Unattended
        if ($StartProcess.Success) {
            Write-Log -Type "CHECK" -Message "Alteryx Service restart process complete"
            $RollbackProcess = Update-ProcessObject -ProcessObject $RollbackProcess -Status "Completed" -Success $true
        } else {
            $RollbackProcess = Update-ProcessObject -ProcessObject $RollbackProcess -Status $StopProcess.Status -ErrorCount $StartProcess.ErrorCount -ExitCode $StartProcess.ExitCode
        }
    }
    End {
        return $RollbackProcess
    }
}