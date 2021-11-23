# Changelog

All notable changes to the [Alteryx deploy](https://github.com/Akaizoku/alteryx-deploy) project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1](https://github.com/Akaizoku/alteryx-deploy/releases/1.1.1) - 2021-11-23

### Changed

- Updated default sources location

### Fixed

- Fixed an issue with upgrade from 2021.3 (or lower) to 2021.4 ([#2](https://github.com/Akaizoku/alteryx-deploy/issues/2))

## [1.1.0](https://github.com/Akaizoku/alteryx-deploy/releases/1.1.0) - 2021-11-21

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
