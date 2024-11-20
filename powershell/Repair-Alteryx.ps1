function Repair-Alteryx {
    <#
        .SYNOPSIS
        Repair Alteryx

        .DESCRIPTION
        Perform maintenance operation to repair or optimise Alteryx by rebuilding database indexes

        .NOTES
        File name:      Repair-Alteryx.ps1
        Author:         Florian Carrier
        Creation date:  2022-04-22
        Last modified:  2022-04-27

        .LINK
        https://knowledge.alteryx.com/index/s/article/How-To-and-When-to-run-a-manual-reindex
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
        Write-Log -Type "DEBUG" -Message $MyInvocation.ScriptName
        # Check version
        if (Compare-Version -Version $Properties.Version -Operator "lt" -Reference "2020.1") {
            $Utility = "CloudCmd"
        } elseif (Compare-Version -Version $Properties.Version -Operator "lt" -Reference "2022.1") {
            $Utility = "ServerHost"
        } else {
            Write-Log -Type "WARN" -Message "No repair steps are available for version 2022.1 and above" -ExitCode 0
        }
        # Default command arguments
        $Command = "--rebuild -mongoconnection:mongodb://user:<Password>@<Hostname>:<Port>/AlteryxGallery?connectTimeoutMS=25000 -luceneconnection:mongodb://user:<Password>@<Hostname>:<Port>/AlteryxGallery_Lucene?connectTimeoutMS=25000 -searchProvider:Lucene"
    }
    Process {
        Write-Log -Type "INFO" -Message "Starting repair of Alteryx $($Properties.Product) $($Properties.Version)"
        $Path = Get-AlteryxUtility -Utility $Utility
        # Retrieve database password
        $Passwords = Get-AlteryxEMongoPassword
        if ($Passwords -match "Non-Admin:\s(?<Password>\w+)") {
            $Password = $Matches.Password
        } else {
            Write-Log -Type "ERROR" -Message "MongoDB database password could not be retrieved" -ExitCode 1
        }
        # Define arguments
        $Tags = [Ordered]@{
            "Hostname"  = "localhost"
            "Port"      = $Properties.MongoDBPort
            "Password"  = $Password
        }
        $Arguments = Set-Tags -String $Command -Tags (Resolve-Tags -Tags $Tags -Prefix "<" -Suffix ">")
        # Build command for debug
        $DebugCommand = ("&", """$Path""", $Arguments) -join " "
        Write-Log -Type "DEBUG" -Message $DebugCommand
        # Run repair and return process
        if ($PSCmdlet.ShouldProcess($Path, "rebuild")) {
            if ($Unattended -eq $false){
                $Confirm = Confirm-Prompt -Prompt "Do you want to rebuild the MongoDB database indexes?"
            }
            if ($Confirm -Or $Unattended) {
                $Repair = Start-Process -FilePath $Path -ArgumentList $Arguments -Verb "RunAs" -PassThru -Wait
            } else {
                Write-Log -Type "WARN" -Message "MongoDB database rebuild cancelled by user" -ExitCode 0
            }
        }
        Write-Log -Type "DEBUG" -Message $Repair
        if ($Repair.ExitCode -eq 0) {
            Write-Log -Type "CHECK" -Message "MongoDB database rebuild completed successfully"
        } else {
            Write-Log -Type "ERROR" -Message "MongoDB database rebuild failed" -ExitCode 1
        }
    }
}