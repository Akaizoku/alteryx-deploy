function Set-Configuration {
    <#
        .SYNOPSIS
        Configure Alteryx Server

        .DESCRIPTION
        Set Alteryx Server configuration

        .NOTES
        File name:      Set-Configuration.ps1
        Author:         Florian Carrier
        Creation date:  2022-05-03
        Last modified:  2022-05-03
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
            Position    = 2,
            Mandatory   = $true,
            HelpMessage = "Installation properties"
        )]
        [ValidateNotNullOrEmpty ()]
        [System.Collections.Specialized.OrderedDictionary]
        $InstallationProperties
    )
    Begin {
        # Get global preference vrariables
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        
    }
    Process {
        
    }
}