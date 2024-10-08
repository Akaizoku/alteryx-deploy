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
        $ConfigureProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
    }
    Process {
        $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -Status "Running"
        if ($PSCmdlet.ShouldProcess("Alteryx System Settings", "Configure")) {
            # TODO
            Write-Log -Type "WARN" -Message "Automated configuration of Alteryx is not yet supported"
            Write-Log -Type "WARN" -Message "Please configure the application through Alteryx System Settings"
            $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -Status "Cancelled"
        } else {
            $ConfigureProcess = Update-ProcessObject -ProcessObject $ConfigureProcess -Status "Completed" -Success $true
        }
    }
    End {
        return $ConfigureProcess
    }
}