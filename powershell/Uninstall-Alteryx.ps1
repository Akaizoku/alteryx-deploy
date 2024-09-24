function Uninstall-Alteryx {
    <#
        .SYNOPSIS
        Uninstall Alteryx

        .DESCRIPTION
        Uninstall the Alteryx platform

        .PARAMETER Properties
        The properties parameter corresponds to the configuration of the application.

        .PARAMETER Unattended
        The unattended switch specifies if the script should run in non-interactive mode.

        .NOTES
        File name:      Uninstall-Alteryx.ps1
        Author:         Florian Carrier
        Creation date:  2021-07-08
        Last modified:  2024-09-23

        .LINK
        https://www.powershellgallery.com/packages/PSAYX

        .LINK
        https://help.alteryx.com/current/en/license-and-activate/administer/use-command-line-options.html

        .LINK
        https://community.alteryx.com/t5/Alteryx-Designer-Knowledge-Base/Complete-Uninstall-of-Alteryx-Designer/ta-p/402897

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
        # Get global preference variables
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        # Log function call
        Write-Log -Type "DEBUG" -Message $MyInvocation.MyCommand.Name
        # Process status
        $Uninstallprocess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Variables
        $ISOTimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $Tags = [Ordered]@{"Version" = $Properties.Version}
        # Filenames
        if ($Properties.Product -eq "Designer") {
            $ServerInstaller = "AlteryxInstallx64_<Version>.exe"
        } else {
            $ServerInstaller = "AlteryxServerInstallx64_<Version>.exe"
        } 
    }
    Process {
        $Uninstallprocess = Update-ProcessObject -ProcessObject $Uninstallprocess -Status "Running"
        Write-Log -Type "NOTICE" -Message "Uninstallation of Alteryx Server $($Properties.Version)"
        # ------------------------------------------------------------------------------
        # * Checks
        # ------------------------------------------------------------------------------
        if ($Unattended -eq $false) {
            # Ask for confirmation to uninstall
            $ConfirmUninstall = Confirm-Prompt -Prompt "Are you sure that you want to uninstall $($Properties.Product)?"
            if ($ConfirmUninstall -eq $false) {
                Write-Log -Type "WARN" -Message "Cancelling uninstallation"
                $Uninstallprocess = Update-ProcessObject -ProcessObject $Uninstallprocess -Status "Cancelled"
                return $Uninstallprocess
            } else {
                # TODO check if Alteryx is installed
                # Suggest backup
                $Backup = Confirm-Prompt -Prompt "Do you want to take a back-up of the database?"
                if ($Backup) {
                    $BackupProcess = Invoke-BackupAlteryx -Properties $BackUpProperties -Unattended:$Unattended
                    if ($BackupProcess.Success -eq $false) {
                        if (Confirm-Prompt -Prompt "Do you still want to proceed with the uninstallation?") {
                            $Uninstallprocess = Update-ProcessObject -ProcessObject $Uninstallprocess -ErrorCount 1
                        } else {
                            $Uninstallprocess = Update-ProcessObject -ProcessObject $Uninstallprocess -Status "Cancelled" -ErrorCount 1
                            return $Uninstallprocess
                        }
                    }
                } else {
                    Write-Log -Type "WARN" -Message "Skipping database back-up"
                }
            }
        }
        # ------------------------------------------------------------------------------
        # * Deactivate license keys
        # ------------------------------------------------------------------------------
        $DeactivateProcess = Invoke-DeactivateAlteryx -Properties $Properties -All -Unattended:$Unattended
        if ($DeactivateProcess.Success -eq $false) {
            $Uninstallprocess = Update-ProcessObject -ProcessObject $Uninstallprocess -ErrorCount 1
        }
        # ------------------------------------------------------------------------------
        # * Uninstall Alteryx Server
        # ------------------------------------------------------------------------------
        # Update file version number
        $ServerFileName = Set-Tags -String $ServerInstaller -Tags (Resolve-Tags -Tags $Tags -Prefix "<" -Suffix ">")
        $ServerPath     = Join-Path -Path $Properties.SrcDirectory -ChildPath $ServerFileName
        Write-Log -Type "INFO" -Message "Uninstalling Alteryx $($Properties.Product)"
        if ($PSCmdlet.ShouldProcess($ServerPath, "Uninstall")) {
            if (Test-Path -Path $ServerPath) {
                if ($Properties.InstallAwareLog -eq $true) {
                    $InstallAwareLog = Join-Path -Path $Properties.LogDirectory -ChildPath "${ISOTimeStamp}_${ServerFileName}.log"
                    $ServerUninstall = Uninstall-AlteryxServer -Path $ServerPath -Version $Properties.Version -Log $InstallAwareLog -Unattended:$Unattended
                } else {
                    $ServerUninstall = Uninstall-AlteryxServer -Path $ServerPath -Version $Properties.Version -Unattended:$Unattended
                }
                Write-Log -Type "DEBUG" -Message $ServerUninstall
                if ($ServerUninstall.ExitCode -eq 0) {
                    Write-Log -Type "CHECK" -Message "Alteryx Server uninstalled successfully"
                } else {
                    Write-Log -Type "ERROR" -Message "An error occured during the uninstallation" -ExitCode $ServerUninstall.ExitCode
                    $Uninstallprocess = Update-ProcessObject -ProcessObject $Uninstallprocess -Status "Failed" -ErrorCount 1 -ExitCode 1
                    return $Uninstallprocess
                    
                }
            } else {
                Write-Log -Type "ERROR" -Message "Path not found $ServerPath"
                Write-Log -Type "ERROR" -Message "Alteryx $($Properties.Product) executable file could not be located"
                $Uninstallprocess = Update-ProcessObject -ProcessObject $Uninstallprocess -Status "Failed" -ErrorCount 1 -ExitCode 1
                return $Uninstallprocess
            }
        }
        # TODO remove leftover files
        # TODO remove registry keys
        # ------------------------------------------------------------------------------
        # * Uninstall add-ons
        # ------------------------------------------------------------------------------
        # TODO enable uninstall of standalone components
        # ------------------------------------------------------------------------------
        # * Check
        # ------------------------------------------------------------------------------
        if ($Uninstallprocess.ErrorCount -eq 0) {
            Write-Log -Type "CHECK" -Message "Uninstallation of Alteryx $($Properties.Product) $Version successfull"
            $Uninstallprocess = Update-ProcessObject -ProcessObject $Uninstallprocess -Status "Completed" -Success $true
        } else {
            if ($Uninstallprocess.ErrorCount -eq 1) {
                $ErrorCount = "one error"
            } else {
                $ErrorCount = "$($Uninstallprocess.ErrorCount) errors"
            }
            Write-Log -Type "WARN" -Message "Alteryx $($Properties.Product) $($Properties.Version) was uninstalled with $ErrorCount"
            $Uninstallprocess = Update-ProcessObject -ProcessObject $Uninstallprocess -Status "Completed"
        }
    }
    End {
        return $Uninstallprocess
    }
}