function Uninstall-Alteryx {
    <#
        .SYNOPSIS
        Uninstall Alteryx

        .DESCRIPTION
        Uninstall the Alteryx platform

        .PARAMETER Properties
        The properties parameter corresponds to the configuration of the application.

        .PARAMETER Unattended
        The unattended switch specifies if the script should run in non-interactive mode.

        .NOTES
        File name:      Uninstall-Alteryx.ps1
        Author:         Florian Carrier
        Creation date:  2021-07-08
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
    }
    Process {
        Write-Log -Type "INFO" -Message "Uninstallation of Alteryx Server $($Properties.Version)"
        # ------------------------------------------------------------------------------
        # Alteryx Server
        # ------------------------------------------------------------------------------
        # TODO check if Alteryx is installed
        # Deactivate license keys
        Invoke-DeactivateAlteryx -Properties $Properties -All -Unattended:$Unattended
        # Update file version number
        $ServerFileName = Set-Tags -String $ServerInstaller -Tags (Resolve-Tags -Tags $Tags -Prefix "<" -Suffix ">")
        $ServerPath     = Join-Path -Path $Properties.SrcDirectory -ChildPath $ServerFileName
        if (Test-Path -Path $ServerPath) {
            Write-Log -Type "INFO" -Message "Uninstalling Alteryx $($InstallationProperties.Product)"
            if ($PSCmdlet.ShouldProcess($ServerPath, "Uninstall")) {
                if ($Properties.InstallAwareLog -eq $true) {
                    $InstallAwareLog = Join-Path -Path $Properties.LogDirectory -ChildPath "${ISOTimeStamp}_${ServerFileName}.log"
                    $ServerUninstall = Uninstall-AlteryxServer -Path $ServerPath -Log $InstallAwareLog -Unattended:$Unattended
                } else {
                    $ServerUninstall = Uninstall-AlteryxServer -Path $ServerPath -Unattended:$Unattended
                }
                Write-Log -Type "DEBUG" -Message $ServerUninstall
                if ($ServerUninstall.ExitCode -eq 0) {
                    Write-Log -Type "CHECK" -Message "Alteryx Server uninstalled successfully"
                } else {
                    Write-Log -Type "ERROR" -Message "An error occured during the uninstallation" -ExitCode $ServerUninstall.ExitCode
                }
            }
        } else {
            Write-Log -Type "ERROR" -Message "Path not found $ServerPath"
            Write-Log -Type "ERROR" -Message "Alteryx $($InstallationProperties.Product) executable file could not be located" -ExitCode 1
        }
        # TODO enable uninstall of standalone components
        Write-Log -Type "CHECK" -Message "Uninstallation of Alteryx $($InstallationProperties.Product) $Version successfull"
    }
}