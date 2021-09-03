function Invoke-BackupAlteryx {
    <#
        .SYNOPSIS
        Backup Alteryx Server

        .DESCRIPTION
        Perform a backup of the Alteryx Server

        .NOTES
        File name:      Invoke-BackupAlteryx.ps1
        Author:         Florian Carrier
        Creation date:  2021-08-26
        Last modified:  2021-08-30
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
        # Variables
        $ISOTimeStamp   = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupPath     = Join-Path -Path $Properties.BackupDirectory -ChildPath "${ISOTimeStamp}_Alteryx_Server"
        $MongoDBPath    = Join-Path -Path $BackupPath -ChildPath "MongoDB"
        $ServicePath    = Join-Path -Path $Properties.InstallationPath -ChildPath "bin\AlteryxService.exe"
        $BackupArchive  = [System.String]::Concat($BackupPath, ".zip")
        # Backup options
        $Backup = [Ordered]@{
            "Database"      = $true
            "Configuration" = $true
            "Token"         = $true
        }
        $BackupType = "full"
        foreach ($Option in $Backup.GetEnumerator()) {
            if ($Option.Value -eq $false) {
                $BackupType = "partial"
                break
            }
        }
        # Configuration files
        $ConfigurationFiles = [Ordered]@{
            "RunTimeSettings"   = "RuntimeSettings.xml"
            "SystemAlias"       = "Engine\SystemAlias.xml"
            "SystemConnections" = "Engine\SystemConnections.xml"
        }
    }
    Process {
        Write-Log -Type "CHECK" -Message "Start $BackupType backup of Alteryx Server"
        # ----------------------------------------------------------------------------
        # Check Alteryx service status
        Write-Log -Type "INFO" -Message "Check Alteryx Service status"
        $Service = "AlteryxService"
        if (Test-Service -Name $Service) {
            $WindowsService = Get-Service -Name $Service
            Write-Log -Type "DEBUG" -Message $Service
            $ServiceStatus = $WindowsService.Status
            if ($ServiceStatus -eq "Running") {
                Invoke-StopAlteryx -Properties $Properties
            }
        } else {
            Write-Log -Type "ERROR" -Message "Alteryx Service ($Service) could not be found" -ExitCode 1
        }
        # ----------------------------------------------------------------------------
        # Create database dump
        if ($Backup.Database -eq $true) {
            Write-Log -Type "INFO" -Message "Create MongoDB database backup"
            $DatabaseBackup = Backup-AlteryxDatabase -Path $MongoDBPath -ServicePath $ServicePath
            if ($DatabaseBackup -match "EMongoDump failed") {
                Write-Log -Type "ERROR" -Message "$DatabaseBackup"
                Write-Log -Type "ERROR" -Message "Database backup failed" -ExitCode 1
            } else {
                Write-Log -Type "DEBUG" -Message "$DatabaseBackup"
            }
        }
        # ----------------------------------------------------------------------------
        # Backup configuration files
        if ($Backup.Configuration -eq $true) {
            Write-Log -Type "INFO" -Message "Backup configuration files"
            $ProgramData = Join-Path -Path ([Environment]::GetEnvironmentVariable("ProgramData")) -ChildPath "Alteryx"
            foreach ($ConfigurationFile in $ConfigurationFiles.GetEnumerator()) {
                $FilePath = Join-Path -Path $ProgramData -ChildPath $ConfigurationFile.Value
                if (Test-Object -Path $FilePath) {
                    Copy-Object -Path $FilePath -Destination $BackupPath -Force
                } else {
                    Write-Log -Type "WARN" -Message "$($ConfigurationFile.Name) configuration file could not be found ($FilePath)"
                }
            }
        }
        # ----------------------------------------------------------------------------
        # Backup tokens
        if ($Backup.Token -eq $true) {
            Write-Log -Type "INFO" -Message "Backup controller token"
            $ControllerToken = Get-AlteryxServerSecret -Path $ServicePath
            Write-Log -Type "DEBUG" -Message $ControllerToken
            $TokenFilePath = Join-Path -Path $BackupPath -ChildPath "ControllerToken.txt"
            Write-Log -Type "DEBUG" -Message $TokenFilePath
            Out-File -InputObject $ControllerToken.Trim() -FilePath $TokenFilePath
        }
        # ----------------------------------------------------------------------------
        # Compress backup
        Write-Log -Type "INFO" -Message "Compress backup files"
        Compress-Archive -Path "$BackupPath\*" -DestinationPath $BackupArchive -CompressionLevel "Optimal" -WhatIf:$WhatIfPreference
        Write-Log -Type "DEBUG" -Message $BackupArchive
        # Remove staging folder
        if (Test-Object -Path $BackupArchive) {
            Write-Log -Type "INFO" -Message "Remove staging backup folder"
            Remove-Object -Path $BackupPath -Type "Folder"
        } elseif (Test-Object -Path $BackupPath) {
            Write-Log -Type "ERROR" -Message "Backup files compression failed"
        } else {
            Write-Log -Type "ERROR" -Message "Alteryx Server backup failed" -ErrorCode 1
        }
        # Restart service if it was running before
        if ($ServiceStatus -eq "Running") {
            Invoke-StartAlteryx -Properties $Properties
        }
    }
    End {
        # If no error occured
        Write-Log -Type "CHECK" -Message "Alteryx Server $BackupType backup complete"
    }
}