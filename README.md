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
