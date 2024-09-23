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
        Last modified:  2024-09-20

        .LINK
        https://www.powershellgallery.com/packages/PSAYX

        .LINK
        https://help.alteryx.com/current/en/license-and-activate/administer/use-command-line-options.html

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
        $Installprocess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Variables
        $ISOTimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $MajorVersion = [System.String]::Concat([System.Version]::Parse($Properties.Version).Major, ".", [System.Version]::Parse($Properties.Version).Minor)
        $Tags = [Ordered]@{"Version" = $Properties.Version}
        # Filenames
        if ($Properties.Product -eq "Designer") {
            $ServerInstaller = "AlteryxInstallx64_<Version>.exe"
        } else {
            $ServerInstaller = "AlteryxServerInstallx64_<Version>.exe"
        }
        # Add-ons paths
        $RDirectory     = Join-Path -Path $Properties.InstallationPath -ChildPath "RInstaller"
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
        $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -Status "Running"
        Write-Log -Type "INFO" -Message "Installation of Alteryx $($Properties.Product) $($Properties.Version)"
        # ------------------------------------------------------------------------------
        # * Alteryx Server
        # ------------------------------------------------------------------------------
        if ($Properties.Product -eq "Designer" -Or $InstallationProperties.Server -eq $true) {
            # Update file version number
            $ServerFileName = Set-Tags -String $ServerInstaller -Tags (Resolve-Tags -Tags $Tags -Prefix "<" -Suffix ">")
            $ServerPath     = Join-Path -Path $Properties.SrcDirectory -ChildPath $ServerFileName
            if (Test-Object -Path $ServerPath -NotFound) {
                $DefaultServerPath = $ServerPath
                # Workaround for files not following naming convention due to duplicate pipeline runs
                $Workaround     = [Ordered]@{"Version" = [System.String]::Concat($Properties.Version, "_1")}
                $ServerFileName = Set-Tags -String $ServerInstaller -Tags (Resolve-Tags -Tags $Workaround -Prefix "<" -Suffix ">")
                $ServerPath     = Join-Path -Path $Properties.SrcDirectory -ChildPath $ServerFileName
                if (Test-Object -Path $ServerPath -NotFound) {
                    Write-Log -Type "ERROR" -Message "Path not found $DefaultServerPath"
                    Write-Log -Type "ERROR" -Message "Alteryx $($Properties.Product) installation file could not be located"
                    Write-Log -Type "WARN" -Message "Alteryx installation failed"
                    $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -Status "Failed" -ErrorCount 1 -ExitCode 1
                    return $Installprocess
                } else {
                    Write-Log -Type "DEBUG" -Message "Path not found $DefaultServerPath"
                }
            }
            Write-Log -Type "INFO" -Message "Installing Alteryx $($Properties.Product)"
            if ($PSCmdlet.ShouldProcess($ServerPath, "Install")) {
                if (Test-Path -Path $ServerPath) {
                    if ($Properties.InstallAwareLog -eq $true) {
                        $InstallAwareLog = Join-Path -Path $Properties.LogDirectory -ChildPath "${ISOTimeStamp}_${ServerFileName}.log"
                        if ($null -eq $Properties.LicenseEmail -Or $Properties.LicenseEmail -eq "") {
                            $ServerInstall = Install-AlteryxServer -Path $ServerPath -InstallDirectory $Properties.InstallationPath -Log $InstallAwareLog -Language $Properties.Language -Version $Properties.Version -AllUsers -Unattended:$Unattended
                        } else {
                            $ServerInstall = Install-AlteryxServer -Path $ServerPath -InstallDirectory $Properties.InstallationPath -Log $InstallAwareLog -Serial $Properties.LicenseEmail -Language $Properties.Language -Version $Properties.Version -AllUsers -Unattended:$Unattended
                        }
                    } else {
                        if ($null -eq $Properties.LicenseEmail -Or $Properties.LicenseEmail -eq "") {
                            $ServerInstall = Install-AlteryxServer -Path $ServerPath -InstallDirectory $Properties.InstallationPath -Language $Properties.Language -Version $Properties.Version -AllUsers -Unattended:$Unattended
                        } else {
                            $ServerInstall = Install-AlteryxServer -Path $ServerPath -InstallDirectory $Properties.InstallationPath -Serial $Properties.LicenseEmail -Language $Properties.Language -Version $Properties.Version -AllUsers -Unattended:$Unattended
                        }
                    }
                    Write-Log -Type "DEBUG" -Message $ServerInstall
                    if ($ServerInstall.ExitCode -eq 0) {
                        Write-Log -Type "CHECK" -Message "Alteryx $($Properties.Product) installed successfully"
                    } else {
                        Write-Log -Type "ERROR" -Message "An error occured during the installation" -ExitCode $ServerInstall.ExitCode
                    }
                } else {
                    Write-Log -Type "ERROR" -Message "Path not found $ServerPath"
                    Write-Log -Type "ERROR" -Message "Alteryx $($Properties.Product) installation file could not be located"
                    Write-Log -Type "WARN" -Message "Alteryx installation failed"
                    $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -Status "Failed" -ErrorCount 1 -ExitCode 1
                    return $Installprocess
                }
            }
        }
        # ------------------------------------------------------------------------------
        # * Predictive Tools
        # ------------------------------------------------------------------------------
        if ($InstallationProperties.PredictiveTools -eq $true) {
            $RInstall = $true
            # Update file version number
            $RFileName = Set-Tags -String $RInstaller -Tags (Resolve-Tags -Tags $Tags -Prefix "<" -Suffix ">")
            if ($Properties.Product -eq "Server") {
                # Use embedded R installer
                $RPath = Join-Path -Path $RDirectory -ChildPath $RFileName
            } elseif ($Properties.Product -eq "Designer") {
                $RPath = Join-Path -Path $Properties.SrcDirectory -ChildPath $RFileName
            }
            # Check source file
            Write-Log -Type "INFO" -Message "Installing Predictive Tools"
            if ($PSCmdlet.ShouldProcess($RPath, "Install")) {
                if (Test-Object -Path $RPath -NotFound) {
                    # Look for a file which may not match the patch versioning
                    $RFile = Get-ChildItem -Path $RDirectory -Filter "RInstaller_*.exe"
                    if (($Properties.Product -eq "Server") -Or (($RFile | Measure-Object).Count) -eq 1) {
                        $RPath = $RFile.FullName
                    } else {
                        Write-Log -Type "ERROR" -Message "Path not found $RPath"
                        Write-Log -Type "ERROR" -Message "Predictive Tools installation file could not be located"
                        Write-Log -Type "WARN"  -Message "Predictive Tools installation failed"
                        $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -ErrorCount 1
                        $RInstall = $false
                    }
                }
                if (($RInstall = $true) -And (Test-Object -Path $RPath)) {
                    $RCommand = (@("&", $RPath, $Arguments) -join " ").Trim()
                    Write-Log -Type "DEBUG" -Message $RCommand
                    if ($Unattended) {
                        $RInstall = Start-Process -FilePath $RPath -ArgumentList $Arguments -Verb "RunAs" -PassThru -Wait
                    } else {
                        $RInstall = Start-Process -FilePath $RPath -Verb "RunAs" -PassThru -Wait
                    }                        
                    Write-Log -Type "DEBUG" -Message $RInstall
                    if ($RInstall.ExitCode -eq 0) {
                        Write-Log -Type "CHECK" -Message "Predictive Tools installed successfully"
                    } else {
                        Write-Log -Type "ERROR" -Message "An error occured during the installation"
                        $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -ErrorCount 1
                    }
                }
            }
        }
        # ------------------------------------------------------------------------------
        # * Intelligence Suite
        # ------------------------------------------------------------------------------
        if ($InstallationProperties.IntelligenceSuite -eq $true) {
            # Update file version number
            $AISFileName = Set-Tags -String $AISInstaller -Tags (Resolve-Tags -Tags $Tags -Prefix "<" -Suffix ">")
            $AISPath = Join-Path -Path $Properties.SrcDirectory -ChildPath $AISFileName
            if (Test-Object -Path $AISPath -NotFound) {
                # Workaround for files not following naming convention due to duplicate pipeline runs
                $Workaround     = [Ordered]@{"Version" = [System.String]::Concat($Properties.Version, "_1")}
                $WorkaroundPath = Set-Tags -String $AISInstaller -Tags (Resolve-Tags -Tags $Workaround -Prefix "<" -Suffix ">")
                if (Test-Path -Path $WorkaroundPath) {
                    $AISFileName    = $WorkaroundPath
                    $AISPath        = Join-Path -Path $Properties.SrcDirectory -ChildPath $AISFileName
                } else {
                    # Check latest file that matches the major version
                    $Check          = [Ordered]@{"Version" = "$MajorVersion.*"}
                    $CheckPattern   = Set-Tags -String $AISInstaller -Tags (Resolve-Tags -Tags $Check -Prefix "<" -Suffix ">")
                    $CheckPath      = Join-Path -Path $Properties.SrcDirectory -ChildPath $CheckPattern
                    $CheckFile      = Get-ChildItem -Path $CheckPath | Sort-Object -Property "LastWriteTime" -Descending | Select-Object -First 1
                    if ($null -ne $CheckFile) {
                        $AISFileName    = $CheckFile.Name
                        $AISPath        = $CheckFile.FullName
                    }
                }
            }
            Write-Log -Type "INFO" -Message "Installing Intelligence Suite"
            if ($PSCmdlet.ShouldProcess($AISPath, "Install")) {
                if (Test-Path -Path $AISPath) {
                    $AISCommand = (@("&", $AISPath, $Arguments) -join " ").Trim()
                    Write-Log -Type "DEBUG" -Message $AISCommand
                    if ($Unattended) {
                        $AISInstall = Start-Process -FilePath $AISPath -ArgumentList $Arguments -Verb "RunAs" -PassThru -Wait
                    } else {
                        $AISInstall = Start-Process -FilePath $AISPath -Verb "RunAs" -PassThru -Wait
                    }
                    Write-Log -Type "DEBUG" -Message $AISInstall
                    if ($AISInstall.ExitCode -eq 0) {
                        Write-Log -Type "CHECK" -Message "Intelligence Suite installed successfully"
                    } else {
                        Write-Log -Type "ERROR" -Message "An error occured during the installation" -ExitCode $AISInstall.ExitCode
                    }
                } else {
                    Write-Log -Type "ERROR" -Message "Path not found $AISPath"
                    Write-Log -Type "ERROR" -Message "Intelligence Suite installation file could not be located"
                    Write-Log -Type "WARN"  -Message "Intelligence Suite installation failed"
                    $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -ErrorCount 1
                }
            }
        }
        # ------------------------------------------------------------------------------
        # * Data packages
        # ------------------------------------------------------------------------------
        # TODO
        if ($InstallationProperties.DataPackages -eq $true) {
            if ($PSCmdlet.ShouldProcess("Alteryx Data Packages", "Install")) {
                $InstallDataPackage = $true
                $DataPackage = $null
                if ($null -ne $DataPackage) {
                    $DataPackagePath    = Join-Path -Path $Properties.SrcDirectory -ChildPath "$DataPackage.7z"
                    $DataPackageLog     = Join-Path -Path $Properties.LogDirectory -ChildPath "${ISOTimeStamp}_${DataPackage}.log"
                    if (-Not (Test-Path -Path $DataPackagePath)) {
                        Write-Log -Type "ERROR" -Message "Path not found $DataPackagePath"
                        Write-Log -Type "ERROR" -Message "Data package could not be located"
                        Write-Log -Type "WARN"  -Message "Data package installation failed"
                        $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -ErrorCount 1
                        $InstallDataPackage = false
                    }
                    if ($InstallDataPackage -eq $true) {
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
                                Write-Log -Type "ERROR" -Message "7zip could not be located"
                                Write-Log -Type "WARN" -Message "Data package installation failed"
                                $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -ErrorCount 1
                                $InstallDataPackage = false
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
                            Write-Log -Type "ERROR" -Message "Data package unzipping failed"
                            Write-Log -Type "WARN"  -Message "Data package installation failed"
                            $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -ErrorCount 1
                        }
                    }
                } else {
                    Write-Log -Type "DEBUG" -Message "No data package specified"
                    Write-Log -Type "WARN" -Message "Skipping data package installation"
                }
            }
        }
        # ------------------------------------------------------------------------------
        # * Licensing
        # ------------------------------------------------------------------------------
        if ($Properties.ActivateOnInstall -eq $true) {
            if ($PSCmdlet.ShouldProcess("Alteryx license", "Activate")) {
                $ActivateProcess = Invoke-ActivateAlteryx -Properties $Properties -Unattended:$Unattended
                if ($ActivateProcess.Success -eq $false) {
                    $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -ErrorCount $ActivateProcess.ErrorCount
                }
            }
        } else {
            Write-Log -Type "WARN" -Message "Skipping license activation"
        }
        # ------------------------------------------------------------------------------
        # * Configuration
        # ------------------------------------------------------------------------------
        if ($Properties.Product -eq "Server") {
            $ConfigureProcess = Set-AlteryxConfiguration -Properties $Properties
            if ($ConfigureProcess.Success -eq $false) {
                $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -ErrorCount $ConfigureProcess.ErrorCount
            }
        }
        # ------------------------------------------------------------------------------
        # * Check
        # ------------------------------------------------------------------------------
        if ($Installprocess.ErrorCount -eq 0) {
            Write-Log -Type "CHECK" -Message "Alteryx $($Properties.Product) $($Properties.Version) installed successfully"
            $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -Status "Completed" -Success $true
        } else {
            if ($Installprocess.ErrorCount -eq 1) {
                $ErrorCount = "one error"
            } else {
                $ErrorCount = "$($Installprocess.ErrorCount) errors"
            }
            Write-Log -Type "WARN" -Message "Alteryx $($Properties.Product) $($Properties.Version) was installed with $ErrorCount"
            $Installprocess = Update-ProcessObject -ProcessObject $Installprocess -Status "Completed"
        }
    }
    End {
        return $Installprocess
    }
}