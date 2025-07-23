# Shell Script Utility (shellutil.sh)

A shell script utility inspired by `psutil.ps1` that parses shell scripts for comments and their corresponding commands, providing a GUI interface to run those commands.

## Features

- **Automatic Script Parsing**: Reads shell scripts and extracts tasks from comments and following commands
- **GUI Interface**: Uses zenity for a user-friendly graphical interface
- **Task Selection**: Interactive task selection with checkbox functionality
- **Execution Logging**: Logs all task executions with timestamps
- **Script Discovery**: Automatically finds shell scripts in the current directory
- **Blacklist Support**: Excludes specific scripts from discovery
- **Progress Tracking**: Shows execution progress and status

## Requirements

- **zenity**: Required for GUI functionality
  ```bash
  sudo apt install zenity  # Ubuntu/Debian
  sudo dnf install zenity  # Fedora
  ```

## Installation

1. Make the script executable:
   ```bash
   chmod +x shellutil.sh
   ```

2. Install zenity (if not already installed):
   ```bash
   sudo apt install zenity  # Ubuntu/Debian
   sudo dnf install zenity  # Fedora
   ```

## Usage

### Interactive Mode
```bash
./shellutil.sh
```

### Direct Script Parsing
```bash
./shellutil.sh -f script.sh
```

### Help
```bash
./shellutil.sh -h
```

## Script Format

The utility expects shell scripts to be formatted with comments describing tasks, followed by the commands to execute:

```bash
# Task Description
command to execute

# Another Task Description
another command
multiple lines
of commands

# Third Task
single command
```

### Example Script

```bash
# Install development tools
sudo apt update
sudo apt install -y git vim curl

# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Clone repository
git clone https://github.com/user/repo.git
cd repo
```

## Features Breakdown

### Task Parsing
- Extracts tasks from comments (lines starting with `#`)
- Groups subsequent non-comment lines as the command for that task
- Handles multi-line commands
- Falls back to treating entire file as single task if no comments found

### GUI Interface
- Checkbox-based task selection
- Progress bar during execution
- Dialog boxes for feedback and errors
- User-friendly graphical interface

### Execution and Logging
- Logs all executions to `~/.shellutil/logs/`
- Timestamps for each task execution
- Success/failure status tracking
- Execution history preservation

## Configuration

The script can be configured by modifying the variables at the top:

```bash
# Script file extensions to search for
SCRIPT_EXTENSIONS=("*.sh" "*.bash")

# Scripts to exclude from discovery
SCRIPT_BLACKLIST=("shellutil.sh" "test.sh")

# Data directory for logs and favorites
DATA_DIR="$HOME/.shellutil"
```

## Directory Structure

The utility creates the following directory structure:

```
~/.shellutil/
├── logs/           # Execution logs
├── favorites/      # Saved task lists (future feature)
└── scripts/        # Custom scripts (future feature)
```

## Examples

### Basic Usage
```bash
# Run in interactive mode
./shellutil.sh

# Parse specific script
./shellutil.sh -f setup.sh
```

### Script Examples

**System Setup Script (setup.sh)**:
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git vim

# Configure firewall
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

**Development Environment (dev-setup.sh)**:
```bash
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Python development tools
sudo apt install -y python3-pip python3-venv

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

## Comparison with psutil.ps1

| Feature | psutil.ps1 | shellutil.sh |
|---------|------------|--------------|
| Platform | Windows (PowerShell) | Linux/Unix (Bash) |
| GUI Framework | Windows Forms | zenity |
| Script Parsing | PowerShell comments | Shell script comments |
| Task Execution | PowerShell commands | Shell commands |
| Logging | Built-in | File-based |
| Interface | GUI + Terminal | GUI only |

## Future Enhancements

- [ ] Favorites system for commonly used tasks
- [ ] Remote script execution via SSH
- [ ] Script templates and generators
- [ ] Configuration file support
- [ ] Task scheduling integration
- [ ] Plugin system for extensions
- [ ] Web interface option

## Troubleshooting

### Common Issues

1. **Script not executable**:
   ```bash
   chmod +x shellutil.sh
   ```

2. **GUI mode not working**:
   ```bash
   sudo apt install zenity
   ```

3. **No scripts found**:
   - Ensure shell scripts have `.sh` or `.bash` extensions
   - Check that scripts are not in the blacklist
   - Verify you're running from the correct directory

4. **Permission errors during execution**:
   - Some tasks may require sudo privileges
   - Run individual commands manually to test permissions

## License

This script is inspired by the psutil.ps1 PowerShell utility and adapted for shell scripting environments.
=======
# PSUtil - PowerShell GUI Task Manager

A Windows Forms GUI application for discovering, organizing, and executing PowerShell scripts with support for multiple execution contexts and remote machines.

## Features

### Core Functionality
- **Script Discovery**: Automatically finds .ps1 files in the application directory
- **Task Management**: Parse and organize PowerShell scripts with comment-based task definitions
- **Bulk Operations**: Select and execute multiple tasks at once
- **Real-time Filtering**: Search and filter tasks instantly
- **Favorites System**: Save and organize frequently used task collections

### Execution Modes
- Current User
- Administrator (with UAC elevation)
- Specific User (with credential prompt)
- Remote SSH execution

### User Interface
- Clean Windows Forms interface
- Multi-column task list with sorting
- Filter toolbar with search
- Sidebar for execution settings
- Progress tracking for batch operations
- Status bar with color-coded messages

## Current Status

### Completed
- ✅ Core architecture and plugin system
- ✅ Main UI with ListView and controls
- ✅ Task discovery and parsing
- ✅ Multiple execution modes
- ✅ Favorites management
- ✅ SSH remote execution
- ✅ Batch execution with progress tracking

### Known Issues
- ❌ Missing `ShowSecondaryPanel()` method
- ❌ Missing `HideSecondaryPanel()` method  
- ❌ Missing `OnCloseSecondary()` method
- ❌ Some config property references need validation
- ❌ GitHub integration needs proper setup

### Quick Fixes Needed

Add these missing methods to the main class:

```powershell
[void]ShowSecondaryPanel([string]$title) {
    $this.Controls.SecondaryContent.Visible = $true
    $this.Controls.ContentSplitter.Visible = $true
    $this.Controls.SecondaryLabel.Text = $title
}

[void]HideSecondaryPanel() {
    $this.Controls.SecondaryContent.Visible = $false
    $this.Controls.ContentSplitter.Visible = $false
}

[void]OnCloseSecondary() {
    $this.HideSecondaryPanel()
}
```

## Usage

1. Place PowerShell scripts (.ps1 files) in the application directory
2. Launch PSUtil to automatically discover tasks
3. Use the filter box to search for specific tasks
4. Select execution mode and target machine
5. Choose tasks and click Execute

## Future Enhancements

- Task grouping and categorization
- Execution history logging
- Task templates and dependencies
- Enhanced scheduling options
- Dark mode themes
- Advanced search capabilities

## Technical Notes

- Pure PowerShell implementation
- No external dependencies beyond System.Windows.Forms
- Uses native Windows credential management
- File-based favorites storage in Documents folder
- SSH support for remote execution

---

**Status**: 95% complete - Ready for launch after fixing missing methods
