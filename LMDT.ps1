<#
This script is a PowerShell GUI application for managing and executing scripts from a GitHub repository.
Features:
- TODO Submit new templates
- FIXME Write commands to PowerShell history
- FIXME Improve execution UI performance - stuttering
- TODO Enable command scheduling
- TODO Add native system notifications, add tooltips where possible elsewhere show in status panel
- TODO Use %Temp% dir by default, provide option to install locally which means Persist Data in %LocalAppData%, Create Start Menu LMDT.desktop
#>
# Load required assemblies first - MUST be at the very beginning for iex compatibility
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# PowerShell GUI utility for executing scripts

[System.Windows.Forms.Application]::EnableVisualStyles()

# Minimal configuration for PSUtilApp
$Global:Config = @{
    ScriptFilesBlacklist        = @('gui.ps1', 'psutil.ps1', 'taaest.ps1')
    DataDir                     = (Split-Path $PSCommandPath -Parent)  # Use script directory instead of Documents
    SubDirs                     = @('Favourites', 'Logs', 'Scripts', 'Templates')
    SSHConfigPath               = "$env:USERPROFILE\.ssh\config"
    SourceComboAllActionsPrefix = 'All Tasks'
    SourceComboFilePrefix       = '📃 '
    SourceComboFavouritePrefix  = '✨ '
    SourceComboTemplatePrefix   = '📋 '
    ScriptExtensions            = @{
        Local  = @('*.ps1')
        Remote = @('.ps1')
    }
    SourceInfo                  = @{
        BackslashSeparator = '\'
        SlashSeparator     = '/'
        DirectoryTypes     = @{ File = 'file'; Dir = 'dir' }
        ErrorFetchingDir   = 'Error fetching directory: '
    }
    Messages                    = @{
        NoScriptFound      = 'No script files found.'
        GitHubError        = 'Error loading from GitHub: '
        LoadError          = 'Error loading scripts: '
        Ready              = 'Ready'
        Running            = 'Running...'
        Completed          = 'Completed'
        Failed             = 'Failed'
        NoScriptsSelected  = 'Please select at least one task to execute.'
        ExecutionError     = 'Execution error: '
        ExecuteFileDesc    = 'Run entire file: '
        ExecuteAsAdmin     = 'Executed as Administrator.'
        ExecuteAsUser      = 'Executed as user: '
        UserPasswordPrompt = 'Enter password for user: '
        CredentialsPrompt  = 'Enter credentials:'
        CancelledByUser    = 'Cancelled by user.'
        FatalError         = 'Fatal error: '
        FatalErrorTitle    = 'Fatal Error'
        StackTrace         = 'Stack trace: '
    }
    Colors                      = @{
        White     = 'White'
        Running   = 'LightYellow'
        Completed = 'LightGreen'
        Failed    = 'LightCoral'
        Text      = 'Black'
        Filtered  = 'Gray'
    }
    Window                      = @{
        Title           = 'Run -'
        Width           = 700
        Height          = 700
        Padding         = '10,10,10,10'
        Position        = 'CenterScreen'
        BackgroundColor = 'WhiteSmoke'
    }
    Panels                      = @{
        ToolbarHeight       = 40
        ToolbarPadding      = '10,5,10,7'
        StatusBarHeight     = 30
        StatusPadding       = '10,0,2,10'
        SidebarWidth        = 160
        SidebarPadding      = '5,5,5,5'
        SecondaryPanelWidth = 320
        SecondaryPadding    = '5,5,10,5'
        SplitterWidth       = 5
        ContentPadding      = '10,5,10,5'
    }
    Controls                    = @{
        FontName           = 'Segoe UI'
        FontSize           = 10
        Dock               = 'None'
        Width              = 120
        Height             = 30
        Padding            = '2,2,2,2'
        BackColor          = 'White'
        ForeColor          = 'Black'
        SelectAllText      = ''
        FilterPlaceholder  = 'Filter Tasks...'
        RefreshText        = 'Refresh'
        CancelText         = 'Cancel'
        CopyCommandText    = 'Copy To Clipboard'
        RunLaterText       = 'Schedule for Later'
        AddCommandText     = 'Save to a List'
        ExecuteBtnTemplate = '▶ Run ({0})'
    }
    ListView                    = @{
        Columns = @(
            @{ Name = 'Task'; Width = 320 },
            @{ Name = 'Command'; Width = 320 },
            @{ Name = 'File'; Width = 120 },
            @{ Name = 'Status'; Width = 90 }
        )
    }
    Patterns                    = @{
        NewlinePattern = "`r?`n"
        HTTPUrl        = '^https?://'
    }
    Defaults                    = @{
        SSHCommandPrefix  = 'ssh '
        SudoCommand       = 'sudo '
        SudoUserCommand   = 'sudo -u '
        PowerShellCommand = 'powershell.exe'
        RunAsVerb         = 'runas'
        CommandArgument   = '-Command'
        WaitParameter     = '-Wait'
        AdminMode         = 'Admin'
        AdminText         = 'Administrator'
        CurrentUserMode   = 'CurrentUser'
        OtherUserText     = 'Other User'
        RemoteText        = ' (Remote)'
    }
    URLs                        = @{
        GitHubAPI = 'https://api.github.com/repos'
        GitHubRaw = 'https://raw.githubusercontent.com'
    }
    Owner                       = 'mrdotkg'
    Repo                        = 'dotfiles'
    Branch                      = 'main'
}

class PSUtilTaskSource {
    [string]$Name
    [string]$Type
    PSUtilTaskSource([string]$name, [string]$type) {
        $this.Name = $name
        $this.Type = $type
    }
    [array]GetTasks() {
        throw 'GetTasks must be implemented by subclasses'
    }
}

# AllTasksSource: aggregates all ScriptFile tasks
class AllTasksSource : PSUtilTaskSource {
    [PSUtilApp]$App
    AllTasksSource([PSUtilApp]$app) : base($app.Config.SourceComboAllActionsPrefix, "AllTasks") {
        $this.App = $app
    }
    [array]GetTasks() {
        $allTasks = @()
        foreach ($src in $this.App.Sources | Where-Object { $_.Type -eq "ScriptFile" }) {
            if ($src -is [PSUtilTaskSource]) {
                $allTasks += $src.GetTasks()
            }
        }
        return $allTasks
    }
}

# TemplateSource: represents a template file
class TemplateSource : PSUtilTaskSource {
    [PSUtilApp]$App
    [string]$TemplateName
    TemplateSource([PSUtilApp]$app, [string]$templateName) : base($templateName, "Template") {
        $this.App = $app
        $this.TemplateName = $templateName
    }
    [array]GetTasks() {
        $templatePath = Join-Path (Join-Path $this.App.Config.DataDir "Templates") ("$($this.TemplateName).txt")
        if (Test-Path $templatePath) {
            $grouped = $this.App.ReadGroupedProfile($templatePath)
            $tasks = @()
            foreach ($group in $grouped.Keys) {
                $tasks += $grouped[$group]
            }
            return $tasks
        }
        return @()
    }
}

# FavouriteSource: represents a favourite file
class FavouriteSource : PSUtilTaskSource {
    [PSUtilApp]$App
    [string]$FavouriteName
    FavouriteSource([PSUtilApp]$app, [string]$favName) : base($favName, "Favourite") {
        $this.App = $app
        $this.FavouriteName = $favName
    }
    [array]GetTasks() {
        $favPath = Join-Path (Join-Path $this.App.Config.DataDir "Favourites") ("$($this.FavouriteName).txt")
        if (Test-Path $favPath) {
            $grouped = $this.App.ReadGroupedProfile($favPath)
            $tasks = @()
            foreach ($group in $grouped.Keys) {
                $tasks += $grouped[$group]
            }
            return $tasks
        }
        return @()
    }
}

class PSUtilTask {
    [string]$Description
    [string]$Command
    [string]$File
    [int]$LineNumber
    PSUtilTask([string]$desc, [string]$cmd, [string]$file, [int]$line) {
        $this.Description = $desc
        $this.Command = $cmd
        $this.File = $file
        $this.LineNumber = $line
    }
}


# LocalScriptFileSource: represents a single script file as a source
class LocalScriptFileSource : PSUtilTaskSource {
    [PSUtilApp]$App
    [string]$FilePath
    [string]$RelativePath
    LocalScriptFileSource([PSUtilApp]$app, [string]$filePath, [string]$relativePath) : base($relativePath, "ScriptFile") {
        $this.App = $app
        $this.FilePath = $filePath
        $this.RelativePath = $relativePath
    }
    [array]GetTasks() {
        $scriptContent = $null
        
        # Try local file first (only if it's a real local path)
        if ($this.FilePath -and (Test-Path $this.FilePath) -and $this.FilePath -notmatch '^https?://') {
            $scriptContent = Get-Content $this.FilePath -Raw
        }
        
        # Fallback to remote GitHub file
        if (!$scriptContent) {
            try {
                $scriptUrl = "$($this.App.Config.URLs.GitHubRaw)/$($this.App.Config.Owner)/$($this.App.Config.Repo)/refs/heads/$($this.App.Config.Branch)/$($this.RelativePath)"
                $scriptContent = (Invoke-WebRequest $scriptUrl -ErrorAction Stop).Content
                Write-Host "[DEBUG] LocalScriptFileSource.GetTasks - Downloaded remote: $($this.RelativePath)" -ForegroundColor Cyan
            }
            catch {
                Write-Warning "[DEBUG] LocalScriptFileSource.GetTasks - Failed to download: $($this.RelativePath) - $_"
                return @()
            }
        }
        
        if ($scriptContent) {
            return $this.App.ParseScriptFile($scriptContent, $this.RelativePath) |
            ForEach-Object { [PSUtilTask]::new($_.Description, $_.Command, $_.File, $_.LineNumber) }
        }
        return @()
    }
}

class PSUtilApp {

    [void]LoadGroupedTasksToListView([hashtable]$groupedTasks) {
        Write-Host "[DEBUG] LoadGroupedTasksToListView $($groupedTasks.Count) groups"
        $this.Controls.ScriptsListView.Items.Clear()
        $this.Controls.ScriptsListView.Groups.Clear()
        foreach ($groupName in $groupedTasks.Keys) {
            $group = New-Object System.Windows.Forms.ListViewGroup($groupName)
            $this.Controls.ScriptsListView.Groups.Add($group) | Out-Null
            foreach ($task in $groupedTasks[$groupName]) {
                $item = New-Object System.Windows.Forms.ListViewItem($task.Description)
                $item.SubItems.Add($task.Command) | Out-Null
                $item.SubItems.Add($task.File) | Out-Null
                $item.SubItems.Add($this.Config.Messages.Ready) | Out-Null
                $item.Tag = $task
                $item.Group = $group
                $this.Controls.ScriptsListView.Items.Add($item) | Out-Null
            }
        }
        $this.UpdateExecuteButtonText()
    }
    [hashtable]$Config
    [hashtable]$Controls = @{}
    [array]$Machines = @()
    [array]$Sources = @() # List of PSUtilTaskSource
    [array]$Users = @()
    [bool]$IsExecuting
    [string]$ExecutionMode = "CurrentUser"
    $MainForm;
    [hashtable]$Plugins = @{}
    [hashtable]$Theme = @{}
    [hashtable]$I18N = @{}
    [hashtable]$State = @{}
    [hashtable]$TaskCache = @{} # Cache for all parsed tasks for fast template lookup

    # Registry for discoverable sources
    static [hashtable]$SourceRegistry = @{}

    static [void]RegisterSourceType([string]$type, [scriptblock]$factory) {
        [PSUtilApp]::SourceRegistry[$type] = $factory
    }

    [void]LoadSources() {
        $this.Sources = @()
        # Add AllTasksSource
        $this.Sources += [AllTasksSource]::new($this)
        
        # Add Template sources
        $templatesDir = Join-Path $this.Config.DataDir "Templates"
        if (Test-Path $templatesDir) {
            $templateFiles = Get-ChildItem -Path $templatesDir -File | Where-Object { $_.Extension -eq ".txt" }
            foreach ($templateFile in $templateFiles) {
                $displayName = "$($this.Config.SourceComboTemplatePrefix)$($templateFile.BaseName)"
                $templateSource = [TemplateSource]::new($this, $templateFile.BaseName)
                $templateSource.Name = $displayName
                $this.Sources += $templateSource
            }
        }
        
        # Add FavouriteSource for each favourite file (keep for backward compatibility)
        $favouritesDir = Join-Path $this.Config.DataDir "Favourites"
        if (Test-Path $favouritesDir) {
            $favFiles = Get-ChildItem -Path $favouritesDir -File | Where-Object { $_.Extension -eq ".txt" }
            foreach ($favFile in $favFiles) {
                $displayName = "$($this.Config.SourceComboFavouritePrefix)$($favFile.BaseName)"
                $favouriteSource = [FavouriteSource]::new($this, $favFile.BaseName)
                $favouriteSource.Name = $displayName
                $this.Sources += $favouriteSource
            }
        }
        # Add ScriptFile sources from registry
        foreach ($type in [PSUtilApp]::SourceRegistry.Keys) {
            $factory = [PSUtilApp]::SourceRegistry[$type]
            $result = & $factory $this
            if ($result) {
                foreach ($src in $result) {
                    $this.Sources += $src
                }
            }
        }
        # Debug output for loaded sources
        Write-Host ("[DEBUG] Sources after LoadSources: " + ($this.Sources | ForEach-Object { "[Type=$($_.GetType().Name), Name=$($_.Name)]" } | Out-String))
        
        # Rebuild task cache after loading sources
        if ($null -ne $this.TaskCache) {
            $this.BuildTaskCache()
        }
    }

    PSUtilApp() {
        Write-Host "[DEBUG] PSUtilApp Constructor"
        $this.Config = $Global:Config
        $this.Initialize()
        $this.InitControls()
    }

    [void]Initialize() {
        Write-Host "[DEBUG] Initialize"
        $this.InitDirectories()
        $this.InitUsers()
        $this.InitMachines()
        $this.LoadSources()
        $this.BuildTaskCache()
    }

    [void]InitDirectories() {
        # Setup directories using config
        $dirs = @($this.Config.DataDir) + ($this.Config.SubDirs | ForEach-Object { "$($this.Config.DataDir)\$_" })
        foreach ($dir in $dirs) {
            if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        }
        
        # Initialize default templates
        $this.InitializeDefaultTemplates()
    }

    [void]InitializeDefaultTemplates() {
        Write-Host "[DEBUG] InitializeDefaultTemplates"
        $templatesDir = Join-Path $this.Config.DataDir "Templates"
        
        # Check if templates already exist - don't create defaults if they do
        $existingTemplates = Get-ChildItem -Path $templatesDir -Filter "*.txt" -ErrorAction SilentlyContinue
        if ($existingTemplates.Count -gt 0) {
            Write-Host "[DEBUG] Found $($existingTemplates.Count) existing templates, skipping default creation" -ForegroundColor Green
            return
        }
        
        # Create default templates only if Templates directory is empty
        Write-Host "[DEBUG] No templates found, creating defaults" -ForegroundColor Yellow
        
        # Windows 11 Debloat Template
        $debloatTemplate = @(
            "# Template: Windows 11 Debloat",
            "# Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
            "# Tasks: 6",
            "",
            "Remove Xbox Gaming Services",
            "Remove Microsoft Teams Personal", 
            "Remove Windows 11 Widgets",
            "Disable Cortana",
            "Disable Windows Telemetry",
            "Configure Privacy Settings"
        )
        $debloatPath = Join-Path $templatesDir "Windows 11 Debloat.txt"
        $debloatTemplate | Set-Content $debloatPath -Force
        
        # Developer Environment Template
        $devTemplate = @(
            "# Template: Developer Environment",
            "# Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
            "# Tasks: 6",
            "",
            "Install Git",
            "Install Visual Studio Code",
            "Install Node.js LTS",
            "Install Docker Desktop",
            "Configure Git Global Settings",
            "Install PowerShell 7"
        )
        $devPath = Join-Path $templatesDir "Developer Environment.txt"
        $devTemplate | Set-Content $devPath -Force
        
        # Content Creator Template
        $contentTemplate = @(
            "# Template: Content Creator Setup",
            "# Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
            "# Tasks: 5",
            "",
            "Install OBS Studio",
            "Install GIMP",
            "Install Audacity",
            "Install VLC Media Player",
            "Configure OBS Settings"
        )
        $contentPath = Join-Path $templatesDir "Content Creator Setup.txt"
        $contentTemplate | Set-Content $contentPath -Force
        
        Write-Host "[DEBUG] Created default templates"
    }

    [void]OnCopyCommand() {
        Write-Host "[DEBUG] OnCopyCommand (robust selection)"
        $lv = $this.Controls.ScriptsListView
        # Try to get selected items robustly (works for all View modes)
        $selectedItems = @()
        for ($i = 0; $i -lt $lv.Items.Count; $i++) {
            if ($lv.Items[$i].Selected) { $selectedItems += $lv.Items[$i] }
        }
        if ($selectedItems.Count -eq 0) {
            $this.SetStatusMessage("Please select a task to copy the command.", 'Orange')
            return
        }
        $commands = @()
        foreach ($item in $selectedItems) {
            $tag = $item.Tag
            if ($tag -and $tag.Command) { $commands += $tag.Command }
        }
        if ($commands.Count -gt 0) {
            $commands -join "`r`n" | Set-Clipboard
            $this.SetStatusMessage("Command(s) copied to clipboard.", 'Green')
        }
    }

    [void]OnRunLater() {
        Write-Host "[DEBUG] OnRunLater (robust selection)"
        $lv = $this.Controls.ScriptsListView
        $selectedItems = @()
        for ($i = 0; $i -lt $lv.Items.Count; $i++) {
            if ($lv.Items[$i].Selected) { $selectedItems += $lv.Items[$i] }
        }
        if ($selectedItems.Count -eq 0) {
            $this.SetStatusMessage("Please select a task to schedule.", 'Orange')
            return
        }
        foreach ($item in $selectedItems) {
            $tag = $item.Tag
            if ($tag -and $tag.Command) {
                $taskName = "PSUtil_" + ($tag.Description -replace '[^a-zA-Z0-9]', '_')
                $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command \"$($tag.Command)\""
                $trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(1))
                try {
                    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Force | Out-Null
                    $this.SetStatusMessage("Task scheduled: $taskName", 'Green')
                }
                catch {
                    $this.SetStatusMessage("Failed to schedule task: $taskName - $_", 'Red')
                }
            }
        }
    }

    [void]OnAddCommand() {
        Write-Host "[DEBUG] OnAddCommand (robust selection)"
        $lv = $this.Controls.ScriptsListView
        $selectedItems = @()
        for ($i = 0; $i -lt $lv.Items.Count; $i++) {
            if ($lv.Items[$i].Selected) { $selectedItems += $lv.Items[$i] }
        }
        if ($selectedItems.Count -eq 0) {
            $this.SetStatusMessage("Please select a task to add/update in Favourites.", 'Orange')
            return
        }
        # Use the secondary panel for input instead of VisualBasic InputBox
        $this.ShowFavouritePanel($selectedItems)
    }

    [void]OnCreateTemplate() {
        Write-Host "[DEBUG] OnCreateTemplate"
        $lv = $this.Controls.ScriptsListView
        $selectedItems = @()
        for ($i = 0; $i -lt $lv.Items.Count; $i++) {
            if ($lv.Items[$i].Selected -or $lv.Items[$i].Checked) { 
                $selectedItems += $lv.Items[$i] 
            }
        }
        if ($selectedItems.Count -eq 0) {
            $this.SetStatusMessage("Please select tasks to create a template.", 'Orange')
            return
        }
        $this.ShowTemplatePanel($selectedItems)
    }

    [void]InitUsers() {
        # Minimal user setup
        $this.Users = @(
            @{ Name = $env:USERNAME; DisplayName = "$env:USERNAME (me)"; Type = "LoggedIn" },
            @{ Name = "Administrator"; DisplayName = "Administrator"; Type = "Administrator" }
        )
    }

    [void]InitMachines() {
        # Minimal machine setup
        $this.Machines = @(@{ Name = $env:COMPUTERNAME; DisplayName = $env:COMPUTERNAME; Type = "Local" })
        if ((Test-Path $this.Config.SSHConfigPath)) {
            (Get-Content $this.Config.SSHConfigPath -ErrorAction SilentlyContinue) | ForEach-Object {
                if ($_ -match '^Host\s+(.+)$' -and $Matches[1] -notmatch '[*?]' -and $Matches[1] -ne "localhost") {
                    $this.Machines += @{ Name = $Matches[1]; DisplayName = $Matches[1]; Type = "SSH" }
                }
            }
        }
    }

    # [void]InitSources() method removed: replaced by OOP LoadSources and source classes

    [array]GetRemoteScriptFilesRecursive([string]$path) {
        Write-Host "[DEBUG] GetRemoteScriptFilesRecursive $path"
        $files = @()
        try {
            $url = if ($path) { "$($this.Config.URLs.GitHubAPI)/$($this.Config.Owner)/$($this.Config.Repo)/contents/$path" } 
            else { "$($this.Config.URLs.GitHubAPI)/$($this.Config.Owner)/$($this.Config.Repo)/contents" }
            $apiResponse = Invoke-WebRequest $url | ConvertFrom-Json
            foreach ($item in $apiResponse) {
                $extension = if ($item.name.Contains('.')) { $item.name.Substring($item.name.LastIndexOf('.')) } else { '' }
                if ($item.type -eq $this.Config.SourceInfo.DirectoryTypes.File -and $this.Config.ScriptExtensions.Remote -contains $extension) {
                    $files += if ($path) { "$path$($this.Config.SourceInfo.SlashSeparator)$($item.name)" } else { $item.name }
                }
                elseif ($item.type -eq $this.Config.SourceInfo.DirectoryTypes.Dir) {
                    $subPath = if ($path) { "$path$($this.Config.SourceInfo.SlashSeparator)$($item.name)" } else { $item.name }
                    $files += $this.GetRemoteScriptFilesRecursive($subPath)
                }
            }
        }
        catch { Write-Warning "$($this.Config.SourceInfo.ErrorFetchingDir)$path : $_" }
        return $files
    }

    [void]InitControls() {
        Write-Host "[DEBUG] InitControls"
        $sourceInfo = $this.GetSourceInfo()
        $createdControls = @{}
        $app = $this

        # Main Form
        $this.MainForm = New-Object System.Windows.Forms.Form
        $this.MainForm.Text = "$($this.Config.Window.Title) $((Split-Path $sourceInfo -Leaf).Substring(0,1).ToUpper() + (Split-Path $sourceInfo -Leaf).Substring(1))"
        $this.MainForm.Width = $this.Config.Window.Width
        $this.MainForm.Height = $this.Config.Window.Height
        $this.MainForm.Padding = $this.Config.Window.Padding
        $this.MainForm.StartPosition = $this.Config.Window.Position
        $this.MainForm.BackColor = $this.Config.Window.BackgroundColor
        $this.MainForm.Add_Shown({ $app.OnFormShown() })

        # Define controls with order for proper placement and future drag-drop (restored classic WinForms order, labels above combos)
        $controlDefs = @{
            Toolbar             = @{ Type = 'Panel'; Order = 30; Layout = 'Form'; Properties = @{ Dock = 'Top'; Height = $this.Config.Panels.ToolbarHeight; Padding = $this.Config.Panels.ToolbarPadding } }
            StatusBar           = @{ Type = 'Panel'; Order = 21; Layout = 'Form'; Properties = @{ BorderStyle = 'FixedSingle'; Dock = 'Bottom'; Height = $this.Config.Panels.StatusBarHeight; Padding = $this.Config.Panels.StatusPadding } }
            Sidebar             = @{ Type = 'Panel'; Order = 20; Layout = 'Form'; Properties = @{ Dock = 'Right'; Width = $this.Config.Panels.SidebarWidth; Padding = $this.Config.Panels.SidebarPadding; Visible = $false } }
            MainContent         = @{ Type = 'Panel'; Order = 10; Layout = 'Form'; Properties = @{ Dock = 'Fill'; Padding = '0, 0, 0, 0' } }
            SecondaryContent    = @{ Type = 'Panel'; Order = 30; Layout = 'MainContent'; Properties = @{ Dock = 'Right'; BackColor = $this.Config.Colors.White; Width = $this.Config.Panels.SecondaryPanelWidth; Padding = $this.Config.Panels.SecondaryPadding; Visible = $false } }
            ContentSplitter     = @{ Type = 'Splitter'; Order = 20; Layout = 'MainContent'; Properties = @{ Dock = 'Right'; Width = $this.Config.Panels.SplitterWidth; Visible = $true; BackColor = 'LightGray'; BorderStyle = 'FixedSingle' } }
            PrimaryContent      = @{ Type = 'Panel'; Order = 10; Layout = 'MainContent'; Properties = @{ Dock = 'Fill'; Padding = $this.Config.Panels.ContentPadding } }
            RefreshBtn          = @{ Type = 'Button'; Order = 0; Layout = 'Toolbar'; Properties = @{ Text = $this.Config.Controls.RefreshText; Dock = 'Left'; Enabled = $false; Visible = $true } }
            FilterText          = @{ Type = 'TextBox'; Order = 1; Layout = 'Toolbar'; Properties = @{ Dock = 'Left'; } }
            SelectAllCheckBox   = @{ Type = 'CheckBox'; Order = 2; Layout = 'Toolbar'; Properties = @{ Text = $this.Config.Controls.SelectAllText; Width = 25; Dock = 'Left'; Padding = '5,0,0,0'; BackColor = 'Transparent' } }
            MoreBtn             = @{ Type = 'Button'; Order = 101; Layout = 'Toolbar'; Properties = @{ Text = '≡'; Width = $this.Config.Controls.Height; Dock = 'Right' } }
            ExecuteBtn          = @{ Type = 'Button'; Order = 100; Layout = 'Toolbar'; Properties = @{ Text = $this.Config.Controls.ExecuteBtnText; Dock = 'Right' } }
            CancelBtn           = @{ Type = 'Button'; Order = 99; Layout = 'Toolbar'; Properties = @{ Text = $this.Config.Controls.CancelText; Dock = 'Right'; Enabled = $false } }
            ExecuteModeLabel    = @{ Type = 'Label'; Order = 2; Layout = 'Sidebar'; Properties = @{ Text = "Run As"; Dock = 'Top'; Height = 18; TextAlign = 'MiddleLeft'; BackColor = 'Transparent' } }
            ExecuteModeCombo    = @{ Type = 'ComboBox'; Order = 1; Layout = 'Sidebar'; Properties = @{ Dock = 'Top' } }
            SpacerPanelExec     = @{ Type = 'Panel'; Order = 3; Layout = 'Sidebar'; Properties = @{ Height = 8; Dock = 'Top'; BackColor = 'Transparent' } }
            MachineLabel        = @{ Type = 'Label'; Order = 5; Layout = 'Sidebar'; Properties = @{ Text = "Target Machine"; Dock = 'Top'; Height = 18; TextAlign = 'MiddleLeft'; BackColor = 'Transparent' } }
            MachineCombo        = @{ Type = 'ComboBox'; Order = 4; Layout = 'Sidebar'; Properties = @{ Dock = 'Top' } }
            SpacerPanelMachine  = @{ Type = 'Panel'; Order = 6; Layout = 'Sidebar'; Properties = @{ Height = 8; Dock = 'Top'; BackColor = 'Transparent' } }
            SourceLabel         = @{ Type = 'Label'; Order = 8; Layout = 'Sidebar'; Properties = @{ Text = "Task List Source"; Dock = 'Top'; Height = 18; TextAlign = 'MiddleLeft'; BackColor = 'Transparent' } }
            SourceCombo         = @{ Type = 'ComboBox'; Order = 7; Layout = 'Sidebar'; Properties = @{ Dock = 'Top' } }
            SpacerPanel2        = @{ Type = 'Panel'; Order = 9; Layout = 'Sidebar'; Properties = @{ Height = 8; BackColor = 'Transparent'; Dock = 'Fill'; } }
            CopyCommandBtn      = @{ Type = 'Button'; Order = 10; Layout = 'Sidebar'; Properties = @{ Text = $this.Config.Controls.CopyCommandText; Dock = 'Bottom'; TextAlign = 'MiddleLeft' } }
            SpacerPanelCopy     = @{ Type = 'Panel'; Order = 11; Layout = 'Sidebar'; Properties = @{ Height = 5; Dock = 'Bottom'; BackColor = 'Transparent' } }
            RunLaterBtn         = @{ Type = 'Button'; Order = 12; Layout = 'Sidebar'; Properties = @{ Text = $this.Config.Controls.RunLaterText; Dock = 'Bottom'; TextAlign = 'MiddleLeft' } }
            SpacerPanelRun      = @{ Type = 'Panel'; Order = 13; Layout = 'Sidebar'; Properties = @{ Height = 5; Dock = 'Bottom'; BackColor = 'Transparent' } }
            AddCommandBtn       = @{ Type = 'Button'; Order = 14; Layout = 'Sidebar'; Properties = @{ Text = $this.Config.Controls.AddCommandText; Dock = 'Bottom'; TextAlign = 'MiddleLeft' } }
            SpacerPanelAdd      = @{ Type = 'Panel'; Order = 15; Layout = 'Sidebar'; Properties = @{ Height = 5; Dock = 'Bottom'; BackColor = 'Transparent' } }
            CreateTemplateBtn   = @{ Type = 'Button'; Order = 16; Layout = 'Sidebar'; Properties = @{ Text = 'Create Template'; Dock = 'Bottom'; TextAlign = 'MiddleLeft' } }
            SpacerPanelTemplate = @{ Type = 'Panel'; Order = 17; Layout = 'Sidebar'; Properties = @{ Height = 5; Dock = 'Bottom'; BackColor = 'Transparent' } }
            ScriptsListView     = @{ Type = 'ListView'; Order = 1; Layout = 'PrimaryContent'; Properties = @{ Dock = 'Fill'; View = 'Details'; GridLines = $true; BorderStyle = 'None'; CheckBoxes = $true; FullRowSelect = $true; AllowDrop = $true } }
            SecondaryLabel      = @{ Type = 'Label'; Order = 1; Layout = 'SecondaryContent'; Properties = @{ Text = 'Secondary Panel'; Dock = 'Top'; Height = 30; TextAlign = 'MiddleCenter' } }
            CloseSecondaryBtn   = @{ Type = 'Button'; Order = 2; Layout = 'SecondaryContent'; Properties = @{ Text = '✕'; Dock = 'Top'; Height = 25; FlatStyle = 'Flat'; TextAlign = 'MiddleCenter'; BackColor = 'LightCoral'; ForeColor = 'White' } }
            StatusLabel         = @{ Type = 'Label'; Order = 1; Layout = 'StatusBar'; Properties = @{ Text = "Ready"; Dock = 'Left'; AutoSize = $true; TextAlign = 'MiddleLeft'; BackColor = 'Transparent' } }
            StatusProgressBar   = @{ Type = 'ProgressBar'; Order = 2; Layout = 'StatusBar'; Properties = @{ Dock = 'Right'; Width = 120; Visible = $false } }
        }

        # Create controls in order
        $controlDefs.GetEnumerator() | Sort-Object { $_.Value.Order } | ForEach-Object {
            $name = $_.Key
            $config = $_.Value
            $ctrl = New-Object "System.Windows.Forms.$($config.Type)"
            if ($config.Type -ne 'Splitter') { $ctrl.Dock = $this.Config.Controls.Dock }
            $ctrl.Width = $this.Config.Controls.Width
            $ctrl.Height = $this.Config.Controls.Height
            $ctrl.Padding = $this.Config.Controls.Padding
            $ctrl.BackColor = $this.Config.Controls.BackColor
            $ctrl.ForeColor = $this.Config.Controls.ForeColor
            if ($config.Type -eq 'ComboBox') { $ctrl.DropDownStyle = 'DropDownList' }
            if ($config.Type -eq 'Splitter') { $ctrl.MinExtra = 100; $ctrl.MinSize = 100 }
            if ($config.Type -eq 'Panel' -or $config.Type -eq 'CheckBox') { $ctrl.BackColor = $this.MainForm.BackColor }
            foreach ($kv in $config.Properties.GetEnumerator()) {
                # Skip PlaceholderText for FilterText, handle manually for broader support
                if ($name -eq 'FilterText' -and $kv.Key -eq 'PlaceholderText') { continue }
                if ($kv.Key -notmatch '^Add_') { $ctrl.($kv.Key) = $kv.Value }
            }
            $createdControls[$name] = $ctrl
        }


        # Add all controls (including panels) to their parent in ascending order of Order, using only Layout property
        $controlDefs.GetEnumerator() | Sort-Object { $_.Value.Order } | ForEach-Object {
            $name = $_.Key
            $config = $_.Value
            $ctrl = $createdControls[$name]
            $parentName = $config.Layout
            if ($createdControls.ContainsKey($parentName)) {
                $createdControls[$parentName].Controls.Add($ctrl)
            }
            elseif ($parentName -eq 'Form') {
                $this.MainForm.Controls.Add($ctrl)
            }
        }

        # Assign controls to class property
        $this.Controls = $createdControls

        # Manual placeholder logic for FilterText (broader support, including iex)
        $filterTextBox = $this.Controls.FilterText
        if ($filterTextBox) {
            $placeholder = $this.Config.Controls.FilterPlaceholder
            $filterTextBox.Text = $placeholder
            $filterTextBox.ForeColor = 'Gray'
            $filterTextBox.Add_Enter({
                    if ($this.Text -eq $placeholder) {
                        $this.Text = ""
                        $this.ForeColor = 'Black'
                    }
                }.GetNewClosure())
            $filterTextBox.Add_Leave({
                    if (-not $this.Text -or $this.Text.Trim() -eq '') {
                        $this.Text = $placeholder
                        $this.ForeColor = 'Gray'
                    }
                }.GetNewClosure())
        }

        # Setup ListView columns using config
        foreach ($column in $this.Config.ListView.Columns) {
            $this.Controls.ScriptsListView.Columns.Add($column.Name, $column.Width) | Out-Null
        }
        $columns = $this.Controls.ScriptsListView.Columns
        
        # Enable column reordering
        $this.Controls.ScriptsListView.AllowColumnReorder = $true
        
        # Add column click handler for sorting
        $this.Controls.ScriptsListView.Add_ColumnClick({
                param($listView, $e)
                $app.OnColumnClick($listView, $e)
            }.GetNewClosure())
        
        # Hide extra columns initially (show only Script)

        # Add context menu for column visibility dynamically based on config columns
        $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

        for ($i = 1; $i -lt $columns.Count; $i++) {
            $columns[$i].Width = 0
            $menuText = "Show $($columns[$i].Text) Column"
            $menuItem = $contextMenu.Items.Add($menuText)
            $menuItem.Checked = $false
            $colIdx = $i
            $menuItem.Add_Click({
                    param($menuSender, $menuArgs)
                    $app.ToggleListViewColumn($menuSender, $menuArgs, $colIdx)
                }.GetNewClosure())
        }
        $this.Controls.ScriptsListView.ContextMenuStrip = $contextMenu

        # Setup drag and drop functionality for ListView
        $this.Controls.ScriptsListView.Add_ItemDrag({ 
                if ($this.SelectedItems.Count -gt 0) {
                    $selectedItem = $this.SelectedItems[0]

                    $this.DoDragDrop($selectedItem, 1) # 1 = Move
                }
            })

        $this.Controls.ScriptsListView.Add_DragEnter({
                param($listView, $e)
                if ($e.Data.GetDataPresent("System.Windows.Forms.ListViewItem")) {
                    $e.Effect = 1 # Move
                }
                else {
                    $e.Effect = 0 # None
                }
            })

        $this.Controls.ScriptsListView.Add_DragLeave({
                $this.InsertionMark.Index = -1
            })

        $this.Controls.ScriptsListView.Add_DragOver({
                param($listView, $e)
                
                # Ensure assemblies are loaded in this context
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

                if ($e.Data.GetDataPresent("System.Windows.Forms.ListViewItem")) {
                    $e.Effect = 1 # Move

                    # Use reflection to get cursor position to avoid type resolution issues
                    try {
                        $cursorType = [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms").GetType("System.Windows.Forms.Cursor")
                        $cursorPos = $cursorType.GetProperty("Position").GetValue($null)
                        $pt = $listView.PointToClient($cursorPos)
                    }
                    catch {
                        # Fallback: use event position if available
                        $pt = New-Object System.Drawing.Point($e.X, $e.Y)
                    }
                    $targetItem = $listView.GetItemAt($pt.X, $pt.Y)

                    if ($targetItem) {
                        $targetIndex = $targetItem.Index

                        $itemBounds = $targetItem.Bounds
                        $midPoint = $itemBounds.Top + ($itemBounds.Height / 2)
                        if ($pt.Y -gt $midPoint) {

                            $listView.InsertionMark.Index = $targetIndex
                            $listView.InsertionMark.AppearsAfterItem = $true

                            Write-Host "DragOver: Target '$($targetItem.Text)' (Index: $targetIndex) - INSERT AFTER" -ForegroundColor Green
                        }
                        else {

                            $listView.InsertionMark.Index = $targetIndex
                            $listView.InsertionMark.AppearsAfterItem = $false

                            Write-Host "DragOver: Target '$($targetItem.Text)' (Index: $targetIndex) - INSERT BEFORE" -ForegroundColor Green
                        }
                    }
                    else {
                        # If we hit empty space, find the closest item based on Y coordinate
                        if ($listView.Items.Count -eq 0) {
                            # Empty list
                            $listView.InsertionMark.Index = 0
                            $listView.InsertionMark.AppearsAfterItem = $false
                            Write-Host "DragOver: Empty list - INSERT AT INDEX 0" -ForegroundColor Magenta
                        }
                        else {
                            # Find the closest item based on Y coordinate
                            $closestItem = $null
                            $closestDistance = [double]::MaxValue
                        
                            for ($i = 0; $i -lt $listView.Items.Count; $i++) {
                                $item = $listView.Items[$i]
                                $itemCenter = $item.Bounds.Top + ($item.Bounds.Height / 2)
                                $distance = [Math]::Abs($pt.Y - $itemCenter)
                            
                                if ($distance -lt $closestDistance) {
                                    $closestDistance = $distance
                                    $closestItem = $item
                                }
                            }
                        
                            if ($closestItem) {
                                $targetIndex = $closestItem.Index
                                $itemBounds = $closestItem.Bounds
                                $midPoint = $itemBounds.Top + ($itemBounds.Height / 2)
                            
                                if ($pt.Y -gt $midPoint) {
                                    $listView.InsertionMark.Index = $targetIndex
                                    $listView.InsertionMark.AppearsAfterItem = $true
                                    Write-Host "DragOver: Closest '$($closestItem.Text)' (Index: $targetIndex) - INSERT AFTER" -ForegroundColor Yellow
                                }
                                else {
                                    $listView.InsertionMark.Index = $targetIndex
                                    $listView.InsertionMark.AppearsAfterItem = $false
                                    Write-Host "DragOver: Closest '$($closestItem.Text)' (Index: $targetIndex) - INSERT BEFORE" -ForegroundColor Yellow
                                }
                            }
                            else {
                                # Fallback to checking if we're at the very end
                                $lastItem = $listView.Items[$listView.Items.Count - 1]
                                if ($pt.Y -gt $lastItem.Bounds.Bottom) {
                                    $listView.InsertionMark.Index = $listView.Items.Count - 1
                                    $listView.InsertionMark.AppearsAfterItem = $true
                                    Write-Host "DragOver: END OF LIST - INSERT AFTER LAST ITEM" -ForegroundColor Magenta
                                }
                                else {
                                    $listView.InsertionMark.Index = 0
                                    $listView.InsertionMark.AppearsAfterItem = $false
                                    Write-Host "DragOver: BEGINNING OF LIST - INSERT BEFORE FIRST ITEM" -ForegroundColor Magenta
                                }
                            }
                        }
                    }
                }
                else {
                    $e.Effect = 0 # None
                    $listView.InsertionMark.Index = -1
                }
            })

        $this.Controls.ScriptsListView.Add_DragDrop({
                param($listView, $e)
                $draggedItem = $e.Data.GetData("System.Windows.Forms.ListViewItem")
                if ($draggedItem) {
                    $targetIndex = $listView.InsertionMark.Index
                    if ($targetIndex -ge 0) {

                        Write-Host "=== DRAG DROP DEBUG ===" -ForegroundColor Yellow
                        Write-Host "Dragged Item: '$($draggedItem.Text)' (Index: $($draggedItem.Index))" -ForegroundColor Cyan
                        Write-Host "Target Index: $targetIndex" -ForegroundColor Cyan
                        Write-Host "Appears After: $($listView.InsertionMark.AppearsAfterItem)" -ForegroundColor Cyan
                        Write-Host "ListView Groups Count: $($listView.Groups.Count)" -ForegroundColor Cyan
                        Write-Host "========================" -ForegroundColor Yellow

                        $app.MoveListViewItem($listView, $draggedItem, $targetIndex, $listView.InsertionMark.AppearsAfterItem)
                    }
                }

                $listView.InsertionMark.Index = -1
            }.GetNewClosure())

        # Setup events (must be done after controls are created)
        $this.Controls.ExecuteBtn.Add_Click({ $app.OnExecute() })
        $this.Controls.CancelBtn.Add_Click({ $app.OnCancelExecution() })
        $this.Controls.SelectAllCheckBox.Add_CheckedChanged({ $app.OnSelectAll() })
        $this.Controls.ExecuteModeCombo.Add_SelectedIndexChanged({ $app.OnSwitchUser() })
        $this.Controls.SourceCombo.Add_SelectedIndexChanged({ $app.OnSwitchSource() })
        $this.Controls.FilterText.Add_TextChanged({ $app.OnFilter() })
        $this.MainForm.Add_Shown({ $app.OnFormShown() })
        $this.Controls.MoreBtn.Add_Click({ $app.OnMore() })
        $this.Controls.CopyCommandBtn.Add_Click({ $app.OnCopyCommand() })
        $this.Controls.RunLaterBtn.Add_Click({ $app.OnRunLater() })
        $this.Controls.AddCommandBtn.Add_Click({ $app.OnAddCommand() })
        $this.Controls.CreateTemplateBtn.Add_Click({ $app.OnCreateTemplate() })
        $this.Controls.CloseSecondaryBtn.Add_Click({ $app.HideSecondaryPanel() })
        $this.Controls.CancelBtn.Add_Click({ $app.OnCancelExecution() })
        $this.Controls.RefreshBtn.Add_Click({ $app.OnRefresh() })

        # Setup execution mode options using $this.Users and all other enabled local users
        $this.Controls.ExecuteModeCombo.Items.Clear()
        foreach ($user in $this.Users) {
            $this.Controls.ExecuteModeCombo.Items.Add($user.DisplayName) | Out-Null
        }
        # Add all other enabled local users (excluding current user and Administrator)
        try {
            $otherUsers = Get-LocalUser | Where-Object { $_.Name -ne $env:USERNAME -and $_.Name -ne "Administrator" -and $_.Enabled } | Select-Object -ExpandProperty Name
            foreach ($ou in $otherUsers) {
                $this.Controls.ExecuteModeCombo.Items.Add($ou) | Out-Null
            }
        }
        catch {
            # No additional users found or error
        }

        # Add "Add to Favourite..." to ListView context menu
        $addFavMenu = $contextMenu.Items.Add("Add to Favourite...")
        $addFavMenu.Add_Click({ $app.OnAddToFavourite() })
        
        # Add "Create Template..." to ListView context menu
        $addTemplateMenu = $contextMenu.Items.Add("Create Template...")
        $addTemplateMenu.Add_Click({ $app.OnCreateTemplate() })
        
        # Add separator
        $contextMenu.Items.Add("-") | Out-Null
        
        # Add move up/down options
        $moveUpMenu = $contextMenu.Items.Add("Move Up")
        $moveUpMenu.Add_Click({ $app.MoveSelectedItemUp() })
        
        $moveDownMenu = $contextMenu.Items.Add("Move Down") 
        $moveDownMenu.Add_Click({ $app.MoveSelectedItemDown() })
    }
    # Sidebar Event Handlers
    [void]OnMore() {
        Write-Host "[DEBUG] OnMore"
        $this.Controls.Sidebar.Visible = !$this.Controls.Sidebar.Visible
    }
    
    [void]OnSelectAll() {
        Write-host "[DEBUG] OnSelectAll"
        $lv = $this.Controls.ScriptsListView
        $doubleBufferProp = $lv.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags] "Instance, NonPublic")
        if ($doubleBufferProp) { $doubleBufferProp.SetValue($lv, $true, $null) }
        $checked = $this.Controls.SelectAllCheckBox.Checked
        $lv.BeginUpdate()
        try {
            $lv.Items | ForEach-Object { $_.Checked = $checked }
        }
        finally {
            $lv.EndUpdate()
        }
        $this.UpdateExecuteButtonText()
    }


    [void]OnSwitchSource() {
        Write-Host "[DEBUG] OnSwitchSource"
        $srcCombo = $this.Controls.SourceCombo
        $idx = $srcCombo.SelectedIndex
        $selectedSource = $null
        if ($idx -ge 0 -and $idx -lt $this.Sources.Count) {
            $selectedSource = $this.Sources[$idx]
        }
        if ($null -eq $selectedSource) {
            $this.LoadTasksToListView(@())
            return
        }
        if ($selectedSource -is [AllTasksSource]) {
            $allTasks = $selectedSource.GetTasks()
            $this.LoadTasksToListView($allTasks)
        }
        elseif ($selectedSource -is [TemplateSource]) {
            $templateName = $selectedSource.TemplateName
            $templatePath = Join-Path (Join-Path $this.Config.DataDir "Templates") "$templateName.txt"
            if (Test-Path $templatePath) {
                $grouped = $this.ReadGroupedProfile($templatePath)
                if ($grouped.Count -gt 0) {
                    $this.LoadGroupedTasksToListView($grouped)
                }
                else {
                    $this.SetStatusMessage("No matching tasks found in scripts for this template.", 'Orange')
                    $this.Controls.ScriptsListView.Items.Clear()
                    $this.UpdateExecuteButtonText()
                }
            }
            else {
                $this.SetStatusMessage("Template file not found.", 'Orange')
                $this.Controls.ScriptsListView.Items.Clear()
                $this.UpdateExecuteButtonText()
            }
        }
        elseif ($selectedSource -is [FavouriteSource]) {
            $favName = $selectedSource.FavouriteName
            $favPath = Join-Path (Join-Path $this.Config.DataDir "Favourites") "$favName.txt"
            if (Test-Path $favPath) {
                $grouped = $this.ReadGroupedProfile($favPath)
                if ($grouped.Count -gt 0) {
                    $this.LoadGroupedTasksToListView($grouped)
                }
                else {
                    $this.SetStatusMessage("No matching tasks found in scripts for this favourite file.", 'Orange')
                    $this.Controls.ScriptsListView.Items.Clear()
                    $this.UpdateExecuteButtonText()
                }
            }
            else {
                $this.SetStatusMessage("No matching tasks found for this favourite.", 'Orange')
                $this.Controls.ScriptsListView.Items.Clear()
                $this.UpdateExecuteButtonText()
            }
        }
        elseif ($selectedSource -is [LocalScriptFileSource]) {
            $tasks = $selectedSource.GetTasks()
            $this.LoadTasksToListView($tasks)
        }
        else {
            # Defensive: if not a known type, try to call GetTasks if it exists
            if ($selectedSource -and ($selectedSource.PSObject.Methods.Name -contains 'GetTasks')) {
                try {
                    $tasks = $selectedSource.GetTasks()
                    $this.LoadTasksToListView($tasks)
                }
                catch {
                    $this.LoadTasksToListView(@())
                }
            }
            else {
                $this.LoadTasksToListView(@())
            }
        }
    }
    [void]ToggleListViewColumn($menuSender, $e, [int]$colIdx) {
        Write-host "[DEBUG] ToggleListViewColumn $colIdx"
        $lv = $this.Controls.ScriptsListView
        if ($lv -and $lv.Columns -and $this.Config.ListView.Columns) {
            $columns = $lv.Columns
            if ($columns.Count -gt $colIdx) {
                if ($columns[$colIdx].Width -eq 0) {
                    $columns[$colIdx].Width = $this.Config.ListView.Columns[$colIdx].Width
                    $menuSender.Checked = $true
                }
                else {
                    $columns[$colIdx].Width = 0
                    $menuSender.Checked = $false
                }
            }
        }
    }
    [void]LoadData() {
        Write-Host "[DEBUG] LoadData"
        # Load machines
        $this.Controls.MachineCombo.Items.Clear()
        $this.Machines | ForEach-Object { $this.Controls.MachineCombo.Items.Add($_.DisplayName) | Out-Null }
        if ($this.Machines.Count -gt 0) {
            $this.Controls.MachineCombo.SelectedIndex = 0
        }

        # Populate SourceCombo using Sources (all are now objects)
        $srcCombo = $this.Controls.SourceCombo
        $srcCombo.Items.Clear()
        foreach ($src in $this.Sources) {
            $srcCombo.Items.Add($src.Name) | Out-Null
        }
        if ($srcCombo.Items.Count -gt 0) {
            $srcCombo.SelectedIndex = 0 # "All Tasks"
        }

        # Set execution mode default
        if ($this.Controls.ExecuteModeCombo.Items.Count -gt 0) {
            $this.Controls.ExecuteModeCombo.SelectedIndex = 0
        }
    }

    [array]ParseScriptFile([string]$content, [string]$fileName) {
        Write-Host "[DEBUG] ParseScriptFile $fileName"
        $scripts = @()
        $lines = $content -split $this.Config.Patterns.NewlinePattern
        $currentScript = $null

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            if ($line -match '^#(.*)$') {
                # If we have a previous script, add it to the list
                if ($currentScript -and $currentScript.Command.Trim()) {
                    $scripts += $currentScript
                }
                # Start a new script action
                $currentScript = @{
                    Description = $Matches[1].Trim()
                    Command     = ""
                    File        = $fileName
                    LineNumber  = $i + 1
                }
            }
            elseif ($line -and !$line.StartsWith('#')) {
                if ($currentScript) {
                    if ($currentScript.Command) {
                        $currentScript.Command += "`n$line"
                    }
                    else {
                        $currentScript.Command = $line
                    }
                }
            }
        }
        # Add the last script if it exists and has a command
        if ($currentScript -and $currentScript.Command.Trim()) {
            $scripts += $currentScript
        }

        # If no scripts found, treat entire file as a single script
        if ($scripts.Count -eq 0) {
            $scripts = @(@{
                    Description = "$($this.Config.Messages.ExecuteFileDesc)$fileName"
                    Command     = $content.Trim()
                    File        = $fileName
                    LineNumber  = 1
                })
        }

        return $scripts
    }

    [void]OnExecute() {
        Write-Host "[DEBUG] OnExecute"
        if ($this.IsExecuting) { return }
        $checkedItems = $this.Controls.ScriptsListView.Items | Where-Object { $_.Checked }
        if (!$checkedItems) { 
            $this.SetStatusMessage($this.Config.Messages.NoScriptsSelected, 'Red')
            return 
        }

        $this.IsExecuting = $true
        $this.Controls.ExecuteBtn.Enabled = $false
        if ($this.Controls.ContainsKey("CancelBtn")) {
            $this.Controls["CancelBtn"].Enabled = $true
            $this.Controls["CancelBtn"].Visible = $true
        }
        if ($this.Controls.ContainsKey("RefreshBtn")) {
            $this.Controls["RefreshBtn"].Enabled = $false
        }
        $progressBar = $this.Controls.StatusProgressBar
        $progressBar.Visible = $true
        $progressBar.Value = 0
        $progressBar.Maximum = $checkedItems.Count
        $this.State.CancelRequested = $false
        $completed = 0
        foreach ($item in $checkedItems) {
            if ($this.State.CancelRequested) {
                $item.SubItems[3].Text = $this.Config.Messages.CancelledByUser
                $item.BackColor = $this.Config.Colors.Filtered
                continue
            }
            $item.SubItems[3].Text = $this.Config.Messages.Running
            $item.BackColor = $this.Config.Colors.Running
            $this.SetStatusMessage("Executing: $($item.Text) ($($completed+1)/$($checkedItems.Count))", 'Blue')
            $this.RefreshUI()
            try {
                $script = $item.Tag
                $result = $this.ExecuteScript($script)
                $item.SubItems[3].Text = if ($result.Success) { $this.Config.Messages.Completed } else { $this.Config.Messages.Failed }
                $item.BackColor = if ($result.Success) { $this.Config.Colors.Completed } else { $this.Config.Colors.Failed }
                $item.Checked = !$result.Success
            }
            catch {
                $item.SubItems[3].Text = $this.Config.Messages.Failed
                $item.BackColor = $this.Config.Colors.Failed
                Write-host "$($this.Config.Messages.ExecutionError)$_" -ForegroundColor Red
            }
            $completed++
            $progressBar.Value = $completed
            $this.RefreshUI()
        }
        $this.IsExecuting = $false; $this.Controls.ExecuteBtn.Enabled = $true
    }

    [hashtable]ExecuteScript([hashtable]$script) {
        Write-Host "[DEBUG] ExecuteScript"        
        try {
            $result = ""
            $machine = $this.Machines[$this.Controls.MachineCombo.SelectedIndex]
            $command = $script.Command
            $file = $script.File
            $line = $script.LineNumber
            # You may also want to retrieve the command at the specified file and line
            $command = $script.Command
            if ($file -and (Test-Path $file)) {
                $lines = Get-Content $file
                if ($line -le $lines.Count -and $line -gt 0) {
                    $command = $lines[$line - 1]
                }
            }
            if ($machine.Type -eq "SSH") {
                $sshCommand = "$($this.Config.Defaults.SSHCommandPrefix)$($machine.Name) '$command'"
                if ($this.ExecutionMode -eq $this.Config.Defaults.AdminMode) { $sshCommand = "$($this.Config.Defaults.SSHCommandPrefix)$($machine.Name) '$($this.Config.Defaults.SudoCommand)$command'" }
                elseif ($this.ExecutionMode -ne $this.Config.Defaults.AdminText) {
                    $targetUser = $this.ExecutionMode.Substring(3)
                    $sshCommand = "$($this.Config.Defaults.SSHCommandPrefix)$($machine.Name) '$($this.Config.Defaults.SudoUserCommand)$targetUser $command'"
                }
                $result = Invoke-Expression $sshCommand
            }
            else {
                # Local execution
                if ($this.ExecutionMode -eq $this.Config.Defaults.AdminMode) {
                    Start-Process $this.Config.Defaults.PowerShellCommand -Verb $this.Config.Defaults.RunAsVerb -ArgumentList $this.Config.Defaults.CommandArgument, $command $this.Config.Defaults.WaitParameter
                    $result = $this.Config.Messages.ExecuteAsAdmin
                }
                elseif ($this.ExecutionMode -ne $this.Config.Defaults.AdminText) {
                    $targetUser = $this.ExecutionMode.Substring(3)
                    $cred = Get-Credential -UserName $targetUser -Message "$($this.Config.Messages.UserPasswordPrompt)$targetUser"
                    if ($cred) {
                        Start-Process $this.Config.Defaults.PowerShellCommand -Credential $cred -ArgumentList $this.Config.Defaults.CommandArgument, $command $this.Config.Defaults.WaitParameter
                        $result = "$($this.Config.Messages.ExecuteAsUser)$targetUser"
                    }
                    else { throw $this.Config.Messages.CancelledByUser }
                }
                elseif ($this.ExecutionMode -eq $this.Config.Defaults.OtherUserText) {
                    $cred = Get-Credential -Message $this.Config.Messages.CredentialsPrompt
                    if ($cred) {
                        Start-Process $this.Config.Defaults.PowerShellCommand -Credential $cred -ArgumentList $this.Config.Defaults.CommandArgument, $command $this.Config.Defaults.WaitParameter
                        $result = "$($this.Config.Messages.ExecuteAsUser)$($cred.UserName)"
                    }
                    else { throw $this.Config.Messages.CancelledByUser }
                }
                else {
                    $result = Invoke-Expression $command
                }
            }
            
            return @{ Success = $true; Output = $result }
        }
        catch {
            return @{ Success = $false; Output = $_.Exception.Message }
        }
    }

    [void]OnSwitchUser() {
        Write-Host "[DEBUG] OnSwitchUser"
        $selectedText = $this.Controls.ExecuteModeCombo.SelectedItem
        $this.ExecutionMode = if ($selectedText.Contains("(Current User)")) { $this.Config.Defaults.CurrentUserMode } 
        elseif ($selectedText -eq $this.Config.Defaults.AdminText) { $this.Config.Defaults.AdminMode } 
        else { $selectedText }
    }

    [void]ReadTasks([array]$scriptFiles) {
        Write-Host "[DEBUG] ReadTasks $($scriptFiles -join ',')"
        $tasks = @()
        foreach ($scriptFile in $scriptFiles) {
            try {
                $scriptContent = $null
                $currentScript = $PSCommandPath
                if ($currentScript -and (Test-Path $currentScript)) {
                    $scriptDir = Split-Path $currentScript -Parent
                    $fullPath = Join-Path $scriptDir $scriptFile.Replace($this.Config.SourceInfo.SlashSeparator, $this.Config.SourceInfo.BackslashSeparator)
                    if ((Test-Path $fullPath)) {
                        $scriptContent = Get-Content $fullPath -Raw
                    }
                }
                if (!$scriptContent) {
                    $scriptUrl = "$($this.Config.URLs.GitHubRaw)/$($this.Config.Owner)/$($this.Config.Repo)/refs/heads/$($this.Config.Branch)/$scriptFile"
                    $scriptContent = (Invoke-WebRequest $scriptUrl -ErrorAction Stop).Content
                }
                $parsedTasks = $this.ParseScriptFile($scriptContent, $scriptFile)
                $tasks += $parsedTasks
            }
            catch { Write-Warning "$($this.Config.Messages.LoadScriptError)$scriptFile - $_" }
        }
        $this.LoadTasksToListView($tasks)
    }

    [void]LoadTasksToListView([array]$tasks) {
        Write-Host "[DEBUG] LoadTasksToListView $($tasks.Count)"
        $this.Controls.ScriptsListView.Items.Clear()
        $this.Controls.ScriptsListView.Groups.Clear()
        foreach ($task in $tasks) {
            $item = New-Object System.Windows.Forms.ListViewItem($task.Description)
            $item.SubItems.Add($task.Command) | Out-Null
            $item.SubItems.Add($task.File) | Out-Null
            $item.SubItems.Add($this.Config.Messages.Ready) | Out-Null
            $item.Tag = $task
            $this.Controls.ScriptsListView.Items.Add($item) | Out-Null
        }
        $this.UpdateExecuteButtonText()
    }

    [void]UpdateExecuteButtonText() {
        Write-Host "[DEBUG] UpdateExecuteButtonText"
        $checkedCount = ($this.Controls.ScriptsListView.Items | Where-Object { $_.Checked }).Count
        $this.Controls.ExecuteBtn.Text = $this.Config.Controls.ExecuteBtnTemplate -f $checkedCount
    }

    [void]OnFilter() {
        Write-Host "[DEBUG] OnFilter"
        $filter = $this.Controls.FilterText.Text
        $placeholder = $this.Config.Controls.FilterPlaceholder
        if ($filter -eq $placeholder) { $filter = "" }
        $filter = $filter.ToLower()
        $this.Controls.ScriptsListView.Items | ForEach-Object {
            $visible = !$filter -or $_.Text.ToLower().Contains($filter) -or $_.SubItems[1].Text.ToLower().Contains($filter)
            $_.ForeColor = if ($visible) { $this.Config.Colors.Text } else { $this.Config.Colors.Filtered }
        }
    }

    [void]OnAddToFavourite() {
        Write-Host "[DEBUG] OnAddToFavourite"
        $selectedItems = $this.Controls.ScriptsListView.Items | Where-Object { $_.Selected }
        if (!$selectedItems) {
            $this.SetStatusMessage("Please select a task to add to Favourites.", 'Orange')
            return
        }
        $this.ShowFavouritePanel($selectedItems)
    }

    [void]ShowFavouritePanel($selectedItems) {
        Write-Host "[DEBUG] ShowFavouritePanel"
        $this.ShowSecondaryPanel("⭐ Add to Favourite")
        # Simple UI: TextBox for name, ListBox for existing favourites, Save/Cancel buttons
        $panel = $this.Controls.SecondaryContent
        
        # Don't clear all controls - preserve the header and close button
        # Remove only the dynamic content controls
        $controlsToRemove = @()
        foreach ($ctrl in $panel.Controls) {
            if ($ctrl -ne $this.Controls.SecondaryLabel -and $ctrl -ne $this.Controls.CloseSecondaryBtn) {
                $controlsToRemove += $ctrl
            }
        }
        foreach ($ctrl in $controlsToRemove) {
            $panel.Controls.Remove($ctrl)
        }
        
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = "Favourite Name:"
        $lbl.Dock = 'Top'
        $panel.Controls.Add($lbl)
        $txt = New-Object System.Windows.Forms.TextBox
        $txt.Dock = 'Top'
        $panel.Controls.Add($txt)
        $lst = New-Object System.Windows.Forms.ListBox
        $lst.Dock = 'Top'
        $lst.Height = 80
        # List existing .txt favourites
        $favouritesDir = Join-Path $this.Config.DataDir "Favourites"
        $existingFavs = @()
        if (Test-Path $favouritesDir) {
            $existingFavs = Get-ChildItem -Path $favouritesDir -File | Where-Object { $_.Extension -eq ".txt" } | Select-Object -ExpandProperty BaseName
        }
        $lst.Items.AddRange($existingFavs)
        $panel.Controls.Add($lst)
        $btnSave = New-Object System.Windows.Forms.Button
        $btnSave.Text = "Save"
        $btnSave.Dock = 'Top'
        $btnSave.Add_Click({
                $name = $txt.Text.Trim()
                if (!$name) { 
                    $this.SetStatusMessage("Enter a name for the favourite.", 'Orange')
                    return 
                }
                $refs = @()
                foreach ($item in $selectedItems) {
                    $tag = $item.Tag
                    $refs += "$($tag.Description)"
                }
                $favPath = Join-Path (Join-Path $this.Config.DataDir "Favourites") "$name.txt"
                $refs | Set-Content $favPath -Force
                $this.LoadSources()  # Reload sources to include new favourite
                $this.LoadData()     # Reload combo box data
                $this.HideSecondaryPanel()
            }.GetNewClosure())
        $panel.Controls.Add($btnSave)
        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Text = "Cancel"
        $btnCancel.Dock = 'Bottom'
        $btnCancel.Add_Click({ $this.HideSecondaryPanel() }.GetNewClosure())
        $panel.Controls.Add($btnCancel)
        $lst.Add_SelectedIndexChanged({
                if ($lst.SelectedItem) { $txt.Text = $lst.SelectedItem }
            }.GetNewClosure())
    }

    [void]ShowTemplatePanel($selectedItems) {
        Write-Host "[DEBUG] ShowTemplatePanel"
        $this.ShowSecondaryPanel("Create Template")
        
        $panel = $this.Controls.SecondaryContent
        
        # Don't clear all controls - preserve the header and close button
        # Remove only the dynamic content controls
        $controlsToRemove = @()
        foreach ($ctrl in $panel.Controls) {
            if ($ctrl -ne $this.Controls.SecondaryLabel -and $ctrl -ne $this.Controls.CloseSecondaryBtn) {
                $controlsToRemove += $ctrl
            }
        }
        foreach ($ctrl in $controlsToRemove) {
            $panel.Controls.Remove($ctrl)
        }
        
        # Template name input
        $lblName = New-Object System.Windows.Forms.Label
        $lblName.Text = "Template Name:"
        $lblName.Dock = 'Top'
        $lblName.Height = 20
        $panel.Controls.Add($lblName)
        
        $txtName = New-Object System.Windows.Forms.TextBox
        $txtName.Dock = 'Top'
        $panel.Controls.Add($txtName)
        
        # Spacer
        $spacer1 = New-Object System.Windows.Forms.Panel
        $spacer1.Height = 10
        $spacer1.Dock = 'Top'
        $spacer1.BackColor = 'Transparent'
        $panel.Controls.Add($spacer1)
        
        # Selected tasks list
        $lblTasks = New-Object System.Windows.Forms.Label
        $lblTasks.Text = "Selected Tasks:"
        $lblTasks.Dock = 'Top'
        $lblTasks.Height = 20
        $panel.Controls.Add($lblTasks)
        
        $lstTasks = New-Object System.Windows.Forms.ListBox
        $lstTasks.Height = 120
        $lstTasks.Dock = 'Top'
        foreach ($item in $selectedItems) {
            $tag = $item.Tag
            $lstTasks.Items.Add($tag.Description) | Out-Null
        }
        $panel.Controls.Add($lstTasks)
        
        # Spacer
        $spacer2 = New-Object System.Windows.Forms.Panel
        $spacer2.Height = 10
        $spacer2.Dock = 'Top'
        $spacer2.BackColor = 'Transparent'
        $panel.Controls.Add($spacer2)
        
        # Save button
        $btnSave = New-Object System.Windows.Forms.Button
        $btnSave.Text = "Create Template"
        $btnSave.Dock = 'Top'
        $btnSave.Add_Click({
                $name = $txtName.Text.Trim()
                if (!$name) { 
                    $this.SetStatusMessage("Enter a name for the template.", 'Orange')
                    return 
                }
            
                # Create template content with metadata and task descriptions only
                $templateContent = @()
                $templateContent += "# Template: $name"
                $templateContent += "# Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
                $templateContent += "# Tasks: $($selectedItems.Count)"
                $templateContent += ""
            
                foreach ($item in $selectedItems) {
                    $tag = $item.Tag
                    # Only store the description (comment) - this will be matched against task cache
                    $templateContent += $tag.Description
                }
            
                # Ensure Templates directory exists
                $templatesDir = Join-Path $this.Config.DataDir "Templates"
                if (!(Test-Path $templatesDir)) {
                    New-Item -ItemType Directory -Path $templatesDir -Force | Out-Null
                }
            
                $templatePath = Join-Path $templatesDir "$name.txt"
                $templateContent | Set-Content $templatePath -Force
            
                # Reload sources to include new template
                $this.LoadSources()
                $this.LoadData()
                $this.HideSecondaryPanel()
                $this.SetStatusMessage("Template '$name' created successfully with $($selectedItems.Count) tasks.", 'Green')
            }.GetNewClosure())
        $panel.Controls.Add($btnSave)
        
        # Cancel button
        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Text = "Cancel"
        $btnCancel.Dock = 'Bottom'
        $btnCancel.Add_Click({ $this.HideSecondaryPanel() }.GetNewClosure())
        $panel.Controls.Add($btnCancel)
    }

    [bool]IsRunningFromGitHub() {
        Write-Host "[DEBUG] IsRunningFromGitHub"
        $currentScript = $MyInvocation.ScriptName
        if (!$currentScript) { $currentScript = $PSCommandPath }
        $isGitHub = $currentScript -match $this.Config.Patterns.HTTPUrl
        Write-Host "[DEBUG] Script path: $currentScript, IsGitHub: $isGitHub"
        return $isGitHub
    }

    [string]GetSourceInfo() {
        Write-Host "[DEBUG] GetSourceInfo"
        $currentScript = $MyInvocation.ScriptName
        if (!$currentScript) { $currentScript = $PSCommandPath }
        
        if ($currentScript -match $this.Config.Patterns.HTTPUrl) {
            return "$($this.Config.Owner.ToUpper())/$($this.Config.Repo.ToUpper())$($this.Config.Defaults.RemoteText)"
        }
        elseif ($currentScript -and (Test-Path $currentScript)) {
            $scriptDir = Split-Path $currentScript -Parent
            return $scriptDir
        }
        else {
            return "$($this.Config.Owner.ToUpper())/$($this.Config.Repo.ToUpper())$($this.Config.Defaults.RemoteText)"
        }
    }
    
    [void]OnFormShown() {
        Write-Host "[DEBUG] OnFormShown"
        $this.MainForm.Activate()
        $this.LoadData()
    }

    [hashtable]ReadGroupedProfile([string]$profilePath) {
        Write-Host "[DEBUG] ReadGroupedProfile $profilePath"
        # Parse a template/profile file into an ordered dictionary of groupName -> [tasks]
        $groupedTasks = [ordered]@{}
        
        if (!(Test-Path $profilePath)) { 
            Write-Warning "[DEBUG] ReadGroupedProfile - File not found: $profilePath"
            return $groupedTasks 
        }
        
        $lines = Get-Content $profilePath -ErrorAction SilentlyContinue
        if (-not $lines) { 
            Write-Warning "[DEBUG] ReadGroupedProfile - File is empty: $profilePath"
            return $groupedTasks 
        }
        
        $currentGroup = "Group 1"
        $matchedCount = 0
        $totalLines = 0
        
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            
            # Skip empty lines - they create new groups
            if ($trimmed -eq "") {
                $currentGroup = "Group $($groupedTasks.Count + 1)"
                continue
            }
            
            # Lines starting with # are group headers or comments
            if ($trimmed.StartsWith("#")) {
                $headerText = $trimmed.TrimStart("#").Trim()
                # Skip metadata comments (Template:, Created:, Tasks:)
                if ($headerText -notmatch "^(Template|Created|Tasks):\s") {
                    $currentGroup = $headerText
                }
                continue
            }
            else {
                $totalLines++
                # Try to find the task by matching the description/comment
                $task = $this.GetTaskById($trimmed)
                if ($task) {
                    if (-not $groupedTasks.Contains($currentGroup)) {
                        $groupedTasks[$currentGroup] = @()
                    }
                    $groupedTasks[$currentGroup] += $task
                    $matchedCount++
                    Write-Host "[DEBUG] ReadGroupedProfile - Matched: '$trimmed' -> '$($task.Description)'" -ForegroundColor Green
                }
                else {
                    Write-Warning "[DEBUG] ReadGroupedProfile - No task found for: '$trimmed'"
                }
            }
        }
        
        Write-Host "[DEBUG] ReadGroupedProfile - Summary: $matchedCount/$totalLines tasks matched, $($groupedTasks.Count) groups created" -ForegroundColor Cyan
        return $groupedTasks
    }

    [void]BuildTaskCache() {
        Write-Host "[DEBUG] BuildTaskCache - Building in-memory cache of all tasks"
        $this.TaskCache.Clear()
        
        foreach ($src in $this.Sources | Where-Object { $_.Type -eq 'ScriptFile' }) {
            $scriptFile = $null  # Declare at foreach level
            try {
                $scriptContent = $null
                
                if ($src -is [LocalScriptFileSource]) {
                    $scriptFile = $src.FilePath
                    # Check if this is a remote file (URL-like path) or local file
                    if ($scriptFile -match $this.Config.Patterns.HTTPUrl -or !(Test-Path $scriptFile)) {
                        # This is a remote file reference
                        $scriptFile = $src.RelativePath
                    }
                }
                else {
                    $scriptFile = $src.Name
                }
                
                # Try to read local file first (only if it's a real local path)
                if ($scriptFile -and (Test-Path $scriptFile) -and $scriptFile -notmatch $this.Config.Patterns.HTTPUrl) {
                    $scriptContent = Get-Content $scriptFile -Raw
                    Write-Host "[DEBUG] BuildTaskCache - Read local file: $scriptFile" -ForegroundColor Green
                }
                
                # Fallback to remote file or if running from GitHub
                if (!$scriptContent) {
                    $scriptUrl = "$($this.Config.URLs.GitHubRaw)/$($this.Config.Owner)/$($this.Config.Repo)/refs/heads/$($this.Config.Branch)/$scriptFile"
                    try { 
                        $scriptContent = (Invoke-WebRequest $scriptUrl -ErrorAction Stop).Content 
                        Write-Host "[DEBUG] BuildTaskCache - Downloaded remote file: $scriptFile" -ForegroundColor Cyan
                    }
                    catch { 
                        Write-Host "[DEBUG] BuildTaskCache - Failed to download: $scriptFile" -ForegroundColor Yellow
                        $scriptContent = $null 
                    }
                }
                
                if ($scriptContent) {
                    $parsed = $this.ParseScriptFile($scriptContent, $scriptFile)
                    foreach ($task in $parsed) {
                        # Index by description (comment text) for template matching
                        $key = $task.Description.Trim()
                        if ($key -and !$this.TaskCache.ContainsKey($key)) {
                            $this.TaskCache[$key] = $task
                            Write-Host "[DEBUG] BuildTaskCache - Cached task: '$key'" -ForegroundColor DarkGreen
                        }
                    }
                    Write-Host "[DEBUG] BuildTaskCache - Processed $($parsed.Count) tasks from: $scriptFile" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "[DEBUG] BuildTaskCache - Error processing $scriptFile : $_"
            }
        }
        
        Write-Host "[DEBUG] BuildTaskCache - Total cached tasks: $($this.TaskCache.Count)" -ForegroundColor Green
    }

    [hashtable]GetTaskById([string]$id) {
        Write-Host "[DEBUG] GetTaskById: '$id'" -ForegroundColor Cyan
        
        # Clean the input ID
        $cleanId = $id.Trim()
        
        # Try exact match first
        if ($this.TaskCache.ContainsKey($cleanId)) {
            Write-Host "[DEBUG] GetTaskById - Found exact match for: '$cleanId'" -ForegroundColor Green
            return $this.TaskCache[$cleanId]
        }
        
        # Try case-insensitive partial match
        foreach ($key in $this.TaskCache.Keys) {
            if ($key -like "*$cleanId*" -or $cleanId -like "*$key*") {
                Write-Host "[DEBUG] GetTaskById - Found partial match: '$key' for '$cleanId'" -ForegroundColor Yellow
                return $this.TaskCache[$key]
            }
        }
        
        Write-Host "[DEBUG] GetTaskById - No match found for: '$cleanId'" -ForegroundColor Red
        return $null
    }

    [void]OnRefresh() {
        Write-Host "[DEBUG] Refresh requested"
        $lv = $this.Controls.ScriptsListView
        foreach ($item in $lv.Items) {
            $item.SubItems[3].Text = $this.Config.Messages.Ready
            $item.BackColor = $this.Config.Colors.White
        }
        $this.Controls.StatusLabel.Text = $this.Config.Messages.Ready
        $this.Controls.StatusProgressBar.Visible = $false
        if ($this.Controls.ContainsKey("RefreshBtn")) {
            $this.Controls["RefreshBtn"].Enabled = $false
        }
        # Optionally, notify other parts of the app
        if ($this.OnRefreshed -is [scriptblock]) {
            & $this.OnRefreshed
        }
    }

    [void]OnCancelExecution() {
        Write-Host "[DEBUG] OnCancelExecution"
        $this.State.CancelRequested = $true
        if ($this.Controls.ContainsKey("CancelBtn")) {
            $this.Controls["CancelBtn"].Enabled = $false
            $this.Controls["CancelBtn"].Visible = $false
        }
        $this.Controls.StatusLabel.Text = $this.Config.Messages.CancelledByUser
        $this.Controls.StatusProgressBar.Visible = $false
        if ($this.Controls.ContainsKey("RefreshBtn")) {
            $this.Controls["RefreshBtn"].Enabled = $true
            $this.Controls["RefreshBtn"].Visible = $true
        }
        # Optionally, notify other parts of the app
        if ($this.OnExecutionCancelled -is [scriptblock]) {
            & $this.OnExecutionCancelled
        }
    }

    # Status management methods
    [void]SetStatusMessage([string]$message, [string]$color = 'Black') {
        Write-Host "[DEBUG] SetStatusMessage: $message"
        $this.Controls.StatusLabel.Text = $message
        $this.Controls.StatusLabel.ForeColor = $color
    }

    [void]ResetStatus() {
        Write-Host "[DEBUG] ResetStatus"
        $this.Controls.StatusLabel.Text = $this.Config.Messages.Ready
        $this.Controls.StatusLabel.ForeColor = 'Black'
    }

    # UI Helper methods
    [void]RefreshUI() {
        # Allow brief pause for UI to update naturally
        # This is more PowerShell-native than DoEvents()
        Start-Sleep -Milliseconds 1
    }

    [void]ShowSecondaryPanel([string]$title) {
        Write-Host "[DEBUG] ShowSecondaryPanel: $title"
        $this.Controls.SecondaryLabel.Text = $title
        $this.Controls.SecondaryContent.Visible = $true
    }

    [void]HideSecondaryPanel() {
        Write-Host "[DEBUG] HideSecondaryPanel"
        $this.Controls.SecondaryContent.Visible = $false
    }

    [void]OnCloseSecondary() {
        Write-Host "[DEBUG] OnCloseSecondary"
        $this.HideSecondaryPanel()
    }

    [void]MoveListViewItem($ListView, $Item, [int]$TargetIndex, [bool]$AppearsAfter = $false) {
        Write-Host "[DEBUG] MoveListViewItem: Moving '$($Item.Text)' from index $($Item.Index) to target index $TargetIndex (AppearsAfter: $AppearsAfter)"
        
        $currentIndex = $Item.Index
        $insertIndex = if ($AppearsAfter) { $TargetIndex + 1 } else { $TargetIndex }

        Write-Host "[DEBUG] Current Index: $currentIndex, Calculated Insert Index: $insertIndex"

        # Don't move if it's the same position
        if ($currentIndex -eq $insertIndex) {
            Write-Host "[DEBUG] Move cancelled - same position"
            return
        }

        # Store item data
        $itemData = @{
            Text        = $Item.Text
            SubItems    = @($Item.SubItems | ForEach-Object { $_.Text })
            Checked     = $Item.Checked
            BackColor   = $Item.BackColor
            ForeColor   = $Item.ForeColor
            Font        = $Item.Font
            Group       = $Item.Group
            Tag         = $Item.Tag
            ToolTipText = $Item.ToolTipText
        }

        $ListView.BeginUpdate()
        try {
            # Remove the item first
            $ListView.Items.RemoveAt($currentIndex)
            Write-Host "[DEBUG] Item removed from index: $currentIndex"
            
            # Adjust insert index if the removed item was before the target
            if ($insertIndex -gt $currentIndex) {
                $insertIndex--
                Write-Host "[DEBUG] Insert index adjusted to: $insertIndex (removed item was before target)"
            }
            
            # Clamp to valid range
            if ($insertIndex -gt $ListView.Items.Count) {
                $insertIndex = $ListView.Items.Count
                Write-Host "[DEBUG] Insert index clamped to list end: $insertIndex"
            }

            Write-Host "[DEBUG] Final insert index: $insertIndex"

            # Create new item
            $newItem = New-Object System.Windows.Forms.ListViewItem($itemData.Text)
            for ($i = 1; $i -lt $itemData.SubItems.Count; $i++) {
                $newItem.SubItems.Add($itemData.SubItems[$i]) | Out-Null
            }
            $newItem.Checked = $itemData.Checked
            $newItem.BackColor = $itemData.BackColor
            $newItem.ForeColor = $itemData.ForeColor
            $newItem.Font = $itemData.Font
            $newItem.Tag = $itemData.Tag
            $newItem.ToolTipText = $itemData.ToolTipText

            # Handle group assignment
            if ($ListView.Groups.Count -gt 0) {
                if ($insertIndex -lt $ListView.Items.Count) {
                    $targetItem = $ListView.Items[$insertIndex]
                    $newItem.Group = $targetItem.Group
                }
                elseif ($ListView.Items.Count -gt 0) {
                    $lastItem = $ListView.Items[$ListView.Items.Count - 1]
                    $newItem.Group = $lastItem.Group
                }
                else {
                    $newItem.Group = $itemData.Group
                }
            }

            # Insert the item
            if ($insertIndex -ge $ListView.Items.Count) {
                $ListView.Items.Add($newItem) | Out-Null
                Write-Host "[DEBUG] Item added at end of list"
            }
            else {
                $ListView.Items.Insert($insertIndex, $newItem) | Out-Null
                Write-Host "[DEBUG] Item inserted at index: $insertIndex"
            }

            # Select the moved item
            $ListView.SelectedItems.Clear()
            $newItem.Selected = $true
            $newItem.EnsureVisible()
            
            Write-Host "[DEBUG] Move completed - Item moved to index $($newItem.Index)"
        }
        finally {
            $ListView.EndUpdate()
            $this.UpdateExecuteButtonText()
        }
    }

    [void]MoveSelectedItemUp() {
        Write-Host "[DEBUG] MoveSelectedItemUp"
        $lv = $this.Controls.ScriptsListView
        if ($lv.SelectedItems.Count -eq 0) { 
            $this.SetStatusMessage("Please select an item to move up.", 'Orange')
            return 
        }

        $selectedItem = $lv.SelectedItems[0]
        $currentIndex = $selectedItem.Index

        if ($currentIndex -gt 0) {
            $this.MoveListViewItem($lv, $selectedItem, $currentIndex - 1, $false)
        }
    }

    [void]MoveSelectedItemDown() {
        Write-Host "[DEBUG] MoveSelectedItemDown"
        $lv = $this.Controls.ScriptsListView
        if ($lv.SelectedItems.Count -eq 0) { 
            $this.SetStatusMessage("Please select an item to move down.", 'Orange')
            return 
        }

        $selectedItem = $lv.SelectedItems[0]
        $currentIndex = $selectedItem.Index

        if ($currentIndex -lt $lv.Items.Count - 1) {
            $this.MoveListViewItem($lv, $selectedItem, $currentIndex + 1, $true)
        }
    }

    [void]OnColumnClick($listView, $e) {
        Write-Host "[DEBUG] OnColumnClick: Column $($e.Column)"
        
        # Initialize sorting state if not exists
        if (-not $this.State.ContainsKey('SortColumn')) {
            $this.State.SortColumn = -1
            $this.State.SortOrder = 'Ascending'
        }
        
        $columnIndex = $e.Column
        $column = $listView.Columns[$columnIndex]
        
        # Determine sort order
        if ($this.State.SortColumn -eq $columnIndex) {
            # Same column clicked, toggle sort order
            $this.State.SortOrder = if ($this.State.SortOrder -eq 'Ascending') { 'Descending' } else { 'Ascending' }
        }
        else {
            # Different column clicked, default to ascending
            $this.State.SortColumn = $columnIndex
            $this.State.SortOrder = 'Ascending'
        }
        
        # Update column headers with sort indicators
        foreach ($col in $listView.Columns) {
            $originalText = $col.Text -replace ' [\^v]', ''
            $col.Text = $originalText
        }
        
        # Add sort indicator to current column
        $sortIndicator = if ($this.State.SortOrder -eq 'Ascending') { ' ^' } else { ' v' }
        $column.Text = $column.Text + $sortIndicator
        
        # Perform the sort
        $this.SortListView($listView, $columnIndex, $this.State.SortOrder)
    }

    [void]SortListView($listView, [int]$columnIndex, [string]$sortOrder) {
        Write-Host "[DEBUG] SortListView: Column $columnIndex, Order $sortOrder"
        
        $listView.BeginUpdate()
        try {
            # Get all items with their data
            $items = @()
            foreach ($item in $listView.Items) {
                $sortValue = if ($columnIndex -lt $item.SubItems.Count) { 
                    $item.SubItems[$columnIndex].Text 
                }
                else { 
                    $item.Text 
                }
                
                $items += @{
                    Item         = $item
                    SortValue    = $sortValue
                    OriginalData = @{
                        Text        = $item.Text
                        SubItems    = @($item.SubItems | ForEach-Object { $_.Text })
                        Checked     = $item.Checked
                        BackColor   = $item.BackColor
                        ForeColor   = $item.ForeColor
                        Font        = $item.Font
                        Group       = $item.Group
                        Tag         = $item.Tag
                        ToolTipText = $item.ToolTipText
                    }
                }
            }
            
            # Sort the items
            if ($sortOrder -eq 'Ascending') {
                $items = $items | Sort-Object { $_.SortValue }
            }
            else {
                $items = $items | Sort-Object { $_.SortValue } -Descending
            }
            
            # Clear and rebuild the ListView
            $listView.Items.Clear()
            
            foreach ($itemData in $items) {
                $newItem = New-Object System.Windows.Forms.ListViewItem($itemData.OriginalData.Text)
                for ($i = 1; $i -lt $itemData.OriginalData.SubItems.Count; $i++) {
                    $newItem.SubItems.Add($itemData.OriginalData.SubItems[$i]) | Out-Null
                }
                $newItem.Checked = $itemData.OriginalData.Checked
                $newItem.BackColor = $itemData.OriginalData.BackColor
                $newItem.ForeColor = $itemData.OriginalData.ForeColor
                $newItem.Font = $itemData.OriginalData.Font
                $newItem.Group = $itemData.OriginalData.Group
                $newItem.Tag = $itemData.OriginalData.Tag
                $newItem.ToolTipText = $itemData.OriginalData.ToolTipText
                
                $listView.Items.Add($newItem) | Out-Null
            }
            
            Write-Host "[DEBUG] Sort completed - $($items.Count) items sorted"
        }
        finally {
            $listView.EndUpdate()
            $this.UpdateExecuteButtonText()
        }
    }
}

# Register built-in sources before app creation
[PSUtilApp]::RegisterSourceType("ScriptFile", {
        param($app)
        $config = $app.Config
        $currentScript = $MyInvocation.ScriptName; if (!$currentScript) { $currentScript = $PSCommandPath }
        
        if ($currentScript -match $config.Patterns.HTTPUrl) {
            # Running from GitHub - scan remote repository
            Write-Host "[DEBUG] Running from GitHub, scanning remote repository" -ForegroundColor Green
            try {
                $remoteFiles = $app.GetRemoteScriptFilesRecursive("")
                Write-Host "[DEBUG] Found $($remoteFiles.Count) remote script files" -ForegroundColor Green
                $remoteFiles | Where-Object { $config.ScriptFilesBlacklist -notcontains $_ } |
                ForEach-Object {
                    Write-Host "[DEBUG] Registering remote script: $_" -ForegroundColor Cyan
                    [LocalScriptFileSource]::new($app, $_, $_)  # Remote files use relative path as both full and relative
                }
            }
            catch {
                Write-Warning "[DEBUG] Failed to scan remote repository: $_"
                # Fallback to empty array if GitHub scanning fails
                @()
            }
        }
        else {
            # Running locally - scan local directory
            Write-Host "[DEBUG] Running locally, scanning local directory" -ForegroundColor Green
            $scriptDir = Split-Path $currentScript -Parent
            @(Get-ChildItem -Path $scriptDir -Filter $config.ScriptExtensions.Local[0] -File -Recurse -ErrorAction SilentlyContinue) |
            Where-Object {
                $rel = $_.FullName.Substring($scriptDir.Length + 1).Replace($config.SourceInfo.BackslashSeparator, $config.SourceInfo.SlashSeparator)
                $config.ScriptFilesBlacklist -notcontains $rel
            } |
            ForEach-Object {
                $rel = $_.FullName.Substring($scriptDir.Length + 1).Replace($config.SourceInfo.BackslashSeparator, $config.SourceInfo.SlashSeparator)
                [LocalScriptFileSource]::new($app, $_.FullName, $rel)
            }
        }
    })

# Main execution block
try {
    # Create the application and show it
    $app = [PSUtilApp]::new()
    [void]$app.MainForm.ShowDialog()
}
catch {
    $errorMessage = "$($Global:Config.Messages.FatalError)$_"
    $traceInfo = "$($Global:Config.Messages.StackTrace)$($_.ScriptStackTrace)"
    
    Write-Error $errorMessage
    Write-Error $traceInfo
    
    # Show error using PowerShell's native notification
    try {
        # Try to use Windows Toast notification if BurntToast module is available
        if (Get-Module -ListAvailable -Name BurntToast) {
            Import-Module BurntToast -ErrorAction SilentlyContinue
            New-BurntToastNotification -Text "PSUtil Error", $errorMessage -AppLogo $null -Silent
        }
        else {
            throw "BurntToast not available"
        }
    }
    catch {
        # Fallback to simple console output
        Write-Host $errorMessage -ForegroundColor Red
        Write-Host $traceInfo -ForegroundColor Red
        Write-Host "Press any key to continue..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}