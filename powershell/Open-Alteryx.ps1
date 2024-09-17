function Open-Alteryx {
    <#
        .SYNOPSIS
        Open Alteryx Server

        .DESCRIPTION
        Open the default web-browser and navigate to Alteryx Gallery

        .NOTES
        File name:      Open-Alteryx.ps1
        Author:         Florian Carrier
        Creation date:  2024-09-16
        Last modified:  2024-09-16
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
        $OpenProcess= New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Parameters
        $HostName = [System.Net.Dns]::GetHostName()
    }
    Process {
        $OpenProcess = Update-ProcessObject -ProcessObject $OpenProcess -Status "Running"
        Write-Log -Type "NOTICE" -Message "Opening Alteryx $($Properties.Product)"
        if ($Properties.Product -eq "Server") {
            Write-Log -Type "INFO" -Message "Opening Alteryx Gallery"
            if ($PSCmdlet.ShouldProcess("Alteryx Gallery", "Open")) {
                if ($Properties.EnableSSL -eq $true) {
                    $Protocol = "https"
                } else {
                    $Protocol = "http"
                }
                $GalleryURL = "$($Protocol)://$($HostName)/gallery"
                Start-Process -FilePath $GalleryURL
                Write-Log -Type "CHECK" -Message "Alteryx Gallery opened successfully"
                $OpenProcess = Update-ProcessObject -ProcessObject $OpenProcess -Status "Completed" -Success $true
            } else {
                # WhatIf
                $OpenProcess = Update-ProcessObject -ProcessObject $OpenProcess -Status "Completed" -Success $true
            }
        } else {
            if ($PSCmdlet.ShouldProcess("Alteryx $($Properties.Product)", "Open")) {
                $DesignerPath = Get-AlteryxUtility -Utility $Properties.Product
                $DesignerProcess = Start-Process -FilePath $DesignerPath -PassThru
                $DesignerProcess.Refresh()
                Write-Log -Type "DEBUG" -Message $DesignerProcess
                if ($DesignerProcess.Responding -eq $true) {
                    Write-Log -Type "CHECK" -Message "Alteryx $($Properties.Product) opened successfully"
                    $OpenProcess = Update-ProcessObject -ProcessObject $OpenProcess -Status "Completed" -Success $true
                } else {
                    Write-Log -Type "ERROR" -Message "Alteryx $($Properties.Product) could not be started"
                    $OpenProcess = Update-ProcessObject -ProcessObject $OpenProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                }
            } else {
                Write-Log -Type "CHECK" -Message "Alteryx $($Properties.Product) opened successfully"
                    $OpenProcess = Update-ProcessObject -ProcessObject $OpenProcess -Status "Completed" -Success $true
            }
        }
    }
    End {
        return $OpenProcess
    }
}