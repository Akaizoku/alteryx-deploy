function Invoke-StartAlteryx {
    <#
        .SYNOPSIS
        Start Alteryx Server

        .DESCRIPTION
        Start the Alteryx Server service

        .NOTES
        File name:      Invoke-StartAlteryx.ps1
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
        Write-Log -Type "INFO" -Message "Starting Alteryx Service"
        if ($PSCmdlet.ShouldProcess("Alteryx Service", "Start")) {
            $Process = Start-Process -FilePath $AlteryxService -ArgumentList "start" -Verb "RunAs" -PassThru -Wait
            Write-Log -Type "DEBUG" -Message $Process
            # TODO check why exit code is 2
            if ($Process.ExitCode -eq 2) {
                Write-Log -Type "CHECK" -Message "Alteryx Service successfully started"
            } else {
                Write-Log -Type "ERROR" -Message "Alteryx Service could not be started" -ExitCode $Process.ExitCode
            }
        }
    }
}