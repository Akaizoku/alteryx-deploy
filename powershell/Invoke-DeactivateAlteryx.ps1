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
        Last modified:  2021-11-21

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
        # License utility
        $LicenseUtility = Get-AlteryxUtility -Utility "License" -Path $Properties.InstallationPath
    }
    Process {
        Write-Log -Type "INFO" -Message "Deactivating Alteryx license"
        # Check licensing system connectivity
        Write-Log -Type "INFO"  -Message "Checking licensing system connectivity"
        if ((Test-HTTPStatus -URI $Properties.LicensingURL) -eq $true) {
            # Deactivate license
            if ($PSCmdlet.ShouldProcess("Alteryx", "Deactivate")) {
                if ($All) {
                    # Remove all license keys
                    $Deactivation = Remove-AlteryxLicense -Path $LicenseUtility
                    # Check deactivation status
                    if (Select-String -InputObject $Dectivation -Pattern "License(s) successfully removed." -SimpleMatch -Quiet) {
                        Write-Log -Type "CHECK" -Message "All licenses were successfully deactivated"
                    } else {
                        # Output error
                        Write-Log -Type "DEBUG" -Message $Deactivation
                    }
                } else {
                    # Check license key(s)
                    if (Test-Object -Path $Properties.LicenseFile -NotFound) {
                        Write-Log -Type "ERROR" -Message "License file path not found $($Properties.LicenseFile)" -ExitCode 1
                    }
                    # Deactivate each key
                    $Keys   = Get-Content -Path $Properties.LicenseFile
                    $Count  = 0
                    foreach ($Key in $Keys) {
                        $Dectivation = Remove-AlteryxLicense -Path $LicenseUtility -Key $Key
                        # Check deactivation status
                        if (Select-String -InputObject $Dectivation -Pattern "License(s) successfully removed." -SimpleMatch -Quiet) {
                            $Count += 1
                        } else {
                            # Output error
                            Write-Log -Type "DEBUG" -Message $Deactivation
                        }
                    }
                    # Check outcome
                    if ($Keys.Count -gt 1) {
                        $Success = "$($Keys.Count) licenses were successfully deactivated"
                        $ErrorCount = $Keys.Count - $Count
                        $Failure = "$ErrorCount out of $($Keys.Count) licenses could not be deactivated"
                    } elseif ($Keys.Count -eq 1) {
                        $Success = "$($Keys.Count) license was successfully deactivated"
                        $Failure = "License could not be deactivated"
                    } else {
                        Write-Log -Type "ERROR" -Message "No license key was provided" -ExitCode 1
                    }
                    if ($Count -eq $Keys.Count) {
                        Write-Log -Type "CHECK" -Message $Success
                    } else {
                        Write-Log -Type "ERROR" -Message $Failure
                    }
                }
            }
        } else {
            Write-Log -Type "ERROR" -Message "Unable to reach licensing system"
            Write-Log -Type "WARN"  -Message "Skipping license deactivation"
        }
    }
}