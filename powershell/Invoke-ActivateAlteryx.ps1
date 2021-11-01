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
        Last modified:  2021-11-01

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
        # License utility
        $LicenseUtility = Get-AlteryxUtility -Utility "License" -Path $Properties.InstallationPath
    }
    Process {
        Write-Log -Type "INFO" -Message "Activating Alteryx license"
        # Check licensing system connectivity
        Write-Log -Type "INFO"  -Message "Checking licensing system connectivity"
        Write-Log -Type "DEBUG" -Message $Properties.LicensingURL
        if ((Test-HTTPStatus -URI $Properties.LicensingURL) -eq $true) {
            # Activate license
            if ($PSCmdlet.ShouldProcess("Alteryx", "Activate")) {
                # Check license key(s)
                if (Test-Object -Path $Properties.LicenseFile -NotFound) {
                    Write-Log -Type "ERROR" -Message "License file path not found $($Properties.LicenseFile)" -ExitCode 1
                }
                $Keys = Get-Content -Path $Properties.LicenseFile
                if ($Keys.Count -gt 1) {
                    $Success = "$($Keys.Count) licenses were successfully activated"
                    $Failure = "Licenses could not be activated"
                    $Keys    = $Keys -join " "
                } elseif ($Keys.Count -eq 1) {
                    $Success = "$($Keys.Count) license was successfully activated"
                    $Failure = "License could not be activated"
                } else {
                    Write-Log -Type "ERROR" -Message "No license key was provided" -ExitCode 1
                }
                # Check email address
                if ($null -eq $Properties.LicenseEmail) {
                    if ($Unattended) {
                        Write-Log -Type "ERROR" -Message "No email address provided for license activation"
                        Write-Log -Type "WARN"  -Message "Retrieving email address associated with current session through Windows Active Directory"
                        $Email = Get-ADUser -Identity $env:UserName -Properties "mail" | Select-Object -ExpandProperty "mail"
                        Write-Log -Type "DEBUG" -Message $Email
                    } else {
                        # Prompt for email address and validate format
                        do {
                            $Email = Read-Host -Prompt "Please enter the email address for license activation"
                        } until ($Email -as [System.Net.Mail.MailAddress])
                    }
                } else {
                    $Email = $Properties.LicenseEmail
                }
                # Call license utility
                $Activation = Add-AlteryxLicense -Path $LicenseUtility -Key $Keys -Email $Email
                # Check activation status
                if (Select-String -InputObject $Activation -Pattern "License(s) successfully activated." -SimpleMatch -Quiet) {
                    Write-Log -Type "CHECK" -Message $Success
                } else {
                    # Output error and stop script
                    Write-Log -Type "ERROR" -Message $Activation
                    Write-Log -Type "ERROR" -Message $Failure -ExitCode 1
                }
            } else {
                Write-Log -Type "CHECK" -Message $Success
            }
        } else {
            Write-Log -Type "ERROR" -Message "Unable to reach licensing system"
            Write-Log -Type "WARN"  -Message "Skipping license activation"
        }
    }
}