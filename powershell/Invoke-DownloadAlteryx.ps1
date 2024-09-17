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
        Last modified:  2024-09-16
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
        $Process = New-ProcessObject -Name $MyInvocation.MyCommand.Name
        # Product IDs
        $Products = [Ordered]@{
            "Designer"  = "Alteryx Designer"
            "Server"    = "Alteryx Server"
        }
        $ProductID = $Products.$($Properties.Product)
        # License API refresh token
        $RefreshToken = Get-Content -Path $Properties.LicenseAPIFile -Raw
        # Placeholder
        $Skip = $false
    }
    Process {
        $Process = Update-ProcessObject -ProcessObject $Process -Status "Running"
        # Get license API access token
        $AccessToken    = Update-AlteryxLicenseToken -Token $RefreshToken -Type "Access"
        Write-Log -Type "DEBUG" -Message $AccessToken
        # Check current and target versions
        $CurrentVersion = Get-AlteryxVersion
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
        # Check if download should proceed
        if ($Skip -eq $false) {
            # Check if 
            if (Compare-Version -Version $TargetVersion -Operator "ne" -Reference $MajorVersion) {
                # If major upgrade, download installer
                Write-Log -Type "INFO" -Message "Downloading $($Release.Product) version $($Release.Version)"
            } else {
                # If minor or patch upgrade, download patch
                Write-Log -Type "INFO" -Message "Downloading $($Release.Product) patch version $($Release.Version)"
                $Release = Get-AlteryxLatestRelease -AccountID $Properties.LicenseAccountID -Token $AccessToken -ProductID $ProductID -Version $TargetVersion -Patch
            }
            $DownloadPath = Join-Path -Path $Properties.SrcDirectory -ChildPath $Release.FileName
            Invoke-WebRequest -Uri $Release.URL -OutFile $DownloadPath
            # Check downloaded file
            Write-Log -Type "DEBUG" -Message $DownloadPath
            if (Test-Path -Path $DownloadPath) {
                Write-Log -Type "CHECK" -Message "Download completed successfully"
                $Process = Update-ProcessObject -ProcessObject $Process -Status "Completed" -Success $true -ExitCode 0 -ErrorCount 0
            } else {
                Write-Log -Type "ERROR" -Message "Download failed"
                $Process = Update-ProcessObject -ProcessObject $Process -Status "Failed" -Success $false -ExitCode 1 -ErrorCount 1
            }
        } else {
            Write-Log -Type "WARN" -Message "Skipping download process"
            $Process = Update-ProcessObject -ProcessObject $Process -Status "Cancelled" -Success $true -ExitCode 0 -ErrorCount 0
        }
        # TODO download add-ons
    }
    End {
        return $Process
    }
}