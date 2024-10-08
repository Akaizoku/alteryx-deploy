function Invoke-RestartAlteryx {
    <#
        .SYNOPSIS
        Restart Alteryx Server

        .DESCRIPTION
        Restart the Alteryx Server service

        .NOTES
        File name:      Invoke-RestartAlteryx.ps1
        Author:         Florian Carrier
        Creation date:  2021-08-27
        Last modified:  2024-09-23
    #>
    [CmdletBinding ()]
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
        $RestartProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
    }
    Process {
        $RestartProcess = Update-ProcessObject -ProcessObject $RestartProcess -Status "Running"
        Write-Log -Type "NOTICE" -Message "Restarting Alteryx Service"
        $StopProcess = Invoke-StopAlteryx  -Properties $Properties -Unattended:$Unattended
        if ($StopProcess.Success) {
            $StartProcess = Invoke-StartAlteryx -Properties $Properties -Unattended:$Unattended
            if ($StartProcess.Success) {
                Write-Log -Type "CHECK" -Message "Alteryx Service restart process complete"
                $RestartProcess = Update-ProcessObject -ProcessObject $RestartProcess -Status "Completed" -Success $true
            } else {
                $RestartProcess = Update-ProcessObject -ProcessObject $RestartProcess -Status $StopProcess.Status -ErrorCount $StartProcess.ErrorCount -ExitCode $StartProcess.ExitCode
            }
        } else {
            $RestartProcess = Update-ProcessObject -ProcessObject $RestartProcess -Status $StartProcess.Status -ErrorCount $StopProcess.ErrorCount -ExitCode $StopProcess.ExitCode
        }
    }
    End {
        return $RestartProcess
    }
}