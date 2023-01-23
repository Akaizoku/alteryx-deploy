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
        Last modified:  2022-04-19
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
        # Variables
        $ISOTimeStamp   = Get-Date  -Format "yyyyMMdd_HHmmss"
        $BackupPath     = Join-Path -Path $Properties.BackupDirectory   -ChildPath "${ISOTimeStamp}_Alteryx_Server_$($Properties.Version).zip"
        $TempBackupPath = Join-Path -Path $Properties.TempDirectory     -ChildPath "${ISOTimeStamp}_Alteryx_Server_$($Properties.Version)"
        $MongoDBPath    = Join-Path -Path $TempBackupPath               -ChildPath "MongoDB"
        $ServicePath    = Join-Path -Path $Properties.InstallationPath  -ChildPath "bin\AlteryxService.exe"
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
        $XMLConfigurationFiles = [Ordered]@{
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
        if ($PSCmdlet.ShouldProcess("Alteryx Service", "Stop")) {
            $Service = "AlteryxService"
            if (Test-Service -Name $Service) {
                $WindowsService = Get-Service -Name $Service
                Write-Log -Type "DEBUG" -Message $Service
                $ServiceStatus = $WindowsService.Status
                if ($ServiceStatus -eq "Running") {
                    Invoke-StopAlteryx -Properties $Properties -Unattended:$Unattended
                }
            } else {
                Write-Log -Type "ERROR" -Message "Alteryx Service ($Service) could not be found" -ExitCode 1
            }
        }
        # ----------------------------------------------------------------------------
        # Create database dump
        if ($Backup.Database -eq $true) {
            Write-Log -Type "INFO" -Message "Create MongoDB database backup"
            if ($PSCmdlet.ShouldProcess("MongoDB", "Back-up")) {
                if (-Not $Unattended) {
                    $BackupConfirm = Confirm-Prompt -Prompt "Do you want to perform a back-up of the MongoDB database?"
                }
                if ($Unattended -Or $BackupConfirm) {
                    $DatabaseBackup = Backup-AlteryxDatabase -Path $MongoDBPath -ServicePath $ServicePath
                    if ($DatabaseBackup -match "EMongoDump failed") {
                        Write-Log -Type "ERROR" -Message "$DatabaseBackup"
                        Write-Log -Type "ERROR" -Message "Database backup failed" -ExitCode 1
                    } else {
                        Write-Log -Type "DEBUG" -Message "$DatabaseBackup"
                    }
                } else {
                    Write-Log -Type "WARN" -Message "MongoDB database backup cancelled by user"
                }
            }
        }
        # ----------------------------------------------------------------------------
        # Backup configuration files
        if ($Backup.Configuration -eq $true) {
            Write-Log -Type "INFO" -Message "Backup configuration files"
            if ($PSCmdlet.ShouldProcess("Configuration files", "Back-up")) {
                # XML configuration files
                $ProgramData = Join-Path -Path ([Environment]::GetEnvironmentVariable("ProgramData")) -ChildPath "Alteryx"
                foreach ($XMLConfigurationFile in $XMLConfigurationFiles.GetEnumerator()) {
                    $FilePath = Join-Path -Path $ProgramData -ChildPath $XMLConfigurationFile.Value
                    if (Test-Object -Path $FilePath) {
                        Copy-Object -Path $FilePath -Destination $TempBackupPath -Force
                    } else {
                        Write-Log -Type "WARN"  -Message "$($XMLConfigurationFile.Name) configuration file could not be found"
                        Write-Log -Type "DEBUG" -Message $FilePath
                    }
                }
                # Extra configuration files
                $ConfigurationFiles = Get-Object -Path (Join-Path -Path $Properties.InstallationPath -ChildPath "bin\server\config") -ChildItem -Type "File"
                foreach ($ConfigurationFile in $ConfigurationFiles) {
                    if (Test-Object -Path $ConfigurationFile.FullName) {
                        Copy-Object -Path $ConfigurationFile.FullName -Destination "$TempBackupPath\Config" -Force
                    } else {
                        Write-Log -Type "WARN"  -Message "$($ConfigurationFile.BaseName) configuration file could not be found"
                        Write-Log -Type "DEBUG" -Message $ConfigurationFile.FullName
                    }
                }
            }
        }
        # ----------------------------------------------------------------------------
        # Backup tokens
        if ($Backup.Token -eq $true) {
            Write-Log -Type "INFO" -Message "Backup controller token"
            if ($PSCmdlet.ShouldProcess("Controller token", "Back-up")) {
                $ControllerToken = Get-AlteryxServerSecret -Path $ServicePath
                Write-Log -Type "DEBUG" -Message $ControllerToken
                $TokenFilePath = Join-Path -Path $TempBackupPath -ChildPath "ControllerToken.txt"
                Write-Log -Type "DEBUG" -Message $TokenFilePath
                Out-File -InputObject $ControllerToken.Trim() -FilePath $TokenFilePath
            }
        }
        # ----------------------------------------------------------------------------
        # Compress backup
        Write-Log -Type "INFO" -Message "Compress backup files"
        if ($PSCmdlet.ShouldProcess("Compress", "Back-up")) {
            if (Test-Object -Path $Properties.BackupDirectory -NotFound) {
                New-Item -Path $Properties.BackupDirectory -ItemType Directory -Force | Out-Null
            }
            Compress-Archive -Path "$TempBackupPath\*" -DestinationPath $BackupPath -CompressionLevel "Optimal" -WhatIf:$WhatIfPreference
            Write-Log -Type "DEBUG" -Message $BackupPath
            if (Test-Object -Path $BackupPath -NotFound) {
                Write-Log -Type "ERROR" -Message "Backup files compression failed" -ErrorCode 1
            } else {
                # Remove staging folder
                Write-Log -Type "INFO" -Message "Remove staging backup folder"
                if ($PSCmdlet.ShouldProcess($TempBackupPath, "Remove")) {
                    Remove-Object -Path $TempBackupPath -Type "Folder"
                }
            }
        }
        # ----------------------------------------------------------------------------
        # Restart service if it was running before
        if ($ServiceStatus -eq "Running") {
            Invoke-StartAlteryx -Properties $Properties -Unattended:$Unattended
        }
    }
    End {
        # If no error occured
        Write-Log -Type "CHECK" -Message "Alteryx Server $BackupType backup complete"
    }
}