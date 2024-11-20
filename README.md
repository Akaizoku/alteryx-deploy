# alteryx-deploy

[![PSScriptAnalyzer](https://github.com/Akaizoku/alteryx-deploy/actions/workflows/scan.yml/badge.svg?branch=main)](https://github.com/Akaizoku/alteryx-deploy/actions/workflows/scan.yml)

<!-- ```asci
       _ _                                _            _            
  __ _| | |_ ___ _ __ _   ___  __      __| | ___ _ __ | | ___  _   _ 
 / _` | | __/ _ \ '__| | | \ \/ /____ / _` |/ _ \ '_ \| |/ _ \| | | |
| (_| | | ||  __/ |  | |_| |>  <|____| (_| |  __/ |_) | | (_) | |_| |
 \__,_|_|\__\___|_|   \__, /_/\_\     \__,_|\___| .__/|_|\___/ \__, |
                      |___/                     |_|            |___/ 
``` -->

`alteryx-deploy` is a small PowerShell utility for the automation of the deployment and maintenance of Alteryx.

## Table of Contents <!-- omit in toc -->

1. [Usage](#usage)
   1. [Installation](#installation)
   2. [Configuration](#configuration)
   3. [Execution](#execution)
2. [Pre-requisites](#pre-requisites)
   1. [Permissions](#permissions)
   2. [PowerShell version](#powershell-version)
   3. [PowerShell Modules](#powershell-modules)
   4. [Alteryx](#alteryx)
3. [Parameters](#parameters)
   1. [Mandatory](#mandatory)
      1. [Action](#action)
   2. [Optional](#optional)
      1. [Version](#version)
      2. [Backup Path](#backup-path)
      3. [Product](#product)
      4. [License Key](#license-key)
      5. [Unattended](#unattended)
      6. [WhatIf](#whatif)
      7. [Debug](#debug)
4. [Process](#process)
   1. [Help](#help)
   2. [Set-up](#set-up)
   3. [Show](#show)
   4. [Download](#download)
   5. [Installation](#installation-1)
   6. [Upgrade](#upgrade)
   7. [Patch](#patch)
   8. [Uninstallation](#uninstallation)
   9. [Activation](#activation)
   10. [Deactivation](#deactivation)
   11. [Backup](#backup)
   12. [Restore](#restore)
   13. [Repair](#repair)
   14. [Rollback](#rollback)
   15. [Start](#start)
   16. [Stop](#stop)
   17. [Restart](#restart)
   18. [Ping](#ping)
   19. [Open](#open)
5. [Logs](#logs)
6. [Dependencies](#dependencies)
7. [Compatibility](#compatibility)
8. [Known issues](#known-issues)
   1. [Access to the cloud file is denied](#access-to-the-cloud-file-is-denied)
   2. [Transcript is not stopped](#transcript-is-not-stopped)

## Usage

### Installation

Download the latest stable version from the [`alteryx-deploy`](https://github.com/Akaizoku/alteryx-deploy) GitHub repository.

```powershell
curl --remote-name --remote-header-name "https://github.com/Akaizoku/alteryx-deploy/releases/download/2.0.1/alteryx-deploy-v2.0.1.zip"
```

Alternatively, if you do not wish to install the PowerShell modules required as dependencies, you can download the portable version.

```powershell
curl --remote-name --remote-header-name "https://github.com/Akaizoku/alteryx-deploy/releases/download/2.0.1/alteryx-deploy-v2.0.1-portable.zip"
```

### Configuration

A set-up wizard is available to interactively configure the script from the command prompt.

```powershell
.\Deploy-Alteryx.ps1 -Action "setup"
```

### Execution

1. Run the [`Deploy-Alteryx.ps1`](./Deploy-Alteryx.ps1) script with the corresponding action parameter;
   - [activate](#activation):       activate the Alteryx application license
   - [backup](#backup):             backup the Alteryx application database
   - [configure](#configuration):   configure the Alteryx application
   - [deactivate](#deactivation):   deactivate the Alteryx application license
   - [download](#download):         download latest Alteryx application release
   - [help](#help)                  display the help documentation of the script
   - [install](#installation):      install the Alteryx application
   - [open](#open):                 open the Alteryx application
   - [patch](#patch):               patch upgrade the Alteryx application
   - [ping](#ping):                 check the status of the Alteryx application
   - [repair](#repair):             repair the Alteryx application database
   - [restart](#restart):           restart the Alteryx application
   - [restore](#restore):           restore a backup of the Alteryx application database
   - [rollback](#rollback)          restore a previous known state of the Alteryx application
   - [setup](#set-up):              set-up the script configuration
   - [show](#show):                 display the script configuration
   - [start](#start):               start the Alteryx application
   - [stop](#stop):                 stop the Alteryx application
   - [uninstall](#uninstallation):  uninstall the Alteryx application
   - [upgrade](#upgrade):           upgrade the Alteryx application
2. Check the logs.

Example to display the current script configuration:

```powershell
.\Deploy-Alteryx.ps1 -Action "show"
```

**Remark** It is strongly recommended to perform a test run using the [`-WhatIf`](#whatif) parameter if you are running the script or operation for the first time.

## Pre-requisites

### Permissions

This script requires administrator rights to be run.

### PowerShell version

This script requires [PowerShell version 5.0](https://docs.microsoft.com/en-us/powershell/scripting/windows-powershell/whats-new/what-s-new-in-windows-powershell-50) or later to be run.

### PowerShell Modules

This script makes use of functions from the PowerShell Tool Kit ([PSTK]) module and Alteryx PowerShell ([PSAYX]) module as described in the [dependencies section](#dependencies).

The modules must be [installed](https://docs.microsoft.com/en-us/powershell/module/powershellget/install-module) on the local machine, or placed in the `lib` folder at the root of the script directory.

```PowerShell
Install-Module -Name "PSTK"
Install-Module -Name "PSAYX"
```

Alternatively, do install the portable version of the script made available in the [`alteryx-deploy`](https://github.com/Akaizoku/alteryx-deploy) GitHub repository.

Example script structure with embedded dependencies:

```bash
.alteryx-deploy
+---conf
+---lib
|   +---PSAYX
|   \---PSTK
+---powershell
\---res
```

### Alteryx

Alteryx installation files must be made available in the source directory (default `C:\Sources`). See the [compatibility section](#compatibility) for more information about the supported versions.

You can download them from <https://downloads.alteryx.com> or download via the `download` action.

Please refer to [Alteryx system requirements](https://help.alteryx.com/current/server/system-requirements) for minimum machine requirements.

## Parameters

In addition to the configuration files presented above, parameters will define the operation performed during the execution.

### Mandatory

This section lists the mandatory parameters that must be specified to run the script.

#### Action

The `Action` parameter corresponds to the operation to perform.

Nineteen options are available:

- activate:     activate the Alteryx application license
- backup:       backup the Alteryx application database
- configure:    configure the Alteryx application
- deactivate:   deactivate the Alteryx application license
- download:     download latest Alteryx application release
- help:         display the help documentation
- install:      install the Alteryx application
- repair:       repair the Alteryx application database
- open:         open the Alteryx application
- patch:        patch upgrade the Alteryx application
- ping:         check the status of the Alteryx application
- repair:       repair the Alteryx application database
- restart:      restart the Alteryx application
- restore:      restore a backup of the Alteryx application database
- rollback:     restore a previous known state of the Alteryx application
- setup:        set-up the script configuration
- show:         display the script configuration
- start:        start the Alteryx application
- stop:         stop the Alteryx application
- uninstall:    uninstall the Alteryx application
- upgrade:      upgrade the Alteryx application

### Optional

This section lists the optional parameters that can be specified at runtime.

#### Version

The `Version` parameter is optional and enables the user to overwrite the version set in the configuration files.

#### Backup Path

The `BackupPath` parameter is optional and enables the user to specify a backup file to use for a database restore.

#### Product

The `Product` parameter is optional and enables the user to define if Alteryx Designer should be installed instead of the default Alteryx Server.

#### License Key

The `LicenseKey` parameter is optional and enables the user to specify license keys at runtime.

#### Unattended

The `Unattended` switch enables the user to specify that the script should run without any interaction.

If this switch is not used, the setup wizard from Alteryx will be displayed and the user will need to go through the installation steps manually.

#### WhatIf

The `WhatIf` switch enables the user to test a command without executing the actions of the command. This means that changes are not applied but processing steps are simply displayed.

#### Debug

The `Debug` standard switch enable the display of additional log information.

A lot of useful debug messages have been defined. Should you wish to enable them, it is recommended to make use of the [`$DebugPreference`](https://docs.microsoft.com/en-us/powershell/module/Microsoft.PowerShell.Core/About/about_Preference_Variables#debugpreference) variable.

```powershell
$DebugPreference = "Continue"
```

## Process

Below are the execution steps of the `.\Deploy-Alteryx.ps1` script.

**Remarks**:

1. The execution steps will vary depending on the configuration of the scripts.
2. The steps described below correspond to a complete and successfull execution of the script.

### Help

Display the help documentation of the script.

```powershell
Get-Help -Name "Deploy-Alteryx.ps1" -Full
```

### Set-up

Start the configuration wizard to guide the user through the set-up of the alteryx-deploy script.

Below are the steps to set-up the `alteryx-deploy` script configuration.

```powershell
.\Deploy-Alteryx.ps1 -Action "setup"
```

1. Configure script parameters;
2. Configure license API token;
3. Configure Server API admin keys;
4. Configure installation properties;
5. Configure license key file
<!-- 6. Configure SSL/TLS options;
7. Configure SMTP options. -->

### Show

Display the current script configuration back to the user.

Below are the steps to display the `alteryx-deploy` script configuration.

```powershell
.\Deploy-Alteryx.ps1 -Action "show"
```

### Download

Download the latest version of the licensed Alteryx application from the Alteryx license portal.

Below are the steps to download the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "download"
```

1. Refresh license API portal access token;
2. Fetch information on latest release;
3. Download latest version of Alteryx Server (or Designer if specified with the `-Product` parameter);
4. Download Predictive Tools (if enabled);
5. Download Intelligence Suite (if enabled).
<!-- 6. Download Data packages (if enabled). -->

### Installation

Start the installation process of the Alteryx application and its add-ons if configured.

Below are the steps to install the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "install"
```

1. Install Alteryx Server (or Designer if specified with the `-Product` parameter);
2. Install Predictive Tools (if enabled);
3. Install Intelligence Suite (if enabled);
4. Install Data packages (if enabled);
5. Activate licenses (if enabled).
<!-- 6. Configure System Settings;
7. Start the Alteryx service. -->

### Upgrade

Start the (major) upgrade process of the Alteryx application and its add-ons if configured.

Below are the steps to upgrade the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "upgrade"
```

1. Backup Alteryx database and configuration files;
2. Upgrade Alteryx Server (or Designer if specified with the `-Product` parameter);
3. Install Predictive Tools (if enabled);
4. Install Intelligence Suite (if enabled);
5. Install Data packages (if enabled);
6. Check installation status and rollback if errors occurred.

### Patch

Start the patch process of the Alteryx application.

Below are the steps to patch the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "patch"
```

1. Backup Alteryx database and configuration files;
2. Patch Alteryx Server (or Designer if specified with the `-Product` parameter);
3. Check installation status.

### Uninstallation

Start the uninstallation process of the Alteryx application and all of its add-ons.

Below are the steps to uninstall the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "uninstall"
```

1. Uninstall Alteryx Server (or Designer if specified with the `-Product` parameter).

**Warnings:**

1. The uninstallation process requires the original installation executable file.
2. The uninstallation of Alteryx Server does also remove all dependencies such as Precdictive Tools, Intelligence Suite, etc.

### Activation

License the Alteryx application by registering the specified license keys through the Alteryx licensing system.

Below are the steps to activate (license) the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "activate"
```

1. Check licensing system connectivity ([whitelist.alteryx.com]);
2. Check license file path;
3. Activate Alteryx licenses.

### Deactivation

Deregister the specified license keys through the Alteryx licensing system.

Below are the steps to deactivate (license) the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "deactivate"
```

1. Check licensing system connectivity ([whitelist.alteryx.com]);
2. Check license file path;
3. Deactivate Alteryx licenses.

### Backup

Start the back-up process of the Alteryx database and all of the configuration files of the application.

Below are the steps to back-up the Alteryx application database.

```powershell
.\Deploy-Alteryx.ps1 -Action "backup"
```

1. Check Alteryx Service status and stop it if it is running;
2. Create database dump;
3. Create copy of application configuration files;
4. Backup controller token;
5. Compress all back-up files;
6. Restart Alteryx Service (if it was running previously).

### Restore

Start the restoration process of the Alteryx database and all of the configuration files of the application from a back-up file.

Below are the steps to restore the Alteryx application database.

```powershell
.\Deploy-Alteryx.ps1 -Action "restore"
```

1. Check Alteryx Service status and stop it if it is running;
2. Check backup path;
   - If backup file is an archive (.ZIP), extract files from archive.
   - If backup path is a directory, select most recent backup file (using [last write time](https://docs.microsoft.com/en-us/dotnet/api/system.io.filesysteminfo.lastwritetime)).
3. Restore application configuration files;
4. Update configuration to match new environment;
5. Restore controller token;
6. Reset storage keys;
7. Restore MongoDB database;
8. Restart Alteryx Service (if it was running previously).

### Repair

Start the repair process of the Alteryx database.

Below are the steps to repair the Alteryx application database.

```powershell
.\Deploy-Alteryx.ps1 -Action "repair"
```

1. Rebuild MongoDB indexes.
<!-- 2. Shrink database. -->

**Remark**: No repair steps are available for version 2022.1 and above.

### Rollback

Start the rollback process of the Alteryx application back to a previous known state from a back-up file.

Below are the steps to roll-back the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "rollback"
```

1. Uninstall the current version;
2. Install previous version;
3. Restore database;
4. Restart service.

### Start

Start the Alteryx service.

Below are the steps to start the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "start"
```

1. Check Alteryx Service status;
2. If it is not already running, start Alteryx Service;
3. Check if the service started properly.

### Stop

Stop the service powering the Alteryx application.

Below are the steps to stop the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "stop"
```

1. Check Alteryx Service status;
2. If it is not already stopped, stop Alteryx Service;
3. Check if the service stopped properly.

### Restart

Restart the service powering the Alteryx application.

Below are the steps to restart the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "restart"
```

1. Stop Alteryx Service;
2. Start Alteryx Service.

### Ping

Check the status of the service powering the Alteryx application and the connectivity to the Gallery.

Below are the steps to ping the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "ping"
```

1. Check that the Alteryx Service is running;
2. Check the HTTP status of the Gallery.

### Open

Open the user interface of the Alteryx application.

Below are the steps to open the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "open"
```

- Server: open the Gallery using the default web-browser;
- Designer: open the GUI.

## Logs

Transcript log files are generated in the log directory of the script.

- The naming convention of the transcript log file is: `<Timestamp>_<Action>-Alteryx.log`
- The format of the log is: `<Timestamp>\t<Message type>\t<Message>`

Additional log files are generated by [InstallAware](https://www.installaware.com/) during the installation, upgrade, or uninstallation of Alteryx as an XML file in the same log directory. Those are disabled by default because of the negative impact on the speed of execution, but they can be enabled by setting the configuration variable `InstallAwareLog` to `true`.

The naming convention of the InstallAware log file is: `<Timestamp>_<Setup.exe>.log`

Below is an example of a successful installation log:

```log
2021-11-15 10:09:36	INFO	Installation of Alteryx Server 2021.3.3.63061
2021-11-15 10:09:36	INFO	Installing Alteryx Server
2021-11-15 10:34:14	CHECK	Alteryx Server installed successfully
2021-11-15 10:34:14	WARN	Do not forget to configure system settings
2021-11-15 10:34:14	INFO	Installing Predictive Tools
2021-11-15 10:36:45	CHECK	Predictive Tools installed successfully
2021-11-15 10:36:45	INFO	Installing Intelligence Suite
2021-11-15 10:49:36	CHECK	Intelligence Suite installed successfully
2021-11-15 10:49:36	INFO	Activating Alteryx license
2021-11-15 10:49:36	INFO	Checking licensing system connectivity
2021-11-15 10:49:54	CHECK	3 licenses were successfully activated
2021-11-15 10:49:54	CHECK	Alteryx Server 2021.3.3.63061 installed successfully
```

## Dependencies

This module depends on the usage of functions provided by two PowerShell modules:

1. PowerShell Tool Kit ([PSTK]) module (version 1.2.6);
2. Alteryx PowerShell ([PSAYX]) module (version 1.1.1).

## Compatibility

Below are listed the compatible versions for each of the release.

Only the first version supported is listed. Later releases should also be compatible as long as no breaking change has been introduced. Please refer to the [Alteryx release notes](https://help.alteryx.com/release-notes) for more information.

| `alteryx-deploy` | Alteryx  | PowerShell | [PSTK] | [PSAYX] |
| ---------------- | -------- | ---------- | ------ | ------- |
| [1.0.0]          | [2021.3] | 5.0        | 1.2.4  | 1.0.0   |
| [1.1.0]          | [2021.3] | 5.0        | 1.2.5  | 1.0.1   |
| [1.1.1]          | [2021.3] | 5.0        | 1.2.5  | 1.0.1   |
| [1.1.2]          | [2021.3] | 5.0        | 1.2.5  | 1.0.1   |
| [2.0.0]          | [2024.1] | 5.1        | 1.2.6  | 1.1.1   |
| [2.0.1]          | [2024.2] | 5.1        | 1.2.6  | 1.1.1   |

## Known issues

Below are listed known issues that might occur depending on your environment.

Please report any new problem using the [GitHub repository issue page](https://github.com/Akaizoku/alteryx-deploy/issues).

### Access to the cloud file is denied

This error can occur during the backup of the application when [OneDrive](https://docs.microsoft.com/en-us/onedrive/one-drive-sync) is installed and is synchronising the temporary backup files while the script attempts to remove them (see [PowerShell issue #9246](https://github.com/PowerShell/PowerShell/issues/9246) for more information).

This has no impact on the backup process and only affects temporary files used to generate the backup archive.

> 2021-11-21 02:12:55     INFO    Remove staging backup folder
> 2021-11-21 02:12:55     ERROR   Access to the cloud file is denied

It can be prevented by configuring a temporary directory (`TempDirectory`) that is not synchronised by OneDrive. Temporary files can also be removed manually.

### Transcript is not stopped

It appears that in some environments, the transcript it not stopped as expected when exiting the script.

If this occurs, simply run the command [`Stop-Transcript`](https://learn.microsoft.com/en-us/powershell/module/Microsoft.PowerShell.Host/Stop-Transcript) or [`Stop-AllTranscripts`](https://github.com/Akaizoku/PSTK/blob/main/Public/Stop-AllTranscripts.ps1).

<!-- Links -->
[PSTK]: https://www.powershellgallery.com/packages/PSTK
[PSAYX]:https://www.powershellgallery.com/packages/PSAYX
[1.0.0]:https://github.com/Akaizoku/alteryx-deploy/releases/1.0.0
[1.1.0]:https://github.com/Akaizoku/alteryx-deploy/releases/1.1.0
[1.1.1]:https://github.com/Akaizoku/alteryx-deploy/releases/1.1.1
[1.1.2]:https://github.com/Akaizoku/alteryx-deploy/releases/1.1.2
[2.0.0]:https://github.com/Akaizoku/alteryx-deploy/releases/2.0.0
[2021.3]:https://help.alteryx.com/release-notes/server/server-20213-release-notes
[2024.1]:https://help.alteryx.com/release-notes/en/release-notes/server-release-notes/server-2024-1-release-notes.html
[2024.2]:https://help.alteryx.com/release-notes/en/release-notes/server-release-notes/server-2024-2-release-notes.html
[whitelist.alteryx.com]:(whitelist.alteryx.com)
