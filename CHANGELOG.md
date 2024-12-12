# Changelog

All notable changes to the [`alteryx-deploy`](https://github.com/Akaizoku/alteryx-deploy) utility will be documented in this file. Roadmap and backlog are documented in the corresponding [GitHub project](https://github.com/users/Akaizoku/projects/4).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.2](https://github.com/Akaizoku/alteryx-deploy/releases/2.0.2) - 2024-12-12

Error handling

### Fixed

- Invoke-DownloadAlteryx: Fixed an issue with expired license API refresh token causing the script to error ([#39](https://github.com/Akaizoku/alteryx-deploy/issues/39))
- Invoke-SetupScript: Fixed an issue with invalid or corrupted encrypted key or license files causing the script to error ([#40](https://github.com/Akaizoku/alteryx-deploy/issues/40))

## [2.0.1](https://github.com/Akaizoku/alteryx-deploy/releases/2.0.1) - 2024-10-20

Fix key encryption and decryption issues.

### Fixed

- Fixed an issue with license API token and keys encryption during setup ([#36](https://github.com/Akaizoku/alteryx-deploy/issues/36))
- Fixed an issue with license API token and keys decryption during download ([#36](https://github.com/Akaizoku/alteryx-deploy/issues/36))
- Fixed an issue when license keys decryption during activation ([#36](https://github.com/Akaizoku/alteryx-deploy/issues/36))
- Fixed an issue when license keys decryption during deactivation ([#36](https://github.com/Akaizoku/alteryx-deploy/issues/36))
- Fixed an issue when attempting to redownload an existing major version without any patch available

## [2.0.0](https://github.com/Akaizoku/alteryx-deploy/releases/2.0.0) - 2024-10-08

Complete revamp to provide support for new installers (2022.3+), license portal API, as well as guardrails and usefull error handling.

### Added

- Invoke-DownloadAlteryx: Fetch releases from the Alteryx license portal
- Invoke-PatchAlteryx: Install patch upgrades
- Invoke-PingAlteryx: Check Server UI (Gallery) connectivity
- Invoke-RollbackAlteryx: Rollback to previous known stable state
- Invoke-SetupScript: Script configuration wizard
- Open-Alteryx: Open Alteryx (G)UI
- Repair-Alteryx: Repair embedded MongoDB database
- Set-AlteryxConfiguration: Configure Alteryx system settings
- Show-Help: Display script help documentation

### Changed

- Invoke-ActivateAlteryx: Improve process robustness
- Invoke-BackupAlteryx: Improve process robustness
- Invoke-DeactivateAlteryx: Deactivate licenses one-by-one
- Invoke-RestartAlteryx: Improve process robustness
- Invoke-RestoreAlteryx: Redesign process to improve robustness
- Invoke-StartAlteryx: Improve process robustness
- Invoke-StopAlteryx: Improve process robustness
- Uninstall-Alteryx: Improve process robustness
- Update-Alteryx: Add rollback in case of failure
- Various changes were made to configuration files, including encryption of sensitive information; Please use the `setup` command to configure the scripts.

## [1.1.2](https://github.com/Akaizoku/alteryx-deploy/releases/1.1.2) - 2021-12-13

UX improvements

### Changed

- Automatically update environment variables during restore (installation path, Gallery URL, etc.)

### Fixed

- Fixed an issue when the license email was not specified ([#4](https://github.com/Akaizoku/alteryx-deploy/issues/4))
- Fixed an issue when the license email was not specified and the Active Directory server was unreachable ([#5](https://github.com/Akaizoku/alteryx-deploy/issues/5))
- Fixed an issue preventing the restoration on a different machine ([#8](https://github.com/Akaizoku/alteryx-deploy/issues/8))

## [1.1.1](https://github.com/Akaizoku/alteryx-deploy/releases/1.1.1) - 2021-11-23

### Changed

- Updated default sources location

### Fixed

- Fixed an issue with upgrade from 2021.3 (or lower) to 2021.4 ([#2](https://github.com/Akaizoku/alteryx-deploy/issues/2))

## [1.1.0](https://github.com/Akaizoku/alteryx-deploy/releases/1.1.0) - 2021-11-21

2021.4 hotfix

### Added

- `Invoke-StartAlteryx` now checks for release version to ensure compatibility
- Check connectivity to licensing system
- Disable Alteryx license action
- Disable Alteryx license(s) during uninstallation
- License key parameter

### Changed

- Disabled InstallAware logging by default to improve performances
- Improved documentation

### Fixed

- Fix conflict with version parameter and PowerShell modules versions
- Fix `Get-AlteryxUtility` function call following refactoring of [PSAYX](https://github.com/Akaizoku/PSAYX)

## [1.0.0](https://github.com/Akaizoku/alteryx-deploy/releases/1.0.0) - 2021-09-20

Minimum viable product (MVP) release for the Alteryx automated deployment utility.

### Added

The following functions have been added:

- Install-Alteryx
- Invoke-ActivateAlteryx
- Invoke-BackupAlteryx
- Invoke-RestartAlteryx
- Invoke-RestoreAlteryx
- Invoke-StartAlteryx
- Invoke-StopAlteryx
- Show-Configuration
- Uninstall-Alteryx
- Update-Alteryx

The following files have been added:

- LICENSE
- README.md
