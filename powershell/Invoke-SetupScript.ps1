function Invoke-SetupScript {
    <#
        .SYNOPSIS
        Set-up Alteryx deploy utility

        .DESCRIPTION
        Set-up wizard to configure the required parameters of the alteryx-deploy utility

        .NOTES
        File name:      Invoke-SetupScript.ps1
        Author:         Florian Carrier
        Creation date:  2022-05-03
        Last modified:  2024-09-23
    #>
    [CmdletBinding (
        SupportsShouldProcess = $true
    )]
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
            HelpMessage = "Default script properties"
        )]
        [ValidateNotNullOrEmpty ()]
        [System.Collections.Specialized.OrderedDictionary]
        $ScriptProperties
    )
    Begin {
        # Get global preference vrariables
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        # Log function call
        Write-Log -Type "DEBUG" -Message $MyInvocation.MyCommand.Name
        # Process status
        $SetupProcess   = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Parameters
        $ConfDirectory  = $ScriptProperties.ConfDirectory
        $DefaultPath    = Join-Path -Path $ConfDirectory -ChildPath $ScriptProperties.DefaultProperties
        $CustomPath     = Join-Path -Path $ConfDirectory -ChildPath $ScriptProperties.CustomProperties
        $CustomHeader   = "# ------------------------------------------------------------------------------
# Add your custom configuration here
# e.g. TempDirectory = D:\Temp
# ------------------------------------------------------------------------------
"
    }
    Process {
        $SetupProcess = Update-ProcessObject -ProcessObject $SetupProcess -Status "Running"
        Write-Log -Type "NOTICE" -Message "Setting up script"
        # ------------------------------------------------------------------------------
        # * Configure script parameters
        # ------------------------------------------------------------------------------
        Write-Log -Type "INFO" -Message "Configuring script parameters"
        if ($PSCmdlet.ShouldProcess("Script parameters", "Configure")) {
            $ConfigureParameters = $true
            # Check if custom configuration ahs already been set
            if (Test-Path -Path $CustomPath) {
                $CustomConfig = Get-Content -Path $CustomPath -Raw
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
                    Write-Log -Type "ERROR" -Message (Get-PowerShellError)
                    Write-Log -Type "ERROR" -Message "Custom configuration could not be saved"
                    $SetupProcess = Update-ProcessObject -ProcessObject $SetupProcess -ErrorCount 1
                }
            }
            # Reload properties
            $Properties = Get-Properties -Path $DefaultPath -CustomPath $CustomPath
        }
        # ------------------------------------------------------------------------------
        # * Configure license API token
        # ------------------------------------------------------------------------------
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
                $LicenseAPIToken = (Read-Host -Prompt $LicenseAPIPrompt).Trim()
                Write-Log -Type "DEBUG" -Message $LicenseAPIToken
                Write-Log -Type "DEBUG" -Message $LicenseAPIPath
                Set-Content -Path $LicenseAPIPath -Value $LicenseAPIToken -NoNewline -Force
                if (Test-Path -Path $LicenseAPIPath) {
                    Write-Log -Type "CHECK" -Message "License Portal API refresh token saved successfully"
                } else {
                    Write-Log -Type "ERROR" -Message (Get-PowerShellError)
                    Write-Log -Type "ERROR" -Message "License Portal API refresh token could not be saved"
                    $SetupProcess = Update-ProcessObject -ProcessObject $SetupProcess -ErrorCount 1
                }
            } else {
                Write-Log -Type "WARN" -Message "Skipping License Portal API refresh token configuration"
            }
        }
        # # ------------------------------------------------------------------------------
        # * Configure Server API keys
        # ------------------------------------------------------------------------------
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
                $ServerAPIKey       = (Read-Host -Prompt $APIKeyPrompt).Trim()
                $ServerAPISecret    = (Read-Host -Prompt $APISecretPrompt).Trim()
                $ServerAPIToken     = [Ordered]@{
                    "key"       = $ServerAPIKey
                    "secret"    = $ServerAPISecret
                } | ConvertTo-JSON
                Write-Log -Type "DEBUG" -Message $ServerAPIToken
                Write-Log -Type "DEBUG" -Message $ServerAPIPath
                Set-Content -Path $ServerAPIPath -Value $ServerAPIToken -Force
                if (Test-Path -Path $ServerAPIPath) {
                    Write-Log -Type "CHECK" -Message "Server API keys saved successfully"
                } else {
                    Write-Log -Type "ERROR" -Message (Get-PowerShellError)
                    Write-Log -Type "ERROR" -Message "Server API keys could not be saved"
                    $SetupProcess = Update-ProcessObject -ProcessObject $SetupProcess -ErrorCount 1
                }
            } else {
                Write-Log -Type "WARN" -Message "Skipping Server API keys configuration"
            }
        }
        # ------------------------------------------------------------------------------
        # * Configure installation properties
        # ------------------------------------------------------------------------------
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
                Set-Content -Path $InstallationPropertiesPath -Value $NewInstallationProperties -Force
            } catch {
                Write-Log -Type "ERROR" -Message (Get-PowerShellError)
                Write-Log -Type "ERROR" -Message "Installation properties could not be saved"
                $SetupProcess = Update-ProcessObject -ProcessObject $SetupProcess -ErrorCount 1
            }
        }
        # ------------------------------------------------------------------------------
        # * Configure license file
        # ------------------------------------------------------------------------------
        Write-Log -Type "INFO" -Message "Configuring license file"
        if ($PSCmdlet.ShouldProcess("License file", "Configure")) {
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
                $LicenseKeys = ((Read-Host -Prompt "Enter Alteryx license key(s)").Trim()) -split '[ ,]+'
                Write-Log -Type "DEBUG" -Message $LicenseKeys
                try {
                    Write-Log -Type "DEBUG" $LicenseFilePath
                    Set-Content -Path $LicenseFilePath -Value $LicenseKeys -Force
                } catch {
                    Write-Log -Type "ERROR" -Message (Get-PowerShellError)
                    Write-Log -Type "ERROR" -Message "License file could not be saved"
                    $SetupProcess = Update-ProcessObject -ProcessObject $SetupProcess -ErrorCount 1
                }
            }
        }
        # ------------------------------------------------------------------------------
        # * Configure SSL/TLS
        # ------------------------------------------------------------------------------
        # Write-Log -Type "INFO" -Message "Configuring SSL/TLS"
        # TODO Check if certificate if provided
        # TODO Generate self-signed cetrificate
        # TODO Enable SSL configuration
        # ------------------------------------------------------------------------------
        # * Configure SMTP
        # ------------------------------------------------------------------------------
        # TODO Configure SMTP settings
        # ------------------------------------------------------------------------------
        if ($SetupProcess.ErrorCount -eq 5) {
            # If all configuration failed
            Write-Log -Type "ERROR" -Message "Set-up wizard failed"
            $SetupProcess = Update-ProcessObject -ProcessObject $SetupProcess -Status "Failed" -ExitCode 1
        } elseif ($SetupProcess.ErrorCount -gt 0) {
            # If only partial failure
            Write-Log -Type "WARN" -Message "Set-up wizard completed with errors"
            $SetupProcess = Update-ProcessObject -ProcessObject $SetupProcess -Status "Completed"
        } else {
            # Otherwise success
            Write-Log -Type "CHECK" -Message "Set-up wizard complete"
            $SetupProcess = Update-ProcessObject -ProcessObject $SetupProcess -Status "Completed" -Success $true
        }
    }
    End {
        return $SetupProcess
    }
}