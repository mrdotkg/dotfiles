<#
PowerShell GUI utility for executing scripts from GitHub repository
Features:
- PS1 script files with embedded metadata 
- Multiple execution modes (Admin, Current User, Other Users)
- Multi-script collections support
#>

Add-Type -AssemblyName System.Drawing, System.Windows.Forms

class PSUtilApp {
    # Config
    [string]$Owner = "mrdotkg"; [string]$Repo = "dotfiles"; [string]$Branch = "main"; [string]$DbFile = "db.ps1"
    [string]$DataDir = "$env:USERPROFILE\Documents\PSUtil Local Data"
    [string]$DatabaseUrl; [hashtable]$Controls = @{}; [hashtable]$Theme = @{
    }
    [array]$Machines = @(); [array]$Collections = @(); [array]$ScriptFiles = @(); [array]$SelectedScriptFiles = @(); [string]$CurrentMachine; [string]$CurrentCollection; [bool]$IsExecuting
    [string]$ExecutionMode = "CurrentUser" # CurrentUser, Admin, OtherUser
    $MainForm  # Remove [System.Windows.Forms.Form] type annotation

    PSUtilApp() {
        try {
            $this.Initialize()
            $this.CreateInterface()
        }
        catch {
            Write-Error "Error during PSUtilApp initialization: $_"
            Write-Error "Stack trace: $($_.ScriptStackTrace)"
            [System.Windows.Forms.MessageBox]::Show("Error during initialization: $_`n`nStack trace: $($_.ScriptStackTrace)", "Initialization Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            throw
        }
    }

    [void]Initialize() {
        # Setup
        @("$($this.DataDir)", "$($this.DataDir)\Collections", "$($this.DataDir)\Logs", "$($this.DataDir)\Scripts") | ForEach-Object { if (!(Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null } }
        $this.DatabaseUrl = "https://raw.githubusercontent.com/$($this.Owner)/$($this.Repo)/refs/heads/$($this.Branch)/$($this.DbFile)"
        
        # Theme
        $accent = try { [System.Drawing.Color]::FromArgb((Get-ItemPropertyValue "HKCU:\Software\Microsoft\Windows\DWM" "AccentColor")) } catch { [System.Drawing.Color]::FromArgb(44, 151, 222) }
        $this.Theme = @{
            Colors = @{ Accent = $accent; Background = [System.Drawing.Color]::FromArgb(241, 243, 249); Surface = [System.Drawing.Color]::White; Text = [System.Drawing.Color]::Black }
            Fonts  = @{ Default = [System.Drawing.Font]::new("Segoe UI", 10); Bold = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold) }
            Layout = @{ 
                Window  = @{ Width = 800; Height = 600; Padding = [System.Windows.Forms.Padding]('5,5,5,5') }; 
                Control = @{ Height = 30; Width = 120; Padding = [System.Windows.Forms.Padding]('1,1,1,1') }; 
                ToolBar = @{ Height = 30; Padding = [System.Windows.Forms.Padding]('2,2,2,2') }; 
                Status  = @{ Height = 30; Padding = [System.Windows.Forms.Padding]('2,2,2,2') } 
            }
        }
        
        # Load machines
        $this.Machines = @(@{ Name = $env:COMPUTERNAME; DisplayName = "On $env:COMPUTERNAME (Local)"; Type = "Local" })
        $this.CurrentMachine = $env:COMPUTERNAME
        if (Test-Path "$env:USERPROFILE\.ssh\config") {
            (Get-Content "$env:USERPROFILE\.ssh\config" -ErrorAction SilentlyContinue) | ForEach-Object {
                if ($_ -match '^Host\s+(.+)$' -and $Matches[1] -notmatch '[*?]' -and $Matches[1] -ne 'localhost') {
                    $this.Machines += @{ Name = $Matches[1]; DisplayName = "On $($Matches[1])"; Type = "SSH" }
                }
            }
        }
        
        # Load script files and collections
        $this.LoadScriptFiles()
        $this.LoadCollections()
    }

    [void]LoadScriptFiles() {
        $this.ScriptFiles = @()
        
        try {
            $sourceInfo = $this.GetSourceInfo()
            
            # Check source type and load accordingly
            if ($sourceInfo.Contains("(GitHub)") -or $sourceInfo.Contains("(Remote)")) {
                $this.LoadRemoteScriptFiles()
            }
            elseif ($sourceInfo.Contains("(Local)")) {
                # Extract directory path from sourceInfo
                $scriptDir = $sourceInfo.Replace(" (Local)", "")
                $this.LoadLocalScriptFiles($scriptDir)
            }
            else {
                # Fallback to remote
                $this.LoadRemoteScriptFiles()
            }
        }
        catch {
            Write-Warning "Error loading script files: $_"
            # Fallback to default
            $this.ScriptFiles = @("db.ps1")
        }
        
        Write-Host "Loaded $($this.ScriptFiles.Count) script files: $($this.ScriptFiles -join ', ')"
    }
    
    [void]LoadRemoteScriptFiles() {
        try {
            # Recursively fetch all script files from GitHub repo
            $this.ScriptFiles = $this.GetRemoteScriptFilesRecursive("")
        }
        catch { 
            Write-Warning "Could not fetch script files from GitHub: $_"
            # Fallback to default
            $this.ScriptFiles = @("db.ps1")
        }
    }
    
    [array]GetRemoteScriptFilesRecursive([string]$path) {
        $files = @()
        $scriptExtensions = @('.ps1', '.sh', '.bash', '.zsh', '.fish', '.py', '.rb', '.pl', '.js', '.ts', '.bat', '.cmd')
        
        try {
            $url = if ($path) { 
                "https://api.github.com/repos/$($this.Owner)/$($this.Repo)/contents/$path" 
            }
            else { 
                "https://api.github.com/repos/$($this.Owner)/$($this.Repo)/contents" 
            }
            
            $apiResponse = Invoke-WebRequest $url | ConvertFrom-Json
            
            foreach ($item in $apiResponse) {
                if ($item.type -eq "file") {
                    $fileName = $item.name
                    $filePath = if ($path) { "$path/$fileName" } else { $fileName }
                    
                    foreach ($ext in $scriptExtensions) {
                        if ($fileName.EndsWith($ext)) {
                            $files += $filePath
                            break
                        }
                    }
                }
                elseif ($item.type -eq "dir") {
                    # Recursively search subdirectories
                    $subPath = if ($path) { "$path/$($item.name)" } else { $item.name }
                    $files += $this.GetRemoteScriptFilesRecursive($subPath)
                }
            }
        }
        catch {
            Write-Warning "Error fetching directory $path : $_"
        }
        
        return $files
    }
    
    [void]LoadLocalScriptFiles([string]$directory) {
        try {
            # Define executable script file extensions
            $scriptExtensions = @('*.ps1', '*.sh', '*.bash', '*.zsh', '*.fish', '*.py', '*.rb', '*.pl', '*.js', '*.ts', '*.bat', '*.cmd')
            
            foreach ($ext in $scriptExtensions) {
                $files = Get-ChildItem -Path $directory -Filter $ext -File -Recurse -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    $relativePath = $file.FullName.Substring($directory.Length + 1).Replace('\', '/')
                    if ($this.ScriptFiles -notcontains $relativePath) {
                        $this.ScriptFiles += $relativePath
                    }
                }
            }
            
            # If no script files found, add default
            if ($this.ScriptFiles.Count -eq 0) {
                $this.ScriptFiles = @("db.ps1")
            }
        }
        catch {
            Write-Warning "Error scanning local directory for script files: $_"
            $this.ScriptFiles = @("db.ps1")
        }
    }

    [void]LoadCollections() {
        $collectionsDir = "$($this.DataDir)\Collections"
        $this.Collections = if (Test-Path $collectionsDir) { (Get-ChildItem $collectionsDir -Filter "*.txt").BaseName } else { @() }
        $defaultCollection = "$collectionsDir\All Commands.txt"
        if (!(Test-Path $defaultCollection)) { 
            "# All Commands - Multiple Script Files`ndb.ps1`n# Add more script files below" | Set-Content $defaultCollection -Force
            $this.Collections += "All Commands" 
        }
        $this.CurrentCollection = if ($this.Collections.Count -gt 0) { $this.Collections[0] } else { $null }
    }

    [void]CreateInterface() {
        try {
            # Determine source for title
            $sourceInfo = $this.GetSourceInfo()
            
            # Main Form
            $this.MainForm = New-Object System.Windows.Forms.Form -Property @{
                Text          = "PSUTIL - $sourceInfo"
                Size          = New-Object System.Drawing.Size(900, 650)
                StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
                BackColor     = $this.Theme.Colors.Background
                Font          = $this.Theme.Fonts.Default
                Padding       = $this.Theme.Layout.Window.Padding
            }
            
            # Define controls with common properties and events
            $commonProps = @{
                Panel          = @{ BackColor = $this.Theme.Colors.Background; Height = $this.Theme.Layout.Control.Height; Padding = $this.Theme.Layout.ToolBar.Padding }
                Button         = @{ Font = $this.Theme.Fonts.Bold; FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; Height = $this.Theme.Layout.Control.Height; Dock = 'Left'; Width = $this.Theme.Layout.Control.Width; }
                ComboBox       = @{ Font = $this.Theme.Fonts.Default; DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList; Height = $this.Theme.Layout.Control.Height; Dock = 'Left'; Width = $this.Theme.Layout.Control.Width }
                TextBox        = @{ Font = $this.Theme.Fonts.Default; Height = $this.Theme.Layout.Control.Height; Dock = 'Right'; Width = $this.Theme.Layout.Control.Width; PlaceholderText = "Filter..."; BackColor = $this.Theme.Colors.Surface; ForeColor = $this.Theme.Colors.Text }
                ListView       = @{ Font = $this.Theme.Fonts.Default; View = [System.Windows.Forms.View]::Details; GridLines = $true; CheckBoxes = $true; FullRowSelect = $true; BackColor = $this.Theme.Colors.Surface; Dock = 'Fill' }
                Label          = @{ Font = $this.Theme.Fonts.Default; BackColor = $this.Theme.Colors.Background; ForeColor = $this.Theme.Colors.Text; Dock = 'Left'; Width = $this.Theme.Layout.Control.Width; TextAlign = 'MiddleLeft' }
                CheckBox       = @{ Font = $this.Theme.Fonts.Default; BackColor = $this.Theme.Colors.Background; ForeColor = $this.Theme.Colors.Text; Dock = 'Left'; Width = $this.Theme.Layout.Control.Width }
                CheckedListBox = @{ Font = $this.Theme.Fonts.Default; BackColor = $this.Theme.Colors.Surface; ForeColor = $this.Theme.Colors.Text; Height = $this.Theme.Layout.Control.Height }
            }
            
            $controlDefs = @{
                Toolbar           = @{ Type = 'Panel'; Layout = 'Form'; Order = 10; Properties = @{ Dock = 'Top' } }
                Status            = @{ Type = 'Panel'; Layout = 'Form'; Order = 20; Properties = @{ Dock = 'Bottom'; } }
                Content           = @{ Type = 'Panel'; Layout = 'Form'; Order = 5; Properties = @{ Dock = 'Fill' } }
                CollectionCombo   = @{ Type = 'ComboBox'; Layout = 'Toolbar'; Order = 100; Properties = @{ Dock = 'Right'; Width = $this.Theme.Layout.Control.Width; Add_SelectedIndexChanged = { $app.OnCollectionChanged() } } }
                FilesCombo        = @{ Type = 'ComboBox'; Layout = 'Toolbar'; Order = 102; Properties = @{ Dock = 'Left'; DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList; Add_SelectedIndexChanged = { $app.OnFilesComboChanged() } } }
                ExecuteModeCombo  = @{ Type = 'ComboBox'; Layout = 'Toolbar'; Order = 105; Properties = @{ Add_SelectedIndexChanged = { $app.OnExecutionModeChanged() } } }
                MachineCombo      = @{ Type = 'ComboBox'; Layout = 'Toolbar'; Order = 108; Properties = @{ Add_SelectedIndexChanged = { $app.SwitchMachine() } } }
                ExecuteBtn        = @{ Type = 'Button'; Layout = 'Toolbar'; Order = 109; Properties = @{ Text = "▶ Run Commands"; BackColor = $this.Theme.Colors.Accent; ForeColor = $this.Theme.Colors.Surface; Add_Click = { $app.ExecuteSelectedScripts() } } }
                SelectAllCheckBox = @{ Type = 'CheckBox'; Layout = 'Toolbar'; Order = 110; Properties = @{ Text = "Select All"; Add_CheckedChanged = { $app.OnSelectAllChanged() } } }
                FilterText        = @{ Type = 'TextBox'; Layout = 'Toolbar'; Order = 1010; Properties = @{ PlaceholderText = "Filter..."; Add_TextChanged = { $app.FilterScripts() } } }
                ScriptsListView   = @{ Type = 'ListView'; Layout = 'Content'; Order = 300; Properties = @{ } }
            }
            
            # Create controls dynamically
            $createdControls = @{}
            $app = $this
            $controlDefs.GetEnumerator() | Sort-Object { $_.Value.Order } | ForEach-Object {
                $name = $_.Key
                $config = $_.Value
                
                try {
                    $ctrl = New-Object "System.Windows.Forms.$($config.Type)"
                }
                catch {
                    Write-Error "Failed to create control $name of type $($config.Type): $_"
                    return
                }
            
                # Merge common properties with specific properties (specific overrides common)
                $mergedProps = @{}
                if ($commonProps[$config.Type]) {
                    $commonProps[$config.Type].GetEnumerator() | ForEach-Object { $mergedProps[$_.Key] = $_.Value }
                }
                $config.Properties.GetEnumerator() | ForEach-Object { $mergedProps[$_.Key] = $_.Value }
                
                # Separate events from regular properties
                $events = @{}
                $properties = @{}
                $mergedProps.GetEnumerator() | ForEach-Object {
                    if ($_.Key.StartsWith('Add_')) {
                        $events[$_.Key] = $_.Value
                    }
                    else {
                        $properties[$_.Key] = $_.Value
                    }
                }
                
                # Apply regular properties
                $properties.GetEnumerator() | ForEach-Object { 
                    # Check if the property exists on the control before trying to set it
                    if ($ctrl.PSObject.Properties.Name -contains $_.Key -or 
                        $ctrl.GetType().GetProperty($_.Key) -ne $null) {
                        $ctrl.($_.Key) = $_.Value 
                    }
                    else {
                        Write-Verbose "Property '$($_.Key)' not supported on control type '$($config.Type)' - skipping"
                    }
                }
                
                # Apply events by calling the methods
                $events.GetEnumerator() | ForEach-Object {
                    try {
                        $ctrl.($_.Key).Invoke($_.Value)
                    }
                    catch {
                        Write-Warning "Failed to set event $($_.Key): $_"
                    }
                }

                $createdControls[$name] = $ctrl
                $parent = if ($config.Layout -eq 'Form') { $this.MainForm } else { $createdControls[$config.Layout] }
                if ($parent) { 
                    $parent.Controls.Add($ctrl) 
                }
                else {
                    Write-Warning "Parent not found for $name (Layout: $($config.Layout))"
                }
            }

            # Assign controls to class property
            $this.Controls = $createdControls
            $this.Controls.ScriptsListView.Columns.Add("Script", 250) | Out-Null
            $this.Controls.ScriptsListView.Columns.Add("Command", 350) | Out-Null
            $this.Controls.ScriptsListView.Columns.Add("File", 100) | Out-Null
            $this.Controls.ScriptsListView.Columns.Add("Status", 100) | Out-Null
        
            # Setup execution mode combo items first
            $this.Controls.ExecuteModeCombo.Items.Add("As $env:USERNAME (Current User)") | Out-Null
            $this.Controls.ExecuteModeCombo.Items.Add("As Admin") | Out-Null
        
            # Add other users on the system
            try {
                $otherUsers = Get-LocalUser | Where-Object { $_.Name -ne $env:USERNAME -and $_.Enabled } | Select-Object -ExpandProperty Name
                foreach ($user in $otherUsers) {
                    $this.Controls.ExecuteModeCombo.Items.Add("As $user") | Out-Null
                }
            }
            catch {
                # Fallback for systems without Get-LocalUser
                try {
                    $otherUsers = Get-WmiObject Win32_UserAccount -Filter "LocalAccount=True" | Where-Object { $_.Name -ne $env:USERNAME -and !$_.Disabled } | Select-Object -ExpandProperty Name
                    foreach ($user in $otherUsers) {
                        $this.Controls.ExecuteModeCombo.Items.Add("As $user") | Out-Null
                    }
                }
                catch {
                    $this.Controls.ExecuteModeCombo.Items.Add("Other User...") | Out-Null
                }
            }
        
            # Set the selected index after all setup is complete
            $this.MainForm.Add_Shown({ 
                    try {
                        $app.OnFormShown() 
                        # Set default selection after form is shown
                        if ($app.Controls.ExecuteModeCombo -and $app.Controls.ExecuteModeCombo.Items.Count -gt 0) {
                            $app.Controls.ExecuteModeCombo.SelectedIndex = 0
                        }
                    }
                    catch {
                        Write-Error "Error in Form_Shown event: $_"
                        Write-Error "Stack trace: $($_.ScriptStackTrace)"
                        [System.Windows.Forms.MessageBox]::Show("Error in Form_Shown: $_`n`nDetails: $($_.ScriptStackTrace)", "Runtime Error")
                    }
                })
        
        }
        catch {
            Write-Error "Error in CreateInterface: $_"
            Write-Error "Stack trace: $($_.ScriptStackTrace)"
            throw
        }
    }

    [void]LoadData() {
        if ($this.Controls.ContainsKey('MachineCombo') -and $this.Controls.MachineCombo) {
            $this.Controls.MachineCombo.Items.Clear()
            $this.Machines | ForEach-Object { $this.Controls.MachineCombo.Items.Add($_.DisplayName) | Out-Null }
            if ($this.Machines.Count -gt 0) {
                $this.Controls.MachineCombo.SelectedIndex = 0
                $this.CurrentMachine = $this.Machines[0].Name
            }
        }
        else {
            Write-Warning "MachineCombo control not found or is null"
        }
    
        try {
            $collectionControl = $this.Controls['CollectionCombo']
            if ($collectionControl) {
                $collectionControl.Items.Clear()
                $this.Collections | ForEach-Object { $collectionControl.Items.Add($_) | Out-Null }
                if ($this.Collections.Count -gt 0) {
                    $collectionControl.SelectedIndex = 0
                    $this.CurrentCollection = $this.Collections[0]
                }
            }
            else {
                Write-Warning "CollectionCombo control is null"
            }
        }
        catch {
            Write-Warning "Error accessing CollectionCombo: $_"
        }

        try {
            $filesCombo = $this.Controls['FilesCombo']
            
            if ($filesCombo) {
                $filesCombo.Items.Clear()
                $filesCombo.Items.Add("From All Files") | Out-Null
                
                $sortedFiles = $this.ScriptFiles | Sort-Object
                $sortedFiles | ForEach-Object { 
                    $filesCombo.Items.Add("From $_") | Out-Null 
                }
                
                $filesCombo.SelectedIndex = 0
                $this.SelectedScriptFiles = $this.ScriptFiles
            }
            else {
                Write-Warning "FilesCombo control is null"
            }
        }
        catch {
            Write-Warning "Error accessing FilesCombo: $_"
        }
    }

    [void]LoadCollectionScripts() {
        if (!$this.CurrentCollection) { return }
        $this.Controls.ScriptsListView.Items.Clear()
    
        try {
            $collectionPath = "$($this.DataDir)\Collections\$($this.CurrentCollection).txt"
            if (Test-Path $collectionPath) {
                $scriptFilesList = (Get-Content $collectionPath) | Where-Object { $_ -and !$_.StartsWith('#') }
            
                foreach ($scriptFile in $scriptFilesList) {
                    $scriptFile = $scriptFile.Trim()
                    $scriptUrl = "https://raw.githubusercontent.com/$($this.Owner)/$($this.Repo)/refs/heads/$($this.Branch)/$scriptFile"
                
                    try {
                        $scriptContent = (Invoke-WebRequest $scriptUrl -ErrorAction Stop).Content
                        $parsedScripts = $this.ParsePS1ScriptFile($scriptContent, $scriptFile)
                    
                        foreach ($script in $parsedScripts) {
                            $item = New-Object System.Windows.Forms.ListViewItem($script.Description)
                            $item.SubItems.Add($script.Command) | Out-Null
                            $item.SubItems.Add($scriptFile) | Out-Null
                            $item.SubItems.Add("Ready") | Out-Null
                            $item.Tag = $script
                            $this.Controls.ScriptsListView.Items.Add($item) | Out-Null
                        }
                    }
                    catch { Write-Warning "Failed to load script file: $scriptFile - $_" }
                }
            }
        }
        catch { [System.Windows.Forms.MessageBox]::Show("Failed to load collection scripts: $_", "Error") }
    }

    [array]ParsePS1ScriptFile([string]$content, [string]$fileName) {
        $scripts = @()
        $lines = $content -split "`n"
        $currentScript = $null
    
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
        
            # Look for script metadata in comments
            if ($line -match '^#\s*Script:\s*(.+)$') {
                if ($currentScript) { $scripts += $currentScript }
                $currentScript = @{
                    Description = $Matches[1].Trim()
                    Command     = ""
                    File        = $fileName
                    LineNumber  = $i + 1
                }
            }
            elseif ($line -match '^#\s*Command:\s*(.+)$' -and $currentScript) {
                $currentScript.Command = $Matches[1].Trim()
            }
            elseif ($line -and !$line.StartsWith('#') -and $currentScript -and !$currentScript.Command) {
                # If no explicit command, use the first non-comment line
                $currentScript.Command = $line
            }
        }
    
        if ($currentScript) { $scripts += $currentScript }
        return $scripts
    }

    [void]ExecuteSelectedScripts() {
        if ($this.IsExecuting) { return }
        $checkedItems = $this.Controls.ScriptsListView.Items | Where-Object { $_.Checked }
        if (!$checkedItems) { [System.Windows.Forms.MessageBox]::Show("No scripts selected."); return }
    
        $this.IsExecuting = $true; $this.Controls.ExecuteBtn.Enabled = $false
        $checkedItems | ForEach-Object {
            $_.SubItems[3].Text = "Running..."; $_.BackColor = [System.Drawing.Color]::LightYellow
            try {
                $script = $_.Tag
                $result = $this.ExecuteScript($script)
            
                $_.SubItems[3].Text = if ($result.Success) { "Completed" } else { "Failed" }
                $_.BackColor = if ($result.Success) { [System.Drawing.Color]::LightGreen } else { [System.Drawing.Color]::LightCoral }
                $_.Checked = !$result.Success
            }
            catch { 
                $_.SubItems[3].Text = "Failed"; $_.BackColor = [System.Drawing.Color]::LightCoral
                Write-host "Execution error: $_" -ForegroundColor Red
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
        $this.IsExecuting = $false; $this.Controls.ExecuteBtn.Enabled = $true
    }

    [hashtable]ExecuteScript([hashtable]$script) {
        $command = $script.Command
        $machine = $this.Machines | Where-Object { $_.Name -eq $this.CurrentMachine }
    
        try {
            if ($machine.Type -eq "SSH") {
                # SSH execution
                $sshCommand = "ssh $($machine.Name) '$command'"
                $result = Invoke-Expression $sshCommand
            }
            elseif ($this.ExecutionMode -eq "Admin") {
                # Run as Administrator
                if ($machine.Type -eq "SSH") {
                    $sshCommand = "ssh $($machine.Name) 'sudo $command'"
                    $result = Invoke-Expression $sshCommand
                }
                else {
                    Start-Process powershell -Verb RunAs -ArgumentList "-Command", $command -Wait
                    $result = "Executed as Administrator"
                }
            }
            elseif ($this.ExecutionMode.StartsWith("As ") -and $this.ExecutionMode -ne "As Admin") {
                # Run as specific user
                $targetUser = $this.ExecutionMode.Substring(3)
                if ($machine.Type -eq "SSH") {
                    $sshCommand = "ssh $($machine.Name) 'sudo -u $targetUser $command'"
                    $result = Invoke-Expression $sshCommand
                }
                else {
                    $cred = Get-Credential -UserName $targetUser -Message "Enter password for $targetUser"
                    if ($cred) {
                        Start-Process powershell -Credential $cred -ArgumentList "-Command", $command -Wait
                        $result = "Executed as $targetUser"
                    }
                    else {
                        throw "Cancelled by user"
                    }
                }
            }
            elseif ($this.ExecutionMode -eq "Other User...") {
                # Prompt for credentials and run as other user
                $cred = Get-Credential -Message "Enter credentials for script execution"
                if ($cred) {
                    if ($machine.Type -eq "SSH") {
                        $userName = $cred.UserName
                        # Note: SSH with different user credentials is complex, simplified here
                        $sshCommand = "ssh $($machine.Name) '$command'"
                        $result = Invoke-Expression $sshCommand
                    }
                    else {
                        Start-Process powershell -Credential $cred -ArgumentList "-Command", $command -Wait
                        $result = "Executed as $($cred.UserName)"
                    }
                }
                else {
                    throw "Cancelled by user"
                }
            }
            else {
                # Current user execution
                if ($machine.Type -eq "SSH") {
                    $sshCommand = "ssh $($machine.Name) '$command'"
                    $result = Invoke-Expression $sshCommand
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
        $selectedIndex = $this.Controls.ExecuteModeCombo.SelectedIndex
        if ($selectedIndex -ge 0) {
            $selectedText = $this.Controls.ExecuteModeCombo.Items[$selectedIndex]
        
            if ($selectedText.Contains("(Current User)")) {
                $this.ExecutionMode = "CurrentUser"
            }
            elseif ($selectedText -eq "As Admin") {
                $this.ExecutionMode = "Admin"
            }
            elseif ($selectedText.StartsWith("As ")) {
                $this.ExecutionMode = $selectedText
            }
            else {
                $this.ExecutionMode = $selectedText
            }
        }
    }

    [void]SwitchMachine() {
        $idx = $this.Controls.MachineCombo.SelectedIndex
        if ($idx -ge 0) { $this.CurrentMachine = $this.Machines[$idx].Name }
    }

    [void]FilterScripts() {
        $filter = $this.Controls.FilterText.Text.ToLower()
        $this.Controls.ScriptsListView.Items | ForEach-Object {
            $visible = !$filter -or $_.Text.ToLower().Contains($filter) -or $_.SubItems[1].Text.ToLower().Contains($filter)
            $_.ForeColor = if ($visible) { $this.Theme.Colors.Text } else { [System.Drawing.Color]::LightGray }
        }
    }

    [void]OnFormShown() { 
        $this.MainForm.Activate()
        # Load data after form is fully shown and controls are initialized
        $this.LoadData()
        if ($this.CurrentCollection) { 
            $this.LoadCollectionScripts() 
        }
    }
    
    [void]OnCollectionChanged() { 
        $idx = $this.Controls.CollectionCombo.SelectedIndex
        if ($idx -ge 0) { 
            $this.CurrentCollection = $this.Collections[$idx]
            $this.LoadCollectionScripts() 
        } 
    }
    
    [void]OnFileSelectionChanged() {
        if ($this.SelectedScriptFiles -and $this.SelectedScriptFiles.Count -gt 0) {
            $this.LoadScriptsFromFiles($this.SelectedScriptFiles)
        }
        else {
            $this.Controls.ScriptsListView.Items.Clear()
        }
    }

    [void]OnFilesComboChanged() {
        try {
            $filesCombo = $this.Controls['FilesCombo']
            if ($filesCombo -and $filesCombo.SelectedIndex -ge 0) {
                $selectedText = $filesCombo.Items[$filesCombo.SelectedIndex]
                
                if ($selectedText -eq "From All Files") {
                    $this.SelectedScriptFiles = $this.ScriptFiles
                }
                else {
                    # Remove "From " prefix to get the actual filename
                    $fileName = $selectedText.Substring(5)
                    $this.SelectedScriptFiles = @($fileName)
                }
                
                $this.OnFileSelectionChanged()
            }
        }
        catch {
            Write-Warning "Error in OnFilesComboChanged: $_"
        }
    }

    [void]LoadScriptsFromFiles([array]$scriptFiles) {
        $this.Controls.ScriptsListView.Items.Clear()
        
        foreach ($scriptFile in $scriptFiles) {
            try {
                $currentScript = $PSCommandPath
                if ($currentScript -and (Test-Path $currentScript)) {
                    $scriptDir = Split-Path $currentScript -Parent
                    $fullPath = Join-Path $scriptDir $scriptFile.Replace('/', '\')
                    if (Test-Path $fullPath) {
                        $scriptContent = Get-Content $fullPath -Raw
                    }
                    else {
                        throw "Local file not found: $fullPath"
                    }
                }
                else {
                    $scriptUrl = "https://raw.githubusercontent.com/$($this.Owner)/$($this.Repo)/refs/heads/$($this.Branch)/$scriptFile"
                    $scriptContent = (Invoke-WebRequest $scriptUrl -ErrorAction Stop).Content
                }
                
                $parsedScripts = $this.ParseScriptFile($scriptContent, $scriptFile)
                
                foreach ($script in $parsedScripts) {
                    $item = New-Object System.Windows.Forms.ListViewItem($script.Description)
                    $item.SubItems.Add($script.Command) | Out-Null
                    $item.SubItems.Add($scriptFile) | Out-Null
                    $item.SubItems.Add("Ready") | Out-Null
                    $item.Tag = $script
                    $this.Controls.ScriptsListView.Items.Add($item) | Out-Null
                }
            }
            catch { 
                Write-Warning "Failed to load script file: $scriptFile - $_" 
            }
        }
        $this.UpdateExecuteButtonText()
    }

    [array]ParseScriptFile([string]$content, [string]$fileName) {
        $extension = [System.IO.Path]::GetExtension($fileName).ToLower()
        
        $return = switch ($extension) {
            '.ps1' { $this.ParsePS1ScriptFile($content, $fileName) }
            '.sh' { $this.ParseShellScriptFile($content, $fileName) }
            '.bash' { $this.ParseShellScriptFile($content, $fileName) }
            '.py' { $this.ParsePythonScriptFile($content, $fileName) }
            default { $this.ParseGenericScriptFile($content, $fileName) }
        }
        return $return
    }

    [array]ParseShellScriptFile([string]$content, [string]$fileName) {
        $scripts = @()
        $lines = $content -split "`n"
        $currentScript = $null
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            
            if ($line -match '^#\s*Script:\s*(.+)$') {
                if ($currentScript) { $scripts += $currentScript }
                $currentScript = @{
                    Description = $Matches[1].Trim()
                    Command     = ""
                    File        = $fileName
                    LineNumber  = $i + 1
                }
            }
            elseif ($line -match '^#\s*Command:\s*(.+)$' -and $currentScript) {
                $currentScript.Command = $Matches[1].Trim()
            }
            elseif ($line -and !$line.StartsWith('#') -and $currentScript -and !$currentScript.Command) {
                $currentScript.Command = $line
            }
        }
        
        if ($currentScript) { $scripts += $currentScript }
        return $scripts
    }

    [array]ParsePythonScriptFile([string]$content, [string]$fileName) {
        $scripts = @()
        $lines = $content -split "`n"
        $currentScript = $null
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            
            if ($line -match '^#\s*Script:\s*(.+)$') {
                if ($currentScript) { $scripts += $currentScript }
                $currentScript = @{
                    Description = $Matches[1].Trim()
                    Command     = ""
                    File        = $fileName
                    LineNumber  = $i + 1
                }
            }
            elseif ($line -match '^#\s*Command:\s*(.+)$' -and $currentScript) {
                $currentScript.Command = $Matches[1].Trim()
            }
            elseif ($line -and !$line.StartsWith('#') -and $currentScript -and !$currentScript.Command) {
                $currentScript.Command = $line
            }
        }
        
        if ($currentScript) { $scripts += $currentScript }
        return $scripts
    }

    [array]ParseGenericScriptFile([string]$content, [string]$fileName) {
        return @(@{
                Description = "Execute $fileName"
                Command     = $content.Trim()
                File        = $fileName
                LineNumber  = 1
            })
    }

    [void]OnSelectAllChanged() {
        try {
            $checked = $this.Controls.SelectAllCheckBox.Checked
            $this.Controls.ScriptsListView.Items | ForEach-Object {
                $_.Checked = $checked
            }
            $this.UpdateExecuteButtonText()
        }
        catch {
            Write-Warning "Error in OnSelectAllChanged: $_"
        }
    }

    [void]UpdateExecuteButtonText() {
        try {
            $checkedCount = ($this.Controls.ScriptsListView.Items | Where-Object { $_.Checked }).Count
            $this.Controls.ExecuteBtn.Text = "▶ Run $checkedCount Commands"
        }
        catch {
            Write-Warning "Error updating execute button text: $_"
        }
    }

    [void]Show() { 
        try {
            [System.Windows.Forms.Application]::EnableVisualStyles()
            $this.MainForm.ShowDialog() | Out-Null 
        }
        catch {
            Write-Error "Error in Show method: $_"
            [System.Windows.Forms.MessageBox]::Show("Error starting application: $_`n`nStack trace: $($_.ScriptStackTrace)", "Application Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
    
    [string]GetSourceInfo() {
        try {
            $currentScript = $MyInvocation.ScriptName
            if (!$currentScript) {
                $currentScript = $PSCommandPath
            }
            
            # Check if running from GitHub URL or local directory
            if ($currentScript -match "^https?://") {
                return "$($this.Owner.ToUpper())/$($this.Repo.ToUpper()) (GitHub)"
            }
            elseif ($currentScript -and (Test-Path $currentScript)) {
                $scriptDir = Split-Path $currentScript -Parent
                return "$scriptDir (Local)"
            }
            else {
                return "$($this.Owner.ToUpper())/$($this.Repo.ToUpper()) (Remote)"
            }
        }
        catch {
            return "$($this.Owner.ToUpper())/$($this.Repo.ToUpper())"
        }
    }
}

# Entry point with error handling
try {
    $app = [PSUtilApp]::new()
    $app.Show()
}
catch {
    Write-Error "Fatal error: $_"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    [System.Windows.Forms.MessageBox]::Show("Fatal error: $_`n`nStack trace: $($_.ScriptStackTrace)", "Fatal Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}