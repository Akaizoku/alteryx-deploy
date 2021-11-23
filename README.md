# Alteryx Deploy

[![PSScriptAnalyzer](https://github.com/Akaizoku/alteryx-deploy/actions/workflows/scan.yml/badge.svg?branch=main)](https://github.com/Akaizoku/alteryx-deploy/actions/workflows/scan.yml)

`alteryx-deploy` is a small PowerShell utility for the automation of the deployment and maintenance of Alteryx.

## Table of contents <!-- omit in toc -->

1. [Usage](#usage)
2. [Pre-requisites](#pre-requisites)
   1. [Permissions](#permissions)
   2. [PowerShell version](#powershell-version)
   3. [PowerShell Modules](#powershell-modules)
   4. [Alteryx](#alteryx)
3. [Configuration](#configuration)
   1. [Script configuration](#script-configuration)
   2. [Installation configuration](#installation-configuration)
4. [Parameters](#parameters)
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
5. [Process](#process)
   1. [Installation](#installation)
   2. [Upgrade](#upgrade)
   3. [Uninstallation](#uninstallation)
   4. [Activation](#activation)
   5. [Deactivation](#deactivation)
   6. [Backup](#backup)
   7. [Restore](#restore)
   8. [Start](#start)
   9. [Stop](#stop)
   10. [Restart](#restart)
6. [Logs](#logs)
7. [Dependencies](#dependencies)
8. [Compatibility](#compatibility)
9. [Known issues](#known-issues)
   1. [Access to the cloud file is denied](#access-to-the-cloud-file-is-denied)

## Usage

1. Check the `default.ini` configuration file located under the `conf` folder;
2. If needed, add custom configuration to the `custom.ini` configuration file in the same configuration folder;
3. Update the installation configuration in the file `install.ini`;
4. Run the `Deploy-Alteryx.ps1` script with the corresponding action parameter;
   - activate:     activate the Alteryx application license
   - backup:       backup the Alteryx application database
   - deactivate:   deactivate the Alteryx application license
   - install:      install the Alteryx application
   - restart:      restart the Alteryx application
   - restore:      restore a backup of the Alteryx application database
   - show:         display the script configuration
   - start:        start the Alteryx application
   - stop:         stop the Alteryx application
   - uninstall:    uninstall the Alteryx application
   - upgrade:      upgrade the Alteryx application
5. Check the logs.

## Pre-requisites

### Permissions

This script requires administrator rights to be run.

### PowerShell version

This script requires [PowerShell version 5.0](https://docs.microsoft.com/en-us/powershell/scripting/windows-powershell/whats-new/what-s-new-in-windows-powershell-50) or later to be run.

### PowerShell Modules

This script makes use of functions from the PowerShell Tool Kit ([PSTK]) module and Alteryx PowerShell ([PSAYX]) module as described in the [dependencies section](#dependencies).

The modules must be [installed](https://docs.microsoft.com/en-us/powershell/module/powershellget/install-module) on the local machine, or placed in the `lib` folder at the root of the script directory.

Example script structure with embedded dependencies:

```cmd
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

You can download them from <https://downloads.alteryx.com>.

Please refer to [Alteryx system requirements](https://help.alteryx.com/20213/server/system-requirements) for minimum machine requirements.

## Configuration

### Script configuration

The default configuration of the utility is stored into `default.ini`. This file should not be amended. All custom configuration must be made in the `custom.ini` file. Any customisation done in that file will override the default values.

Below is an example of custom configuration file:

```ini
[Paths]
# Sources directory
SrcDirectory        = D:\Alteryx\Sources
# Alteryx installation directory
InstallationPath    = D:\Alteryx\Server
# Backup directory
BackupDirectory     = D:\Alteryx\Server\backup
# Data packages installation directory
DataPackagesPath    = D:\Alteryx\Data
```

### Installation configuration

To configure which products should be installed, edit the `install.ini` configuration file located in the `conf` directory.

Below is an example of installation configuration file:

```ini
[Installation]
Server              = true
PredictiveTools     = true
IntelligenceSuite   = true
DataPackages        = false
```

## Parameters

In addition to the configuration files presented above, parameters will define the operation performed during the execution.

### Mandatory

This section lists the mandatory parameters that must be specified to run the script.

#### Action

The `Action` parameter corresponds to the operation to perform.

Eleven options are available:

- activate:     activate the Alteryx application license
- backup:       backup the Alteryx application database
- deactivate:   deactivate the Alteryx application license
- install:      install the Alteryx application
- restart:      restart the Alteryx application
- restore:      restore a backup of the Alteryx application database
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

### Installation

Below are the steps to install the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "install"
```

1. Install Alteryx Server (or Designer if specified with the `-Product` parameter;
2. Install Predictive Tools (if enabled);
3. Install Intelligence Suite (if enabled);
4. Install Data packages (if enabled).

### Upgrade

Below are the steps to upgrade the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "upgrade"
```

1. Backup Alteryx database and configuration files;
2. Upgrade Alteryx Server (or Designer if specified with the `-Product` parameter;
3. Install Predictive Tools (if enabled);
4. Install Intelligence Suite (if enabled);
5. Install Data packages (if enabled);
6. Check installation status and rollback if errors occurred.

### Uninstallation

Below are the steps to uninstall the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "uninstall"
```

1. Uninstall Alteryx Server (or Designer if specified with the `-Product` parameter.

**Warnings:**

1. The uninstallation process requires the original installation executable file.
2. The uninstallation of Alteryx Server does also remove all dependencies such as Precdictive Tools, Intelligence Suite, etc.

### Activation

Below are the steps to activate (license) the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "activate"
```

1. Check licensing system connectivity (<whitelist.alteryx.com>);
2. Check license file path;
3. Activate Alteryx licenses.

### Deactivation

Below are the steps to deactivate (license) the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "deactivate"
```

1. Check licensing system connectivity (<whitelist.alteryx.com>);
2. Check license file path;
3. Deactivate Alteryx licenses.

### Backup

Below are the steps to backup the Alteryx application database.

```powershell
.\Deploy-Alteryx.ps1 -Action "backup"
```

1. Check Alteryx Service status and stop it if it is running;
2. Create database dump;
3. Create copy of application configuration files;
4. Backup controller token;
5. Compress all backup files;
6. Restart Alteryx Service (if it was running previously).

### Restore

Below are the steps to restore the Alteryx application database.

```powershell
.\Deploy-Alteryx.ps1 -Action "restore"
```

1. Check Alteryx Service status and stop it if it is running;
2. Check backup path;
   - If backup file is an archive (.ZIP), extract files from archive.
   - If backup path is a directory, select most recent backup file (using [last write time](https://docs.microsoft.com/en-us/dotnet/api/system.io.filesysteminfo.lastwritetime)).
3. Restore MongoDB database;
4. Restore application configuration files;
5. Restore controller token;
6. Reset storage keys;
7. Restart Alteryx Service (if it was running previously).

### Start

Below are the steps to start the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "start"
```

1. Check Alteryx Service status;
2. If it is not already running, start Alteryx Service;
3. Check if the service started properly.

### Stop

Below are the steps to stop the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "stop"
```

1. Check Alteryx Service status;
2. If it is not already stopped, stop Alteryx Service;
3. Check if the service stopped properly.

### Restart

Below are the steps to restart the Alteryx application.

```powershell
.\Deploy-Alteryx.ps1 -Action "restart"
```

1. Stop Alteryx Service;
2. Start Alteryx Service.

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

1. PowerShell Tool Kit ([PSTK]) module (version 1.2.5)
2. Alteryx PowerShell ([PSAYX]) module (version 1.0.1)

## Compatibility

Below are listed the compatible versions for each of the release.

Only the first version supported is listed. Later releases should also be compatible as long as no breaking change has been introduced. Please refer to the [Alteryx release notes](https://help.alteryx.com/release-notes) for more information.

| `alteryx-deploy` | Alteryx  | PowerShell | [PSTK] | [PSAYX] |
| ---------------- | -------- | ---------- | ------ | ------- |
| [1.0.0]          | [2021.3] | 5.0        | 1.2.4  | 1.0.0   |
| [1.1.0]          | [2021.3] | 5.0        | 1.2.5  | 1.0.1   |
| [1.1.1]          | [2021.3] | 5.0        | 1.2.5  | 1.0.1   |

## Known issues

### Access to the cloud file is denied

This error can occur during the backup of the application when [OneDrive](https://docs.microsoft.com/en-us/onedrive/one-drive-sync) is installed and is synchronising the temporary backup files while the script attempts to remove them (see [PowerShell issue #9246](https://github.com/PowerShell/PowerShell/issues/9246) for more information).

This has no impact on the backup process and only affects temporary files used to generate the backup archive.

> 2021-11-21 02:12:55     INFO    Remove staging backup folder
>
> 2021-11-21 02:12:55     ERROR   Access to the cloud file is denied

It can be prevented by configuring a temporary directory (`TempDirectory`) that is not synchronised by OneDrive. Temporary files can also be removed manually.

<!-- Links -->
[PSTK]: https://www.powershellgallery.com/packages/PSTK
[PSAYX]: https://www.powershellgallery.com/packages/PSAYX
[1.0.0]:https://github.com/Akaizoku/alteryx-deploy/releases/1.0.0
[1.1.0]:https://github.com/Akaizoku/alteryx-deploy/releases/1.1.0
[1.1.1]:https://github.com/Akaizoku/alteryx-deploy/releases/1.1.1
[2021.3]:https://help.alteryx.com/release-notes/server/server-20213-release-notes
