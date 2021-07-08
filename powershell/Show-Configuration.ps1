function Show-Configuration {
    <#
        .SYNOPSIS
        Show configuration

        .DESCRIPTION
        Display the script configuration

        .PARAMETER Properties
        The properties parameter corresponds to the script configuration

        .NOTES
        File name:      Show-Configuration.ps1
        Author:         Florian Carrier
        Creation date:  2021-07-08
        Last modified:  2021-07-08
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
        $Properties
    )
    Begin {
        # Get global preference variables
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        # Display colour
        $Colour = "Cyan"
    }
    Process {
        # Display default x custom script configuration
        Write-Log -Type "INFO" -Object "Script configuration"
        Write-Host -Object ($Properties | Out-String).Trim() -ForegroundColor $Colour
    }
}