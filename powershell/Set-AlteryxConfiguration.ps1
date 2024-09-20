function Set-AlteryxConfiguration {
    <#
        .SYNOPSIS
        Configure Alteryx

        .DESCRIPTION
        Automatically configure Alteryx System Settings

        .NOTES
        File name:      Set-Configuration.ps1
        Author:         Florian Carrier
        Creation date:  2022-05-03
        Last modified:  2024-09-20
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
            Position    = 2,
            Mandatory   = $true,
            HelpMessage = "Default script properties"
        )]
        [ValidateNotNullOrEmpty ()]
        [System.Collections.Specialized.OrderedDictionary]
        $ScriptProperties
    )
    Begin {
        # Get global preference vrariables
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        # Log function call
        Write-Log -Type "DEBUG" -Message $MyInvocation.MyCommand.Name
        # Process status
        $ConfigureProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
    }
    Process {
        $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -Status "Running"
        # TODO
        Write-Log -Type "ERROR" -Message "Automated configuration of Alteryx is not yet support"
        Write-Log -Type "WARN"  -Message "Please configure the application through Alteryx System Settings"
        $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -Status "Cancelled"
    }
    End {
        return $ConfigureProcess
    }
}