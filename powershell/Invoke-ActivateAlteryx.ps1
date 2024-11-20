function Invoke-ActivateAlteryx {
    <#
        .SYNOPSIS
        Activate Alteryx license

        .DESCRIPTION
        Activate one or more license keys for Alteryx

        .PARAMETER Properties
        The properties parameter corresponds to the configuration of the application.

        .PARAMETER Unattended
        The unattended switch specifies if the script should run in non-interactive mode.

        .NOTES
        File name:      Invoke-ActivateAlteryx.ps1
        Author:         Florian Carrier
        Creation date:  2021-07-05
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
        $ActivateProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # License utility
        $LicenseUtility = Get-AlteryxUtility -Utility "License" -Path $Properties.InstallationPath
        # Expected license format
        $LicensePattern = "\w{4}-\w{4}-\w{4}-\w{4}-\w{4}-\w{4}-\w{4}-\w{4}"
    }
    Process {
        $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -Status "Running"
        Write-Log -Type "NOTICE" -Message "Activating Alteryx"
        if ($PSCmdlet.ShouldProcess("Alteryx", "Activate")) {
            # Check licensing system connectivity
            Write-Log -Type "INFO"  -Message "Checking licensing system connectivity"
            if ((Test-HTTPStatus -URI $Properties.LicensingURL) -eq $true) {
                # Check license keys
                Write-Log -Type "INFO" -Message "Checking license keys"
                if (-Not (Find-Key -Hashtable $Properties -Key "LicenseKey")) {
                    # Check license file
                    if ($null -eq $Properties.LicenseFile -Or $Properties.LicenseFile -eq "") {
                        Write-Log -Type "ERROR" -Message "No license key or file have been specified"
                        Write-Log -Type "WARN"  -Message "Alteryx product activation failed"
                        $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                        return $ActivateProcess
                    }
                    # Read keys from license file
                    $LicenseFilePath = Join-Path -Path $Properties.ResDirectory -ChildPath $Properties.LicenseFile
                    if (Test-Object -Path $LicenseFilePath -NotFound) {
                        Write-Log -Type "ERROR" -Message "License file does not exist $($Properties.LicenseFile)"
                        Write-Log -Type "WARN"  -Message "Alteryx product activation failed"
                        $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                        return $ActivateProcess
                    }
                    # Fetch and decrypt license keys
                    $Properties.LicenseKey = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((ConvertTo-SecureString -String (Get-Content -Path $LicenseFilePath))))) -split '[ ,]+'
                }
                Write-Log -Type "DEBUG" -Message $Properties.LicenseKey
                # Count keys
                if ($Properties.LicenseKey.Count -eq 0) {
                    Write-Log -Type "ERROR" -Message "No license key was provided"
                    Write-Log -Type "WARN"  -Message "Alteryx product activation failed"
                    $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                    return $ActivateProcess
                } else {
                    # Check existing licenses keys
                    $CurrentLicenses = Get-AlteryxLicense -Path $LicenseUtility
                    $NewLicenses = New-Object -TypeName "System.Collections.ArrayList"
                    if ($CurrentLicenses | Select-String -Pattern "\b$LicensePattern\b" -Quiet) {
                        $CurrentKeys = ($CurrentLicenses | Select-String -Pattern "\b$LicensePattern\b" -AllMatches).Matches.Value
                        foreach ($Key in $Properties.LicenseKey) {
                            if ($CurrentKeys.Contains($Key)) {
                                Write-Log -Type "WARN" -Message "$Key is already activated"
                            } elseif ($Key -notmatch "^$LicensePattern$") {
                                Write-Log -Type "ERROR" -Message "$Key key does not match the expected format"
                                $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -ErrorCount 1
                                Write-Log -Type "WARN" -Message "Skipping license $Key"
                            } else {
                                $NewLicenses.Add($Key)
                            }
                        }
                    } else {
                        $NewLicenses.AddRange($Properties.LicenseKey)
                    }
                }
                # Check remaining list of keys
                if ($NewLicenses.Count -eq 0) {
                    if ($ActivateProcess.ErrorCount -ge 1) {
                        Write-Log -Type "ERROR" -Message "No valid license key was provided"
                        Write-Log -Type "WARN"  -Message "Alteryx product activation failed"
                        $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -Status "Failed" -ExitCode 1
                    } else {
                        Write-Log -Type "WARN" -Message "No new license key was provided"
                        Write-Log -Type "WARN" -Message "Skipping license activation process"
                        $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -Status "Completed" -Success 1
                    }
                    return $ActivateProcess
                }
                # Check email address
                $Email = $Properties.LicenseEmail
                if ($null -eq $Email -Or $Email -eq "") {
                    if ($Unattended) {
                        Write-Log -Type "ERROR" -Message "No email address provided for license activation"
                        $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -ErrorCount 1
                        Write-Log -Type "WARN"  -Message "Retrieving email address associated with current session through Windows Active Directory"
                        try {
                            $Email = Get-ADUser -Identity $env:UserName -Properties "mail" | Select-Object -ExpandProperty "mail"
                            Write-Log -Type "DEBUG" -Message $Email
                        } catch {
                            Write-Log -Type "ERROR" -Message $Error[0].Exception
                            $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -ErrorCount 1
                            Write-Log -Type "INFO" -Message "Failed to retrieve email from active session"
                            $Email = $null
                        }
                    } else {
                        # Prompt for email address and validate format
                        do {
                            $Email = Read-Host -Prompt "Please enter the email address for license activation"
                        } until ($Email -as [System.Net.Mail.MailAddress])
                    }
                } else {
                    if ($Email -as [System.Net.Mail.MailAddress]) {
                        $Email = $Properties.LicenseEmail
                    } else {
                        if ($null -eq $Email) {
                            Write-Log -Type "ERROR" -Message "Email address is missing"
                        } else {
                            Write-Log -Type "ERROR" -Message "Email address is invalid"
                        }
                        Write-Log -Type "WARN"  -Message "Skipping product activation"
                        $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                        return $ActivateProcess
                    }
                }
                # Call license utility
                $Count = 0
                foreach ($Key in $NewLicenses) {
                    Write-Log -Type "INFO" -Message "Activating license $Key"
                    if ($Key -match "^$LicensePattern$") {
                        $Activation = Add-AlteryxLicense -Path $LicenseUtility -Key $Key -Email $Email
                        # Check activation status
                        if (Select-String -InputObject $Activation -Pattern "License(s) successfully activated." -SimpleMatch -Quiet) {
                            Write-Log -Type "CHECK" -Message "License key $Key successfully activated"
                            $Count += 1
                        } else {
                            Write-Log -Type "ERROR" -Message $Activation
                            $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -ErrorCount 1
                        }
                    } else {
                        Write-Log -Type "ERROR" -Message "$Key does not match the expected Alteryx license key format"
                        $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -ErrorCount 1
                    }
                    
                }
                # Check activation results
                if ($Count -eq $NewLicenses.Count) {
                    if ($NewLicenses.Count -eq 1) {
                        $Success = "$($NewLicenses.Count) license was successfully activated"
                    } else {
                        $Success = "$($NewLicenses.Count) licenses were successfully activated"
                    }
                    Write-Log -Type "CHECK" -Message $Success
                    $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -Status "Completed" -Success $true
                } elseif ($Count -gt 0) {
                    Write-Log -Type "WARN" -Message "$Count out of $($NewLicenses.Count) could not be activated"
                    $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -Status "Completed"
                } else {
                    Write-Log -Type "WARN" -Message "No license could not be activated"
                    $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -Status "Failed" -ExitCode 1
                }
            } else {
                Write-Log -Type "ERROR" -Message "Unable to reach licensing system"
                Write-Log -Type "WARN"  -Message "Skipping product activation"
                $ActivateProcess = Update-ProcessObject -ProcessObject $ActivateProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
            }
        }
    }
    End {
        return $ActivateProcess
    }
}