function Invoke-DeactivateAlteryx {
    <#
        .SYNOPSIS
        Deactivate Alteryx license

        .DESCRIPTION
        Deactivate one or more license keys for Alteryx

        .PARAMETER Properties
        The properties parameter corresponds to the configuration of the application.

        .PARAMETER Unattended
        The unattended switch specifies if the script should run in non-interactive mode.

        .NOTES
        File name:      Invoke-DeactivateAlteryx.ps1
        Author:         Florian Carrier
        Creation date:  2021-11-20
        Last modified:  2024-11-20

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
            HelpMessage = "Switch to remove all license keys"
        )]
        [Switch]
        $All,
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
        $DeactivateProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # License utility
        $LicenseUtility = Get-AlteryxUtility -Utility "License" -Path $Properties.InstallationPath
        # Expected license format
        $LicensePattern = "\w{4}-\w{4}-\w{4}-\w{4}-\w{4}-\w{4}-\w{4}-\w{4}"
    }
    Process {
        $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -Status "Running"
        Write-Log -Type "NOTICE" -Message "Deactivating Alteryx"
        if ($PSCmdlet.ShouldProcess("Alteryx", "Deactivate")) {
            # Check licensing system connectivity
            Write-Log -Type "INFO"  -Message "Checking licensing system connectivity"
            if ((Test-HTTPStatus -URI $Properties.LicensingURL) -eq $true) {
                # Check existing license keys
                $CurrentLicenses = Get-AlteryxLicense -Path $LicenseUtility
                if ($CurrentLicenses -match "No license keys found.") {
                    Write-Log -Type "WARN" -Message "No license key is currently activated"
                    Write-Log -Type "WARN"  -Message "Skipping Alteryx product deactivation"
                    $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -Status "Completed" -Success $true
                } else {
                    # Deactivate licenses
                    if ($All) {
                        # Remove all license keys
                        $Deactivation = Remove-AlteryxLicense -Path $LicenseUtility
                        # Check deactivation status
                        if (Select-String -InputObject $Deactivation -Pattern "License(s) successfully removed." -SimpleMatch -Quiet) {
                            Write-Log -Type "CHECK" -Message "All licenses were successfully deactivated"
                            $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -Status "Completed" -Success $true
                        } else {
                            # Output error
                            Write-Log -Type "ERROR" -Message $Deactivation
                            $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                            return $DeactivateProcess
                        }
                    } else {
                        # Check license keys
                        Write-Log -Type "INFO" -Message "Checking license keys"
                        if (-Not (Find-Key -Hashtable $Properties -Key "LicenseKey")) {
                            # Check license file
                            if ($null -eq $Properties.LicenseFile -Or $Properties.LicenseFile -eq "") {
                                Write-Log -Type "ERROR" -Message "No license key or file have been specified"
                                Write-Log -Type "WARN"  -Message "Alteryx product deactivation failed"
                                $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                                return $DeactivateProcess
                            }
                            # Read keys from license file
                            $LicenseFilePath = Join-Path -Path $Properties.ResDirectory -ChildPath $Properties.LicenseFile
                            if (Test-Object -Path $LicenseFilePath -NotFound) {
                                Write-Log -Type "ERROR" -Message "License file path not found $($Properties.LicenseFile)"
                                Write-Log -Type "WARN"  -Message "Alteryx product deactivation failed"
                                $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                                return $DeactivateProcess
                            } else {
                                # Fetch and decrypt license keys
                                $Properties.LicenseKey = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((ConvertTo-SecureString -String (Get-Content -Path $LicenseFilePath))))) -split '[ ,]+'
                            }
                        }
                        Write-Log -Type "DEBUG" -Message $Properties.LicenseKey
                        if ($Properties.LicenseKey.Count -eq 0) {
                            Write-Log -Type "ERROR" -Message "No license key was provided"
                            Write-Log -Type "WARN"  -Message "Alteryx product deactivation failed"
                            $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                            return $DeactivateProcess
                        }
                        # Deactivate each key
                        $CurrentKeys = ($CurrentLicenses | Select-String -Pattern "\b$LicensePattern\b" -AllMatches).Matches.Value
                        $Count = 0
                        foreach ($Key in $Properties.LicenseKey) {
                            if ($CurrentKeys.Contains($Key)) {
                                Write-Log -Type "INFO" -Message "Deactivating license key $Key"
                                $Dectivation = Remove-AlteryxLicense -Path $LicenseUtility -Key $Key
                                # Check deactivation status
                                if (Select-String -InputObject $Dectivation -Pattern "License(s) successfully removed." -SimpleMatch -Quiet) {
                                    Write-Log -Type "CHECK" -Message "License key $Key successfully deactivated"
                                    $Count += 1
                                } else {
                                    Write-Log -Type "ERROR" -Message $Deactivation
                                    $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -ErrorCount 1
                                }
                            } else {
                                Write-Log -Type "ERROR" -Message "$Key is not currently activated"
                                $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -ErrorCount 1
                            }
                        }
                        # Check outcome
                        if ($Properties.LicenseKey.Count -gt 1) {
                            $Success = "$($Properties.LicenseKey.Count) licenses were successfully deactivated"
                            $ErrorCount = $Properties.LicenseKey.Count - $Count
                            if ($ErrorCount -eq $Properties.LicenseKey.Count) {
                                $Failure = "None of the licenses could not be deactivated"
                            } else {
                                $Failure = "$ErrorCount out of $($Properties.LicenseKey.Count) licenses could not be deactivated"
                            }
                        } elseif ($Properties.LicenseKey.Count -eq 1) {
                            $Success = "$($Properties.LicenseKey.Count) license was successfully deactivated"
                            $Failure = "License could not be deactivated"
                        }
                        if ($Count -eq $Properties.LicenseKey.Count) {
                            Write-Log -Type "CHECK" -Message $Success
                            $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -Status "Completed" -Success $true
                        } elseif ($ErrorCount -eq $Properties.LicenseKey.Count) {
                            Write-Log -Type "ERROR" -Message $Failure
                            $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -Status "Failed" -ExitCode 1
                        } else {
                            Write-Log -Type "WARN" -Message $Failure
                            $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -Status "Completed"
                        }
                    }
                }
            } else {
                Write-Log -Type "ERROR" -Message "Unable to reach licensing system"
                Write-Log -Type "WARN"  -Message "Skipping license deactivation"
                $DeactivateProcess = Update-ProcessObject -ProcessObject $DeactivateProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
            }
        }
    }
    End {
        return $DeactivateProcess
    }
}