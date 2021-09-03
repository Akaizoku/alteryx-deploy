#Requires -Version 5.0
#Requires -RunAsAdministrator

<#
	.SYNOPSIS
	Setup Alteryx

	.DESCRIPTION
	Setup and configure Alteryx

	.PARAMETER Action
	The action parameter corresponds to the operation to perform.
	Eight options are available:
	- backup:		backup the Alteryx application database
	- configure:	configure the Alteryx application
	- install:		install the Alteryx application
	- restart:		restart the Alteryx application
	- restore:		restore a backup of the Alteryx application database
	- show:			display the script configuration
	- start:		start the Alteryx application
	- stop:			stop the Alteryx application
	- uninstall:	uninstall the Alteryx application
	- upgrade:		upgrade the Alteryx application

	.PARAMETER Unattended
	The unattended switch define if the script should run in silent mode without any user interaction.

	.NOTES
	File name:      Deploy-Alteryx.psm1
	Author:         Florian Carrier
	Creation date:  2021-06-13
	Last modified:  2021-08-30
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
		Mandatory   = $false,
		HelpMessage = "Action to perform"
	)]
	[ValidateSet (
		"activate",
		"backup",
		"configure",
		"install",
		"reload",
		"restart",
		"restore",
		"show",
		"start",
		"stop",
		"uninstall",
		"upgrade"
	)]
	[String]
	$Action,
	[Parameter (
		Position	= 2,
		Mandatory	= $false,
		HelpMessage	= "Version parameter overwrite"
	)]
	[System.Version]
	$Version,
	[Parameter (
		Position	= 3,
		Mandatory	= $false,
		HelpMessage = "Database backup path"
	)]
	[String]
	$BackupPath,
	[Parameter (
		HelpMessage = "Run script in non-interactive mode"
	)]
	[Switch]
	$Unattended
)

Begin {
	# ----------------------------------------------------------------------------
	# Global preferences
	# ----------------------------------------------------------------------------
	$ErrorActionPreference	= "Stop"
	$DebugPreference 		= "Continue"
	Set-StrictMode -Version Latest

	# ----------------------------------------------------------------------------
	# Global variables
	# ----------------------------------------------------------------------------
	# General
	$ISOTimeStamp       = Get-Date -Format "yyyyMMdd_HHmmss"

	# Configuration
	$LibDirectory       = Join-Path -Path $PSScriptRoot -ChildPath "lib"
	$ConfDirectory      = Join-Path -Path $PSScriptRoot -ChildPath "conf"
	$DefaultProperties  = "default.ini"
	$CustomProperties   = "custom.ini"

	# ----------------------------------------------------------------------------
	# Modules
	# ----------------------------------------------------------------------------
	# List all required modules
	$Modules = @("PSTK", "PSAYX")
	foreach ($Module in $Modules) {
	try {
		# Check if module is installed
		Import-Module -Name "$Module" -ErrorAction "Stop" -Force
		Write-Log -Type "CHECK" -Object "The $Module module was successfully loaded."
	} catch {
		# Otherwise check if package is available locally
		try {
			Import-Module -Name (Join-Path -Path $LibDirectory -ChildPath "$Module") -ErrorAction "Stop" -Force
			Write-Log -Type "CHECK" -Object "The $Module module was successfully loaded from the library directory."
		} catch {
			Throw "The $Module library could not be loaded. Make sure it has been made available on the machine or manually put it in the ""$LibDirectory"" directory"
		}
	}
	}

	# ----------------------------------------------------------------------------
	# Script configuration
	# ----------------------------------------------------------------------------
	# General settings
	$Properties = Get-Properties -File $DefaultProperties -Directory $ConfDirectory -Custom $CustomProperties
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
	# Checks
	# ------------------------------------------------------------------------------
	# Ensure shell is running as 64 bit process
	if ([Environment]::Is64BitProcess -eq $false) {
		Write-Log -Type "ERROR" -Message "PowerShell is running as a 32-bit process" -ExitCode 1
	}

	# ----------------------------------------------------------------------------
	# Functions
	# ----------------------------------------------------------------------------
	# Load PowerShell functions
	$Functions = Get-ChildItem -Path $Properties.PSDirectory
	foreach ($Function in $Functions) {
		Write-Log -Type "DEBUG" -Message "Import $($Function.Name)"
		try   { . $Function.FullName }
		catch { Write-Error -Message "Failed to import function $($Function.FullName): $PSItem" }
	}

	# ----------------------------------------------------------------------------
	# Variables
	# ----------------------------------------------------------------------------
	# (Re)load environment variables
	# Write-Log -Type "DEBUG" -Message "Load environment variables"
	# $EnvironmentVariables = @()
	# foreach ($EnvironmentVariable in $EnvironmentVariables) {
	# 	Sync-EnvironmentVariable -Name $EnvironmentVariable -Scope $Properties.EnvironmentVariableScope | Out-Null
	# }

	# ----------------------------------------------------------------------------
	# Optional parameters
	# ----------------------------------------------------------------------------
	if ($PSBoundParameters.ContainsKey("Version")) {
		$Properties.Version = $Version
	}
	if ($PSBoundParameters.ContainsKey("BackupPath")) {
		$Properties.Add("BackupPath", $BackupPath)
	}
}

Process {
	# Check operation to perform
	switch ($Action) {
		"activate"  { Invoke-ActivateAlteryx	-Properties $Properties -Unattended:$Unattended               }
		"backup"    { Invoke-BackupAlteryx    	-Properties $Properties -Unattended:$Unattended               }
		"install"   { Install-Alteryx         	-Properties $Properties -Unattended:$Unattended               }
		"restart"   { Invoke-RestartAlteryx   	-Properties $Properties -Unattended:$Unattended               }
		"restore"   { Invoke-RestoreAlteryx   	-Properties $Properties -Unattended:$Unattended               }
		"show"      { Show-Configuration      	-Properties $Properties                                       }
		"start"     { Invoke-StartAlteryx     	-Properties $Properties -Unattended:$Unattended               }
		"stop"      { Invoke-StopAlteryx      	-Properties $Properties -Unattended:$Unattended               }
		"uninstall"	{ Uninstall-Alteryx       	-Properties $Properties -Unattended:$Unattended               }
		"upgrade"	{ Invoke-UpgradeAlteryx		-Properties $Properties -Unattended:$Unattended               }
		default     { Write-Log -Type "ERROR" 	-Message """$Action"" operation is not supported" -ExitCode 1 }
	}
}

End {
	# Stop script and transcript
	Stop-Script -ExitCode 0
}