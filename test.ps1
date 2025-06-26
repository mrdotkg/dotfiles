# PowerShell GUI utility for executing scripts from GitHub repository
# Features: PS1 script files with embedded metadata, Multiple execution modes, Multi-script collections support

[System.Windows.Forms.Application]::EnableVisualStyles()
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# Configuration - All constants and strings centralized for modularity
$Global:Config = @{
    # Repository settings
    Owner            = "mrdotkg"
    Repo             = "dotfiles" 
    Branch           = "main"
    DbFile           = "db.ps1"
    
    # Paths and directories
    DataDir          = "$env:USERPROFILE\Documents\PSUtil Local Data"
    SubDirs          = @("Collections", "Logs", "Scripts")
    SSHConfigPath    = "$env:USERPROFILE\.ssh\config"
    
    # UI Settings
    Window           = @{
        Title               = "PSUTIL"
        Width               = 900
        Height              = 650
        BackgroundColor     = [System.Drawing.Color]::FromArgb(241, 243, 249)
        AccentColorFallback = [System.Drawing.Color]::FromArgb(44, 151, 222)
        Position            = "CenterScreen"
    }
    
    # Panel dimensions
    Panels           = @{
        ToolbarHeight   = 25
        StatusBarHeight = 28
        ContentPadding  = '8, 0, 8, 0' # Left, Top, Right, Bottom padding for content area
        ToolbarPadding  = '8, 0, 8, 0' # Left, Top, Right, Bottom padding for toolbar
        StatusPadding   = '8, 4, 8, 4' # Left, Top, Right, Bottom padding for status bar
    }
    
    # Control dimensions and text
    Controls         = @{
        # Standard dimensions for consistency
        Dock               = 'Left'
        Width              = 120
        Height             = 25
        Padding            = '0, 0, 0, 0' # Left, Top, Right, Bottom padding
        Margin             = '2, 2, 2, 2' # Left, Top, Right, Bottom margin
        # Font settings to control ComboBox height
        FontName           = "Segoe UI"
        FontSize           = 9.0
        
        # Control text
        SelectAllText      = "Select All"
        ExecuteBtnText     = "▶ Run 0 Commands"
        ExecuteBtnTemplate = "▶ Run {0} Commands"
        FilterPlaceholder  = "Filter..."
    }
    
    # ListView columns
    ListView         = @{
        Columns = @(
            @{ Name = "Script"; Width = 250 }
            @{ Name = "Command"; Width = 350 }
            @{ Name = "File"; Width = 100 }
            @{ Name = "Status"; Width = 100 }
        )
    }
    
    # Script file extensions
    ScriptExtensions = @{
        Remote = @('.ps1', '.sh', '.bash', '.py', '.rb', '.js', '.bat', '.cmd')
        Local  = @('*.ps1', '*.sh', '*.py', '*.rb', '*.js', '*.bat', '*.cmd')
    }
    
    # File extensions and patterns
    FileExtensions   = @{
        Text          = "*.txt"
        TextExtension = ".txt"
    }
    
    # Default values and text constants
    Defaults         = @{
        CollectionFile     = "All Commands.txt"
        CollectionContent  = "# All Commands - Multiple Script Files`ndb.ps1`n# Add more script files below"
        FallbackScript     = "db.ps1"
        FilesComboDefault  = "From All Files"
        CurrentUserText    = "As $env:USERNAME (Current User)"
        AdminText          = "As Admin"
        OtherUserText      = "Other User..."
        ExecutionModes     = @("CurrentUser", "Admin")
        LocalhostName      = "localhost"
        FilePrefix         = "From "
        LocalText          = " (Local)"
        RemoteText         = " (Remote)"
        GitHubText         = " (GitHub)"
        LocalMachinePrefix = "On "
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
    Messages         = @{
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
    Colors           = @{
        Ready     = [System.Drawing.Color]::Black
        Running   = [System.Drawing.Color]::LightYellow
        Completed = [System.Drawing.Color]::LightGreen
        Failed    = [System.Drawing.Color]::LightCoral
        Filtered  = [System.Drawing.Color]::LightGray
        Text      = [System.Drawing.Color]::Black
        White     = [System.Drawing.Color]::White
    }
    
    # Regex patterns
    Patterns         = @{
        SSHHost           = '^Host\s+(.+)$'
        SSHExclude        = '[*?]'
        ScriptMetadata    = '^#\s*Script:\s*(.+)$'
        CommandMetadata   = '^#\s*Command:\s*(.+)$'
        CommentLine       = '^#'
        HTTPUrl           = '^https?://'
        CommentPrefix     = '#'
        WhitespacePattern = '\s+'
        NewlinePattern    = "`n"
    }
    
    # API URLs
    URLs             = @{
        GitHubAPI = "https://api.github.com/repos"
        GitHubRaw = "https://raw.githubusercontent.com"
    }
    
    # Registry paths
    Registry         = @{
        AccentColor      = "HKCU:\Software\Microsoft\Windows\DWM"
        AccentColorValue = "AccentColor"
    }
    
    # Source info constants
    SourceInfo       = @{
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
    [string]$Owner; [string]$Repo; [string]$Branch; [string]$DbFile
    [string]$DataDir
    [hashtable]$Config
    [hashtable]$Controls = @{}; [array]$Machines = @(); [array]$Collections = @(); [array]$ScriptFiles = @()
    [array]$SelectedScriptFiles = @(); [string]$CurrentMachine; [string]$CurrentCollection; [bool]$IsExecuting
    [string]$ExecutionMode = "CurrentUser"; $MainForm

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
        $defaultCollection = "$collectionsDir\$($this.Config.Defaults.CollectionFile)"
        if (!(Test-Path $defaultCollection)) { 
            $this.Config.Defaults.CollectionContent | Set-Content $defaultCollection -Force
            $this.Collections += ($this.Config.Defaults.CollectionFile -replace $this.Config.FileExtensions.TextExtension, '') 
        }
        $this.CurrentCollection = if ($this.Collections.Count -gt 0) { $this.Collections[0] } else { $null }
    }

    [void]CreateInterface() {
        $sourceInfo = $this.GetSourceInfo()
        $accent = try { [System.Drawing.Color]::FromArgb((Get-ItemPropertyValue $this.Config.Registry.AccentColor $this.Config.Registry.AccentColorValue)) } 
        catch { $this.Config.Window.AccentColorFallback }
        
        # Main Form
        $this.MainForm = New-Object System.Windows.Forms.Form -Property @{
            Text = "$($this.Config.Window.Title) - $sourceInfo"; Size = New-Object System.Drawing.Size($this.Config.Window.Width, $this.Config.Window.Height)
            StartPosition = $this.Config.Window.Position; BackColor = $this.Config.Window.BackgroundColor
        }
        
        # Standard parameters to reduce repetition in control definitions
        $standardFont = New-Object System.Drawing.Font($this.Config.Controls.FontName, $this.Config.Controls.FontSize)
        $standardWidth = $this.Config.Controls.Width
        $standardHeight = $this.Config.Controls.Height
        $standardDock = $this.Config.Controls.Dock
        $standardPadding = $this.Config.Controls.Padding
        $standardMargin = $this.Config.Controls.Margin
        $standardDropDownStyle = 'DropDownList'
        $standardBackColor = $this.MainForm.BackColor
        
        # Define controls with order for proper placement and future drag-drop
        $controlDefs = @{
            # Panels (Order 1-3)
            Toolbar           = @{ Type = 'Panel'; Order = 1; Layout = 'Form'; Properties = @{ Dock = 'Top'; Height = $this.Config.Panels.ToolbarHeight; Padding = $this.Config.Panels.ToolbarPadding } }
            StatusBar         = @{ Type = 'Panel'; Order = 2; Layout = 'Form'; Properties = @{ Dock = 'Bottom'; Height = $this.Config.Panels.StatusBarHeight; Padding = $this.Config.Panels.StatusPadding } }
            Content           = @{ Type = 'Panel'; Order = 3; Layout = 'Form'; Properties = @{ Dock = 'Fill'; Padding = $this.Config.Panels.ContentPadding } }
            
            # Toolbar controls (Order 10-70) - Left to Right: Execute, Select All, From Files, Machine, Execution Mode, Collection, Filter
            SelectAllCheckBox = @{ Type = 'CheckBox'; Order = 10; Layout = 'Toolbar'; Properties = @{ Text = $this.Config.Controls.SelectAllText; Width = '80'; Dock = 'Left'; Padding = '5,1,0,1' } }
            FilterText        = @{ Type = 'TextBox'; Order = 20; Layout = 'Toolbar'; Properties = @{ PlaceholderText = $this.Config.Controls.FilterPlaceholder } }
            SpacerPanel1      = @{ Type = 'Panel'; Order = 25; Layout = 'Toolbar'; Properties = @{ Width = $this.Config.Controls.Width / 3; BackColor = 'Transparent' } }
            ExecuteBtn        = @{ Type = 'Button'; Order = 28; Layout = 'Toolbar'; Properties = @{ Text = $this.Config.Controls.ExecuteBtnText; Width = $standardWidth * 1.5; FlatStyle = 'Flat'; BackColor = $accent; ForeColor = $this.Config.Colors.White } }
            SpacerPanel2      = @{ Type = 'Panel'; Order = 29; Layout = 'Toolbar'; Properties = @{ Width = $this.Config.Controls.Width / 3; BackColor = 'Transparent' } }
            FilesCombo        = @{ Type = 'ComboBox'; Order = 30; Layout = 'Toolbar'; Properties = @{} }
            MachineCombo      = @{ Type = 'ComboBox'; Order = 40; Layout = 'Toolbar'; Properties = @{} }
            ExecuteModeCombo  = @{ Type = 'ComboBox'; Order = 50; Layout = 'Toolbar'; Properties = @{} }
            CollectionCombo   = @{ Type = 'ComboBox'; Order = 60; Layout = 'Toolbar'; Properties = @{} }
            
            # Content controls (Order 100+)
            ScriptsListView   = @{ Type = 'ListView'; Order = 100; Layout = 'Content'; Properties = @{ Dock = 'Fill'; View = 'Details'; GridLines = $true; CheckBoxes = $true; FullRowSelect = $true } }
        }
        
        # Create controls in order
        $createdControls = @{}
        $app = $this
        
        $controlDefs.GetEnumerator() | Sort-Object { $_.Value.Order } | ForEach-Object {
            $name = $_.Key
            $config = $_.Value
            
            $ctrl = New-Object "System.Windows.Forms.$($config.Type)"
            
            # Apply standard parameters as defaults (can be overridden by control-specific properties)
            $ctrl.Font = $standardFont
            $ctrl.Dock = $standardDock
            $ctrl.Width = $standardWidth
            $ctrl.Height = $standardHeight
            $ctrl.Padding = $standardPadding
            $ctrl.Margin = $standardMargin
            
            # Apply ComboBox-specific defaults
            if ($config.Type -eq 'ComboBox') {
                $ctrl.DropDownStyle = $standardDropDownStyle
            }

            # Panel-specific defaults
            if ($config.Type -eq 'Panel') {
                $ctrl.BackColor = $standardBackColor
            }
            
            # Apply control-specific properties (these override the defaults above)
            $config.Properties.GetEnumerator() | ForEach-Object { 
                $ctrl.($_.Key) = $_.Value 
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
        
        # Setup events
        $this.Controls.ExecuteBtn.Add_Click({ $app.ExecuteSelectedScripts() })
        $this.Controls.SelectAllCheckBox.Add_CheckedChanged({ $app.OnSelectAllChanged() })
        $this.Controls.ExecuteModeCombo.Add_SelectedIndexChanged({ $app.OnExecutionModeChanged() })
        $this.Controls.MachineCombo.Add_SelectedIndexChanged({ $app.SwitchMachine() })
        $this.Controls.CollectionCombo.Add_SelectedIndexChanged({ $app.OnCollectionChanged() })
        $this.Controls.FilesCombo.Add_SelectedIndexChanged({ $app.OnFilesComboChanged() })
        $this.Controls.FilterText.Add_TextChanged({ $app.FilterScripts() })
        $this.MainForm.Add_Shown({ $app.OnFormShown() })
        
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
            
            if ($line -match $this.Config.Patterns.ScriptMetadata) {
                if ($currentScript) { $scripts += $currentScript }
                $currentScript = @{
                    Description = $Matches[1].Trim()
                    Command = ""; File = $fileName; LineNumber = $i + 1
                }
            }
            elseif ($line -match $this.Config.Patterns.CommandMetadata -and $currentScript) {
                $currentScript.Command = $Matches[1].Trim()
            }
            elseif ($line -and !$line.StartsWith('#') -and $currentScript -and !$currentScript.Command) {
                $currentScript.Command = $line
            }
        }
        
        if ($currentScript) { $scripts += $currentScript }
        
        # If no scripts found with metadata, treat entire file as single script
        if ($scripts.Count -eq 0) {
            $scripts = @(@{ Description = "$($this.Config.Messages.ExecuteFileDesc)$fileName"; Command = $content.Trim(); File = $fileName; LineNumber = 1 })
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
}

# Entry point with error handling
try {
    $app = [PSUtilApp]::new()
    $app.Show()
}
catch {
    Write-Error "$($Global:Config.Messages.FatalError)$_"
    Write-Error "$($Global:Config.Messages.StackTrace)$($_.ScriptStackTrace)"
    [System.Windows.Forms.MessageBox]::Show("$($Global:Config.Messages.FatalError)$_`n`n$($Global:Config.Messages.StackTrace)$($_.ScriptStackTrace)", $Global:Config.Messages.FatalErrorTitle, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}