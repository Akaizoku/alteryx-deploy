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
        Last modified:  2022-04-19
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
        Write-Log -Type "DEBUG" -Message $MyInvocation.ScriptName
    }
    Process {
        Write-Log -Type "CHECK" -Message "Restarting Alteryx Service"
        Invoke-StopAlteryx  -Properties $Properties -Unattended:$Unattended
        Invoke-StartAlteryx -Properties $Properties -Unattended:$Unattended
        Write-Log -Type "CHECK" -Message "Alteryx Service restart complete"
    }
}