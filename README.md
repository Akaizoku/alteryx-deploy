# Alteryx Deploy

Alteryx automated deployment utility.

## Table of contents <!-- omit in toc -->

- [Usage](#usage)
- [Process](#process)
  - [Installation](#installation)
  - [Upgrade](#upgrade)
  - [Uninstallation](#uninstallation)
  - [Activate](#activate)
  - [Backup](#backup)
  - [Restore](#restore)
  - [Start](#start)
  - [Stop](#stop)
  - [Restart](#restart)
- [Dependencies](#dependencies)

## Usage

1. Check the `default.ini` configuration file located under the `conf` folder;
2. If needed, add custom configuration to the `custom.ini` configuration file in the same configuration folder;
3. Update the installation configuration in the file `install.ini`;
4. Run the `Deploy-Alteryx.ps1` script with the corresponding action parameter;
   - backup:    backup the Alteryx application database
   - configure: configure the Alteryx application
   - install:   install the Alteryx application
   - restart:   restart the Alteryx application
   - restore:   restore a backup of the Alteryx application database
   - show:      display the script configuration
   - start:     start the Alteryx application
   - stop:      stop the Alteryx application
   - uninstall: uninstall the Alteryx application
   - upgrade:   upgrade the Alteryx application
5. Check the logs.

## Process

Below are the execution steps of the `Deploy-Alteryx.ps1` script.

### Installation

Below are the steps to install the Alteryx application.

```powershell
Deploy-Alteryx.ps1 -action "install"
```

1. Install Alteryx Server (or Designer if specified with the `-Product` parameter;
2. Install Predictive Tools (if enabled);
3. Install Intelligence Suite (if enabled);
4. Install Data packages (if enabled).

### Upgrade

Below are the steps to upgrade the Alteryx application.

```powershell
Deploy-Alteryx.ps1 -action "upgrade"
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
Deploy-Alteryx.ps1 -action "uninstall"
```

1. Uninstall Alteryx Server (or Designer if specified with the `-Product` parameter.

**Warnings:**

1. The uninstallation process requires the original installation executable file.
2. The uninstallation of Alteryx Server does also remove all dependencies such as Precdictive Tools, Intelligence Suite, etc.

### Activate

Below are the steps to activate (license) the Alteryx application.

```powershell
Deploy-Alteryx.ps1 -action "activate"
```

1. Check licensing system connectivity (<whitelist.alteryx.com>);
2. Check license file path;
3. Activate Alteryx application.

### Backup

Below are the steps to backup the Alteryx application database.

```powershell
Deploy-Alteryx.ps1 -action "backup"
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
Deploy-Alteryx.ps1 -action "restore"
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
Deploy-Alteryx.ps1 -action "start"
```

1. Check Alteryx Service status;
2. If it is not already running, start Alteryx Service;
3. Check if the service started properly.

### Stop

Below are the steps to stop the Alteryx application.

```powershell
Deploy-Alteryx.ps1 -action "stop"
```

1. Check Alteryx Service status;
2. If it is not already stopped, stop Alteryx Service;
3. Check if the service stopped properly.

### Restart

Below are the steps to restart the Alteryx application.

```powershell
Deploy-Alteryx.ps1 -action "restart"
```

1. Stop Alteryx Service;
2. Start Alteryx Service.

## Dependencies

This module depends on the usage of functions provided by two PowerShell modules:

1. [PowerShell Tool Kit (PSTK) module (version 1.2.4)](https://www.powershellgallery.com/packages/PSTK)
2. [Alteryx PowerShell (PSAYX) module (version 1.0.0)](https://www.powershellgallery.com/packages/PSAYX)
