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
        Last modified:  2021-11-21
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
        $AlteryxService = Get-AlteryxUtility -Utility "Service" -Path $Properties.InstallationPath
    }
    Process {
        Write-Log -Type "INFO" -Message "Starting Alteryx Service"
        # Check service status
        $WindowsService = Get-Service -Name $ServiceName
        Write-Log -Type "DEBUG" -Message $WindowsService
        if ($WindowsService.Status -eq "Running") {
            Write-Log -Type "WARN" -Message "Alteryx Service ($ServiceName) is already running"
        } else {
            if ($PSCmdlet.ShouldProcess("Alteryx Service", "Start")) {
                if ($Unattended -eq $false) {
                    $Confirm = Confirm-Prompt -Prompt "Do you want to start the Alteryx Service?"
                }
                if ($Unattended -Or ($Confirm -eq $true)) {
                    # Start service
                    $Process = Start-Process -FilePath $AlteryxService -ArgumentList "start" -Verb "RunAs" -PassThru -Wait
                    Write-Log -Type "DEBUG" -Message $Process
                    # Check process outcome
                    if (Compare-Version -Version $Properties.Version -Operator "ge" -Reference "2021.4.1") {
                        $ExpectedExitCode = 0
                    } else {
                        # Do not ask
                        $ExpectedExitCode = 2
                    }
                    if ($Process.ExitCode -eq $ExpectedExitCode) {
                        # Wait for service to start
                        while ((Get-Service -Name $ServiceName).Status -eq "StartPending") {
                            Write-Log -Type "INFO" -Message "Alteryx Service is starting..."
                            Start-Sleep -Seconds 1
                        }
                        # Check status
                        if ((Get-Service -Name $ServiceName).Status -eq "Running") {
                            Write-Log -Type "DEBUG" -Message (Get-Service -Name $ServiceName)
                            Write-Log -Type "CHECK" -Message "Alteryx Service successfully started"
                        } else {
                            Write-Log -Type "ERROR" -Message "Attempt to start the Alteryx Service ($ServiceName) failed" -ExitCode 1
                        }
                    } else {
                        Write-Log -Type "ERROR" -Message "Alteryx Service could not be started" -ExitCode $Process.ExitCode
                    }
                } else {
                    Write-Log -Type "WARN" -Message "Action was cancelled by the user" -ExitCode 0
                }
            }
        }
    }
}