function Invoke-DownloadAlteryx {
    <#
        .SYNOPSIS
        Download Alteryx release

        .DESCRIPTION
        Download the latest Alteryx release for a specified product

        .NOTES
        File name:      Invoke-DownloadAlteryx.ps1
        Author:         Florian Carrier
        Creation date:  2024-09-04
        Last modified:  2024-09-23
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
            Position    = 2,
            Mandatory   = $true,
            HelpMessage = "Installation properties"
        )]
        [ValidateNotNullOrEmpty ()]
        [System.Collections.Specialized.OrderedDictionary]
        $InstallationProperties,
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
        $DownloadProcess = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Product IDs
        $Products = [Ordered]@{
            "Designer"  = "Alteryx Designer"
            "Server"    = "Alteryx Server"
        }
        $ProductID = $Products.$($Properties.Product)
        # Alteryx installation registry key
        $RegistryKey = "HKLM:HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\SRC\Alteryx"
        # License API refresh token
        $LicenseAPIPath = Join-Path -Path $Properties.ResDirectory -ChildPath $Properties.LicenseAPIFile
        $RefreshToken = (Get-Content -Path $LicenseAPIPath -Raw) -replace "`r|`n", ""
        # Placeholder
        $Skip = $false
    }
    Process {
        $DownloadProcess = Update-ProcessObject -ProcessObject $DownloadProcess -Status "Running"
        Write-Log -Type "NOTICE" -Message "Starting download process"
        # ------------------------------------------------------------------------------
        # * Checks
        # ------------------------------------------------------------------------------
        if ($null -eq $RefreshToken) {
            Write-Log -Type "ERROR" -Message "The Alteryx license portal API refresh token has not been configured"
            if (-Not $Unattended) {
                $RefreshToken = Read-Host -Prompt "Enter your Alteryx license portal API refresh token"
            } else {
                Write-Log -Type "ERROR" -Message "Download process cannot proceed"
                $DownloadProcess = Update-ProcessObject -ProcessObject $DownloadProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                return $DownloadProcess
            }
        }
        if ($null -eq $Properties.AccountID) {
            Write-Log -Type "ERROR" -Message "The AccountID parameter has not been configured"
            if (-Not $Unattended) {
                $Properties.AccountID = Read-Host -Prompt "What is the ID of your account in the Alteryx license portal?"
            } else {
                Write-Log -Type "ERROR" -Message "Download process cannot proceed"
                $DownloadProcess = Update-ProcessObject -ProcessObject $DownloadProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                return $DownloadProcess
            }
        }
        # ------------------------------------------------------------------------------
        # * Fetch latest version
        # ------------------------------------------------------------------------------
        # Get license API access token
        if ($PSCmdlet.ShouldProcess("License Portal access token", "Refresh")) {
            try {
                # Catch issues calling the API
                $AccessToken = Update-AlteryxLicenseToken -Token $RefreshToken -Type "Access"
                Write-Log -Type "DEBUG" -Message $AccessToken
            } catch {
                Write-Log -Type "ERROR" -Message (Get-PowerShellError)
                Write-Log -Type "ERROR" -Message "Cannot connect to License portal API"
                $DownloadProcess = Update-ProcessObject -ProcessObject $DownloadProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                return $DownloadProcess
            }
            
        }
        # Check current and target versions
        if ($PSCmdlet.ShouldProcess("Latest release version", "Fetch")) {
            if (Test-Path -Path $RegistryKey) {
                $CurrentVersion = Get-AlteryxVersion
            } else {
                $CurrentVersion = "0.0"
            }
            $MajorVersion   = [System.String]::Concat([System.Version]::Parse($CurrentVersion).Major    , ".", [System.Version]::Parse($CurrentVersion).Minor)
            $TargetVersion  = [System.String]::Concat([System.Version]::Parse($Properties.Version).Major, ".", [System.Version]::Parse($Properties.Version).Minor)
            # Check latest version
            Write-Log -Type "INFO" -Message "Retrieve latest release for $ProductID version $TargetVersion"
            $Release = Get-AlteryxLatestRelease -AccountID $Properties.LicenseAccountID -Token $AccessToken -ProductID $ProductID -Version $TargetVersion
            # Compare versions
            if (Compare-Version -Version $Release.Version -Operator "lt" -Reference $CurrentVersion) {
                Write-Log -Type "WARN" -Message "The specified version ($($Release.Version)) is lower than the current one ($CurrentVersion)"
                if (($Unattended -eq $false) -And (-Not (Confirm-Prompt -Prompt "Do you still want to download $ProductID version $($Release.Version)?"))) {
                    $Skip = $true
                }
            } elseif (Compare-Version -Version $Release.Version -Operator "eq" -Reference $CurrentVersion) {
                Write-Log -Type "WARN" -Message "The version installed ($CurrentVersion) is the latest version available for $ProductID"
                if (($Unattended -eq $false) -And (-Not (Confirm-Prompt -Prompt "Do you still want to download $ProductID version $($Release.Version)?"))) {
                    $Skip = $true
                }
            } else {
                Write-Log -Type "INFO" -Message "$ProductID version $($Release.Version) is available"
                if (-Not $Unattended) {
                    $Continue = Confirm-Prompt -Prompt "Do you want to download it?"
                    if (-Not $Continue) {
                        $Skip = $true
                    }
                }
            }
        }
        # ------------------------------------------------------------------------------
        # * Download
        # ------------------------------------------------------------------------------
        # Check if download should proceed
        if ($Skip -eq $false) {
            # TODO improve and loop through installation properties
            if ($PSCmdlet.ShouldProcess("Patch installer", "Check")) {
                # Check upgrade step
                if (Compare-Version -Version $TargetVersion -Operator "ne" -Reference $MajorVersion) {
                    # If major upgrade, download installer
                    Write-Log -Type "INFO" -Message "Downloading $($Release.Product) version $($Release.Version)"
                } else {
                    # If minor or patch upgrade, download patch
                    Write-Log -Type "INFO" -Message "Downloading $($Release.Product) patch version $($Release.Version)"
                    $Release = Get-AlteryxLatestRelease -AccountID $Properties.LicenseAccountID -Token $AccessToken -ProductID $ProductID -Version $TargetVersion -Patch
                }
            }
            # ------------------------------------------------------------------------------
            # * Server/Designer
            # ------------------------------------------------------------------------------
            if ($PSCmdlet.ShouldProcess($ProductID, "Download")) {
                $DownloadEXE = $true
                $DownloadPath = Join-Path -Path $Properties.SrcDirectory -ChildPath $Release.FileName
                # Check if file already exists
                if (Test-Path -Path $DownloadPath) {
                    Write-Log -Type "WARN" -Message "$ProductID installation file already exist in source directory"
                    Write-Log -Type "DEBUG" -Message $DownloadPath
                    if ($Unattended -eq $false) {
                        $DownloadEXE = Confirm-Prompt "Do you want to redownload and overwrite the existing file?"
                    } else {
                        $DownloadEXE = $false
                    }
                }
                if ($DownloadEXE -eq $true) {
                    if (Test-Object -Path $Properties.SrcDirectory -NotFound) {
                        Write-Log -Type "INFO" -Message "Creating source directory $($Properties.SrcDirectory)"
                        New-Item -Path $DownloadPath -ItemType "Directory" | Out-Null
                    }
                    # Download file
                    try {
                        Invoke-WebRequest -Uri $Release.URL -OutFile $DownloadPath -UseBasicParsing
                    } catch {
                        Write-Log -Type "ERROR" -Message (Get-PowerShellError)
                        # Remove failed download file
                        Remove-Item -Path $DownloadPath -Force
                    }
                    # Check downloaded file
                    Write-Log -Type "DEBUG" -Message $DownloadPath
                    if (Test-Path -Path $DownloadPath) {
                        Write-Log -Type "CHECK" -Message "$ProductID download completed successfully"
                    } else {
                        Write-Log -Type "ERROR" -Message "Download failed"
                        $DownloadProcess = Update-ProcessObject -ProcessObject $DownloadProcess -Status "Failed" -ErrorCount 1 -ExitCode 1
                    }
                } else {
                    Write-Log -Type "WARN" -Message "Skipping download of $ProductID version $($Release.Version)"
                }
            }
            # ------------------------------------------------------------------------------
            # * Predictive Tools
            # ------------------------------------------------------------------------------
            # Check if download should proceed
            if ($InstallationProperties.PredictiveTools -eq $true) {
                if ($PSCmdlet.ShouldProcess("Predictive Tools", "Download")) {
                    $DownloadR = $true
                    if ($Properties.Product -eq "Server") {
                        Write-Log -Type "INFO" -Message "Predictive Tools installer is packaged within the main installation file"
                        if ($Unattended -eq $false) {
                            $DownloadR = Confirm-Prompt -Prompt "Do you still want to download Predictive Tools separately?"
                        } else {
                            $DownloadR = $false
                        }
                    }
                    if ($DownloadR = $true) {
                        # TODO download RInstaller
                    }
                }
            }
            # ------------------------------------------------------------------------------
            # * Intelligence Suite
            # ------------------------------------------------------------------------------
            if ($InstallationProperties.IntelligenceSuite -eq $true) {
                if ($PSCmdlet.ShouldProcess("Intelligence Suite", "Download")) {
                    $DownloadIS = $true
                    if ($Unattended -eq $false) {
                        $DownloadIS = Confirm-Prompt -Prompt "Do you want to download Intelligence Suite?"
                    }
                    if ($DownloadIS -eq $true) {
                        # TODO download IS
                    }
                }
            }
            # ------------------------------------------------------------------------------
            # * Data packages
            # ------------------------------------------------------------------------------
            if ($InstallationProperties.DataPackages -eq $true) {
                if ($PSCmdlet.ShouldProcess("Data Packages", "Download")) {
                    # TODO download data packages
                }
            }
        } else {
            Write-Log -Type "WARN" -Message "Skipping download process"
            $DownloadProcess = Update-ProcessObject -ProcessObject $DownloadProcess -Status "Cancelled" -Success $true -ExitCode 0 -ErrorCount 0
        }
        # ------------------------------------------------------------------------------
        # * Check
        # ------------------------------------------------------------------------------
        if ($DownloadProcess.ErrorCount -eq 0) {
            Write-Log -Type "CHECK" -Message "Download of Alteryx $($Properties.Product) $Version successfull"
            $DownloadProcess = Update-ProcessObject -ProcessObject $DownloadProcess -Status "Completed" -Success $true
        } elseif ($DownloadProcess.ErrorCount -eq 4) {
                Write-Log -Type "ERROR" -Message "Download failed"
                $DownloadProcess = Update-ProcessObject -ProcessObject $DownloadProcess -Status "Failed" -ExitCode 1
        } else {
            if ($DownloadProcess.ErrorCount -eq 1) {
                $ErrorCount = "one error"
            } else {
                $ErrorCount = "$($DownloadProcess.ErrorCount) errors"
            }
            Write-Log -Type "WARN" -Message "Download completed with $ErrorCount"
            $DownloadProcess = Update-ProcessObject -ProcessObject $DownloadProcess -Status "Completed"
        }
    }
    End {
        return $DownloadProcess
    }
}