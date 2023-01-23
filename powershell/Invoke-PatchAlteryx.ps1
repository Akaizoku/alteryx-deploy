function Invoke-PatchAlteryx {
    <#
        .SYNOPSIS
        Install Alteryx patch

        .DESCRIPTION
        Perform a patch upgrade to Alteryx

        .NOTES
        File name:      Invoke-PatchAlteryx.ps1
        Author:         Florian Carrier
        Creation date:  2022-06-29
        Last modified:  2022-06-29
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
        # Variables
        $ISOTimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $Tags = [Ordered]@{"Version" = $Properties.Version}
        # Filenames
        if ($InstallationProperties.Product -eq "Designer") {
            $PatchInstaller = "AlteryxPatchInstall_<Version>.exe"
        } else {
            $PatchInstaller = "AlteryxServerPatchInstall_<Version>.exe"
        }
        # Unattended execution arguments
        if ($Unattended) {
            $Arguments = "/s"
        } else {
            $Arguments = ""
        }
    }
    Process {
        Write-Log -Type "INFO" -Message "Installation of Alteryx $($InstallationProperties.Product) patch $($Properties.Version)"
        if ($InstallationProperties.Product -eq "Designer" -Or $InstallationProperties.Server -eq $true) {
            # Update file version number
            $PatchFileName = Set-Tags -String $PatchInstaller -Tags (Resolve-Tags -Tags $Tags -Prefix "<" -Suffix ">")
            $PatchPath     = Join-Path -Path $Properties.SrcDirectory -ChildPath $PatchFileName
            if ($PSCmdlet.ShouldProcess($PatchPath, "Install")) {
                if (Test-Path -Path $PatchPath) {
                    # Stop Alteryx Service
                    Write-Log -Type "INFO" -Message "Check Alteryx Service status"
                    if ($PSCmdlet.ShouldProcess("Alteryx Service", "Stop")) {
                        $Service = "AlteryxService"
                        if (Test-Service -Name $Service) {
                            $WindowsService = Get-Service -Name $Service
                            Write-Log -Type "DEBUG" -Message $Service
                            $ServiceStatus = $WindowsService.Status
                            if ($ServiceStatus -eq "Running") {
                                Invoke-StopAlteryx -Properties $Properties -Unattended:$Unattended
                            }
                        } else {
                            Write-Log -Type "ERROR" -Message "Alteryx Service ($Service) could not be found" -ExitCode 1
                        }
                    }
                    if ($Properties.InstallAwareLog -eq $true) {
                        $InstallAwareLog = Join-Path -Path $Properties.LogDirectory -ChildPath "${ISOTimeStamp}_${PatchFileName}.log"
                        $PatchInstall = Install-AlteryxServer -Path $PatchPath -InstallDirectory $Properties.InstallationPath -Log $InstallAwareLog -Language $Properties.Language -AllUsers -Unattended:$Unattended
                    } else {
                        $PatchInstall = Install-AlteryxServer -Path $PatchPath -InstallDirectory $Properties.InstallationPath -Language $Properties.Language -AllUsers -Unattended:$Unattended
                    }
                    Write-Log -Type "DEBUG" -Message $PatchInstall
                    if ($PatchInstall.ExitCode -eq 0) {
                        Write-Log -Type "CHECK" -Message "Alteryx $($InstallationProperties.Product) patched successfully"
                    } else {
                        Write-Log -Type "ERROR" -Message "An error occured during the patch installation" -ExitCode $PatchInstall.ExitCode
                    }
                    # TODO check registry for version and installinfo configuration file
                } else {
                    Write-Log -Type "ERROR" -Message "Path not found $PatchPath"
                    Write-Log -Type "ERROR" -Message "Alteryx $($InstallationProperties.Product) patch file could not be located"
                    Write-Log -Type "WARN" -Message "Alteryx patch installation failed" -ExitCode 1
                }
                # Restart service if it was running before
                if ($ServiceStatus -eq "Running") {
                    Invoke-StartAlteryx -Properties $Properties -Unattended:$Unattended
                }
            }
        } else {
            Write-Log -Type "ERROR" -Message "Designer or Server products must be enabled for a patch upgrade" -ExitCode 0
        }
    }
}