function Invoke-RestoreAlteryx {
    <#
        .SYNOPSIS
        Restore Alteryx database

        .DESCRIPTION
        Perform a restore of the Alteryx Server MongoDB database

        .NOTES
        File name:      Invoke-RestoreAlteryx.ps1
        Author:         Florian Carrier
        Creation date:  2021-08-26
        Last modified:  2021-12-09
        Comment:        User configuration files are out of scope of this procedure:
                        - %APPDATA%\Alteryx\Engine\UserConnections.xml
                        - %APPDATA%\Alteryx\Engine\UserAlias.xml

        .LINK
        https://help.alteryx.com/20213/server/server-host-recovery-guide
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
        $ServicePath    = Join-Path -Path $Properties.InstallationPath -ChildPath "bin\AlteryxService.exe"
        $TargetPath     = Join-Path -Path $Properties.InstallationPath -ChildPath "Service\Persistence\MongoDB"
        $Staging        = $false
        # Restore options
        $Restore = [Ordered]@{
            "Database"      = $true
            "Configuration" = $true
            "Token"         = $true
            "RunAsUser"     = $true
            "SMTPPassword"  = $true
        }
        $RestoreType = "full"
        foreach ($Option in $Restore.GetEnumerator()) {
            if ($Option.Value -eq $false) {
                $RestoreType = "partial"
                break
            }
        }
        # Configuration files
        $ConfigurationFiles = [Ordered]@{
            "RunTimeSettings"   = "$env:ProgramData\Alteryx\RuntimeSettings.xml"
            "SystemAlias"       = "$env:ProgramData\Alteryx\Engine\SystemAlias.xml"
            "SystemConnections" = "$env:ProgramData\Alteryx\Engine\SystemConnections.xml"
        }
    }
    Process {
        Write-Log -Type "CHECK" -Message "Start $RestoreType restore of Alteryx Server"
        if ($PSCmdlet.ShouldProcess("Alteryx Service", "Stop")) {
            # ----------------------------------------------------------------------------
            # Check Alteryx service status
            Write-Log -Type "INFO" -Message "Check Alteryx Service status"
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
        # Check source backup path
        if ($PSCmdlet.ShouldProcess("Backup files", "Retrieve")) {
            if ($null -eq (Get-KeyValue -Hashtable $Properties -Key "BackupPath" -Silent)) {
                $SourcePath = $Properties.BackupDirectory
            } else {
                $SourcePath = $Properties.BackupPath
            }
            if (Test-Object -Path $SourcePath) {
                if ($SourcePath -is [System.IO.FileInfo]) {
                    if ([System.IO.Path]::GetExtension($SourcePath) -eq ".zip") {
                        # Extract archive file
                        Write-Log -Type "INFO" -Message "Extract backup file contents"
                        $BackupPath = Join-Path -Path $Properties.TempDirectory -ChildPath ([System.IO.Path]::GetFileNameWithoutExtension($SourcePath))
                        Expand-Archive -Path $SourcePath -DestinationPath $BackupPath -Force -WhatIf:$WhatIfPreference
                        $Staging = $true
                    } else {
                        Write-Log -Type "ERROR" -Message "Only ZIP or uncompressed files are supported" -ExitCode 1
                    }
                } else {
                    # Select most recent backup in the directory
                    Write-Log -Type "WARN" -Message "No backup file was specified"
                    Write-Log -Type "DEBUG" -Message $SourcePath
                    Write-Log -Type "INFO" -Message "Retrieving most recent backup"
                    $BackupFile = (Get-Object -Path $SourcePath -ChildItem -Type "File" -Filter "*.zip" | Sort-Object -Descending -Property "LastWriteTime" | Select-Object -First 1).FullName
                    Write-Log -Type "DEBUG" -Message $BackupFile
                    # Extract archive file
                    Write-Log -Type "INFO" -Message "Extract backup file contents"
                    $BackupPath = Join-Path -Path $Properties.TempDirectory -ChildPath ([System.IO.Path]::GetFileNameWithoutExtension($BackupFile))
                    Expand-Archive -Path $BackupFile -DestinationPath $BackupPath -Force -WhatIf:$WhatIfPreference
                    $Staging = $true
                }
            } else {
                Write-Log -Type "ERROR" -Message "No database backup could be found" -ExitCode 1
            }
        }
        # ----------------------------------------------------------------------------
        # Restore database
        if ($Restore.Database -eq $true) {
            Write-Log -Type "INFO" -Message "Restore MongoDB database from backup"
            if ($PSCmdlet.ShouldProcess("MongoDB", "Restore")) {
                $MongoDBPath = Join-Path -Path $BackupPath -ChildPath "MongoDB"
                $DatabaseRestore = Restore-AlteryxDatabase -SourcePath $MongoDBPath -TargetPath $TargetPath -ServicePath $ServicePath
                if ($DatabaseRestore -match "failed") {
                    Write-Log -Type "ERROR" -Message $DatabaseRestore
                    Write-Log -Type "ERROR" -Message "Database restore failed" -ExitCode 1
                } else {
                    Write-Log -Type "DEBUG" -Message $DatabaseRestore
                }
            }
        }
        # ----------------------------------------------------------------------------
        # Restore configuration files
        if ($Restore.Configuration -eq $true) {
            Write-Log -Type "INFO" -Message "Restore configuration files"
            if ($PSCmdlet.ShouldProcess("Configuration files", "Restore")) {
                $BackupConfigurationFiles   = Get-Object -Path $BackupPath -ChildItem -Filter "*.xml"
                foreach ($ConfigurationFile in $ConfigurationFiles.GetEnumerator()) {
                    $BackupConfigurationFile = $BackupConfigurationFiles | Where-Object -Property "BaseName" -EQ -Value $ConfigurationFile.Name
                    if ($null -ne $BackupConfigurationFile) {
                        # Overwrite existing file
                        Copy-Object -Path $BackupConfigurationFile.FullName -Destination $ConfigurationFile.Value -Force
                    } else {
                        Write-Log -Type "WARN" -Message "$($ConfigurationFile.Name) backup configuration file could not be found"
                    }
                }
            }
        }
        # ----------------------------------------------------------------------------
        # (Re)Set controller token
        if ($Restore.Token -eq $true) {
            Write-Log -Type "INFO" -Message "Remove encrypted controller token"
            $XPath = "SystemSettings/Controller/ServerSecretEncrypted"
            $RunTimeSettingsXML = New-Object -TypeName "System.XML.XMLDocument"
            $RunTimeSettingsXML.Load($ConfigurationFiles.RunTimeSettings)
            $ServerSecretEncrypted = Select-XMLNode -XML $RunTimeSettingsXML -XPath $XPath
            if ($null -ne $ServerSecretEncrypted) {
                Write-Log -Type "DEBUG" -Message $ServerSecretEncrypted.InnerText
                [Void]$ServerSecretEncrypted.ParentNode.RemoveChild($ServerSecretEncrypted)
                $RunTimeSettingsXML.Save($ConfigurationFiles.RunTimeSettings)
            } else {
                Write-Log -Type "WARN" -Message "Encrypted controller token could not be found"
            }
            Write-Log -Type "INFO" -Message "Restore controller token"
            if ($PSCmdlet.ShouldProcess("Controller token", "Restore")) {
                $TokenFile = Join-Path -Path $BackupPath -ChildPath "ControllerToken.txt"
                if (Test-Object -Path $TokenFile) {
                    $ControllerToken = Get-Content -Path $TokenFile -Raw
                    $SetToken = Set-AlteryxServerSecret -Secret $ControllerToken.Trim() -Path $ServicePath
                    if ($SetToken -match "failed") {
                        Write-Log -Type "ERROR" -Message $SetToken
                        Write-Log -Type "ERROR" -Message "Controller token update failed"
                    } else {
                        # Ignore successfull empty output
                        if ($SetToken -ne "") {
                            Write-Log -Type "DEBUG" -Message $SetToken
                        }
                    }
                }
            }
        }
        # ----------------------------------------------------------------------------
        # Set Run-As user
        if ($Restore.RunAsUser -eq $true) {
            # TODO
        }
        # ----------------------------------------------------------------------------
        # Set SMTP password
        if ($Restore.SMTPPassword -eq $true) {
            # TODO
        }
        # ----------------------------------------------------------------------------
        # Reset storage key
        if ($Restore.Configuration -eq $true) {
            Write-Log -Type "INFO" -Message "Restore storage key"
            if ($PSCmdlet.ShouldProcess("Storage Key", "Restore")) {
                $XPath = "SystemSettings/Controller/StorageKeysEncrypted"
                # Retrieve backup storage keys value
                $BackUpRunTimeSettings = Get-Object -Path $BackupPath -ChildItem -Filter "RunTimeSettings.xml"
                if ($null -ne $BackUpRunTimeSettings) {
                    $BackupXML = New-Object -TypeName "System.XML.XMLDocument"
                    $BackupXML.Load($BackUpRunTimeSettings.FullName)
                    $BackupXMLNode  = Select-XMLNode -XML $BackupXML -XPath $XPath
                    Write-Log -Type "DEBUG" -Message $BackupXMLNode.InnerText
                    # Update configuration file
                    $RunTimeSettingsXML = New-Object -TypeName "System.XML.XMLDocument"
                    $RunTimeSettingsXML.Load($ConfigurationFiles.RunTimeSettings)
                    $NewXMLNode  = Select-XMLNode -XML $RunTimeSettingsXML -XPath $XPath
                    $NewXMLNode.InnerText = $BackupXMLNode.InnerText
                    $RunTimeSettingsXML.Save($ConfigurationFiles.RunTimeSettings)
                } else {
                    Write-Log -Type "WARN" -Message "RunTimeSettings.xml backup configuration file could not be located"
                }
            }
        }
        # ----------------------------------------------------------------------------
        # Remove staging folder
        if ($Staging -eq $true) {
            Write-Log -Type "INFO" -Message "Remove staging backup folder"
            Remove-Object -Path $BackupPath -Type "Folder"
        }
        # Restart service if it was running before
        if ($PSCmdlet.ShouldProcess("Alteryx Service", "Restart")) {
            if ($ServiceStatus -eq "Running") {
                Invoke-StartAlteryx -Properties $Properties -Unattended:$Unattended
            }
        }
    }
    End {
        # If no error occured
        Write-Log -Type "CHECK" -Message "Alteryx Server $RestoreType restore complete"
    }
}