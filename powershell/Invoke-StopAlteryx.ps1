function Invoke-StopAlteryx {
    <#
        .SYNOPSIS
        Stop Alteryx Server

        .DESCRIPTION
        Stop the Alteryx Server service

        .NOTES
        File name:      Invoke-StopAlteryx.ps1
        Author:         Florian Carrier
        Creation date:  2021-07-08
        Last modified:  2021-07-08
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
        $Properties
    )
    Begin {
        # Get global preference vrariables
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        # Retrieve Alteryx Service utility path
        $AlteryxService = Get-AlteryxServerProcess -Process "Service" -InstallDirectory $Properties.InstallationPath
    }
    Process {
        Write-Log -Type "INFO" -Message "Stopping Alteryx Service"
        if ($PSCmdlet.ShouldProcess("Alteryx Service", "Stop")) {
            $Process = Start-Process -FilePath $AlteryxService -ArgumentList "stop" -Verb "RunAs" -PassThru -Wait
            Write-Log -Type "DEBUG" -Message $Process
            if ($Process.ExitCode -eq 0) {
                Write-Log -Type "CHECK" -Message "Alteryx Service successfully stopped"
            } else {
                Write-Log -Type "ERROR" -Message "Alteryx Service could not be stopped" -ExitCode $Process.ExitCode
            }
        }
    }
}