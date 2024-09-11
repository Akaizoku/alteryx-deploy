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
        $StartProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Retrieve Alteryx Service utility path
        $AlteryxService = Get-AlteryxUtility -Utility "Service" -Path $Properties.InstallationPath
        # Check installed version
        $InstalledVersion = Get-AlteryxVersion
        if (Compare-Version -Version $InstalledVersion -Operator "ne" -Reference $Properties.Version) {
            Write-Log -Type "WARN" -Message "The configured version ($($Properties.Version)) does not match the version currently installed ($InstalledVersion)"
            $Properties.Version = $InstalledVersion
        }
    }
    Process {
        $StartProcess = Update-ProcessObject -ProcessObject $StartProcess -Status "Running"
        Write-Log -Type "INFO" -Message "Starting Alteryx Service"
        # Check service status
        $WindowsService = Get-Service -Name $Properties.ServiceName
        Write-Log -Type "DEBUG" -Message $WindowsService
        if ($WindowsService.Status -eq "Running") {
            Write-Log -Type "WARN" -Message "Alteryx Service ($($Properties.ServiceName)) is already running"
            $StartProcess = Update-ProcessObject -ProcessObject $StartProcess -Status "Completed" -Success $true
        } else {
            if ($PSCmdlet.ShouldProcess("Alteryx Service", "Start")) {
                if ($Unattended -eq $false) {
                    $Confirm = Confirm-Prompt -Prompt "Do you want to start the Alteryx Service?"
                }
                if ($Unattended -Or ($Confirm -eq $true)) {
                    # Start service
                    $ServiceProcess = Start-Process -FilePath $AlteryxService -ArgumentList "start" -Verb "RunAs" -PassThru -Wait
                    Write-Log -Type "DEBUG" -Message $ServiceProcess
                    # Check process outcome
                    if (Compare-Version -Version $Properties.Version -Operator "ge" -Reference "2021.4.1") {
                        $ExpectedExitCode = 0
                    } else {
                        # Do not ask
                        $ExpectedExitCode = 2
                    }
                    if ($ServiceProcess.ExitCode -eq $ExpectedExitCode) {
                        # Wait for service to start
                        while ((Get-Service -Name $Properties.ServiceName).Status -eq "StartPending") {
                            Write-Log -Type "INFO" -Message "Alteryx Service is starting..."
                            Start-Sleep -Seconds 1
                        }
                        # Check status
                        if ((Get-Service -Name $Properties.ServiceName).Status -eq "Running") {
                            Write-Log -Type "DEBUG" -Message (Get-Service -Name $Properties.ServiceName)
                            Write-Log -Type "CHECK" -Message "Alteryx Service successfully started"
                            $StartProcess = Update-ProcessObject -ProcessObject $StartProcess -Status "Completed" -Success $true
                        } else {
                            Write-Log -Type "ERROR" -Message "Attempt to start the Alteryx Service ($($Properties.ServiceName)) failed"
                            $StartProcess = Update-ProcessObject -ProcessObject $StartProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                        }
                    } else {
                        Write-Log -Type "DEBUG" -Message $ServiceProcess.ExitCode
                        Write-Log -Type "ERROR" -Message "Alteryx Service could not be started"
                        $StartProcess = Update-ProcessObject -ProcessObject $StartProcess -Status "Failed" -ErrorCount 1 -ExitCode $ServiceProcess.ExitCode
                    }
                } else {
                    Write-Log -Type "WARN" -Message "Action was cancelled by the user"
                    $StartProcess = Update-ProcessObject -ProcessObject $StartProcess -Status "Cancelled"
                }
            } else {
                # Dummy success return for test run
                $StartProcess = Update-ProcessObject -ProcessObject $StartProcess -Status "Completed" -Success $true
            }
        }
    }
    End {
        return $StartProcess
    }
}