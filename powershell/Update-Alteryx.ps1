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
        $UpgradeProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
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
        $UpgradeProcess = Update-ProcessObject -ProcessObject $UpgradeProcess -Status "Running"
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
                $UpgradeProcess = Update-ProcessObject -ProcessObject $UpgradeProcess -Status "Cancelled"
                return $UpgradeProcess
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
                $UpgradeProcess = Update-ProcessObject -ProcessObject $UpgradeProcess -ErrorCount $BackupProcess.ErrorCount
            } else {
                $UpgradeProcess = Update-ProcessObject -ProcessObject $UpgradeProcess -Status "Cancelled" -ErrorCount $BackupProcess.ErrorCount
                return $UpgradeProcess
            }
        }
        # ------------------------------------------------------------------------------
        # * Upgrade
        # ------------------------------------------------------------------------------
        $InstallProcess = Install-Alteryx -Properties $Properties -InstallationProperties $InstallationProperties -Unattended:$Unattended
        if ($InstallProcess.Success -eq $true) {
            Write-Log -Type "CHECK" -Object "Alteryx Server upgrade completed successfully"
        } else {
            Write-Log -Type "ERROR" -Object "Upgrade process failed"
            $UpgradeProcess = Update-ProcessObject -ProcessObject $UpgradeProcess -Status "Failed" -ErrorCount $InstallProcess.ErrorCount -ExitCode $InstallProcess.ExitCode
            # ------------------------------------------------------------------------------
            # * Rollback
            # ------------------------------------------------------------------------------
            $RollbackProcess = Invoke-RollbackAlteryx -Properties $Properties -InstallationProperties $InstallationProperties -Unattended:$Unattended
            if ($RollbackProcess.Success -eq $false) {
                Write-Log -Type "ERROR" -Message "Rollback process failed"
                $UpgradeProcess = Update-ProcessObject -ProcessObject $UpgradeProcess -Status "Failed" -ErrorCount $RollbackProcess.ErrorCount -ExitCode $RollbackProcess.ExitCode
                return $UpgradeProcess
            }
        }
        # ------------------------------------------------------------------------------
        # * Checks
        # ------------------------------------------------------------------------------
        if ($UpgradeProcess.ErrorCount -eq 0) {
            Write-Log -Type "CHECK" -Message "Alteryx $($Properties.Product) $($Properties.Version) upgraded successfully"
            $UpgradeProcess = Update-ProcessObject -ProcessObject $UpgradeProcess -Status "Completed" -Success $true
        } else {
            if ($UpgradeProcess.ErrorCount -eq 1) {
                $ErrorCount = "one error"
            } else {
                $ErrorCount = "$($UpgradeProcess.ErrorCount) errors"
            }
            if ($null -eq $RollbackProcess) {
                Write-Log -Type "WARN" -Message "Alteryx $($Properties.Product) $($Properties.Version) was upgraded with $ErrorCount"
                $UpgradeProcess = Update-ProcessObject -ProcessObject $UpgradeProcess -Status "Completed"
            } else {
                Write-Log -Type "WARN" -Message "Alteryx $($Properties.Product) $($Properties.Version) upgraded process failed with $ErrorCount"
                $UpgradeProcess = Update-ProcessObject -ProcessObject $UpgradeProcess -Status "Failed" -ExitCode 1
            }
        }
    }
    End {
        return $UpgradeProcess
    }
}