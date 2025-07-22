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