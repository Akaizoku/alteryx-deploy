function Set-Configuration {
    <#
        .SYNOPSIS
        Configure Alteryx Server

        .DESCRIPTION
        Set Alteryx Server configuration

        .NOTES
        File name:      Set-Configuration.ps1
        Author:         Florian Carrier
        Creation date:  2022-05-03
        Last modified:  2022-05-03
    #>
    [CmdletBinding ()]
    Param (
        [Parameter (
            Position    = 1,
            Mandatory   = $true,
            HelpMessage = "Script properties"
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
        $InstallationProperties
    )
    Begin {
        # Get global preference vrariables
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        
    }
    Process {
        $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -Status "Running"
        Write-Log -Type "NOTICE" -Message "Configuring script"
        # ------------------------------------------------------------------------------
        # * Configure script parameters
        Write-Log -Type "INFO" -Message "Configuring script parameters"
        if ($PSCmdlet.ShouldProcess("Script parameters", "Configure")) {
            $ConfigureParameters = $true
            # Check if custom configuration ahs already been set
            if (Test-Path -Path $CustomPath) {
                $CustomConfig = (Get-Content -Path $CustomPath).Trim()
                if ($CustomConfig -ne $CustomHeader) {
                    $ConfigureParameters = Confirm-Prompt -Prompt "Do you want to overwrite the existing configuration?"
                }
            }
            if ($ConfigureParameters -eq $true) {
                Write-Log -Type "INFO" -Message "Leave blank to keep default value"
                # Fetch default configuration
                $DefaultConfiguration   = Get-Properties -Path $DefaultPath -Metadata
                $CustomConfiguration    = New-Object -TypeName "System.Collections.Specialized.OrderedDictionary"
                # Define parameters to exclude
                $ExclusionList = ($($DefaultConfiguration.GetEnumerator()).Value | Where-Object { $PSItem.Section -eq "Checks" }).Value
                # Loop through parameters
                foreach ($Property in $DefaultConfiguration.GetEnumerator()) {
                    # Exclude reserved parameters
                    if ($($Property.Value).Section -notin ("SSL", "Checks") -And (-Not $ExclusionList.Contains($Property.Name))) {
                        $ValuePrompt = [System.String]::Concat($($Property.Value).Description, " (", $Property.Name, ")")
                        $DefaultValue = $($Property.Value).Value
                        # Check if a default value exists to display back to user
                        if ($DefaultValue.Trim() -notin @($null, "")) {
                            $ValuePrompt = "$ValuePrompt [default value: $DefaultValue]"
                        }
                        # Prompt user for input
                        $NewValue = (Read-Host -Prompt $ValuePrompt).Trim()
                        if ($NewValue -notin @($null, "")) {
                            $NewProperty        = [Ordered]@{
                                "Value"         = $NewValue
                                "Description"   = $($Property.Value).Description
                                "Section"       = $($Property.Value).Section
                            }
                            $CustomConfiguration.Add($Property.Name, $NewProperty)
                            Write-Log -Type "DEBUG" -Message $CustomConfiguration[$Property.Name]
                        }
                    }
                }
                # Generate custom configuration file
                Write-Log -Type "DEBUG" -Message $CustomConfiguration
                $CustomProperties = $CustomHeader
                if ($CustomConfiguration.Count -ge 1) {
                    foreach ($CustomProperty in $CustomConfiguration.GetEnumerator()) {
                        $Name = $CustomProperty.Name
                        $Value = $($CustomProperty.Value).Value
                        $Description = $($CustomProperty.Value).Description
                        $CustomProperties += [System.String]::Concat("`n", "# $Description", "`n", $Name, " = ", "$Value")
                    }
                }
                # Save back to file
                try {
                    Write-Log -Type "DEBUG" -Message $CustomPath
                    Set-Content -Path $CustomPath -Value $CustomProperties.Trim() -Force
                } catch {
                    Write-Log -Type "ERROR" -Message (Get-Error)
                    Write-Log -Type "ERROR" -Message "Custom configuration could not be saved"
                    $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -ErrorCount 1
                }
            }
            # Reload properties
            $Properties = Get-Properties -Path $DefaultPath -CustomPath $CustomPath
        }
        # ------------------------------------------------------------------------------
        # # * Configure license API token
        Write-Log -Type "INFO" -Message "Configuring License Portal API refresh token"
        if ($PSCmdlet.ShouldProcess("License Portal API refresh token", "Configure")) {
            $LicenseAPIPath         = Join-Path -Path "$PSScriptRoot/.." -ChildPath "$($Properties.ResDirectory)/$($Properties.LicenseAPIFile)"
            $LicenseAPIPrompt       = "License Portal API refresh token"
            $ConfigureLicenseAPI    = $true
            if (Test-Path -Path $LicenseAPIPath) {
                $RefreshAPIToken = Get-Content -Path $LicenseAPIPath
                if ($RefreshAPIToken -notin ($null, "")) {
                    Write-Log -Type "WARN"  -Message "License Portal API refresh token has already been configured"
                    Write-Log -Type "DEBUG" -Message $RefreshAPIToken
                    $ConfigureLicenseAPI = Confirm-Prompt -Prompt "Do you want to reconfigure the License Portal API refresh token?"
                }
            }
            if ($ConfigureLicenseAPI) {
                $LicenseAPIToken = Read-Host -Prompt $LicenseAPIPrompt
                Write-Log -Type "DEBUG" -Message $LicenseAPIToken
                Write-Log -Type "DEBUG" -Message $LicenseAPIPath
                Out-File -FilePath $LicenseAPIPath -InputObject $LicenseAPIToken -Force
                if (Test-Path -Path $LicenseAPIPath) {
                    Write-Log -Type "CHECK" -Message "License Portal API refresh token saved successfully"
                } else {
                    Write-Log -Type "ERROR" -Message (Get-Error)
                    Write-Log -Type "ERROR" -Message "License Portal API refresh token could not be saved"
                    $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -ErrorCount 1
                }
            } else {
                Write-Log -Type "WARN" -Message "Skipping License Portal API refresh token configuration"
            }
        }
        # # ------------------------------------------------------------------------------
        # # * Configure Server API keys
        Write-Log -Type "INFO" -Message "Configuring Server API keys"
        if ($PSCmdlet.ShouldProcess("Server API keys", "Configure")) {
            $ServerAPIPath      = Join-Path -Path "$PSScriptRoot/.." -ChildPath "$($Properties.ResDirectory)/$($Properties.ServerAdminAPI)"
            $APIKeyPrompt       = "Admin Server API key"
            $APISecretPrompt    = "Admin Server API secret"
            $ConfigureServerAPI = $true
            # Check if API keys have already been saved
            if (Test-Path -Path $ServerAPIPath) {
                $APIKeys = Get-Content -Path $ServerAPIPath | ConvertFrom-JSON
                if ($APIKeys -notin ($null, "")) {
                    Write-Log -Type "WARN"  -Message "Server API keys have already been configured"
                    Write-Log -Type "DEBUG" -Message $APIKeys
                    $ConfigureServerAPI = Confirm-Prompt -Prompt "Do you want to reconfigure Server API keys?"
                    if ($ConfigureServerAPI) {
                        $APIKeyPrompt       = "$APIKeyPrompt (current $($APIKeys.Key))"
                        $APISecretPrompt    = "$APISecretPrompt (current $($APIKeys.Secret))"
                    }
                }
            }
            if ($ConfigureServerAPI) {
                $ServerAPIKey       = Read-Host -Prompt $APIKeyPrompt
                $ServerAPISecret    = Read-Host -Prompt $APISecretPrompt
                $ServerAPIToken     = [Ordered]@{
                    "key"       = $ServerAPIKey
                    "secret"    = $ServerAPISecret
                } | ConvertTo-JSON
                Write-Log -Type "DEBUG" -Message $ServerAPIToken
                Write-Log -Type "DEBUG" -Message $ServerAPIPath
                Out-File -FilePath $ServerAPIPath -InputObject $ServerAPIToken -Force
                if (Test-Path -Path $ServerAPIPath) {
                    Write-Log -Type "CHECK" -Message "Server API keys saved successfully"
                } else {
                    Write-Log -Type "ERROR" -Message (Get-Error)
                    Write-Log -Type "ERROR" -Message "Server API keys could not be saved"
                    $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -ErrorCount 1
                }
            } else {
                Write-Log -Type "WARN" -Message "Skipping Server API keys configuration"
            }
        }
        # ------------------------------------------------------------------------------
        # * Configure installation properties
        Write-Log -Type "INFO" -Message "Configuring installation properties"
        if ($PSCmdlet.ShouldProcess("Installation properties", "Configure")) {
            $InstallationPropertiesPath = Join-Path -Path $ConfDirectory -ChildPath $Properties.InstallationOptions
            $InstallationProperties     = Get-Properties -Path $InstallationPropertiesPath
            $NewInstallationProperties  = "[Installation]"
            foreach ($InstallationProperty in $InstallationProperties.GetEnumerator()) {
                $Product = [regex]::Replace($InstallationProperty.Name, '([a-z])([A-Z])', '$1 $2')
                if (Confirm-Prompt -Prompt "Install $($Product)?") {
                    $Newvalue = "true"
                } else {
                    $NewValue = "false"
                }
                $NewInstallationProperties += [System.String]::Concat("`n", $InstallationProperty.Name, " = ", $NewValue)
            }
            try {
                Write-Log -Type "DEBUG" -Message $NewInstallationProperties
                Set-Content -Path $InstallationPropertiesPath -Value $NewInstallationProperties
            } catch {
                Write-Log -Type "ERROR" -Message (Get-Error)
                Write-Log -Type "ERROR" -Message "Installation properties could not be saved"
                $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -ErrorCount 1
            }
        }
        # ------------------------------------------------------------------------------
        # * Configure license file
        Write-Log -Type "INFO" -Message "Configuring license file"
        if ($PSCmdlet.ShouldProcess("License file", "Configure")) {
            Write-Log -Type "NOTICE" -Message $Properties
            $LicenseFilePath        = Join-Path -Path "$PSScriptRoot/.." -ChildPath "$($Properties.ResDirectory)/$($Properties.LicenseFile)"
            $ConfigureLicenseFile   = $true
            if (Test-Path -Path $LicenseFilePath) {
                $LicenseKeys = Get-Content -Path $LicenseFilePath
                if ($LicenseKeys -notin ($null, "")) {
                    Write-Log -Type "WARN"  -Message "License keys have already been configured"
                    Write-Log -Type "DEBUG" -Message $LicenseKeys
                    $ConfigureLicenseFile = Confirm-Prompt -Prompt "Do you want to overwrite the existing license keys?"
                }
            }
            if ($ConfigureLicenseFile) {
                $LicenseKeys = (Read-Host -Prompt "Enter Alteryx license key(s)") -split '[ ,]+'
                Write-Log -Type "DEBUG" -Message $LicenseKeys
                try {
                    Write-Log -Type "DEBUG" $LicenseFilePath
                    Set-Content -Path $LicenseFilePath -Value $LicenseKeys
                } catch {
                    Write-Log -Type "ERROR" -Message (Get-Error)
                    Write-Log -Type "ERROR" -Message "License file could not be saved"
                    $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -ErrorCount 1
                }
            }
        }
        # ------------------------------------------------------------------------------
        # TODO Configure SSL certificate
        # Write-Log -Type "INFO" -Message "Configuring SSL/TLS"
        # ------------------------------------------------------------------------------
        if ($ConfigureProcess.ErrorCount -eq 5) {
            # If all configuration failed
            Write-Log -Type "ERROR" -Message "Configuration wizard failed"
            $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -Status "Failed" -ExitCode 1
        } elseif ($ConfigureProcess.ErrorCount -gt 0) {
            # If only partial failure
            Write-Log -Type "WARN" -Message "Configuration wizard completed with errors"
            $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -Status "Completed"
        } else {
            # Otherwise success
            Write-Log -Type "CHECK" -Message "Configuration wizard complete"
            $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -Status "Completed" -Success $true
        }
    }
    End {
        return $ConfigureProcess
    }
}