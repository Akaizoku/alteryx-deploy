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
        Last modified:  2021-08-30
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
            HelpMessage = "Non-interactive mode"
        )]
        [Switch]
        $Unattended
    )
    Begin {
        # Get global preference vrariables
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        # Variables
        $ServiceName = "AlteryxService"
        # Retrieve Alteryx Service utility path
        $AlteryxService = Get-AlteryxServerProcess -Process "Service" -InstallDirectory $Properties.InstallationPath
    }
    Process {
        Write-Log -Type "INFO" -Message "Stopping Alteryx Service"
        # Check service status
        $WindowsService = Get-Service -Name $ServiceName
        Write-Log -Type "DEBUG" -Message $WindowsService
        if ($WindowsService.Status -eq "Stopped") {
            Write-Log -Type "WARN" -Message "Alteryx Service ($ServiceName) is already stopped"
        } else {
            if ($PSCmdlet.ShouldProcess("Alteryx Service", "Stop")) {
                if ($Unattended -eq $false) {
                    $Confirm = Confirm-Prompt -Prompt "Do you want to stop the Alteryx Service?"
                }
                if ($Unattended -Or ($Confirm -eq $true)) {
                    # Stop service
                    $Process = Start-Process -FilePath $AlteryxService -ArgumentList "stop" -Verb "RunAs" -PassThru -Wait
                    Write-Log -Type "DEBUG" -Message $Process
                    # Check process outcome
                    if ($Process.ExitCode -eq 0) {
                        # Wait for service to stop
                        while ((Get-Service -Name $ServiceName).Status -eq "StopPending") {
                            Write-Log -Type "INFO" -Message "Alteryx Service is stopping..."
                            Start-Sleep -Seconds 1
                        }
                        # Check status
                        if ((Get-Service -Name $ServiceName).Status -eq "Stopped") {
                            Write-Log -Type "DEBUG" -Message (Get-Service -Name $ServiceName)
                            Write-Log -Type "CHECK" -Message "Alteryx Service successfully stopped"
                        } else {
                            Write-Log -Type "ERROR" -Message "Attempt to stop the Alteryx Service ($ServiceName) failed" -ExitCode 1
                        }
                    } else {
                        Write-Log -Type "ERROR" -Message "Alteryx Service could not be stopped" -ExitCode $Process.ExitCode
                    }
                } else {
                    Write-Log -Type "WARN" -Message "Action was cancelled by the user" -ExitCode 0
                }
            }
        }
    }
}