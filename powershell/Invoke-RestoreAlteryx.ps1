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
        Last modified:  2024-09-11
        Comment:        User configuration files are out of scope of this procedure:
                        - %APPDATA%\Alteryx\Engine\UserConnections.xml
                        - %APPDATA%\Alteryx\Engine\UserAlias.xml

        .LINK
        https://help.alteryx.com/current/en/server/install/server-host-recovery-guide.html
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
        $RestoreProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Variables
        $ServicePath    = Join-Path -Path $Properties.InstallationPath -ChildPath "bin\AlteryxService.exe"
        $Staging        = $false
        $MajorVersion = [System.String]::Concat([System.Version]::Parse($Properties.Version).Major, ".", [System.Version]::Parse($Properties.Version).Minor)
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
        $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -Status "Running"
        Write-Log -Type "NOTICE" -Message "Start $RestoreType restore of Alteryx Server"
        # ----------------------------------------------------------------------------
        # * Checks
        # ----------------------------------------------------------------------------
        if ($PSCmdlet.ShouldProcess("Alteryx Service", "Stop")) {
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
                Write-Log -Type "ERROR" -Message "Alteryx Service ($Service) could not be found"
                $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -Status "Failed" -ErrorCode 1 -ExitCode 1
                return $RestoreProcess
            }
        }
        # Check source backup path
        if ($PSCmdlet.ShouldProcess("Backup files", "Retrieve")) {
            # Check if custom backup path is specified
            if ($null -eq (Get-KeyValue -Hashtable $Properties -Key "BackupPath" -Silent)) {
                $SourcePath = $Properties.BackupDirectory
            } else {
                $SourcePath = $Properties.BackupPath
            }
            # Look for backup file
            if (Test-Object -Path $SourcePath) {
                $Source = Get-Item -Path $SourcePath
                # Check if source is a file
                if ($Source.PSIsContainer -eq $false) {
                    if ((Format-String -String $Source.Extension -Format "LowerCase") -eq ".zip") {
                        # Extract archive file
                        Write-Log -Type "INFO" -Message "Extract backup file contents"
                        $BackupPath = Join-Path -Path $Properties.TempDirectory -ChildPath ([System.IO.Path]::GetFileNameWithoutExtension($SourcePath))
                        Expand-Archive -Path $SourcePath -DestinationPath $BackupPath -Force -WhatIf:$WhatIfPreference
                        $Staging = $true
                    } else {
                        Write-Log -Type "ERROR" -Message "Only ZIP files are supported"
                        $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -Status "Failed" -ErrorCode 1 -ExitCode 1
                        return $RestoreProcess
                    }
                } else {
                    # Select most recent backup in the directory
                    Write-Log -Type "WARN" -Message "No backup file was specified"
                    # Ask user confirmation on most recent file
                    if ($Unattended -eq $false) {
                        $Confirmation = Confirm-Prompt -Prompt "Do you want to fetch the latest backup file?"
                        if ($Confirmation -eq $false) {
                            Write-Log -Type "WARN" -Message "Restore operation cancelled by user"
                            $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -Status "Cancelled"
                            return $RestoreProcess
                        }
                    }
                    Write-Log -Type "DEBUG" -Message $SourcePath
                    Write-Log -Type "INFO" -Message "Retrieving most recent backup matching major version $MajorVersion"
                    $Pattern = ".+Alteryx_$($Properties.Product)_$($MajorVersion).+"
                    $BackupFile = (Get-Object -Path $SourcePath -ChildItem -Type "File" -Filter "*.zip" | Where-Object -Property "Name" -Match $Pattern | Sort-Object -Descending -Property "LastWriteTime" | Select-Object -First 1).FullName
                    Write-Log -Type "DEBUG" -Message $BackupFile
                    if ($null -ne $BackupFile) {
                    # Ask user confirmation on backup file
                        if ($Unattended -eq $false) {
                            $Confirmation = Confirm-Prompt -Prompt "Do you want to restore backup from $BackupFile?"
                            if ($Confirmation -eq $false) {
                                Write-Log -Type "WARN" -Message "Restore operation cancelled by user"
                                $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -Status "Cancelled"
                                return $RestoreProcess
                            }
                        }
                    } else {
                        Write-Log -Type "ERROR" -Message "No suitable database back-up file could be found"
                        $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                        return $RestoreProcess
                    }
                    # Extract archive file
                    Write-Log -Type "INFO" -Message "Extract backup file contents"
                    $BackupPath = Join-Path -Path $Properties.TempDirectory -ChildPath ([System.IO.Path]::GetFileNameWithoutExtension($BackupFile))
                    Expand-Archive -Path $BackupFile -DestinationPath $BackupPath -Force -WhatIf:$WhatIfPreference
                    $Staging = $true
                }
            } else {
                Write-Log -Type "ERROR" -Message "No database back-up file could be found"
                $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                return $RestoreProcess
            }
        }
        # ----------------------------------------------------------------------------
        # * Restore configuration files
        # ----------------------------------------------------------------------------
        if ($Restore.Configuration -eq $true) {
            Write-Log -Type "INFO" -Message "Restore configuration files"
            # TODO restore extra configuration files
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
        # * Update configuration
        # ----------------------------------------------------------------------------
        Write-Log -Type "INFO" -Message "Updating configuration"
        if ($PSCmdlet.ShouldProcess("RunTimeSetting.xml", "Update")) {
            $RunTimeSettingsXML = New-Object -TypeName "System.XML.XMLDocument"
            $RunTimeSettingsXML.Load($ConfigurationFiles.RunTimeSettings)
            # Gallery URL
            $BaseAddress = Select-XMLNode -XML $RunTimeSettingsXML -XPath "SystemSettings/Gallery/BaseAddress"
            if ($BaseAddress.InnerText -match "https?://.+?/gallery") {
                # Assume this is a hostname
                $BaseAddressMatch   = Select-String -InputObject $BaseAddress.InnerText -Pattern "https?://(.+?)/gallery"
                $SourceHostname     = $BaseAddressMatch.Matches.Groups[1].Value
                $NewHostname        = $env:ComputerName
                if ($SourceHostname -ne $NewHostname) {
                    Write-Log -Type "INFO"  -Message "Updating hostname"
                    # Update base Gallery URL
                    Write-Log -Type "DEBUG" -Message "Source=$SourceHostname"
                    Write-Log -Type "DEBUG" -Message "Destination=$NewHostname"
                    $NewBaseAddress = $BaseAddress.InnerText.Replace($SourceHostname, $NewHostname)
                    Write-Log -Type "DEBUG" -Message $NewBaseAddress
                    $BaseAddress.InnerText = $NewBaseAddress
                    # Update authentication URL
                    $ServiceProviderEntityID = Select-XMLNode -XML $RunTimeSettingsXML -XPath "SystemSettings/Authentication/ServiceProviderEntityID"
                    $ServiceProviderEntityID.InnerText = $ServiceProviderEntityID.InnerText.Replace($SourceHostname, $NewHostname)
                }
            }
            # SSL
            if ($Properties.EnableSSL -eq $true) {
                $Protocol = "https"
                $Action   = "Enabling"
            } else {
                $Protocol = "http"
                $Action   = "Disabling"
            }
            # ! Node name is case-sensitive: SslEnabled
            $SSLEnabled = Select-XMLNode -XML $RunTimeSettingsXML -XPath "SystemSettings/Gallery/SslEnabled"
            if ($null -ne $SSLEnabled) {
                if ($SSLEnabled.InnerText -ne $Properties.EnableSSL.ToString()) {
                    Write-Log -Type "INFO" -Message ($Action + " SSL")
                    $SSLEnabled.InnerText = $Properties.EnableSSL.ToString()
                }
            } else {
                # If SSL configuration is not explicitly defined
                if ($Properties.EnableSSL -eq $true) {
                    # Create SSL node
                    $Gallery = Select-XMLNode -XML $RunTimeSettingsXML -XPath "SystemSettings/Gallery"
                    $SSLEnabled = $RunTimeSettingsXML.CreateElement("SslEnabled")
                    $SSLEnabled.InnerText = $Properties.EnableSSL.ToString()
                    [Void]$Gallery.AppendChild($SSLEnabled)
                }
            }
            if ($BaseAddress.InnerText -notmatch "^${Protocol}://") {
                Write-Log -Type "INFO" -Message ($Action + " HTTPS")
                $SSLAddress = $BaseAddress.InnerText -replace "^https?", "$Protocol"
                Write-Log -Type "DEBUG" -Message $SSLAddress
                $BaseAddress.InnerText = $SSLAddress
            }
            # Update configuration file
            $RunTimeSettingsXML.Save($ConfigurationFiles.RunTimeSettings)
            # Installation path
            $WorkingPath = Select-XMLNode -XML $RunTimeSettingsXML -XPath "SystemSettings/Environment/WorkingPath"
            if ($WorkingPath.InnerText -ne $Properties.InstallationPath) {
                Write-Log -Type "INFO"  -Message "Updating installation paths"
                Write-Log -Type "DEBUG" -Message "Source=$($WorkingPath.InnerText)"
                Write-Log -Type "DEBUG" -Message "Destination=$($Properties.InstallationPath)"
                $RunTimeSettings = Get-Content -Path $ConfigurationFiles.RunTimeSettings
                $UpdatedSettings = New-Object -TypeName "System.Collections.Arraylist"
                foreach ($Property in $RunTimeSettings) {
                    [Void]$UpdatedSettings.Add($Property.Replace($WorkingPath.InnerText, $Properties.InstallationPath))
                }
                # Overwrite source configuration
                Set-Content -Path $ConfigurationFiles.RunTimeSettings -Value $UpdatedSettings
                # Reload XML settings
                $RunTimeSettingsXML.Load($ConfigurationFiles.RunTimeSettings)
            }
        }
        # ----------------------------------------------------------------------------
        # * (Re)Set controller token
        # ----------------------------------------------------------------------------
        if ($Restore.Token -eq $true) {
            Write-Log -Type "INFO" -Message "Remove encrypted controller token"
            if ($PSCmdlet.ShouldProcess("Encrypted controller token", "Remove")) {
                $ControllerSettingsXML = New-Object -TypeName "System.XML.XMLDocument"
                $ControllerSettingsXML.Load($ConfigurationFiles.RunTimeSettings)
                $ServerSecretEncrypted = Select-XMLNode -XML $ControllerSettingsXML -XPath "SystemSettings/Controller/ServerSecretEncrypted"
                if ($null -ne $ServerSecretEncrypted) {
                    Write-Log -Type "DEBUG" -Message $ServerSecretEncrypted.InnerText
                    [Void]$ServerSecretEncrypted.ParentNode.RemoveChild($ServerSecretEncrypted)
                    $ControllerSettingsXML.Save($ConfigurationFiles.RunTimeSettings)
                } else {
                    Write-Log -Type "WARN" -Message "Encrypted controller token could not be found"
                    $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -ErrorCount 1
                }
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
                        $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -ErrorCount 1
                    } else {
                        # Ignore successfull empty output
                        if ($SetToken -ne "") {
                            Write-Log -Type "DEBUG" -Message $SetToken
                        }
                    }
                } else {
                    Write-Log -Type "DEBUG" -Message $TokenFile
                    Write-Log -Type "ERROR" -Message "No controller token backup file could not be found"
                    $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -ErrorCount 1
                    Write-Log -Type "WARN" -Message "Skipping controller token restore"
                }
            }
        }
        # ----------------------------------------------------------------------------
        # * Set Run-as user
        # ----------------------------------------------------------------------------
        if ($Restore.RunAsUser -eq $true) {
            if ($PSCmdlet.ShouldProcess("Run-as user credentials", "Restore")) {
                # TODO
                Write-Log -Type "WARN" -Message "Run-as user credentials restore is not currently supported"
            }
        }
        # ----------------------------------------------------------------------------
        # * Set SMTP password
        # ----------------------------------------------------------------------------
        if ($Restore.SMTPPassword -eq $true) {
            if ($PSCmdlet.ShouldProcess("SMTP password", "Restore")) {
                # TODO
                Write-Log -Type "WARN" -Message "SMTP password restore is not currently supported"
            }
        }
        # ----------------------------------------------------------------------------
        # * Reset storage key
        # ----------------------------------------------------------------------------
        if ($Restore.Configuration -eq $true) {
            Write-Log -Type "INFO" -Message "Restore storage key"
            if ($PSCmdlet.ShouldProcess("Storage Key", "Restore")) {
                $XPath = "SystemSettings/Controller/StorageKeysEncrypted"
                # Retrieve backup storage keys value
                $BackUpRunTimeSettings = Get-Object -Path $BackupPath -ChildItem -Filter "RunTimeSettings.xml"
                if ($null -ne $BackUpRunTimeSettings) {
                    $BackupXML = New-Object -TypeName "System.XML.XMLDocument"
                    $BackupXML.Load($BackUpRunTimeSettings.FullName)
                    $BackupXMLNode = Select-XMLNode -XML $BackupXML -XPath $XPath
                    Write-Log -Type "DEBUG" -Message $BackupXMLNode.InnerText
                    # Update configuration file
                    $StorageSettingsXML = New-Object -TypeName "System.XML.XMLDocument"
                    $StorageSettingsXML.Load($ConfigurationFiles.RunTimeSettings)
                    $NewXMLNode = Select-XMLNode -XML $StorageSettingsXML -XPath $XPath
                    $NewXMLNode.InnerText = $BackupXMLNode.InnerText
                    $StorageSettingsXML.Save($ConfigurationFiles.RunTimeSettings)
                } else {
                    Write-Log -Type "WARN" -Message "RunTimeSettings.xml backup configuration file could not be located"
                    $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -ErrorCount 1
                }
            }
        }
        # ----------------------------------------------------------------------------
        # * Restore database
        # ----------------------------------------------------------------------------
        if ($Restore.Database -eq $true) {
            Write-Log -Type "INFO" -Message "Restore MongoDB database from backup"
            if ($PSCmdlet.ShouldProcess("MongoDB", "Restore")) {
                $EmbeddedMongoDBEnabled = Select-XMLNode -XML $RunTimeSettingsXML -XPath "SystemSettings/Controller/EmbeddedMongoDBEnabled"
                if ($EmbeddedMongoDBEnabled.InnerText -eq $true) {
                    $EmbeddedMongoDBRootPath = Select-XMLNode -XML $RunTimeSettingsXML -XPath "SystemSettings/Controller/EmbeddedMongoDBRootPath"
                    if ($null -ne $EmbeddedMongoDBRootPath) {
                        $TargetPath = $EmbeddedMongoDBRootPath.InnerText
                    } else {
                        # Use system default
                        $TargetPath = Join-Path -Path $Properties.InstallationPath -ChildPath "Service\Persistence\MongoDB"
                    }
                    $MongoDBPath = Join-Path -Path $BackupPath -ChildPath "MongoDB"
                    $DatabaseRestore = Restore-AlteryxDatabase -SourcePath $MongoDBPath -TargetPath $TargetPath -ServicePath $ServicePath
                    if ($DatabaseRestore -match "failed") {
                        Write-Log -Type "ERROR" -Message $DatabaseRestore
                        Write-Log -Type "ERROR" -Message "Database restore failed"
                        $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                    } else {
                        Write-Log -Type "DEBUG" -Message $DatabaseRestore
                    }
                } else {
                    Write-Log -Type "ERROR" -Message "User-managed MongoDB is not supported"
                    Write-Log -Type "WARN"  -Message "Skipping database restore"
                    $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
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
        if (($RestoreProcess.ErrorCount -eq 0) -And ($RestoreProcess.ExitCode -eq 0)) {
            Write-Log -Type "CHECK" -Message "Alteryx Server $RestoreType restore complete"
            $RestoreProcess = Update-ProcessObject -ProcessObject $RestoreProcess -Status "Completed" -Success $true
        } else {
            Write-Log -Type "ERROR" -Message "Alteryx Server $RestoreType restore could not be completed"
        }
    }
    End {
        return $RestoreProcess
    }
}