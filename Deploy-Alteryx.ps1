#Requires -Version 5.0
#Requires -RunAsAdministrator

<#
    .SYNOPSIS
    Deploy Alteryx

    .DESCRIPTION
    Deploy and configure Alteryx on the current machine

    .PARAMETER Action
    The action parameter corresponds to the operation to perform.

    Nineteen options are available:

    - activate:     activate the Alteryx application license
    - backup:       backup the Alteryx application database
    - configure:    configure the Alteryx application
    - deactivate:   deactivate the Alteryx application license
    - download:     download latest Alteryx application release
    - install:      install the Alteryx application
    - repair:       repair the Alteryx application database
    - open:         open the Alteryx application
    - patch:        patch upgrade the Alteryx application
    - ping:         check the status of the Alteryx application
    - repair:       repair the Alteryx application database
    - restart:      restart the Alteryx application
    - restore:      restore a backup of the Alteryx application database
    - setup:        set-up the script configuration
    - show:         display the script configuration
    - start:        start the Alteryx application
    - stop:         stop the Alteryx application
    - uninstall:    uninstall the Alteryx application
    - upgrade:      upgrade the Alteryx application

    .PARAMETER Unattended
    The unattended switch define if the script should run in silent mode without any user interaction.

    .NOTES
    File name:      Deploy-Alteryx.ps1
    Author:         Florian Carrier
    Creation date:  2021-06-13
    Last modified:  2024-09-20
    Dependencies:   - PowerShell Tool Kit (PSTK)
                    - Alteryx PowerShell Module (PSAYX)

    .LINK
    https://github.com/Akaizoku/alteryx-deploy

    .LINK
    https://www.powershellgallery.com/packages/PSTK

    .LINK
    https://www.powershellgallery.com/packages/PSAYX
#>

[CmdletBinding (
    SupportsShouldProcess = $true
)]

# Static parameters
Param (
    [Parameter (
        Position    = 1,
        Mandatory   = $true,
        HelpMessage = "Action to perform"
    )]
    [ValidateSet (
        "activate",
        "backup",
        "configure",
        "deactivate",
        "download",
        "install",
        "open",
        "patch",
        "ping",
        "repair",
        "repair",
        "restart",
        "restore",
        "setup",
        "show",
        "start",
        "stop",
        "uninstall",
        "upgrade"
    )]
    [System.String]
    $Action,
    [Parameter (
		Position	= 2,
		Mandatory	= $false,
		HelpMessage	= "Version parameter overwrite"
	)]
	[ValidateNotNullOrEmpty ()]
	[System.String]
	$Version,
	[Parameter (
		Position	= 3,
		Mandatory	= $false,
		HelpMessage = "Database backup path"
	)]
	[ValidateNotNullOrEmpty ()]
	[System.String]
	$BackupPath,
	[Parameter (
		Position	= 4,
		Mandatory	= $false,
		HelpMessage	= "Product to install"
	)]
	[ValidateSet (
		"Designer",
		"Server"
	)]
	[ValidateNotNullOrEmpty ()]
	[System.String]
	$Product = "Server",
    [Parameter (
        Position    = 5,
        Mandatory   = $false,
        HelpMessage = "License key(s)"
    )]
    [ValidatePattern ("^\w{4}-\w{4}-\w{4}-\w{4}-\w{4}-\w{4}-\w{4}-\w{4}(\s\w{4}-\w{4}-\w{4}-\w{4}-\w{4}-\w{4}-\w{4}-\w{4})*$")]
    [Alias (
        "Keys",
        "Serial"
    )]
    [System.String[]]
    $LicenseKey,
    [Parameter (
        HelpMessage = "Run script in non-interactive mode"
    )]
    [Switch]
    $Unattended
)

Begin {
    # ----------------------------------------------------------------------------
    # * Global preferences
    # ----------------------------------------------------------------------------
    $ErrorActionPreference  = "Stop"
    $ProgressPreference     = "Continue"

    # ----------------------------------------------------------------------------
    # * Global variables
    # ----------------------------------------------------------------------------
    # General
    $ISOTimeStamp       = Get-Date -Format "yyyyMMdd_HHmmss"

    # Script configuration
    $ScriptProperties = [Ordered]@{
        LibDirectory        = (Join-Path -Path $PSScriptRoot -ChildPath "lib")
        ConfDirectory       = (Join-Path -Path $PSScriptRoot -ChildPath "conf")
        DefaultProperties   = "default.ini"
        CustomProperties    = "custom.ini"
    }

    # ----------------------------------------------------------------------------
    # * Modules
    # ----------------------------------------------------------------------------
    # Dependencies
    $Modules = [Ordered]@{
        "PSTK"  = "1.2.6"
        "PSAYX" = "1.0.4"
    }
    # Load modules
    foreach ($Module in $Modules.GetEnumerator()) {
        try {
            # Check if package is available locally
            Import-Module -Name (Join-Path -Path $ScriptProperties.LibDirectory -ChildPath $Module.Name) -MinimumVersion $Module.Value -ErrorAction "Stop" -Force
            $ModuleVersion = (Get-Module -Name $Module.Name).Version
            Write-Log -Type "CHECK" -Object "The $($Module.Name) module (v$ModuleVersion) was successfully loaded from the library directory."
        } catch {
            try {
                # Otherwise check if module is installed
                Import-Module -Name $Module.Name -MinimumVersion $Module.Value -ErrorAction "Stop" -Force
                $ModuleVersion = (Get-Module -Name $Module.Name).Version
                Write-Log -Type "CHECK" -Object "The $($Module.Name) module (v$ModuleVersion) was successfully loaded."
            } catch {
                Throw "The $($Module.Name) module (v$($Module.Value)) could not be loaded. Make sure it has been installed on the machine or packaged in the ""$($ScriptProperties.LibDirectory)"" directory"
            }
        }
    }

    # ----------------------------------------------------------------------------
    # * Script configuration
    # ----------------------------------------------------------------------------
    # General settings
    $Properties = Get-Properties -File $ScriptProperties.DefaultProperties -Directory $ScriptProperties.ConfDirectory -Custom $ScriptProperties.CustomProperties
    # Resolve relative paths
    Write-Log -Type "DEBUG" -Message "Script structure check"
    $Properties = Get-Path -PathToResolve $Properties.RelativePaths -Hashtable $Properties -Root $PSScriptRoot

    # Transcript
    $FormattedAction  = Format-String -String $Action -Format "TitleCase"
    $Transcript       = Join-Path -Path $Properties.LogDirectory -ChildPath "${ISOTimeStamp}_${FormattedAction}-Alteryx.log"
    Start-Script -Transcript $Transcript

    # Log command line
    Write-Log -Type "DEBUG" -Message $PSCmdlet.MyInvocation.Line

    # ------------------------------------------------------------------------------
    # * Checks
    # ------------------------------------------------------------------------------
    # Ensure shell is running as 64 bit process
    if ([Environment]::Is64BitProcess -eq $false) {
        Write-Log -Type "ERROR" -Message "PowerShell is running as a 32-bit process"
        Write-Log -Type "INFO"  -Message "Please run PowerShell as a 64-bit process" -ExitCode 1
    }

    # ----------------------------------------------------------------------------
    # * Functions
    # ----------------------------------------------------------------------------
    # Load PowerShell functions
    $Functions = Get-ChildItem -Path $Properties.PSDirectory
    foreach ($Function in $Functions) {
        Write-Log -Type "DEBUG" -Message "Import $($Function.Name)"
        try   { . $Function.FullName }
        catch { Write-Error -Message "Failed to import function $($Function.FullName): $PSItem" }
    }

    # ----------------------------------------------------------------------------
    # * Variables
    # ----------------------------------------------------------------------------
    # (Re)load environment variables
    Write-Log -Type "DEBUG" -Message "Load environment variables"
    $EnvironmentVariables = @()
    foreach ($EnvironmentVariable in $EnvironmentVariables) {
        Sync-EnvironmentVariable -Name $EnvironmentVariable -Scope $Properties.EnvironmentVariableScope | Out-Null
    }

    # Check installation path
    if ($Properties.InstallationPath -eq "") {
        if ($Unattended -eq $false) {
            do {
                Write-Log -Type "WARN" -Message "Path not found $($Properties.InstallationPath)"
                $Properties.InstallationPath = Read-Host -Prompt "Please enter the Alteryx installation path"
            } until (Test-Object -Path $Properties.InstallationPath)
        } else {
            if ($Action -ne "install") {
                # Retrieve path from registry
                $Properties.InstallationPath = Get-AlteryxInstallDirectory
            } else {
                Write-Log -Type "ERROR" -Message "No Alteryx installation path has been provided" -ExitCode 1
            }
        }
    } elseif (Test-Object -Path $Properties.InstallationPath -NotFound) {
        New-Item -Path $Properties.InstallationPath -ItemType "Directory" -Force | Out-Null
    }

    # ----------------------------------------------------------------------------
    # * Options
    # ----------------------------------------------------------------------------
    # Installation properties
    $ValidateSet = @(
        "Server"
        "PredictiveTools"
        "IntelligenceSuite"
        "DataPackages"
    )
    $InstallationProperties = Get-Properties -File $Properties.InstallationOptions -Directory $Properties.ConfDirectory -ValidateSet $ValidateSet
    $Properties.Add("Product", $Product)
    # Optional parameters
    if ($PSBoundParameters.ContainsKey("Version")) {
        $Properties.Version = $Version
    }
    if ($PSBoundParameters.ContainsKey("BackupPath")) {
        $Properties.Add("BackupPath", $BackupPath)
    }
    if ($PSBoundParameters.ContainsKey("LicenseKey")) {
        if ($LicenseKey.Count -eq 1 -And $LicenseKey -match "\s") {
            $LicenseKey = $LicenseKey.Split(" ")
        }
        $Properties.Add("LicenseKey", @($LicenseKey))
    }
}

Process {
    # Check operation to perform
    switch ($Action) {
        "activate"      { $Process = Invoke-ActivateAlteryx     -Properties $Properties -Unattended:$Unattended                                                 }
        "backup"        { $Process = Invoke-BackupAlteryx       -Properties $Properties -Unattended:$Unattended                                                 }
        "configure"     { $Process = Set-AlteryxConfiguration   -Properties $Properties -Unattended:$Unattended                                                 }
        "deactivate"    { $Process = Invoke-DeactivateAlteryx   -Properties $Properties -Unattended:$Unattended                                                 }
        "download"      { $Process = Invoke-DownloadAlteryx     -Properties $Properties -InstallationProperties $InstallationProperties -Unattended:$Unattended }
        "install"       { $Process = Install-Alteryx            -Properties $Properties -InstallationProperties $InstallationProperties -Unattended:$Unattended }
        "repair"        { $Process = Repair-Alteryx             -Properties $Properties -Unattended:$Unattended                                                 }
        "open"          { $Process = Open-Alteryx               -Properties $Properties -Unattended:$Unattended                                                 }
        "patch"         { $Process = Invoke-PatchAlteryx        -Properties $Properties -Unattended:$Unattended                                                 }
        "ping"          { $Process = Invoke-PingAlteryx         -Properties $Properties -Unattended:$Unattended                                                 }
        "repair"        { $Process = Repair-Alteryx             -Properties $Properties -Unattended:$Unattended                                                 }
        "restart"       { $Process = Invoke-RestartAlteryx      -Properties $Properties -Unattended:$Unattended                                                 }
        "restore"       { $Process = Invoke-RestoreAlteryx      -Properties $Properties -Unattended:$Unattended                                                 }
        "setup"         { $Process = Invoke-SetupScript         -Properties $Properties -ScriptProperties $ScriptProperties                                     }
        "show"          { $Process = Show-Configuration         -Properties $Properties -InstallationProperties $InstallationProperties                         }
        "start"         { $Process = Invoke-StartAlteryx        -Properties $Properties -Unattended:$Unattended                                                 }
        "stop"          { $Process = Invoke-StopAlteryx         -Properties $Properties -Unattended:$Unattended                                                 }
        "uninstall"     { $Process = Uninstall-Alteryx          -Properties $Properties -InstallationProperties $InstallationProperties -Unattended:$Unattended }
        "upgrade"       { $Process = Update-Alteryx             -Properties $Properties -InstallationProperties $InstallationProperties -Unattended:$Unattended }
        default         { Write-Log -Type "ERROR" -Message """$Action"" operation is not supported" -ExitCode 1                                                 }
    }
}

End {
    # Check outcome and gracefully end script
    $Process = $Process[0]
    if ($Process.ErrorCount -gt 0) {
        if ($Process.ErrorCount -gt 1) {
            $Errors = "with $($Process.ErrorCount) errors"
        } else {
            $Errors = "with $($Process.ErrorCount) error"
        }
    } else {
        $Errors = ""
    }
    if ($Process.Status -eq "Completed") {
        if ($Process.Success) {
            Write-Log -Type "CHECK" -Message "Alteryx $Action process completed successfully" -ExitCode $Process.ExitCode
        } else {
            Write-Log -Type "WARN" -Message "Alteryx $Action process completed $Errors" -ExitCode $Process.ExitCode
        }
    } else {
        switch ($Process.Status) {
            "Cancelled" { $Outcome = "was cancelled"    }
            "Failed"    { $Outcome = "failed"           }
            "Stopped"   { $Outcome = "was stopped"      }
            default     { $Outcome = "failed"           }
        }
        Write-Log -Type "ERROR" -Message "Alteryx $Action process $Outcome $Errors" -ExitCode $Process.ExitCode
    }
}