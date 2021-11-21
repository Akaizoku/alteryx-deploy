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
        Last modified:  2021-11-20

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
        # Variables
        $ISOTimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $Tags = [Ordered]@{"Version" = $Properties.Version}
        # Filenames
        if ($InstallationProperties.Product -eq "Designer") {
            $ServerInstaller = "AlteryxInstallx64_<Version>.exe"
        } else {
            $ServerInstaller = "AlteryxServerInstallx64_<Version>.exe"
        }
        # $RFileName AISFileName
        $RInstaller     = "RInstaller_<Version>.exe"
        $AISInstaller   = "AlteryxAISInstall_<Version>.exe"
        # Unattended execution arguments
        if ($Unattended) {
            $Arguments = "/s"
        } else {
            $Arguments = ""
        }
    }
    Process {
        Write-Log -Type "INFO" -Message "Installation of Alteryx $($InstallationProperties.Product) $($Properties.Version)"
        # ------------------------------------------------------------------------------
        # Alteryx Server
        # ------------------------------------------------------------------------------
        if ($InstallationProperties.Product -eq "Designer" -Or $InstallationProperties.Server -eq $true) {
            # Update file version number
            $ServerFileName = Set-Tags -String $ServerInstaller -Tags (Resolve-Tags -Tags $Tags -Prefix "<" -Suffix ">")
            $ServerPath     = Join-Path -Path $Properties.SrcDirectory -ChildPath $ServerFileName
            Write-Log -Type "INFO" -Message "Installing Alteryx $($InstallationProperties.Product)"
            if ($PSCmdlet.ShouldProcess($ServerPath, "Install")) {
                if (Test-Path -Path $ServerPath) {
                    if ($Properties.InstallAwareLog -eq $true) {
                        $InstallAwareLog = Join-Path -Path $Properties.LogDirectory -ChildPath "${ISOTimeStamp}_${ServerFileName}.log"
                        $ServerInstall = Install-AlteryxServer -Path $ServerPath -InstallDirectory $Properties.InstallationPath -Log $InstallAwareLog -Serial $Properties.LicenseEmail -Language $Properties.Language -AllUsers -Unattended:$Unattended
                    } else {
                        $ServerInstall = Install-AlteryxServer -Path $ServerPath -InstallDirectory $Properties.InstallationPath -Serial $Properties.LicenseEmail -Language $Properties.Language -AllUsers -Unattended:$Unattended
                    }
                    Write-Log -Type "DEBUG" -Message $ServerInstall
                    if ($ServerInstall.ExitCode -eq 0) {
                        Write-Log -Type "CHECK" -Message "Alteryx $($InstallationProperties.Product) installed successfully"
                    } else {
                        Write-Log -Type "ERROR" -Message "An error occured during the installation" -ExitCode $ServerInstall.ExitCode
                    }
                } else {
                    Write-Log -Type "ERROR" -Message "Path not found $ServerPath"
                    Write-Log -Type "ERROR" -Message "Alteryx $($InstallationProperties.Product) installation file could not be located" -ExitCode 1
                }
            }
            # Configuration
            if ($InstallationProperties.Product -eq "Server") {
                if ($Unattended) {
                    Write-Log -Type "WARN"  -Message "Do not forget to configure system settings"
                } else {
                    # TODO start system settings
                    Write-Log -Type "WARN"  -Message "Do not forget to configure system settings"
                }
            }
        }
        # ------------------------------------------------------------------------------
        # Predictive Tools
        # ------------------------------------------------------------------------------
        if ($InstallationProperties.PredictiveTools -eq $true) {
            # Update file version number
            $RFileName = Set-Tags -String $RInstaller -Tags (Resolve-Tags -Tags $Tags -Prefix "<" -Suffix ">")
            if ($InstallationProperties.Product -eq "Server") {
                # Use embedded R installer
                $RPath = Join-Path -Path $Properties.InstallationPath -ChildPath "RInstaller\$RFileName"
            } elseif ($InstallationProperties.Product -eq "Designer") {
                $RPath = Join-Path -Path $Properties.SrcDirectory -ChildPath $RFileName
            }
            # Check source file
            Write-Log -Type "INFO" -Message "Installing Predictive Tools"
            if ($PSCmdlet.ShouldProcess($RPath, "Install")) {
                if (Test-Path -Path $RPath) {
                    $RCommand = (@("&", $RPath, $Arguments) -join " ").Trim()
                    Write-Log -Type "DEBUG" -Message $RCommand
                    $RInstall = Start-Process -FilePath $RPath -ArgumentList $Arguments -Verb "RunAs" -PassThru -Wait
                    Write-Log -Type "DEBUG" -Message $RInstall
                    if ($RInstall.ExitCode -eq 0) {
                        Write-Log -Type "CHECK" -Message "Predictive Tools installed successfully"
                    } else {
                        Write-Log -Type "ERROR" -Message "An error occured during the installation" -ExitCode $RInstall.ExitCode
                    }
                } else {
                    Write-Log -Type "ERROR" -Message "Path not found $RPath"
                    Write-Log -Type "ERROR" -Message "Predictive Tools installation file could not be located" -ExitCode 1
                }
            }
        }
        # ------------------------------------------------------------------------------
        # Intelligence Suite
        # ------------------------------------------------------------------------------
        if ($InstallationProperties.IntelligenceSuite -eq $true) {
            # Update file version number
            $AISFileName = Set-Tags -String $AISInstaller -Tags (Resolve-Tags -Tags $Tags -Prefix "<" -Suffix ">")
            $AISPath = Join-Path -Path $Properties.SrcDirectory -ChildPath $AISFileName
            Write-Log -Type "INFO" -Message "Installing Intelligence Suite"
            if ($PSCmdlet.ShouldProcess($AISPath, "Install")) {
                if (Test-Path -Path $AISPath) {
                    $AISCommand = (@("&", $AISPath, $Arguments) -join " ").Trim()
                    Write-Log -Type "DEBUG" -Message $AISCommand
                    $AISInstall = Start-Process -FilePath $AISPath -ArgumentList $Arguments -Verb "RunAs" -PassThru -Wait
                    Write-Log -Type "DEBUG" -Message $AISInstall
                    if ($AISInstall.ExitCode -eq 0) {
                        Write-Log -Type "CHECK" -Message "Intelligence Suite installed successfully"
                    } else {
                        Write-Log -Type "ERROR" -Message "An error occured during the installation" -ExitCode $AISInstall.ExitCode
                    }
                } else {
                    Write-Log -Type "ERROR" -Message "Path not found $AISPath"
                    Write-Log -Type "ERROR" -Message "Alteryx Intelligence Suite installation file could not be located" -ExitCode 1
                }
            }
        }
        # ------------------------------------------------------------------------------
        # Data packages
        # ------------------------------------------------------------------------------
        if ($InstallationProperties.DataPackages -eq $true) {
            # TODO
            $DataPackage = $null
            if ($null -ne $DataPackage) {
                $DataPackagePath    = Join-Path -Path $Properties.SrcDirectory -ChildPath "$DataPackage.7z"
                $DataPackageLog     = Join-Path -Path $Properties.LogDirectory -ChildPath "${ISOTimeStamp}_${DataPackage}.log"
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
        # ------------------------------------------------------------------------------
        Invoke-ActivateAlteryx -Properties $Properties -Unattended:$Unattended
    }
    End {
        Write-Log -Type "CHECK" -Message "Alteryx $($InstallationProperties.Product) $($Properties.Version) installed successfully"
    }
}