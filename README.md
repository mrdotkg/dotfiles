# LMDT - Let me do this!

A comprehensive PowerShell application for managing and automating system configuration tasks with advanced scheduling capabilities.

## 🚀 Key Features

### ✅ Core Task Management (Complete)
- **Task Discovery**: Automatically scans PowerShell scripts for executable tasks
- **Multi-Selection**: Check/uncheck individual tasks or use "Select All"
- **Filtering**: Real-time search through task descriptions
- **Execution Control**: Run tasks immediately or schedule for later
- **Progress Tracking**: Real-time execution status with progress bars

### ✅ Advanced Scheduling System (Complete)
- **Flexible Scheduling**: Schedule tasks to run once, daily, weekly, monthly, or yearly
- **Date/Time Picker**: Intuitive calendar and time selection interface
- **Windows Task Scheduler Integration**: Creates proper scheduled tasks in Windows
- **Schedule Management**: View, monitor, and manage all scheduled LMDT tasks
- **Task Feedback**: Success messages with action buttons for task management
- **Schedule Results**: Clear status feedback with "View Tasks" and "Clear" options

### ✅ Template System (Complete)
- **Template Creation**: Create reusable task collections from selected tasks
- **Template Storage**: Save templates in Templates directory with metadata
- **Default Templates**: Pre-built templates (Developer Environment, Windows 11 Debloat, Content Creator)
- **Template Loading**: Quick access to saved templates via dropdown
- **Template Management**: Edit and organize template collections

### ✅ Keyboard Shortcuts (Complete)
- **Ctrl+A**: Select all tasks
- **F5**: Refresh current view
- **Ctrl+E / F9**: Execute selected tasks
- **Escape**: Cancel execution or clear filters/selections
- **Ctrl+F**: Focus filter box
- **Ctrl+R**: Retry failed tasks
- **Ctrl+D**: Clear results
- **Ctrl+T**: Create template from selected tasks
- **F1**: Toggle sidebar
- **Ctrl+C**: Copy command (when ListView focused)
- **Delete**: Clear selected items
- **Space**: Toggle checked state of selected items

### ✅ GitHub Integration (Complete)
- **Remote Repository Scanning**: Discover scripts from GitHub repositories
- **Automatic Detection**: Seamlessly switch between local and remote execution
- **GitHub API Integration**: Browse and execute scripts from remote repositories
- **Multi-Source Support**: Local files, templates, and remote repositories

### ✅ User Interface (Complete)
- **Modern Layout**: Clean, intuitive Windows Forms interface
- **Dynamic Status Bar**: Context-sensitive controls and feedback
- **Sidebar Panel**: Quick access to execution options and utilities
- **Column Management**: Show/hide columns and reorder as needed
- **Drag & Drop**: Reorder tasks within the list view

## 🔧 How to Use

### Basic Task Execution
1. **Launch LMDT**: Run `.\LMDT.ps1` in PowerShell
2. **Browse Tasks**: View available tasks in the main list
3. **Select Tasks**: Check the boxes next to tasks you want to run
4. **Execute**: Click "Execute" button or press Ctrl+E

### Schedule Tasks for Later
1. **Select Tasks**: Choose one or more tasks from the list
2. **Click "More"**: Open the sidebar panel (or press F1)
3. **Click "Run Later"**: Open the scheduling interface
4. **Set Schedule**: Choose date, time, and repeat frequency
5. **Click "Schedule"**: Create the scheduled task
6. **Manage Tasks**: Use "View Tasks" to open Task Scheduler and monitor

### Create Templates
1. **Select Tasks**: Choose tasks you want in the template
2. **Create Template**: Press Ctrl+T or click "Create Template"
3. **Name Template**: Enter a descriptive name
4. **Save**: Template is saved and available in the source dropdown

### Find Scheduled Tasks
- **In LMDT**: Click "View Tasks" button after scheduling
- **Task Scheduler**: Press Win+R, type `taskschd.msc`, look for tasks starting with "LMDT_"
- **PowerShell**: Run `Get-ScheduledTask -TaskName "LMDT_*"`

## 📁 Project Structure

```
LMDT/
├── LMDT.ps1              # Main application file
├── gui.ps1               # GUI helper functions
├── db.json               # Configuration database
├── README.md             # This file
├── Config/               # Configuration files
│   ├── Powershell/       # PowerShell profiles and scripts
│   ├── starship/         # Starship prompt configuration
│   └── wezterm/          # Terminal configuration
├── Scripts/              # Deployment scripts
│   ├── win11.ps1         # Windows 11 configuration tasks
│   └── linuxmint.sh      # Linux Mint setup scripts
└── Templates/            # User-created task templates
    ├── Developer Environment.txt
    ├── Windows 11 Debloat.txt
    └── Content Creator Setup.txt
```

## ⚠️ Remaining Features to Implement

### 🎨 Theme System (Framework exists, needs implementation)
- **Theme Toggle**: UI button and keyboard shortcut for dark/light mode
- **Theme Application**: Logic to apply themes to interface elements
- **Theme Persistence**: Save user's theme preference

### 🔌 Plugin System (Architecture ready, needs plugins)
- **Plugin Loading**: Mechanism to load external plugins
- **Plugin Management**: UI for enabling/disabling plugins
- **Plugin API**: Documentation for creating custom plugins

### 🌐 Community Features (Future enhancement)
- **Template Sharing**: Export/import templates
- **Community Templates**: Browse and download community-created templates
- **GitHub Integration**: Submit templates back to repository

### 🔧 System Integration (Partial)
- **Installer**: Create desktop shortcuts and Start Menu entries
- **Notifications**: Windows toast notifications for completed tasks
- **Auto-updates**: Check for application updates

## 🎯 Current Status: ~90% Feature Complete!

The core functionality is robust and production-ready. The advanced scheduling system is fully implemented with proper Windows Task Scheduler integration. The application provides excellent user experience with comprehensive keyboard shortcuts, template management, and multi-source task execution.

**Key Achievement**: ✅ **Advanced Scheduling System Complete** - Full Windows Task Scheduler integration with flexible scheduling options and management interface.

## 🚀 Quick Start

```powershell
# Clone the repository
git clone https://github.com/mrdotkg/dotfiles.git
cd dotfiles

# Run LMDT - Let me do this!
.\LMDT.ps1

# Try scheduling a task:
# 1. Select a task from the list
# 2. Click "More" to open sidebar  
# 3. Click "Run Later"
# 4. Set your preferred date/time
# 5. Choose repeat frequency
# 6. Click "Schedule"
# 7. Use "View Tasks" to manage in Task Scheduler
```

## 📝 Notes

- **Windows Only**: Currently designed for Windows PowerShell environments
- **Admin Rights**: Some tasks may require elevated privileges
- **Task Scheduler**: Scheduled tasks integrate with Windows Task Scheduler
- **Templates**: All templates are stored as plain text files for easy editing

## 🏆 Development Achievements

### Recently Completed ✅
- **Advanced Task Scheduling**: Complete Windows Task Scheduler integration
- **Scheduling UI**: Intuitive date/time picker with repeat options
- **Task Management**: View and manage scheduled tasks from within LMDT
- **Error Handling**: Robust error handling for scheduling operations
- **Status Feedback**: Clear success/failure messaging with action buttons

### Technical Highlights 🔧
- **Clean Architecture**: Separation of scheduling logic and UI concerns
- **State Management**: Proper cleanup of UI controls and state
- **Integration**: Seamless Windows Task Scheduler API integration
- **User Experience**: Context-sensitive status bar with dynamic controls
- **Debugging**: Comprehensive debug logging for troubleshooting

The LMDT application now provides enterprise-grade task scheduling capabilities while maintaining ease of use for everyday automation tasks.