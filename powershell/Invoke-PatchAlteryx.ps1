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
        Last modified:  2024-09-10
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
        Write-Log -Type "DEBUG" -Message $MyInvocation.MyCommand.Name
        # Process status
        $PatchProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Variables
        $ISOTimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
        # Filenames
        if ($InstallationProperties.Product -eq "Designer") {
            $PatchPrefix = "AlteryxPatchInstall"
        } else {
            $PatchPrefix = "AlteryxServerPatchInstall"
        }
    }
    Process {
        $PatchProcess = Update-ProcessObject -ProcessObject $PatchProcess -Status "Running"
        Write-Log -Type "INFO" -Message "Installation of Alteryx $($InstallationProperties.Product) patch $($Properties.Version)"
        # Check products to install
        if ($InstallationProperties.Product -eq "Designer" -Or $InstallationProperties.Server -eq $true) {
            # Generate patch file version number
            $PatchVersion = [System.Version]::Parse($Properties.Version).Major.ToString() + "." + [System.Version]::Parse($Properties.Version).Minor.ToString() + "." + [System.Version]::Parse($Properties.Version).Build.ToString() + ".?." + [System.Version]::Parse($Properties.Version).Revision.ToString()
            $PatchInstaller = "$($PatchPrefix)_$($PatchVersion).exe"
            $PatchPath = Join-Path -Path $Properties.SrcDirectory -ChildPath $PatchInstaller
            if ($PSCmdlet.ShouldProcess($PatchPath, "Install")) {
                if (Test-Path -Path $PatchPath) {
                    # Get actual filepath
                    $PatchPath = (Resolve-Path -Path $PatchPath).Path
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
                            Write-Log -Type "ERROR" -Message "Alteryx Service ($Service) could not be found"
                            $PatchProcess = Update-ProcessObject -ProcessObject $PatchProcess -Status "Failed" -Success $false -ExitCode 1 -ErrorCount 1
                            return $PatchProcess
                        }
                    }
                    if ($Properties.InstallAwareLog -eq $true) {
                        $InstallAwareLog = Join-Path -Path $Properties.LogDirectory -ChildPath "${ISOTimeStamp}_${PatchFileName}.log"
                        $PatchInstall = Install-AlteryxServer -Path $PatchPath -InstallDirectory $Properties.InstallationPath -Log $InstallAwareLog -Language $Properties.Language -Version $Properties.Version -AllUsers -Unattended:$Unattended
                    } else {
                        $PatchInstall = Install-AlteryxServer -Path $PatchPath -InstallDirectory $Properties.InstallationPath -Language $Properties.Language -Version $Properties.Version -AllUsers -Unattended:$Unattended
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
    End {
        return $PatchProcess
    }
}