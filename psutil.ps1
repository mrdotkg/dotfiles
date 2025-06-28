# Load required assemblies first - MUST be at the very beginning for iex compatibility
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# PowerShell GUI utility for executing scripts from GitHub repository
# Features: PS1 script files with embedded metadata, Multiple execution modes, Multi-script collections support

[System.Windows.Forms.Application]::EnableVisualStyles()

# Configuration - All constants and strings centralized for modularity
$Global:Config = @{
    ScriptFilesBlacklist = @("gui.ps1", "psutil.ps1", "taaest.ps1")
    # Repository settings
    Owner                = "mrdotkg"
    Repo                 = "dotfiles" 
    Branch               = "main"
    DbFile               = "db.ps1"
    
    # Paths and directories
    DataDir              = "$env:USERPROFILE\Documents\PSUtil Local Data"
    SubDirs              = @("Collections", "Logs", "Scripts")
    SSHConfigPath        = "$env:USERPROFILE\.ssh\config"
    
    # UI Settings
    Window               = @{
        Title               = "Executor"
        Width               = 600
        Height              = 600
        BackgroundColor     = [System.Drawing.Color]::FromArgb(241, 243, 249)
        AccentColorFallback = [System.Drawing.Color]::FromArgb(44, 151, 222)
        Position            = "Manual"
        Padding             = '5,5,5,5'
    }
    
    # Panel dimensions
    Panels               = @{
        ToolbarHeight       = 35
        StatusBarHeight     = 25
        SidebarWidth        = 150
        SecondaryPanelWidth = 300
        SplitterWidth       = 3
        ContentPadding      = '0, 0, 0, 0' # Left, Top, Right, Bottom padding for content area
        ToolbarPadding      = '0, 5, 0, 5' # Left, Top, Right, Bottom padding for toolbar
        StatusPadding       = '0, 0, 0, 0' # Left, Top, Right, Bottom padding for status bar
        SidebarPadding      = '5, 0, 0, 0' # Left, Top, Right, Bottom padding for sidebar
        SecondaryPadding    = '0, 2, 0, 0' # Left, Top, Right, Bottom padding for secondary panel
    }
    
    # Control dimensions and text
    Controls             = @{
        # Standard dimensions for consistency
        Dock               = 'Left'
        Width              = 120
        Height             = 25
        Padding            = '0, 0, 0, 0' # Left, Top, Right, Bottom padding
        BackColor          = [System.Drawing.Color]::White # Default control background color    
        ForeColor          = [System.Drawing.Color]::Black # Default control foreground color
        # Font settings to control ComboBox height
        FontName           = "Segoe UI"
        FontSize           = 10.0
        
        # Control text
        SelectAllText      = "Check All"
        ExecuteBtnText     = "▶ Run 0"
        ExecuteBtnTemplate = "▶ Run {0}"
        FilterPlaceholder  = "Filter..."
        
        # Sidebar button texts
        CopyCommandText    = "Copy"
        RunLaterText       = "Schedule Later"
        AddCommandText     = "Save To Collection"
    }
    
    # ListView columns
    ListView             = @{
        Columns = @(
            @{ Name = "Script"; Width = 300 }
            @{ Name = "Command"; Width = 100 }
            @{ Name = "File"; Width = 100 }
            @{ Name = "Status"; Width = 100 }
        )
    }
    
    # Script file extensions
    ScriptExtensions     = @{
        Remote = @('.ps1', '.sh', '.bash', '.py', '.rb', '.js', '.bat', '.cmd')
        Local  = @('*.ps1', '*.sh', '*.py', '*.rb', '*.js', '*.bat', '*.cmd')
    }
    
    # File extensions and patterns
    FileExtensions       = @{
        Text          = "*.txt"
        TextExtension = ".txt"
    }
    
    # Default values and text constants
    Defaults             = @{
        CollectionDefault  = "All Commands"
        CollectionContent  = "# All Commands - Multiple Script Files`ndb.ps1`n# Add more script files below"
        FallbackScript     = "db.ps1"
        FilesComboDefault  = "All Scripts"
        CurrentUserText    = "As $env:USERNAME (Active)"
        AdminText          = "As Admin"
        OtherUserText      = "Other User..."
        ExecutionModes     = @("CurrentUser", "Admin")
        LocalhostName      = "localhost"
        FilePrefix         = ""
        LocalText          = " (Local)"
        RemoteText         = " (Remote)"
        GitHubText         = " (GitHub)"
        LocalMachinePrefix = ""
        LocalMachineText   = " (Local)"
        SSHCommandPrefix   = "ssh "
        SudoCommand        = "sudo "
        SudoUserCommand    = "sudo -u "
        AsPrefix           = "As "
        CurrentUserMode    = "CurrentUser"
        AdminMode          = "Admin"
        PowerShellCommand  = "powershell"
        CommandArgument    = "-Command"
        RunAsVerb          = "RunAs"
        WaitParameter      = "-Wait"
    }
    
    # Status messages
    Messages             = @{
        NoScriptsSelected  = "No scripts selected."
        ExecutionError     = "Execution error: "
        FatalError         = "Fatal error: "
        FatalErrorTitle    = "Fatal Error"
        StackTrace         = "Stack trace: "
        InitError          = "Error during PSUtilApp initialization: "
        LoadError          = "Error loading script files: "
        GitHubError        = "Could not fetch script files from GitHub: "
        LocalError         = "Error scanning local directory for script files: "
        CollectionError    = "Failed to load collection scripts: "
        ScriptFileError    = "Failed to load script file: "
        ExecuteAsAdmin     = "Executed as Administrator"
        ExecuteAsUser      = "Executed as "
        CancelledByUser    = "Cancelled by user"
        CredentialsPrompt  = "Enter credentials for script execution"
        UserPasswordPrompt = "Enter password for "
        Running            = "Running..."
        Ready              = "Ready"
        Completed          = "Completed"
        Failed             = "Failed"
        ExecuteFileDesc    = "Execute "
        LoadScriptError    = "Failed to load script file: "
    }
    
    # Status colors
    Colors               = @{
        Ready     = [System.Drawing.Color]::Black
        Running   = [System.Drawing.Color]::LightYellow
        Completed = [System.Drawing.Color]::LightGreen
        Failed    = [System.Drawing.Color]::LightCoral
        Filtered  = [System.Drawing.Color]::LightGray
        Text      = [System.Drawing.Color]::Black
        White     = [System.Drawing.Color]::White
    }
    
    # Regex patterns
    Patterns             = @{
        SSHHost           = '^Host\s+(.+)$'
        SSHExclude        = '[*?]'
        InlineComments    = '^\s*#'
        MultiLineComments = '<#([\s\S]*?)#>'
        CommentLine       = '^#'
        HTTPUrl           = '^https?://'
        CommentPrefix     = '#'
        WhitespacePattern = '\s+'
        NewlinePattern    = "`n"
    }
    
    # API URLs
    URLs                 = @{
        GitHubAPI = "https://api.github.com/repos"
        GitHubRaw = "https://raw.githubusercontent.com"
    }
    
    # Registry paths
    Registry             = @{
        AccentColor      = "HKCU:\Software\Microsoft\Windows\DWM"
        AccentColorValue = "AccentColor"
    }
    
    # Source info constants
    SourceInfo           = @{
        ErrorFetchingDir   = "Error fetching directory "
        DirectoryTypes     = @{
            File = "file"
            Dir  = "dir"
        }
        SlashSeparator     = "/"
        BackslashSeparator = "\"
        RefSeparator       = "/refs/heads/"
    }
}

class PSUtilApp {
    # Core properties
    [string]$Owner; [string]$Repo; [string]$Branch; [string]$DbFile; [string]$DataDir
    [hashtable]$Config; [hashtable]$Controls = @{}; [array]$Machines = @(); [array]$Collections = @(); [array]$ScriptFiles = @()
    [array]$SelectedScriptFiles = @(); [string]$CurrentMachine; [string]$CurrentCollection; [bool]$IsExecuting
    [string]$ExecutionMode = "CurrentUser"; [bool]$IsSecondaryPanelVisible = $false; $MainForm; $StatusLabel; $StatusProgressBar;

    PSUtilApp() {
        $this.Config = $Global:Config
        $this.Owner = $this.Config.Owner
        $this.Repo = $this.Config.Repo
        $this.Branch = $this.Config.Branch
        $this.DbFile = $this.Config.DbFile
        $this.DataDir = $this.Config.DataDir
        $this.Initialize()
        $this.CreateInterface()
    }

    [void]Initialize() {
        # Setup directories using config
        @($this.DataDir) + ($this.Config.SubDirs | ForEach-Object { "$($this.DataDir)\$_" }) | 
        ForEach-Object { if (!(Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null } }
        
        # Load machines
        $this.Machines = @(@{ Name = $env:COMPUTERNAME; DisplayName = "$($this.Config.Defaults.LocalMachinePrefix)$env:COMPUTERNAME$($this.Config.Defaults.LocalMachineText)"; Type = $this.Config.Defaults.LocalText.Trim() })
        $this.CurrentMachine = $env:COMPUTERNAME
        if ((Test-Path $this.Config.SSHConfigPath)) {
            (Get-Content $this.Config.SSHConfigPath -ErrorAction SilentlyContinue) | ForEach-Object {
                if ($_ -match $this.Config.Patterns.SSHHost -and $Matches[1] -notmatch $this.Config.Patterns.SSHExclude -and $Matches[1] -ne $this.Config.Defaults.LocalhostName) {
                    $this.Machines += @{ Name = $Matches[1]; DisplayName = "$($this.Config.Defaults.LocalMachinePrefix)$($Matches[1])"; Type = "SSH" }
                }
            }
        }
        
        $this.LoadScriptFiles()
        $this.LoadCollections()
    }

    [void]LoadScriptFiles() {
        $this.ScriptFiles = @()
        try {
            $sourceInfo = $this.GetSourceInfo()
            if ($sourceInfo.Contains("(Local)")) {
                $scriptDir = $sourceInfo.Replace(" (Local)", "")
                $this.LoadLocalScriptFiles($scriptDir)
            }
            else {
                $this.LoadRemoteScriptFiles()
            }
        }
        catch {
            Write-Warning "$($this.Config.Messages.LoadError)$_"
            $this.ScriptFiles = @($this.Config.Defaults.FallbackScript)
        }
        # Remove blacklisted files from $this.ScriptFiles
        if ($this.Config.ScriptFilesBlacklist) {
            $blacklist = $this.Config.ScriptFilesBlacklist
            $this.ScriptFiles = $this.ScriptFiles | Where-Object { $blacklist -notcontains $_ }
        }
    }
    
    [void]LoadRemoteScriptFiles() {
        try {
            $this.ScriptFiles = $this.GetRemoteScriptFilesRecursive("")
        }
        catch { 
            Write-Warning "$($this.Config.Messages.GitHubError)$_"
            $this.ScriptFiles = @($this.Config.Defaults.FallbackScript)
        }
    }
    
    [array]GetRemoteScriptFilesRecursive([string]$path) {
        $files = @()
        try {
            $url = if ($path) { "$($this.Config.URLs.GitHubAPI)/$($this.Owner)/$($this.Repo)/contents/$path" } 
            else { "$($this.Config.URLs.GitHubAPI)/$($this.Owner)/$($this.Repo)/contents" }
            $apiResponse = Invoke-WebRequest $url | ConvertFrom-Json
            foreach ($item in $apiResponse) {
                if ($item.type -eq $this.Config.SourceInfo.DirectoryTypes.File -and $this.Config.ScriptExtensions.Remote -contains [System.IO.Path]::GetExtension($item.name)) {
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
    
    [void]LoadLocalScriptFiles([string]$directory) {
        try {
            foreach ($ext in $this.Config.ScriptExtensions.Local) {
                $files = Get-ChildItem -Path $directory -Filter $ext -File -Recurse -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    $relativePath = $file.FullName.Substring($directory.Length + 1).Replace($this.Config.SourceInfo.BackslashSeparator, $this.Config.SourceInfo.SlashSeparator)
                    if ($this.ScriptFiles -notcontains $relativePath) { $this.ScriptFiles += $relativePath }
                }
            }
            if ($this.ScriptFiles.Count -eq 0) { $this.ScriptFiles = @($this.Config.Defaults.FallbackScript) }
        }
        catch {
            Write-Warning "$($this.Config.Messages.LocalError)$_"
            $this.ScriptFiles = @($this.Config.Defaults.FallbackScript)
        }
    }

    [void]LoadCollections() {
        $collectionsDir = "$($this.DataDir)\$($this.Config.SubDirs[0])"
        $this.Collections = if ((Test-Path $collectionsDir)) { (Get-ChildItem $collectionsDir -Filter $this.Config.FileExtensions.Text).BaseName } else { @() }
        $defaultCollection = "$collectionsDir\$($this.Config.Defaults.CollectionDefault)"
        if (!(Test-Path $defaultCollection)) { 
            $this.Config.Defaults.CollectionContent | Set-Content $defaultCollection -Force
            $this.Collections += ($this.Config.Defaults.CollectionFile -replace $this.Config.FileExtensions.TextExtension, '') 
        }
        $this.CurrentCollection = if ($this.Collections.Count -gt 0) { $this.Collections[0] } else { $null }
    }

    [void]CreateInterface() {
        $sourceInfo = $this.GetSourceInfo()
        $createdControls = @{}
        $app = $this

        # Main Form
        $this.MainForm = New-Object System.Windows.Forms.Form -Property @{
            Text = "$($this.Config.Window.Title) - $([System.IO.Path]::GetFileName($sourceInfo))";
            Size = New-Object System.Drawing.Size($this.Config.Window.Width, $this.Config.Window.Height)
            Padding = $this.Config.Window.Padding
            StartPosition = $this.Config.Window.Position; BackColor = $this.Config.Window.BackgroundColor
            Add_Shown = { $app.OnFormShown() }
        }
        
        # Define controls with order for proper placement and future drag-drop
        $controlDefs = @{
            # Main Layout Panels (Order 1-5)
            Toolbar           = @{ Type = 'Panel'; Order = 1; Layout = 'Form'; Properties = @{ Dock = 'Top'; Height = $this.Config.Panels.ToolbarHeight; Padding = $this.Config.Panels.ToolbarPadding } }
            StatusBar         = @{ Type = 'Panel'; Order = 2; Layout = 'Form'; Properties = @{ Dock = 'Bottom'; Height = $this.Config.Panels.StatusBarHeight; Padding = $this.Config.Panels.StatusPadding } }
            Sidebar           = @{ Type = 'Panel'; Order = 3; Layout = 'Form'; Properties = @{ Dock = 'Right'; Width = $this.Config.Panels.SidebarWidth; Padding = $this.Config.Panels.SidebarPadding; Visible = $false } }
            MainContent       = @{ Type = 'Panel'; Order = 4; Layout = 'Form'; Properties = @{ Dock = 'Fill'; Padding = '0, 0, 0, 0' } }
            
            # Content Layout with Splitter (Order 5-8) - SecondaryContent first, then splitter, then PrimaryContent fills
            SecondaryContent  = @{ Type = 'Panel'; Order = 5; Layout = 'MainContent'; Properties = @{ Dock = 'Right'; BackColor = $this.Config.Colors.White; Width = $this.Config.Panels.SecondaryPanelWidth; Padding = $this.Config.Panels.SecondaryPadding; Visible = $false } }
            ContentSplitter   = @{ Type = 'Splitter'; Order = 6; Layout = 'MainContent'; Properties = @{ Dock = 'Right'; Width = $this.Config.Panels.SplitterWidth; Visible = $false; BackColor = [System.Drawing.Color]::LightGray; BorderStyle = 'FixedSingle' } }
            PrimaryContent    = @{ Type = 'Panel'; Order = 7; Layout = 'MainContent'; Properties = @{ Dock = 'Fill'; Padding = $this.Config.Panels.ContentPadding } }
            
            # Toolbar controls (Order 10-70) - Left to Right: Select All, Filter, Spacers, Execute, Combos
            SelectAllCheckBox = @{ Type = 'CheckBox'; Order = 10; Layout = 'Toolbar'; Properties = @{ Text = $this.Config.Controls.SelectAllText; Width = '100'; Dock = 'Left'; Padding = '6,2,0,1' } } 
            FilterText        = @{ Type = 'TextBox'; Order = 20; Layout = 'Toolbar'; Properties = @{ PlaceholderText = $this.Config.Controls.FilterPlaceholder } }
            MoreBtn           = @{ Type = 'Button'; Order = 30; Layout = 'Toolbar'; Properties = @{ Text = '≡'; Width = 30; Dock = 'Right' } }
            ExecuteBtn        = @{ Type = 'Button'; Order = 40; Layout = 'Toolbar'; Properties = @{ Text = $this.Config.Controls.ExecuteBtnText; Dock = 'Right' } }
            
            # Sidebar controls (Order 80-89)
            CopyCommandBtn    = @{ Type = 'Button'; Order = 80; Layout = 'Sidebar'; Properties = @{ Text = $this.Config.Controls.CopyCommandText; Dock = 'Top'; TextAlign = 'MiddleLeft' } }
            RunLaterBtn       = @{ Type = 'Button'; Order = 81; Layout = 'Sidebar'; Properties = @{ Text = $this.Config.Controls.RunLaterText; Dock = 'Top'; TextAlign = 'MiddleLeft' } }
            AddCommandBtn     = @{ Type = 'Button'; Order = 82; Layout = 'Sidebar'; Properties = @{ Text = $this.Config.Controls.AddCommandText; Dock = 'Top'; TextAlign = 'MiddleLeft' } }
            # SpacerPanel1      = @{ Type = 'Panel'; Order = 44; Layout = 'Sidebar'; Properties = @{ Width = $this.Config.Controls.Width / 3; BackColor = 'Transparent'; Dock = 'Top' } }
            ExecuteModeCombo  = @{ Type = 'ComboBox'; Order = 45; Layout = 'Sidebar'; Properties = @{ Dock = 'Top' } }
            MachineCombo      = @{ Type = 'ComboBox'; Order = 50; Layout = 'Sidebar'; Properties = @{ Dock = 'Top' } }
            FilesCombo        = @{ Type = 'ComboBox'; Order = 60; Layout = 'Sidebar'; Properties = @{ Dock = 'Top' } }
            CollectionCombo   = @{ Type = 'ComboBox'; Order = 70; Layout = 'Sidebar'; Properties = @{ Dock = 'Top' } }
            SpacerPanel2      = @{ Type = 'Panel'; Order = 75; Layout = 'Sidebar'; Properties = @{ Width = $this.Config.Controls.Width / 3; BackColor = 'Transparent'; Dock = 'Top'; } }
            
            # Primary content controls (Order 100+)
            ScriptsListView   = @{ Type = 'ListView'; Order = 100; Layout = 'PrimaryContent'; Properties = @{ Dock = 'Fill'; View = 'Details'; GridLines = $true; BorderStyle = 'None'; CheckBoxes = $true; FullRowSelect = $true } }
            
            # Secondary content controls (Order 200+) - Will be added dynamically based on selected tool
            SecondaryLabel    = @{ Type = 'Label'; Order = 200; Layout = 'SecondaryContent'; Properties = @{ Text = 'Secondary Panel'; Dock = 'Top'; Height = 30; TextAlign = 'MiddleCenter'; Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold) } }
            CloseSecondaryBtn = @{ Type = 'Button'; Order = 201; Layout = 'SecondaryContent'; Properties = @{ Text = '✕'; Dock = 'Top'; Height = 25; FlatStyle = 'Flat'; TextAlign = 'MiddleCenter'; BackColor = [System.Drawing.Color]::LightCoral; ForeColor = $this.Config.Colors.White; Add_Click = { $app.HideSecondaryPanel() }; } }
        }


        # Create controls in order
        $controlDefs.GetEnumerator() | Sort-Object { $_.Value.Order } | ForEach-Object {
            $name = $_.Key
            $config = $_.Value

            $ctrl = New-Object "System.Windows.Forms.$($config.Type)"

            # Apply standard parameters as defaults (can be overridden by control-specific properties)
            $ctrl.Font = New-Object System.Drawing.Font($this.Config.Controls.FontName, $this.Config.Controls.FontSize)
            $ctrl.Dock = $this.Config.Controls.Dock
            $ctrl.Width = $this.Config.Controls.Width
            $ctrl.Height = $this.Config.Controls.Height
            $ctrl.Padding = $this.Config.Controls.Padding
            $ctrl.BackColor = $this.Config.Controls.BackColor
            $ctrl.ForeColor = $this.Config.Controls.ForeColor

            # Apply ComboBox-specific defaults
            if ($config.Type -eq 'ComboBox') {
                $ctrl.DropDownStyle = 'DropDownList'
            }

            # Apply Splitter-specific defaults
            if ($config.Type -eq 'Splitter') {
                $ctrl.MinExtra = 100
                $ctrl.MinSize = 100
            }

            # Panel-specific defaults
            if ($config.Type -eq 'Panel' -or $config.Type -eq 'CheckBox') {
                $ctrl.BackColor = $this.MainForm.BackColor
            }

            # Apply control-specific properties (these override the defaults above)
            foreach ($kv in $config.Properties.GetEnumerator()) {
                # Only assign if not an event property (Add_Click, Add_TextChanged, etc.)
                if ($kv.Key -notmatch '^Add_') {
                    $ctrl.($kv.Key) = $kv.Value
                }
            }

            $createdControls[$name] = $ctrl
        }

        # Add controls to parents in reverse order (because of how WinForms stacking works with Dock=Left)
        $controlDefs.GetEnumerator() | Sort-Object { $_.Value.Order } -Descending | ForEach-Object {
            $name = $_.Key
            $config = $_.Value
            $ctrl = $createdControls[$name]

            $parent = if ($config.Layout -eq 'Form') { $this.MainForm } else { $createdControls[$config.Layout] }
            if ($parent) { 
                $parent.Controls.Add($ctrl)
            }
        }

        # Assign controls to class property
        $this.Controls = $createdControls

        # Save references for status controls for easy access
        $this.StatusLabel = $this.Controls.StatusLabel
        $this.StatusProgressBar = $this.Controls.StatusProgressBar

        # Setup ListView columns using config
        foreach ($column in $this.Config.ListView.Columns) {
            $this.Controls.ScriptsListView.Columns.Add($column.Name, $column.Width) | Out-Null
        }

        # Setup events (must be done after controls are created)
        $this.Controls.ExecuteBtn.Add_Click({ $app.ExecuteSelectedScripts() })
        $this.Controls.SelectAllCheckBox.Add_CheckedChanged({ $app.OnSelectAllChanged() })
        $this.Controls.ExecuteModeCombo.Add_SelectedIndexChanged({ $app.OnExecutionModeChanged() })
        $this.Controls.MachineCombo.Add_SelectedIndexChanged({ $app.SwitchMachine() })
        $this.Controls.CollectionCombo.Add_SelectedIndexChanged({ $app.OnCollectionChanged() })
        $this.Controls.FilesCombo.Add_SelectedIndexChanged({ $app.OnFilesComboChanged() })
        $this.Controls.FilterText.Add_TextChanged({ $app.FilterScripts() })
        $this.MainForm.Add_Shown({ $app.OnFormShown() })
        $this.Controls.MoreBtn.Add_Click({ $app.ToggleSidebar() })
        $this.Controls.CopyCommandBtn.Add_Click({ $app.OnCopyCommand() })
        $this.Controls.RunLaterBtn.Add_Click({ $app.OnRunLater() })
        $this.Controls.AddCommandBtn.Add_Click({ $app.OnAddCommand() })
        $this.Controls.CloseSecondaryBtn.Add_Click({ $app.HideSecondaryPanel() })

        # Setup execution mode options using config
        $this.Controls.ExecuteModeCombo.Items.AddRange(@($this.Config.Defaults.CurrentUserText, $this.Config.Defaults.AdminText))
        try {
            $otherUsers = Get-LocalUser | Where-Object { $_.Name -ne $env:USERNAME -and $_.Enabled } | Select-Object -ExpandProperty Name
            $otherUsers | ForEach-Object { $this.Controls.ExecuteModeCombo.Items.Add("As $_") | Out-Null }
        }
        catch {
            $this.Controls.ExecuteModeCombo.Items.Add($this.Config.Defaults.OtherUserText) | Out-Null
        }
    }

    [void]LoadData() {
        # Load machines
        $this.Controls.MachineCombo.Items.Clear()
        $this.Machines | ForEach-Object { $this.Controls.MachineCombo.Items.Add($_.DisplayName) | Out-Null }
        if ($this.Machines.Count -gt 0) {
            $this.Controls.MachineCombo.SelectedIndex = 0
            $this.CurrentMachine = $this.Machines[0].Name
        }
        
        # Load collections
        $this.Controls.CollectionCombo.Items.Clear()
        $this.Collections | ForEach-Object { $this.Controls.CollectionCombo.Items.Add($_) | Out-Null }
        if ($this.Collections.Count -gt 0) {
            $this.Controls.CollectionCombo.SelectedIndex = 0
            $this.CurrentCollection = $this.Collections[0]
        }
        
        # Load files using config
        $this.Controls.FilesCombo.Items.Clear()
        $this.Controls.FilesCombo.Items.Add($this.Config.Defaults.FilesComboDefault) | Out-Null
        ($this.ScriptFiles | Sort-Object) | ForEach-Object { $this.Controls.FilesCombo.Items.Add("$($this.Config.Defaults.FilePrefix)$_") | Out-Null }
        $this.Controls.FilesCombo.SelectedIndex = 0
        $this.SelectedScriptFiles = $this.ScriptFiles
        
        # Set execution mode default
        if ($this.Controls.ExecuteModeCombo.Items.Count -gt 0) {
            $this.Controls.ExecuteModeCombo.SelectedIndex = 0
        }
    }

    [void]LoadCollectionScripts() {
        if (!$this.CurrentCollection) { return }
        $this.Controls.ScriptsListView.Items.Clear()
        try {
            $collectionPath = "$($this.DataDir)\$($this.Config.SubDirs[0])\$($this.CurrentCollection)$($this.Config.FileExtensions.TextExtension)"
            if ((Test-Path $collectionPath)) {
                $scriptFilesList = (Get-Content $collectionPath) | Where-Object { $_ -and !$_.StartsWith('#') }
                foreach ($scriptFile in $scriptFilesList) {
                    $this.LoadScriptFromFile($scriptFile.Trim())
                }
            }
        }
        catch { Write-Warning "$($this.Config.Messages.CollectionError)$_" }
    }
    
    [void]LoadScriptFromFile([string]$scriptFile) {
        try {
            $scriptUrl = "$($this.Config.URLs.GitHubRaw)/$($this.Owner)/$($this.Repo)/refs/heads/$($this.Branch)/$scriptFile"
            $scriptContent = (Invoke-WebRequest $scriptUrl -ErrorAction Stop).Content
            $parsedScripts = $this.ParseScriptFile($scriptContent, $scriptFile)
            foreach ($script in $parsedScripts) {
                $item = New-Object System.Windows.Forms.ListViewItem($script.Description)
                $item.SubItems.Add($script.Command) | Out-Null
                $item.SubItems.Add($scriptFile) | Out-Null
                $item.SubItems.Add($this.Config.Messages.Ready) | Out-Null
                $item.Tag = $script
                $this.Controls.ScriptsListView.Items.Add($item) | Out-Null
            }
        }
        catch { Write-Warning "$($this.Config.Messages.ScriptFileError)$scriptFile - $_" }
    }

    [array]ParseScriptFile([string]$content, [string]$fileName) {
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

    [void]ExecuteSelectedScripts() {
        if ($this.IsExecuting) { return }
        $checkedItems = $this.Controls.ScriptsListView.Items | Where-Object { $_.Checked }
        if (!$checkedItems) { [System.Windows.Forms.MessageBox]::Show($this.Config.Messages.NoScriptsSelected); return }
    
        $this.IsExecuting = $true; $this.Controls.ExecuteBtn.Enabled = $false
        $checkedItems | ForEach-Object {
            $_.SubItems[3].Text = $this.Config.Messages.Running; $_.BackColor = $this.Config.Colors.Running
            try {
                $script = $_.Tag
                $result = $this.ExecuteScript($script)
            
                $_.SubItems[3].Text = if ($result.Success) { $this.Config.Messages.Completed } else { $this.Config.Messages.Failed }
                $_.BackColor = if ($result.Success) { $this.Config.Colors.Completed } else { $this.Config.Colors.Failed }
                $_.Checked = !$result.Success
            }
            catch { 
                $_.SubItems[3].Text = $this.Config.Messages.Failed; $_.BackColor = $this.Config.Colors.Failed
                Write-host "$($this.Config.Messages.ExecutionError)$_" -ForegroundColor Red
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
        $this.IsExecuting = $false; $this.Controls.ExecuteBtn.Enabled = $true
    }

    [hashtable]ExecuteScript([hashtable]$script) {
        $command = $script.Command
        $machine = $this.Machines | Where-Object { $_.Name -eq $this.CurrentMachine }
        
        try {
            $result = ""
            if ($machine.Type -eq "SSH") {
                $sshCommand = "$($this.Config.Defaults.SSHCommandPrefix)$($machine.Name) '$command'"
                if ($this.ExecutionMode -eq $this.Config.Defaults.AdminMode) { $sshCommand = "$($this.Config.Defaults.SSHCommandPrefix)$($machine.Name) '$($this.Config.Defaults.SudoCommand)$command'" }
                elseif ($this.ExecutionMode.StartsWith($this.Config.Defaults.AsPrefix) -and $this.ExecutionMode -ne $this.Config.Defaults.AdminText) {
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
                elseif ($this.ExecutionMode.StartsWith($this.Config.Defaults.AsPrefix) -and $this.ExecutionMode -ne $this.Config.Defaults.AdminText) {
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

    [void]OnExecutionModeChanged() {
        $selectedText = $this.Controls.ExecuteModeCombo.SelectedItem
        $this.ExecutionMode = if ($selectedText.Contains("(Current User)")) { $this.Config.Defaults.CurrentUserMode } 
        elseif ($selectedText -eq $this.Config.Defaults.AdminText) { $this.Config.Defaults.AdminMode } 
        else { $selectedText }
    }

    [void]SwitchMachine() {
        $idx = $this.Controls.MachineCombo.SelectedIndex
        if ($idx -ge 0) { $this.CurrentMachine = $this.Machines[$idx].Name }
    }

    [void]FilterScripts() {
        $filter = $this.Controls.FilterText.Text.ToLower()
        $this.Controls.ScriptsListView.Items | ForEach-Object {
            $visible = !$filter -or $_.Text.ToLower().Contains($filter) -or $_.SubItems[1].Text.ToLower().Contains($filter)
            $_.ForeColor = if ($visible) { $this.Config.Colors.Text } else { $this.Config.Colors.Filtered }
        }
    }

    [void]OnFormShown() { 
        $this.MainForm.Activate()
        $this.LoadData()
        if ($this.CurrentCollection) { $this.LoadCollectionScripts() }
    }
    
    [void]OnCollectionChanged() { 
        $idx = $this.Controls.CollectionCombo.SelectedIndex
        if ($idx -ge 0) { 
            $this.CurrentCollection = $this.Collections[$idx]
            $this.LoadCollectionScripts() 
        } 
    }
    
    [void]OnFilesComboChanged() {
        $selectedText = $this.Controls.FilesCombo.SelectedItem
        $this.SelectedScriptFiles = if ($selectedText -eq $this.Config.Defaults.FilesComboDefault) { $this.ScriptFiles } 
        else { @($selectedText.Substring($this.Config.Defaults.FilePrefix.Length)) }
        $this.LoadScriptsFromFiles($this.SelectedScriptFiles)
    }

    [void]LoadScriptsFromFiles([array]$scriptFiles) {
        $this.Controls.ScriptsListView.Items.Clear()
        foreach ($scriptFile in $scriptFiles) {
            try {
                # Try local first, then remote
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
                    $scriptUrl = "$($this.Config.URLs.GitHubRaw)/$($this.Owner)/$($this.Repo)/refs/heads/$($this.Branch)/$scriptFile"
                    $scriptContent = (Invoke-WebRequest $scriptUrl -ErrorAction Stop).Content
                }
                
                $parsedScripts = $this.ParseScriptFile($scriptContent, $scriptFile)
                foreach ($script in $parsedScripts) {
                    $item = New-Object System.Windows.Forms.ListViewItem($script.Description)
                    $item.SubItems.Add($script.Command) | Out-Null
                    $item.SubItems.Add($scriptFile) | Out-Null
                    $item.SubItems.Add($this.Config.Messages.Ready) | Out-Null
                    $item.Tag = $script
                    $this.Controls.ScriptsListView.Items.Add($item) | Out-Null
                }
            }
            catch { Write-Warning "$($this.Config.Messages.LoadScriptError)$scriptFile - $_" }
        }
        $this.UpdateExecuteButtonText()
    }

    [void]OnSelectAllChanged() {
        $checked = $this.Controls.SelectAllCheckBox.Checked
        $this.Controls.ScriptsListView.Items | ForEach-Object { $_.Checked = $checked }
        $this.UpdateExecuteButtonText()
    }

    [void]UpdateExecuteButtonText() {
        $checkedCount = ($this.Controls.ScriptsListView.Items | Where-Object { $_.Checked }).Count
        $this.Controls.ExecuteBtn.Text = $this.Config.Controls.ExecuteBtnTemplate -f $checkedCount
    }

    [void]Show() { 
        $this.MainForm.ShowDialog() | Out-Null 
    }
    
    [string]GetSourceInfo() {
        $currentScript = $MyInvocation.ScriptName
        if (!$currentScript) { $currentScript = $PSCommandPath }
        
        if ($currentScript -match $this.Config.Patterns.HTTPUrl) {
            return "$($this.Owner.ToUpper())/$($this.Repo.ToUpper())$($this.Config.Defaults.GitHubText)"
        }
        elseif ($currentScript -and (Test-Path $currentScript)) {
            $scriptDir = Split-Path $currentScript -Parent
            return "$scriptDir$($this.Config.Defaults.LocalText)"
        }
        else {
            return "$($this.Owner.ToUpper())/$($this.Repo.ToUpper())$($this.Config.Defaults.RemoteText)"
        }
    }
    
    # Sidebar Event Handlers
    [void]ToggleSidebar() {
        $this.Controls.Sidebar.Visible = !$this.Controls.Sidebar.Visible
    }
    
    [void]ShowSecondaryPanel([string]$title) {
        $this.Controls.SecondaryLabel.Text = $title
        $this.Controls.SecondaryContent.Visible = $true
        $this.Controls.ContentSplitter.Visible = $true
        $this.IsSecondaryPanelVisible = $true
    }
    
    [void]HideSecondaryPanel() {
        $this.Controls.SecondaryContent.Visible = $false
        $this.Controls.ContentSplitter.Visible = $false
        $this.IsSecondaryPanelVisible = $false
    }
    
    [void]ToggleSecondaryPanel([string]$title) {
        if ($this.IsSecondaryPanelVisible -and $this.Controls.SecondaryLabel.Text -eq $title) {
            $this.HideSecondaryPanel()
        }
        else {
            $this.ShowSecondaryPanel($title)
        }
    }
    
    [void]OnCopyCommand() {
        $selectedItems = $this.Controls.ScriptsListView.Items | Where-Object { $_.Selected }
        if ($selectedItems) {
            $commands = $selectedItems | ForEach-Object { $_.SubItems[1].Text }
            $commandText = $commands -join "`n"
            [System.Windows.Forms.Clipboard]::SetText($commandText)
            [System.Windows.Forms.MessageBox]::Show("Commands copied to clipboard!", "Copy Command", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Please select a command to copy.", "Copy Command", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    }
    
    [void]OnRunLater() {
        $this.ToggleSecondaryPanel("⏰ Run Later - Schedule Commands")
        # TODO: Add scheduling functionality in secondary panel
    }
    
    [void]OnAddCommand() {
        $this.ToggleSecondaryPanel("➕ Add Command - Create New Script")
        # TODO: Add command creation functionality in secondary panel
    }
    
    [void]OnProfiles() {
        $this.ToggleSecondaryPanel("👤 Profiles - Manage Execution Profiles")
        # TODO: Add profile management functionality in secondary panel
    }
    
    [void]OnTools() {
        $this.ToggleSecondaryPanel("🔧 Tools - Additional Utilities")
        # TODO: Add additional tools in secondary panel
    }
}

# Entry point with error handling
try {
    $app = [PSUtilApp]::new()
    $app.Show()
}
catch {
    Write-Error "$($Global:Config.Messages.FatalError)$_"
    Write-Error "$($Global:Config.Messages.StackTrace)$($_.ScriptStackTrace)"
    # Ensure MessageBox is available for error display
    try {
        [System.Windows.Forms.MessageBox]::Show("$($Global:Config.Messages.FatalError)$_`n`n$($Global:Config.Messages.StackTrace)$($_.ScriptStackTrace)", $Global:Config.Messages.FatalErrorTitle, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    catch {
        # Fallback to Write-Host if MessageBox fails
        Write-Host "$($Global:Config.Messages.FatalError)$_" -ForegroundColor Red
        Write-Host "$($Global:Config.Messages.StackTrace)$($_.ScriptStackTrace)" -ForegroundColor Red
    }
}