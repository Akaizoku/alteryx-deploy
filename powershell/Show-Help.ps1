function Show-Help {
    <#
        .SYNOPSIS
        Show help documentation

        .DESCRIPTION
        Displays the help documentation and provide usefull links

        .NOTES
        File name:      Show-Help.ps1
        Author:         Florian Carrier
        Creation date:  2024-09-23
        Last modified:  2024-09-23
    #>
    Begin {
        # Get global preference vrariables
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        # Log function call
        Write-Log -Type "DEBUG" -Message $MyInvocation.MyCommand.Name
        # Process status
        $HelpProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Variables
        $Path   = Resolve-Path -Path "$PSScriptRoot\..\"
        $Script = "Deploy-Alteryx.ps1"
        $ReadMe = "README.md"
    }
    Process {
        $HelpProcess = Update-ProcessObject -ProcessObject $HelpProcess -Status "Running"
        Write-Log -Type "NOTICE" -Message @"
Help documentation
       _ _                                _            _            
  __ _| | |_ ___ _ __ _   ___  __      __| | ___ _ __ | | ___  _   _ 
 / _`` | | __/ _ \ '__| | | \ \/ /____ / _`` |/ _ \ '_ \| |/ _ \| | | |
| (_| | | ||  __/ |  | |_| |>  <|____| (_| |  __/ |_) | | (_) | |_| |
 \__,_|_|\__\___|_|   \__, /_/\_\     \__,_|\___| .__/|_|\___/ \__, |
                      |___/                     |_|            |___/ 
"@
        $Documentation  = Get-Help -Name "$Path\$Script" -Full
        Write-Log -Type "INFO" -Message $Documentation
        Write-Log -Type "INFO" -Message "Additional information is available in the README file ($PSScriptRoot\$ReadMe)"
        $HelpProcess = Update-ProcessObject -ProcessObject $HelpProcess -Status "Completed" -Success $true
    }
    End {
        return $HelpProcess
    }
}