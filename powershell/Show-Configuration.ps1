function Show-Configuration {
    <#
        .SYNOPSIS
        Show configuration

        .DESCRIPTION
        Display the script configuration

        .PARAMETER Properties
        The properties parameter corresponds to the script configuration

        .PARAMETER InstallationProperties
        The installation properties parameter corresponds to the installation configuration

        .NOTES
        File name:      Show-Configuration.ps1
        Author:         Florian Carrier
        Creation date:  2021-07-08
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
            Position    = 2,
            Mandatory   = $true,
            HelpMessage = "Installation properties"
        )]
        [ValidateNotNullOrEmpty ()]
        [System.Collections.Specialized.OrderedDictionary]
        $InstallationProperties
    )
    Begin {
        # Get global preference variables
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        # Log function call
        Write-Log -Type "DEBUG" -Message $MyInvocation.ScriptName
        # Display colour
        $Colour = "Cyan"
    }
    Process {
        # Display default x custom script configuration
        Write-Log -Type "INFO" -Object "Script configuration"
        Write-Host -Object ($Properties | Out-String).Trim() -ForegroundColor $Colour
        # Display installation configuration
        Write-Log -Type "INFO" -Object "Installation configuration"
        Write-Host -Object ($InstallationProperties | Out-String).Trim() -ForegroundColor $Colour
    }
}