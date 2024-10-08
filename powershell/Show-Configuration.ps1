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
        Last modified:  2024-09-11
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
        Write-Log -Type "DEBUG" -Message $MyInvocation.MyCommand.Name
        # Process status
        $ShowProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Display colour
        $Colour = "Cyan"
    }
    Process {
        $ShowProcess = Update-ProcessObject -ProcessObject $ShowProcess -Status "Running"
        Write-Log -Type "NOTICE" -Message "Displaying script configuration"
        # Display default x custom script parameters
        Write-Log -Type "INFO" -Object "Script parameters"
        Write-Host -Object ($Properties | Out-String).Trim() -ForegroundColor $Colour
        # Display installation parameters
        Write-Log -Type "INFO" -Object "Installation parameters"
        Write-Host -Object ($InstallationProperties | Out-String).Trim() -ForegroundColor $Colour
        $ShowProcess = Update-ProcessObject -ProcessObject $ShowProcess -Status "Completed" -Success $true
    }
    End {
        return $ShowProcess
    }
}