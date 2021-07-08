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
        Last modified:  2021-07-08

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
        # Variables
        $ISOTimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
    }
    Process {
        Write-Log -Type "INFO" -Message "Uninstallation of Alteryx Server $($Properties.Version)"
        # ------------------------------------------------------------------------------
        # Alteryx Server
        # ------------------------------------------------------------------------------
        # TODO check if Alteryx is installed
        $ServerFileName = [System.String]::Concat($Properties.ServerInstaller, $Properties.Version)
        $ServerPath = Join-Path -Path $Properties.SrcDirectory -ChildPath "$ServerFileName.exe"
        if (Test-Path -Path $ServerPath) {
            Write-Log -Type "INFO" -Message "Uninstalling Alteryx Server"
            if ($PSCmdlet.ShouldProcess($ServerPath, "Uninstall")) {
                $ServerLog = Join-Path -Path $Properties.LogDirectory -ChildPath "${ISOTimeStamp}_${ServerFileName}.log"
                $ServerUninstall = Uninstall-AlteryxServer -Path $ServerPath -Log $ServerLog -Unattended:$Unattended
                Write-Log -Type "DEBUG" -Message $ServerUninstall
                if ($ServerUninstall.ExitCode -eq 0) {
                    Write-Log -Type "CHECK" -Message "Alteryx Server uninstalled successfully"
                } else {
                    Write-Log -Type "ERROR" -Message "An error occured during the uninstallation" -ExitCode $ServerUninstall.ExitCode
                }
            }
        } else {
            Write-Log -Type "ERROR" -Message "Path not found $ServerPath"
            Write-Log -Type "ERROR" -Message "Alteryx Server executable file could not be located" -ExitCode 1
        }
        Write-Log -Type "CHECK" -Message "Uninstallation of Alteryx Server $Version successfull"
    }
}