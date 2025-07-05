# Load required assemblies first - MUST be at the very beginning for iex compatibility
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# PowerShell GUI utility for executing scripts

[System.Windows.Forms.Application]::EnableVisualStyles()

# Configuration - All constants and strings centralized for modularity
$Global:Config = @{
    ScriptFilesBlacklist        = @("gui.ps1", "psutil.ps1", "taaest.ps1")
    # Repository settings
    Owner                       = "mrdotkg"
    Repo                        = "dotfiles" 
    Branch                      = "main"
    
    # Paths and directories
    DataDir                     = "$env:USERPROFILE\Documents\PSUtil Local Data"
    SubDirs                     = @("Favourites", "Logs", "Scripts") # <-- Fix: Use "Favourites" not "Favorites"
    SSHConfigPath               = "$env:USERPROFILE\.ssh\config"
    
    # UI Settings
    Window                      = @{
        Title               = ""
        Width               = 600
        Height              = 700
        BackgroundColor     = [System.Drawing.Color]::FromArgb(241, 243, 249)
        AccentColorFallback = [System.Drawing.Color]::FromArgb(44, 151, 222)
        Position            = "CenterScreen"
        Padding             = '5,5,5,5'
        AlwaysOnTop         = $true
    }
    
    # Panel dimensions
    Panels                      = @{
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
    Controls                    = @{
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
    ListView                    = @{
        Columns = @(
            @{ Name = "Task List"; Width = 400 }
            @{ Name = "Command"; Width = 100 }
            @{ Name = "File"; Width = 100 }
            @{ Name = "Status"; Width = 100 }
        )
    }
    
    # Script file extensions
    ScriptExtensions            = @{
        Remote = @('.ps1', '.sh', '.bash', '.py', '.rb', '.js', '.bat', '.cmd')
        Local  = @('*.ps1', '*.sh', '*.py', '*.rb', '*.js', '*.bat', '*.cmd')
    }
    
    # File extensions and patterns
    FileExtensions              = @{
        Text = "*.txt"
    }
    
    # Default values and text constants
    Defaults                    = @{
        CollectionDefault  = "All Commands"
        CollectionContent  = "# All Commands - Multiple Script Files`ndb.ps1`n# Add more script files below"
        CurrentUserText    = "$env:USERNAME (Logged In)"
        AdminText          = "Administrator"
        OtherUserText      = "Other User..."
        ExecutionModes     = @("CurrentUser", "Admin")
        LocalhostName      = "localhost"
        LocalMachinePrefix = "🖥️ "
        LocalMachineText   = " (This PC)"
        SSHCommandPrefix   = "ssh "
        SudoCommand        = "sudo "
        SudoUserCommand    = "sudo -u "
        CurrentUserMode    = "CurrentUser"
        AdminMode          = "Admin"
        PowerShellCommand  = "powershell"
        CommandArgument    = "-Command"
        RunAsVerb          = "RunAs"
        WaitParameter      = "-Wait"
    }
    
    # Status messages
    Messages                    = @{
        NoScriptFound      = "No script files found in the specified directory."
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
    Colors                      = @{
        Ready     = [System.Drawing.Color]::Black
        Running   = [System.Drawing.Color]::LightYellow
        Completed = [System.Drawing.Color]::LightGreen
        Failed    = [System.Drawing.Color]::LightCoral
        Filtered  = [System.Drawing.Color]::LightGray
        Text      = [System.Drawing.Color]::Black
        White     = [System.Drawing.Color]::White
    }
    
    # Regex patterns
    Patterns                    = @{
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
    URLs                        = @{
        GitHubAPI = "https://api.github.com/repos"
        GitHubRaw = "https://raw.githubusercontent.com"
    }
    
    # Registry paths
    Registry                    = @{
        AccentColor      = "HKCU:\Software\Microsoft\Windows\DWM"
        AccentColorValue = "AccentColor"
    }
    
    # Source info constants
    SourceInfo                  = @{
        ErrorFetchingDir   = "Error fetching directory "
        DirectoryTypes     = @{
            File = "file"
            Dir  = "dir"
        }
        SlashSeparator     = "/"
        BackslashSeparator = "\"
        RefSeparator       = "/refs/heads/"
    }
    SourceComboAllActionsPrefix = "All Tasks"                # Use star emoji as all actions prefix
    SourceComboFilePrefix       = "📃 "                        # Use document emoji as file prefix
    SourceComboFavouritePrefix  = "✨ "                        # Use gem emoji as favourite prefix
}

class PSUtilApp {
    # Core properties
    [hashtable]$Config
    [hashtable]$Controls = @{}
    [array]$Machines = @()
    [array]$Sources = @()
    [array]$Users = @() # New member variable for user types
    [bool]$IsExecuting
    [string]$ExecutionMode = "CurrentUser"
    $MainForm;

    PSUtilApp() {
        Write-Host "[DEBUG] PSUtilApp Constructor"
        $this.Config = $Global:Config
        $this.Initialize()
        $this.CreateInterface()
    }

    [void]Initialize() {
        Write-Host "[DEBUG] Initialize"
        # Setup directories using config
        @($this.Config.DataDir) + ($this.Config.SubDirs | ForEach-Object { "$($this.Config.DataDir)\$_" }) | 
        ForEach-Object { if (!(Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null } }

        # Initialize Users array (Logged In, Administrator)
        $this.Users = @(
            @{ Name = $env:USERNAME; DisplayName = "$env:USERNAME (Logged In)"; Type = "LoggedIn" },
            @{ Name = "Administrator"; DisplayName = "Administrator"; Type = "Administrator" }
        )

        # Load machines
        $this.Machines = @(@{ Name = $env:COMPUTERNAME; DisplayName = "$($this.Config.Defaults.LocalMachinePrefix)$env:COMPUTERNAME$($this.Config.Defaults.LocalMachineText)"; Type = $this.Config.Defaults.LocalMachineText.Trim() })
        if ((Test-Path $this.Config.SSHConfigPath)) {
            (Get-Content $this.Config.SSHConfigPath -ErrorAction SilentlyContinue) | ForEach-Object {
                if ($_ -match $this.Config.Patterns.SSHHost -and $Matches[1] -notmatch $this.Config.Patterns.SSHExclude -and $Matches[1] -ne $this.Config.Defaults.LocalhostName) {
                    $this.Machines += @{ Name = $Matches[1]; DisplayName = "$($this.Config.Defaults.LocalMachinePrefix)$($Matches[1])"; Type = "SSH" }
                }
            }
        }

        # --- Combine all sources into one variable and initialize it ---
        $this.Sources = @()
        $this.Sources += @{ Type = "AllActions"; Name = $this.Config.SourceComboAllActionsPrefix }
        $favouritesDir = Join-Path $this.Config.DataDir "Favourites"
        if (Test-Path $favouritesDir) {
            $favFiles = Get-ChildItem -Path $favouritesDir -File | Where-Object { $_.Extension -eq ".txt" }
            foreach ($favFile in $favFiles) {
                $this.Sources += @{ Type = "Favourite"; Name = $favFile.BaseName }
            }
        }

        # Populate ScriptFile sources directly into Sources
        $scriptFiles = @()
        try {
            $sourceInfo = $this.GetSourceInfo()
            if ($sourceInfo.Contains("(Local)")) {
                $scriptDir = $sourceInfo.Replace(" (Local)", "")
                foreach ($ext in $this.Config.ScriptExtensions.Local) {
                    $files = Get-ChildItem -Path $scriptDir -Filter $ext -File -Recurse -ErrorAction SilentlyContinue
                    foreach ($file in $files) {
                        $relativePath = $file.FullName.Substring($scriptDir.Length + 1).Replace($this.Config.SourceInfo.BackslashSeparator, $this.Config.SourceInfo.SlashSeparator)
                        if ($scriptFiles -notcontains $relativePath) { $scriptFiles += $relativePath }
                    }
                }
                if ($scriptFiles.Count -eq 0) { Write-Warning "$($this.Config.Messages.NoScriptFound)" }
            }
            else {
                try {
                    $scriptFiles = $this.GetRemoteScriptFilesRecursive("")
                }
                catch { 
                    Write-Warning "$($this.Config.Messages.GitHubError)$_"
                }
            }
        }
        catch {
            Write-Warning "$($this.Config.Messages.LoadError)$_"
        }
        # Remove blacklisted files from $scriptFiles
        if ($this.Config.ScriptFilesBlacklist) {
            $blacklist = $this.Config.ScriptFilesBlacklist
            $scriptFiles = $scriptFiles | Where-Object { $blacklist -notcontains $_ }
        }
        foreach ($file in $scriptFiles) {
            $this.Sources += @{ Type = "ScriptFile"; Name = $file }
        }
    }

    [array]GetRemoteScriptFilesRecursive([string]$path) {
        Write-Host "[DEBUG] GetRemoteScriptFilesRecursive $path"
        $files = @()
        try {
            $url = if ($path) { "$($this.Config.URLs.GitHubAPI)/$($this.Config.Owner)/$($this.Config.Repo)/contents/$path" } 
            else { "$($this.Config.URLs.GitHubAPI)/$($this.Config.Owner)/$($this.Config.Repo)/contents" }
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

    [void]CreateInterface() {
        Write-Host "[DEBUG] CreateInterface"
        $sourceInfo = $this.GetSourceInfo()
        $createdControls = @{}
        $app = $this

        # Main Form
        $this.MainForm = New-Object System.Windows.Forms.Form -Property @{
            Text = "$($this.Config.Window.Title) $([System.IO.Path]::GetFileName($sourceInfo).Substring(0,1).ToUpper() + [System.IO.Path]::GetFileName($sourceInfo).Substring(1))";
            Size = New-Object System.Drawing.Size($this.Config.Window.Width, $this.Config.Window.Height)
            Padding = $this.Config.Window.Padding
            StartPosition = $this.Config.Window.Position; BackColor = $this.Config.Window.BackgroundColor
            Add_Shown = { $app.OnFormShown() }
        }
        
        # Define controls with order for proper placement and future drag-drop
        $controlDefs = @{
            # Main Layout Panels (Order 1-5)
            Toolbar            = @{ Type = 'Panel'; Order = 1; Layout = 'Form'; Properties = @{ Dock = 'Top'; Height = $this.Config.Panels.ToolbarHeight; Padding = $this.Config.Panels.ToolbarPadding } }
            StatusBar          = @{ Type = 'Panel'; Order = 2; Layout = 'Form'; Properties = @{ Dock = 'Bottom'; Height = $this.Config.Panels.StatusBarHeight; Padding = $this.Config.Panels.StatusPadding } }
            Sidebar            = @{ Type = 'Panel'; Order = 3; Layout = 'Form'; Properties = @{ Dock = 'Right'; Width = $this.Config.Panels.SidebarWidth; Padding = $this.Config.Panels.SidebarPadding; Visible = $false } }
            MainContent        = @{ Type = 'Panel'; Order = 4; Layout = 'Form'; Properties = @{ Dock = 'Fill'; Padding = '0, 0, 0, 0' } }
            
            # Content Layout with Splitter (Order 5-8) - SecondaryContent first, then splitter, then PrimaryContent fills
            SecondaryContent   = @{ Type = 'Panel'; Order = 5; Layout = 'MainContent'; Properties = @{ Dock = 'Right'; BackColor = $this.Config.Colors.White; Width = $this.Config.Panels.SecondaryPanelWidth; Padding = $this.Config.Panels.SecondaryPadding; Visible = $false } }
            ContentSplitter    = @{ Type = 'Splitter'; Order = 6; Layout = 'MainContent'; Properties = @{ Dock = 'Right'; Width = $this.Config.Panels.SplitterWidth; Visible = $false; BackColor = [System.Drawing.Color]::LightGray; BorderStyle = 'FixedSingle' } }
            PrimaryContent     = @{ Type = 'Panel'; Order = 7; Layout = 'MainContent'; Properties = @{ Dock = 'Fill'; Padding = $this.Config.Panels.ContentPadding } }
            
            # Toolbar controls (Order 10-70) - Left to Right: Select All, Filter, Spacers, Execute, Combos
            SelectAllCheckBox  = @{ Type = 'CheckBox'; Order = 10; Layout = 'Toolbar'; Properties = @{ Text = $this.Config.Controls.SelectAllText; Width = '25'; Dock = 'Left'; Padding = '5,5,0,0'; BackColor = 'Transparent' } } 
            FilterText         = @{ Type = 'TextBox'; Order = 20; Layout = 'Toolbar'; Properties = @{ PlaceholderText = $this.Config.Controls.FilterPlaceholder } }
            MoreBtn            = @{ Type = 'Button'; Order = 30; Layout = 'Toolbar'; Properties = @{ Text = '≡'; Width = 30; Dock = 'Right' } }
            ExecuteBtn         = @{ Type = 'Button'; Order = 40; Layout = 'Toolbar'; Properties = @{ Text = $this.Config.Controls.ExecuteBtnText; Dock = 'Right' } }
            
            # Sidebar controls (Order 80-89)
            CopyCommandBtn     = @{ Type = 'Button'; Order = 80; Layout = 'Sidebar'; Properties = @{ Text = $this.Config.Controls.CopyCommandText; Dock = 'Bottom'; TextAlign = 'MiddleLeft' } }
            SpacerPanelCopy    = @{ Type = 'Panel'; Order = 80.2; Layout = 'Sidebar'; Properties = @{ Height = 5; Dock = 'Bottom'; BackColor = 'Transparent' } }
            RunLaterBtn        = @{ Type = 'Button'; Order = 81; Layout = 'Sidebar'; Properties = @{ Text = $this.Config.Controls.RunLaterText; Dock = 'Bottom'; TextAlign = 'MiddleLeft' } }
            SpacerPanelRun     = @{ Type = 'Panel'; Order = 81.2; Layout = 'Sidebar'; Properties = @{ Height = 5; Dock = 'Bottom'; BackColor = 'Transparent' } }
            AddCommandBtn      = @{ Type = 'Button'; Order = 82; Layout = 'Sidebar'; Properties = @{ Text = $this.Config.Controls.AddCommandText; Dock = 'Bottom'; TextAlign = 'MiddleLeft' } }
            SpacerPanelAdd     = @{ Type = 'Panel'; Order = 82.2; Layout = 'Sidebar'; Properties = @{ Height = 5; Dock = 'Bottom'; BackColor = 'Transparent' } }
            ExecuteModeLabel   = @{ Type = 'Label'; Order = 44.5; Layout = 'Sidebar'; Properties = @{ Text = "Run As"; Dock = 'Top'; Height = 18; TextAlign = 'MiddleLeft'; Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Regular); BackColor = 'Transparent' } }
            ExecuteModeCombo   = @{ Type = 'ComboBox'; Order = 45; Layout = 'Sidebar'; Properties = @{ Dock = 'Top' } }
            SpacerPanelExec    = @{ Type = 'Panel'; Order = 45.2; Layout = 'Sidebar'; Properties = @{ Height = 8; Dock = 'Top'; BackColor = 'Transparent' } }
            MachineLabel       = @{ Type = 'Label'; Order = 49.5; Layout = 'Sidebar'; Properties = @{ Text = "Target Machine"; Dock = 'Top'; Height = 18; TextAlign = 'MiddleLeft'; Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Regular); BackColor = 'Transparent' } }
            MachineCombo       = @{ Type = 'ComboBox'; Order = 50; Layout = 'Sidebar'; Properties = @{ Dock = 'Top' } }
            SpacerPanelMachine = @{ Type = 'Panel'; Order = 50.2; Layout = 'Sidebar'; Properties = @{ Height = 8; Dock = 'Top'; BackColor = 'Transparent' } }
            SourceLabel        = @{ Type = 'Label'; Order = 64.5; Layout = 'Sidebar'; Properties = @{ Text = "Task List Source"; Dock = 'Top'; Height = 18; TextAlign = 'MiddleLeft'; Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Regular); BackColor = 'Transparent' } }
            SourceCombo        = @{ Type = 'ComboBox'; Order = 65; Layout = 'Sidebar'; Properties = @{ Dock = 'Top' } }
            SpacerPanel2       = @{ Type = 'Panel'; Order = 75; Layout = 'Sidebar'; Properties = @{ Height = 8; BackColor = 'Transparent'; Dock = 'Fill'; } }

            # StatusBar controls (Order 300+)
            StatusLabel        = @{ Type = 'Label'; Order = 300; Layout = 'StatusBar'; Properties = @{ Text = "Ready"; Dock = 'Left'; AutoSize = $true; TextAlign = 'MiddleLeft'; BackColor = 'Transparent' } }
            StatusProgressBar  = @{ Type = 'ProgressBar'; Order = 301; Layout = 'StatusBar'; Properties = @{ Dock = 'Right'; Width = 120; Visible = $false } }
            
            # Primary content controls (Order 100+)
            ScriptsListView    = @{ Type = 'ListView'; Order = 100; Layout = 'PrimaryContent'; Properties = @{ Dock = 'Fill'; View = 'Details'; GridLines = $true; BorderStyle = 'None'; CheckBoxes = $true; FullRowSelect = $true } }
            
            # Secondary content controls (Order 200+) - Will be added dynamically based on selected tool
            SecondaryLabel     = @{ Type = 'Label'; Order = 200; Layout = 'SecondaryContent'; Properties = @{ Text = 'Secondary Panel'; Dock = 'Top'; Height = 30; TextAlign = 'MiddleCenter'; Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold) } }
            CloseSecondaryBtn  = @{ Type = 'Button'; Order = 201; Layout = 'SecondaryContent'; Properties = @{ Text = '✕'; Dock = 'Top'; Height = 25; FlatStyle = 'Flat'; TextAlign = 'MiddleCenter'; BackColor = [System.Drawing.Color]::LightCoral; ForeColor = $this.Config.Colors.White; Add_Click = { $app.HideSecondaryPanel() }; } }
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



        # Setup ListView columns using config
        foreach ($column in $this.Config.ListView.Columns) {
            $this.Controls.ScriptsListView.Columns.Add($column.Name, $column.Width) | Out-Null
        }
        $columns = $this.Controls.ScriptsListView.Columns
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
                    param($sender, $e)
                    $app.ToggleListViewColumn($sender, $e, $colIdx)
                }.GetNewClosure())
        }
        $this.Controls.ScriptsListView.ContextMenuStrip = $contextMenu

        # Setup events (must be done after controls are created)
        $this.Controls.ExecuteBtn.Add_Click({ $app.OnExecute() })
        $this.Controls.SelectAllCheckBox.Add_CheckedChanged({ $app.OnSelectAll() })
        $this.Controls.ExecuteModeCombo.Add_SelectedIndexChanged({ $app.OnSwitchUser() })
        $this.Controls.SourceCombo.Add_SelectedIndexChanged({ $app.OnSwitchSource() })
        $this.Controls.FilterText.Add_TextChanged({ $app.OnFilter() })
        $this.MainForm.Add_Shown({ $app.OnFormShown() })
        $this.Controls.MoreBtn.Add_Click({ $app.OnMore() })
        # $this.Controls.CopyCommandBtn.Add_Click({ $app.OnCopyCommand() })
        # $this.Controls.RunLaterBtn.Add_Click({ $app.OnRunLater() })
        # $this.Controls.AddCommandBtn.Add_Click({ $app.OnAddCommand() })
        $this.Controls.CloseSecondaryBtn.Add_Click({ $app.OnCloseSecondary() })

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
    }
    # Sidebar Event Handlers
    [void]OnMore() {
        Write-Host "[DEBUG] OnMore"
        $this.Controls.Sidebar.Visible = !$this.Controls.Sidebar.Visible
    }
    
    [void]OnSelectAll() {
        Write-host "[DEBUG] OnSelectAll"
        $checked = $this.Controls.SelectAllCheckBox.Checked
        $this.Controls.ScriptsListView.Items | ForEach-Object { $_.Checked = $checked }
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

        switch ($selectedSource.Type) {
            "AllActions" {
                $this.ReadActions($this.Sources.Where({ $_.Type -eq "ScriptFile" }).Name)
            }
            "ScriptFile" {
                $this.ReadActions(@($selectedSource.Name))
            }
            "Favourite" {

                $favName = $selectedSource.Name
                $favPath = Join-Path (Join-Path $this.Config.DataDir "Favourites") "$favName.txt"
                if (Test-Path $favPath) {
                    $grouped = $this.ReadGroupedProfile($favPath)
                    if ($grouped.Count -gt 0) {
                        $this.LoadGroupedActionsToListView($grouped)
                    }
                    else {
                        [System.Windows.Forms.MessageBox]::Show("No matching actions found in scripts for this favourite file.", "No Actions", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                        $this.Controls.ScriptsListView.Items.Clear()
                        $this.UpdateExecuteButtonText()
                    }
                }
                else {
                    [System.Windows.Forms.MessageBox]::Show("No matching actions found for this favourite.", "No Actions", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    $this.Controls.ScriptsListView.Items.Clear()
                    $this.UpdateExecuteButtonText()
                }
            }
        }
    }
    [void]ToggleListViewColumn($sender, $e, [int]$colIdx) {
        Write-host "[DEBUG] ToggleListViewColumn $colIdx"
        $lv = $this.Controls.ScriptsListView
        if ($lv -and $lv.Columns -and $this.Config.ListView.Columns) {
            $columns = $lv.Columns
            if ($columns.Count -gt $colIdx) {
                if ($columns[$colIdx].Width -eq 0) {
                    $columns[$colIdx].Width = $this.Config.ListView.Columns[$colIdx].Width
                    $sender.Checked = $true
                }
                else {
                    $columns[$colIdx].Width = 0
                    $sender.Checked = $false
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

        # Populate SourceCombo using Sources
        $srcCombo = $this.Controls.SourceCombo
        $srcCombo.Items.Clear()
        foreach ($src in $this.Sources) {
            switch ($src.Type) {
                "AllActions" { $srcCombo.Items.Add($src.Name) | Out-Null }
                "Favourite" { $srcCombo.Items.Add("$($this.Config.SourceComboFavouritePrefix)$($src.Name)") | Out-Null }
                "ScriptFile" { $srcCombo.Items.Add("$($this.Config.SourceComboFilePrefix)$($src.Name)") | Out-Null }
            }
        }
        $srcCombo.SelectedIndex = 0 # "All Actions"

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

    [void]ReadActions([array]$scriptFiles) {
        Write-Host "[DEBUG] ReadActions $($scriptFiles -join ',')"
        $actions = @()
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
                $parsedScripts = $this.ParseScriptFile($scriptContent, $scriptFile)
                $actions += $parsedScripts
            }
            catch { Write-Warning "$($this.Config.Messages.LoadScriptError)$scriptFile - $_" }
        }
        $this.LoadActionsToListView($actions)
    }

    [void]LoadActionsToListView([array]$actions) {
        Write-Host "[DEBUG] LoadActionsToListView $($actions.Count)"
        $this.Controls.ScriptsListView.Items.Clear()
        $this.Controls.ScriptsListView.Groups.Clear()
        foreach ($script in $actions) {
            $item = New-Object System.Windows.Forms.ListViewItem($script.Description)
            $item.SubItems.Add($script.Command) | Out-Null
            $item.SubItems.Add($script.File) | Out-Null
            $item.SubItems.Add($this.Config.Messages.Ready) | Out-Null
            $item.Tag = $script
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
        $filter = $this.Controls.FilterText.Text.ToLower()
        $this.Controls.ScriptsListView.Items | ForEach-Object {
            $visible = !$filter -or $_.Text.ToLower().Contains($filter) -or $_.SubItems[1].Text.ToLower().Contains($filter)
            $_.ForeColor = if ($visible) { $this.Config.Colors.Text } else { $this.Config.Colors.Filtered }
        }
    }

    [void]OnAddToFavourite() {
        Write-Host "[DEBUG] OnAddToFavourite"
        $selectedItems = $this.Controls.ScriptsListView.Items | Where-Object { $_.Selected }
        if (!$selectedItems) {
            [System.Windows.Forms.MessageBox]::Show("Please select an action to add to Favourites.", "Add to Favourite", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        $this.ShowFavouritePanel($selectedItems)
    }

    [void]ShowFavouritePanel($selectedItems) {
        Write-Host "[DEBUG] ShowFavouritePanel"
        $this.ShowSecondaryPanel("⭐ Add to Favourite")
        # Simple UI: TextBox for name, ListBox for existing favourites, Save/Cancel buttons
        $panel = $this.Controls.SecondaryContent
        $panel.Controls.Clear()
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
                if (!$name) { [System.Windows.Forms.MessageBox]::Show("Enter a name."); return }
                $refs = @()
                foreach ($item in $selectedItems) {
                    $tag = $item.Tag
                    $refs += "$($tag.Description)"
                }
                $favPath = Join-Path (Join-Path $this.Config.DataDir "Favourites") "$name.txt"
                $refs | Set-Content $favPath -Force
                $this.LoadData()
                $this.HideSecondaryPanel()
            }.GetNewClosure())
        $panel.Controls.Add($btnSave)
        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Text = "Cancel"
        $btnCancel.Dock = 'Top'
        $btnCancel.Add_Click({ $this.HideSecondaryPanel() })
        $panel.Controls.Add($btnCancel)
        $lst.Add_SelectedIndexChanged({
                if ($lst.SelectedItem) { $txt.Text = $lst.SelectedItem }
            })
    }

    [string]GetSourceInfo() {
        Write-Host "[DEBUG] GetSourceInfo"
        $currentScript = $MyInvocation.ScriptName
        if (!$currentScript) { $currentScript = $PSCommandPath }
        
        if ($currentScript -match $this.Config.Patterns.HTTPUrl) {
            return "$($this.Config.Owner.ToUpper())/$($this.Config.Repo.ToUpper())"
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
        # Parse a profile file into an ordered dictionary of groupName -> [actions]
        $groupedScripts = [ordered]@{}
        if (!(Test-Path $profilePath)) { return $groupedScripts }
        $lines = Get-Content $profilePath -ErrorAction SilentlyContinue
        if (-not $lines) { return $groupedScripts }
        $currentGroup = "Group 1"
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed -eq "") {
                $currentGroup = "Group $($groupedScripts.Count + 1)"
                continue
            }
            elseif ($trimmed.StartsWith("#")) {
                $currentGroup = $trimmed.TrimStart("#").Trim()
                continue
            }
            else {
                # Try to find the action by ID (line)
                $action = $this.GetActionById($trimmed)
                if ($action) {
                    if (-not $groupedScripts.Contains($currentGroup)) {
                        $groupedScripts[$currentGroup] = @()
                    }
                    $groupedScripts[$currentGroup] += $action
                }
            }
        }
        return $groupedScripts
    }

    [hashtable]GetActionById([string]$id) {
        Write-Host "[DEBUG] GetActionById $id"
        # Try to find an action by ID in all script files (assume ID is in Description or Command)
        foreach ($src in $this.Sources | Where-Object { $_.Type -eq 'ScriptFile' }) {
            $scriptFile = $src.Name
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
                try { $scriptContent = (Invoke-WebRequest $scriptUrl -ErrorAction Stop).Content } catch { $scriptContent = $null }
            }
            if ($scriptContent) {
                $parsed = $this.ParseScriptFile($scriptContent, $scriptFile)
                foreach ($action in $parsed) {
                    if ($action.Description -eq $id -or $action.Command -eq $id) { return $action }
                }
            }
        }
        return $null
    }

    [void]LoadGroupedActionsToListView([hashtable]$groupedScripts) {
        Write-Host "[DEBUG] LoadGroupedActionsToListView"
        # Display grouped actions in the ListView using ListView groups
        $lv = $this.Controls.ScriptsListView
        $lv.Items.Clear()
        $lv.Groups.Clear()
        $groupCount = $groupedScripts.Keys.Count
        foreach ($groupName in $groupedScripts.Keys) {
            $group = $null
            if ($groupCount -gt 1) {
                $group = New-Object System.Windows.Forms.ListViewGroup($groupName, $groupName)
                $lv.Groups.Add($group) | Out-Null
            }
            foreach ($action in $groupedScripts[$groupName]) {
                $item = New-Object System.Windows.Forms.ListViewItem($action.Description)
                $item.SubItems.Add($action.Command) | Out-Null
                $item.SubItems.Add($action.File) | Out-Null
                $item.SubItems.Add($this.Config.Messages.Ready) | Out-Null
                $item.Tag = $action
                if ($group) { $item.Group = $group }
                $lv.Items.Add($item) | Out-Null
            }
        }
        $this.UpdateExecuteButtonText()
    }
}

# Entry point with error handling
try {
    $app = [PSUtilApp]::new()
    $app.MainForm.ShowDialog() | Out-Null 
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