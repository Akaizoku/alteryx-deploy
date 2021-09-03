function Install-Alteryx {
    <#
        .SYNOPSIS
        Install Alteryx

        .DESCRIPTION
        Install and configure the Alteryx platform

        .PARAMETER Properties
        The properties parameter corresponds to the configuration of the application.

        .PARAMETER Unattended
        The unattended switch specifies if the script should run in non-interactive mode.

        .NOTES
        File name:      Install-Alteryx.ps1
        Author:         Florian Carrier
        Creation date:  2021-07-05
        Last modified:  2021-09-02

        .LINK
        https://www.powershellgallery.com/packages/PSAYX

        .LINK
        https://help.alteryx.com/current/product-activation-and-licensing/use-command-line-options

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
        # Get global preference variables
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        # Variables
        $ISOTimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
        # Unattended execution arguments
        if ($Unattended) {
            $Arguments = "/s"
        } else {
            $Arguments = ""
        }
        # Installation
        $InstallationOptions    = [Ordered]@{
            "Server"            = $true
            "PredictiveTools"   = $true
            "IntelligenceSuite" = $true
            "DataPackages"      = $true
        }
    }
    Process {
        Write-Log -Type "INFO" -Message "Installation of Alteryx Server $($Properties.Version)"
        # ------------------------------------------------------------------------------
        # Alteryx Server
        if ($InstallationOptions.Server -eq $true) {
            $ServerFileName = [System.String]::Concat($Properties.ServerInstaller, $Properties.Version)
            $ServerPath = Join-Path -Path $Properties.SrcDirectory -ChildPath "$ServerFileName.exe"
            if (Test-Path -Path $ServerPath) {
                Write-Log -Type "INFO" -Message "Installing Alteryx Server"
                if ($PSCmdlet.ShouldProcess($ServerPath, "Install")) {
                    $ServerLog = Join-Path -Path $Properties.LogDirectory -ChildPath "${ISOTimeStamp}_${ServerFileName}.log"
                    $ServerInstall = Install-AlteryxServer -Path $ServerPath -InstallDirectory $Properties.InstallationPath -Log $ServerLog -Serial $Properties.LicenseEmail -Language $Properties.Language -AllUsers -Unattended:$Unattended
                    Write-Log -Type "DEBUG" -Message $ServerInstall
                    if ($ServerInstall.ExitCode -eq 0) {
                        Write-Log -Type "CHECK" -Message "Alteryx Server installed successfully"
                    } else {
                        Write-Log -Type "ERROR" -Message "An error occured during the installation" -ExitCode $ServerInstall.ExitCode
                    }
                }
            } else {
                Write-Log -Type "ERROR" -Message "Path not found $ServerPath"
                Write-Log -Type "ERROR" -Message "Alteryx Server installation file could not be located" -ExitCode 1
            }
            # Configuration
            if ($Unattended) {
                Write-Log -Type "WARN"  -Message "Do not forget to configure system settings"
            } else {
                # TODO start system settings
            }
        }
        # ------------------------------------------------------------------------------
        # Predictive Tools
        if ($InstallationOptions.PredictiveTools -eq $true) {
            $RFileName = [System.String]::Concat($Properties.RInstaller, $Properties.Version, ".exe")
            $RPath = Join-Path -Path $Properties.InstallationPath -ChildPath "RInstaller\$RFileName"
            if (Test-Path -Path $RPath) {
                Write-Log -Type "INFO" -Message "Installing Predictive Tools"
                if ($PSCmdlet.ShouldProcess($RPath, "Install")) {
                    $RInstall = Start-Process -FilePath $RPath -ArgumentList $Arguments -Verb "RunAs" -PassThru -Wait
                    Write-Log -Type "DEBUG" -Message $RInstall
                    if ($RInstall.ExitCode -eq 0) {
                        Write-Log -Type "CHECK" -Message "Predictive Tools installed successfully"
                    } else {
                        Write-Log -Type "ERROR" -Message "An error occured during the installation" -ExitCode $RInstall.ExitCode
                    }
                }
            } else {
                Write-Log -Type "ERROR" -Message "Path not found $RPath"
                Write-Log -Type "ERROR" -Message "Predictive Tools installation file could not be located" -ExitCode 1
            }
        }
        # ------------------------------------------------------------------------------
        # Intelligence Suite
        if ($InstallationOptions.IntelligenceSuite -eq $true) {
            $AISFileName = [System.String]::Concat($Properties.AISInstaller, $Properties.Version, ".exe")
            $AISPath = Join-Path -Path $Properties.SrcDirectory -ChildPath $AISFileName
            if (Test-Path -Path $AISPath) {
                Write-Log -Type "INFO" -Message "Installing Intelligence Suite"
                if ($PSCmdlet.ShouldProcess($AISPath, "Install")) {
                    $AISInstall = Start-Process -FilePath $AISPath -ArgumentList $Arguments -Verb "RunAs" -PassThru -Wait
                    Write-Log -Type "DEBUG" -Message $AISInstall
                    if ($AISInstall.ExitCode -eq 0) {
                        Write-Log -Type "CHECK" -Message "Intelligence Suite installed successfully"
                    } else {
                        Write-Log -Type "ERROR" -Message "An error occured during the installation" -ExitCode $AISInstall.ExitCode
                    }
                }
            } else {
                Write-Log -Type "ERROR" -Message "Path not found $AISPath"
                Write-Log -Type "ERROR" -Message "Alteryx Intelligence Suite installation file could not be located" -ExitCode 1
            }
        }
        # ------------------------------------------------------------------------------
        # Data packages
        if ($InstallationOptions.DataPackages -eq $true) {
            # TODO
            $DataPackage = $null
            if ($null -ne $DataPackage) {
                $DataPackagePath = Join-Path -Path $Properties.SrcDirectory -ChildPath "$DataPackage.7z"
                $DataPackageLog = Join-Path -Path $Properties.LogDirectory -ChildPath "${ISOTimeStamp}_${DataPackage}.log"
                if (-Not (Test-Path -Path $DataPackagePath)) {
                    Write-Log -Type "ERROR" -Message "Path not found $DataPackagePath"
                    Write-Log -Type "ERROR" -Message "Data package could not be located" -ExitCode 1
                }
                # Unzip data package
                $Destination = $DataPackagePath.Replace('.7z', '')
                if (Test-Path -Path $Destination) {
                    Write-Log -Type "WARN" -Message "Path already exists $Destination"
                    Write-Log -Type "INFO" -Message "Skipping data package unzip"
                } else {
                    $7zip = "& ""$($Properties.'7zipPath')"" x ""$DataPackagePath"" -o$Destination -y"
                    Write-Log -Type "DEBUG" -Message $7zip
                    if (Test-Path -Path $Properties.'7zipPath') {
                        if ($PSCmdlet.ShouldProcess($DataPackagePath, "Unzip")) {
                            $Unzip = Invoke-Expression -Command $7zip | Out-String
                        }
                    } else {
                        Write-Log -Type "ERROR" -Message "Path not found $($Properties.'7zipPath')"
                        Write-Log -Type "ERROR" -Message "7zip could not be located" -ExitCode 1
                    }
                    # ! TODO check unzip
                    Write-Log -Type "DEBUG" -Message $Unzip
                }
                # Check unzip outcome
                if (Test-Path -Path $Destination) {
                    # Run installer
                    $DataPackageInstaller = Join-Path -Path $Destination -ChildPath "DataInstallCmd.exe"
                    if (Test-Path -Path $DataPackageInstaller) {
                        Install-AlteryxDataPackage -Path $DataPackageInstaller -InstallDirectory $Properties.DataPackagesPath -Log $DataPackageLog -Action "Install" -Unattended:$Unattended
                    }
                } else {
                    Write-Log -Type "ERROR" -Message "Path not found $Destination"
                    Write-Log -Type "ERROR" -Message "Data package unzipping failed" -ExitCode 1
                }
            } else {
                Write-Log -Type "DEBUG" -Message "No data package specified"
            }
        }
        # ------------------------------------------------------------------------------
        # Licensing
        Invoke-ActivateAlteryx	-Properties $Properties -Unattended:$Unattended
    }
    End {
        Write-Log -Type "CHECK" -Message "Alteryx Server $($Properties.Version) installed successfully"
    }
}