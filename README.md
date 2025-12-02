# Temurin LTS JDK Manager

A modern Windows GUI application for managing Eclipse Temurin LTS Java Development Kits via winget.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Install/Upgrade** Eclipse Temurin LTS JDK versions (8, 11, 17, 21, 25)
- **Uninstall** JDK versions with confirmation
- **Set Default JDK** - Automatically configures `JAVA_HOME` and `PATH`
- **Install All Missing** - Batch install all LTS versions not yet installed
- **Modern Dark UI** - Clean, modern interface with Catppuccin-inspired theme
- **Keyboard Shortcuts** - F5 (Refresh), Ctrl+I (Install), Ctrl+U (Uninstall), Ctrl+D (Set Default)
- **Context Menu** - Right-click for quick actions
- **Logging** - All operations logged to `manager.log`

## Screenshots

The application features a modern dark theme with:
- Version badges showing JDK major version
- Status indicators (Installed/Not Installed)
- Default JDK badge
- Progress bar with percentage
- winget status indicator

## Requirements

- Windows 10/11
- [winget](https://docs.microsoft.com/en-us/windows/package-manager/winget/) (App Installer from Microsoft Store)
- PowerShell 5.1+ (for running the script)
- PowerShell 7+ (for building the EXE)

## Installation

### Option 1: Download the EXE (Recommended)
Download `TemurinLTS-Manager.exe` from the [Releases](../../releases) page and run it.

### Option 2: Run the PowerShell Script
```powershell
.\TemurinLTS-GUI.ps1
```

## Building from Source

### Prerequisites
- PowerShell 7 (`pwsh`)
- PS2EXE module (auto-installed by build script)

### Build Commands

**Using the batch file:**
```cmd
Build-TemurinGUI.bat
```

**Using PowerShell:**
```powershell
pwsh -File Build-TemurinGUI.ps1
```

**Build options:**
```powershell
# Default build (no console window)
pwsh -File Build-TemurinGUI.ps1

# Build with console window (for debugging)
pwsh -File Build-TemurinGUI.ps1 -NoConsole:$false

# Build requiring admin privileges
pwsh -File Build-TemurinGUI.ps1 -RequireAdmin
```

### Custom Icon
Place a file named `temurin.ico` in the project directory before building to use a custom icon.

## Usage

1. **Launch** the application
2. **Select** a JDK version from the list
3. **Install** - Click "Install / Upgrade" or press Ctrl+I
4. **Set Default** - Click "Set as Default" or press Ctrl+D (or double-click)
5. **Uninstall** - Click "Uninstall" or press Ctrl+U

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| F5 | Refresh JDK list |
| Ctrl+I | Install/Upgrade selected |
| Ctrl+U | Uninstall selected |
| Ctrl+D | Set selected as default |
| Double-click | Set as default (if installed) |

## File Locations

| Item | Location |
|------|----------|
| JDK Installations | `%USERPROFILE%\GravvlJDK\Temurin\{version}` |
| Default JDK Config | `%USERPROFILE%\GravvlJDK\Temurin\default_jdk.txt` |
| Log File | `%USERPROFILE%\GravvlJDK\Temurin\manager.log` |

## How It Works

1. Uses **winget** to install Eclipse Temurin JDKs to a custom location
2. Manages **JAVA_HOME** and **PATH** environment variables (User scope)
3. Tracks the default JDK selection in a config file
4. Runs winget operations in the background to keep the UI responsive

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- [Eclipse Temurin](https://adoptium.net/) - High-quality Java runtimes
- [PS2EXE](https://github.com/MScholtes/PS2EXE) - PowerShell to EXE compiler
- [Catppuccin](https://github.com/catppuccin/catppuccin) - Color palette inspiration
