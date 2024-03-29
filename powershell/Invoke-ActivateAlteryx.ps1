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
        Last modified:  2022-04-19

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
        # Log function call
        Write-Log -Type "DEBUG" -Message $MyInvocation.ScriptName
        # License utility
        $LicenseUtility = Get-AlteryxUtility -Utility "License" -Path $Properties.InstallationPath
    }
    Process {
        Write-Log -Type "INFO" -Message "Activating Alteryx"
        if ($PSCmdlet.ShouldProcess("Alteryx", "Activate")) {
            # Check licensing system connectivity
            Write-Log -Type "INFO"  -Message "Checking licensing system connectivity"
            if ((Test-HTTPStatus -URI $Properties.LicensingURL) -eq $true) {
                # Check license key(s)
                if (-Not (Find-Key -Hashtable $Properties -Key "LicenseKey")) {
                    # Check license file
                    if ($null -eq $Properties.LicenseFile -Or $Properties.LicenseFile -eq "") {
                        Write-Log -Type "ERROR" -Message "No license key or file have been specified"
                        Write-Log -Type "WARN"  -Message "Alteryx product activation failed" -ExitCode 1
                    }
                    # Read keys from license file
                    if (Test-Object -Path $Properties.LicenseFile -NotFound) {
                        Write-Log -Type "ERROR" -Message "License file path not found $($Properties.LicenseFile)"
                        Write-Log -Type "WARN"  -Message "Alteryx product activation failed" -ExitCode 1
                    }
                    $Properties.LicenseKey = @(Get-Content -Path $Properties.LicenseFile)
                }
                # Count keys
                if ($Properties.LicenseKey.Count -gt 1) {
                    $Success = "$($Properties.LicenseKey.Count) licenses were successfully activated"
                    $Failure = "Licenses could not be activated"
                    $Grammar = "licenses"
                    $Properties.LicenseKey = $Properties.LicenseKey -join " "
                } elseif ($Properties.LicenseKey.Count -eq 1) {
                    $Success = "$($Properties.LicenseKey.Count) license was successfully activated"
                    $Failure = "License could not be activated"
                    $Grammar = "license"
                } else {
                    Write-Log -Type "ERROR" -Message "No license key was provided"
                    Write-Log -Type "WARN"  -Message "Alteryx product activation failed" -ExitCode 1
                }
                # Check email address
                if ($null -eq $Properties.LicenseEmail -Or $Properties.LicenseEmail -eq "") {
                    if ($Unattended) {
                        Write-Log -Type "ERROR" -Message "No email address provided for license activation"
                        Write-Log -Type "WARN"  -Message "Retrieving email address associated with current session through Windows Active Directory"
                        try {
                            $Email = Get-ADUser -Identity $env:UserName -Properties "mail" | Select-Object -ExpandProperty "mail"
                            Write-Log -Type "DEBUG" -Message $Email
                        } catch {
                            Write-Log -Type "ERROR" -Message $Error[0].Exception
                            $Email = $null
                        }
                    } else {
                        # Prompt for email address and validate format
                        do {
                            $Email = Read-Host -Prompt "Please enter the email address for license activation"
                        } until ($Email -as [System.Net.Mail.MailAddress])
                    }
                } else {
                    $Email = $Properties.LicenseEmail
                }
                # TODO check email format
                if ($Email -as [System.Net.Mail.MailAddress]) {
                    # Call license utility
                    Write-Log -Type "INFO" -Message "Activating $Grammar"
                    $Activation = Add-AlteryxLicense -Path $LicenseUtility -Key $Properties.LicenseKey -Email $Email
                    # Check activation status
                    if (Select-String -InputObject $Activation -Pattern "License(s) successfully activated." -SimpleMatch -Quiet) {
                        Write-Log -Type "CHECK" -Message $Success
                    } else {
                        # Output error and stop script
                        Write-Log -Type "ERROR" -Message $Activation
                        Write-Log -Type "ERROR" -Message $Failure -ExitCode 1
                    }
                } else {
                    Write-Log -Type "ERROR" -Message "Email address is missing or invalid"
                    Write-Log -Type "WARN"  -Message "Skipping product activation"
                }
            } else {
                Write-Log -Type "ERROR" -Message "Unable to reach licensing system"
                Write-Log -Type "WARN"  -Message "Skipping product activation"
            }
        }
    }
}