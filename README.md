# Alteryx Deploy

Alteryx automated deployment utility.

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

## Dependencies

This module depends on the usage of functions provided by two PowerShell modules:

1. [PowerShell Tool Kit (PSTK) module (version 1.2.4)](https://www.powershellgallery.com/packages/PSTK)
2. [Alteryx PowerShell (PSAYX) module (version 1.0.0)](https://www.powershellgallery.com/packages/PSAYX)
