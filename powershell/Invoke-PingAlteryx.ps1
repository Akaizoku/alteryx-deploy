function Invoke-PingAlteryx {
    <#
        .SYNOPSIS
        Ping Alteryx Server

        .DESCRIPTION
        Ping Alteryx Server to check if it alive

        .NOTES
        File name:      Invoke-PingAlteryx.ps1
        Author:         Florian Carrier
        Creation date:  2024-09-16
        Last modified:  2024-09-16
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
        $PingProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Parameters
        $HostName       = [System.Net.Dns]::GetHostName()
        $ServiceName    = "AlteryxService"
    }
    Process {
        $PingProcess = Update-ProcessObject -ProcessObject $PingProcess -Status "Running"
        Write-Log -Type "NOTICE" -Message "Pinging Alteryx Server"
        # ----------------------------------------------------------------------------
        # Check Alteryx service status
        Write-Log -Type "INFO" -Message "Check Alteryx Service status"
        if ($PSCmdlet.ShouldProcess("Alteryx Service", "Check")) {
            $AlteryxService = Get-Service -Name $ServiceName
            Write-Log -Type "DEBUG" -Message $AlteryxService
            $ServiceStatus = Format-String -String $AlteryxService.Status -Format "LowerCase"
            if ($AlteryxService.Status -eq "Running") {
                Write-Log -Type "CHECK" -Message "$ServiceName is $ServiceStatus"
            } else {
                Write-Log -Type "ERROR" -Message "$ServiceName is $ServiceStatus"
                $PingProcess = Update-ProcessObject -ProcessObject $PingProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                if ($Unattended -eq $false) {
                    $Continue = Confirm-Prompt -Prompt "Alteryx Service does not appear to be running, do you still want to try to ping the Gallery?"
                    if ($Continue -eq $false) {
                        return $PingProcess
                    }
                } else {
                    return $PingProcess
                }
            }
        } else {
            # WhatIf
            Write-Log -Type "CHECK" -Message "$ServiceName is running"
        }
        # ----------------------------------------------------------------------------
        # Check Gallery
        Write-Log -Type "INFO" -Message "Check Alteryx Gallery status"
        if ($PSCmdlet.ShouldProcess("Alteryx Gallery", "Ping")) {
            if ($Properties.EnableSSL -eq $true) {
                $Protocol = "https"
            } else {
                $Protocol = "http"
            }
            $GalleryURL = "$($Protocol)://$($HostName)/gallery"
            if (Test-HTTPStatus -URI $GalleryURL) {
                Write-Log -Type "CHECK" -Message "Alteryx Gallery is accessible"
                $PingProcess = Update-ProcessObject -ProcessObject $PingProcess -Status "Completed" -Success $true
            } else {
                Write-Log -Type "ERROR" -Message "Alteryx Gallery is not accessible"
                $PingProcess = Update-ProcessObject -ProcessObject $PingProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
            }
        } else {
            # WhatIf
            Write-Log -Type "CHECK" -Message "Alteryx Gallery is accessible"
            $PingProcess = Update-ProcessObject -ProcessObject $PingProcess -Status "Completed" -Success $true
        }
    }
    End {
        return $PingProcess
    }
}