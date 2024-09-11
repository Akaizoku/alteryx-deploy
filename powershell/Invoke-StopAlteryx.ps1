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
        Last modified:  2024-09-11
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
        # Log function call
        Write-Log -Type "DEBUG" -Message $MyInvocation.MyCommand.Name
        # Process status
        $StopProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Retrieve Alteryx Service utility path
        $AlteryxService = Get-AlteryxUtility -Utility "Service" -Path $Properties.InstallationPath
    }
    Process {
        $StopProcess = Update-ProcessObject -ProcessObject $StopProcess -Status "Running"
        Write-Log -Type "INFO" -Message "Stopping Alteryx Service"
        # Check service status
        $WindowsService = Get-Service -Name $Properties.ServiceName
        Write-Log -Type "DEBUG" -Message $WindowsService
        if ($WindowsService.Status -eq "Stopped") {
            Write-Log -Type "WARN" -Message "Alteryx Service ($($Properties.ServiceName)) is already stopped"
            $StopProcess = Update-ProcessObject -ProcessObject $StopProcess -Status "Completed" -Success $true
        } else {
            if ($PSCmdlet.ShouldProcess("Alteryx Service", "Stop")) {
                if ($Unattended -eq $false) {
                    $Confirm = Confirm-Prompt -Prompt "Do you want to stop the Alteryx Service?"
                }
                if ($Unattended -Or ($Confirm -eq $true)) {
                    # Stop service
                    $ServiceProcess = Start-Process -FilePath $AlteryxService -ArgumentList "stop" -Verb "RunAs" -PassThru -Wait
                    Write-Log -Type "DEBUG" -Message $ServiceProcess
                    # Check process outcome
                    if ($ServiceProcess.ExitCode -eq 0) {
                        # Wait for service to stop
                        while ((Get-Service -Name $Properties.ServiceName).Status -eq "StopPending") {
                            Write-Log -Type "INFO" -Message "Alteryx Service is stopping..."
                            Start-Sleep -Seconds 1
                        }
                        # Check status
                        if ((Get-Service -Name $Properties.ServiceName).Status -eq "Stopped") {
                            Write-Log -Type "DEBUG" -Message (Get-Service -Name $Properties.ServiceName)
                            Write-Log -Type "CHECK" -Message "Alteryx Service successfully stopped"
                            $StopProcess = Update-ProcessObject -ProcessObject $StopProcess -Status "Completed" -Success $true
                        } else {
                            Write-Log -Type "DEBUG" -Message $ServiceProcess
                            Write-Log -Type "ERROR" -Message "Attempt to stop the Alteryx Service ($Properties.ServiceName) failed"
                            $StopProcess = Update-ProcessObject -ProcessObject $StopProcess -Status "Failed" -ExitCode 1
                        }
                    } else {
                        Write-Log -Type "DEBUG" -Message $ServiceProcess
                        Write-Log -Type "ERROR" -Message "Alteryx Service could not be stopped"
                        $StopProcess = Update-ProcessObject -ProcessObject $StopProcess -Status "Failed" -ExitCode $ServiceProcess.ExitCode
                    }
                } else {
                    Write-Log -Type "WARN" -Message "Action was cancelled by the user"
                    $StopProcess = Update-ProcessObject -ProcessObject $StopProcess -Status "Cancelled"
                }
            }
        }
    }
    End {
        return $StopProcess
    }
}