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
    [array]$Machines = @(); [array]$Collections = @(); [array]$ScriptFiles = @(); [string]$CurrentMachine; [string]$CurrentCollection; [bool]$IsExecuting
    [string]$ExecutionMode = "CurrentUser" # CurrentUser, Admin, OtherUser
    [System.Windows.Forms.Form]$MainForm

    PSUtilApp() {
        $this.Initialize()
        $this.CreateInterface()
        # Remove LoadData() call from here - it will be called in OnFormShown()
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
                Control = @{ Height = 30; Width = 100; Padding = [System.Windows.Forms.Padding]('1,1,1,1') }; 
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
        $this.ScriptFiles = @("db.ps1") # Default main script file
        try {
            # Fetch list of PS1 files from GitHub repo
            $apiResponse = Invoke-WebRequest "https://api.github.com/repos/$($this.Owner)/$($this.Repo)/contents" | ConvertFrom-Json
            $this.ScriptFiles += ($apiResponse | Where-Object { $_.name -match '\.ps1$' -and $_.name -ne 'db.ps1' }).name
        }
        catch { Write-Warning "Could not fetch script files from GitHub" }
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
        # Main Form
        $this.MainForm = New-Object System.Windows.Forms.Form -Property @{
            Text          = "PSUTIL-$($this.Owner.ToUpper())/$($this.Repo.ToUpper())"
            Size          = New-Object System.Drawing.Size(900, 650)
            StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
            BackColor     = $this.Theme.Colors.Background
            Font          = $this.Theme.Fonts.Default
            Padding       = $this.Theme.Layout.Window.Padding
        }
        
        # Define controls with common properties and events
        $commonProps = @{
            Panel    = @{ BackColor = $this.Theme.Colors.Background; Height = $this.Theme.Layout.Control.Height; Padding = $this.Theme.Layout.ToolBar.Padding }
            Button   = @{ Font = $this.Theme.Fonts.Bold; FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; Height = $this.Theme.Layout.Control.Height; Dock = 'Left'; Width = $this.Theme.Layout.Control.Width; }
            ComboBox = @{ Font = $this.Theme.Fonts.Default; DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList; Height = $this.Theme.Layout.Control.Height; Dock = 'Left'; Width = $this.Theme.Layout.Control.Width }
            TextBox  = @{ Font = $this.Theme.Fonts.Default; Height = $this.Theme.Layout.Control.Height; Dock = 'Right'; Width = $this.Theme.Layout.Control.Width; PlaceholderText = "Filter..."; BackColor = $this.Theme.Colors.Surface; ForeColor = $this.Theme.Colors.Text }
            ListView = @{ Font = $this.Theme.Fonts.Default; View = [System.Windows.Forms.View]::Details; GridLines = $true; CheckBoxes = $true; FullRowSelect = $true; BackColor = $this.Theme.Colors.Surface; Dock = 'Fill' }
            Label    = @{ Font = $this.Theme.Fonts.Default; BackColor = $this.Theme.Colors.Background; ForeColor = $this.Theme.Colors.Text; Dock = 'Left'; Width = $this.Theme.Layout.Control.Width; TextAlign = 'MiddleLeft' }
            CheckBox = @{ Font = $this.Theme.Fonts.Default; BackColor = $this.Theme.Colors.Background; ForeColor = $this.Theme.Colors.Text; Dock = 'Left'; Width = $this.Theme.Layout.Control.Width }
        }
        
        $controlDefs = @{
            Toolbar           = @{ Type = 'Panel'; Layout = 'Form'; Order = 10; Properties = @{ Dock = 'Top' } }
            Status            = @{ Type = 'Panel'; Layout = 'Form'; Order = 20; Properties = @{ Dock = 'Bottom'; } }
            Content           = @{ Type = 'Panel'; Layout = 'Form'; Order = 5; Properties = @{ Dock = 'Fill' } }
            ExecuteBtn        = @{ Type = 'Button'; Layout = 'Toolbar'; Order = 109; Properties = @{ Text = "▶ Execute"; BackColor = $this.Theme.Colors.Accent; ForeColor = $this.Theme.Colors.Surface }; Events = @{ Click = 'ExecuteSelectedScripts' } }
            ExecuteModeCombo  = @{ Type = 'ComboBox'; Layout = 'Toolbar'; Order = 105; Properties = @{}; Events = @{ SelectedIndexChanged = 'OnExecutionModeChanged' } }
            SelectAllCheckBox = @{ Type = 'CheckBox'; Layout = 'Toolbar'; Order = 110; Properties = @{ Text = "Select All" }; Events = @{ CheckedChanged = 'OnSelectAllChanged' } }
            MachineCombo      = @{ Type = 'ComboBox'; Layout = 'Toolbar'; Order = 108; Properties = @{}; Events = @{ SelectedIndexChanged = 'SwitchMachine' } }
            FilterText        = @{ Type = 'TextBox'; Layout = 'Toolbar'; Order = 1010; Properties = @{ PlaceholderText = "Filter..." }; Events = @{ TextChanged = 'FilterScripts' } }
            CollectionCombo   = @{ Type = 'ComboBox'; Layout = 'Toolbar'; Order = 100; Properties = @{Width = $this.Theme.Layout.Control.Width }; Events = @{ SelectedIndexChanged = 'OnCollectionChanged' } }
            ScriptsListView   = @{ Type = 'ListView'; Layout = 'Content'; Order = 300; Properties = @{ } }
        }
        
        # Create controls dynamically
        $createdControls = @{}
        $app = $this
        $controlDefs.GetEnumerator() | Sort-Object { $_.Value.Order } | ForEach-Object {
            $name = $_.Key
            $config = $_.Value
            $ctrl = New-Object "System.Windows.Forms.$($config.Type)"
        
            # Apply common then specific properties
            if ($commonProps[$config.Type]) { 
                $commonProps[$config.Type].GetEnumerator() | ForEach-Object { 
                    try { $ctrl.($_.Key) = $_.Value } catch {} 
                } 
            }
            $config.Properties.GetEnumerator() | ForEach-Object { 
                try { $ctrl.($_.Key) = $_.Value } catch {} 
            }
        
            # Add events
            if ($config.Events) { 
                $config.Events.GetEnumerator() | ForEach-Object { 
                    try { $ctrl."Add_$($_.Key)"({ $app.($_.Value)() }) } catch {} 
                } 
            }
        
            $createdControls[$name] = $ctrl
            $parent = if ($config.Layout -eq 'Form') { $this.MainForm } else { $createdControls[$config.Layout] }
            if ($parent) { $parent.Controls.Add($ctrl) }
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
                $app.OnFormShown() 
                # Set default selection after form is shown
                if ($app.Controls.ExecuteModeCombo -and $app.Controls.ExecuteModeCombo.Items.Count -gt 0) {
                    $app.Controls.ExecuteModeCombo.SelectedIndex = 0
                }
            })
    }

    [void]LoadData() {
        Write-Host "LoadData called. Controls available: $($this.Controls.Keys -join ', ')"
    
        if ($this.Controls.ContainsKey('MachineCombo') -and $this.Controls.MachineCombo) {
            Write-Host "Loading MachineCombo with $($this.Machines.Count) machines"
            $this.Controls.MachineCombo.Items.Clear()
            $this.Machines | ForEach-Object { $this.Controls.MachineCombo.Items.Add($_.DisplayName) | Out-Null }
            if ($this.Machines.Count -gt 0) {
                # Always select the local machine (first item) as default
                $this.Controls.MachineCombo.SelectedIndex = 0
                $this.CurrentMachine = $this.Machines[0].Name
            }
        }
        else {
            Write-Warning "MachineCombo control not found or is null"
        }
    
        if ($this.Controls.ContainsKey('CollectionCombo') -and $this.Controls.CollectionCombo) {
            Write-Host "Loading CollectionCombo with $($this.Collections.Count) collections"
            $this.Controls.CollectionCombo.Items.Clear()
            $this.Collections | ForEach-Object { $this.Controls.CollectionCombo.Items.Add($_) | Out-Null }
            if ($this.Collections.Count -gt 0) {
                $this.Controls.CollectionCombo.SelectedIndex = 0
                $this.CurrentCollection = $this.Collections[0]
            }
        }
        else {
            Write-Warning "CollectionCombo control not found or is null"
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
                $buttonText = "▶ Execute"
            }
            elseif ($selectedText -eq "As Admin") {
                $this.ExecutionMode = "Admin"
                $buttonText = "▶ Run as Admin"
            }
            elseif ($selectedText.StartsWith("As ")) {
                $this.ExecutionMode = $selectedText
                $userName = $selectedText.Substring(3)
                $buttonText = "▶ Run as $userName"
            }
            else {
                $this.ExecutionMode = $selectedText
                $buttonText = "▶ Run as User..."
            }
        
            $this.Controls.ExecuteBtn.Text = $buttonText
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
        Write-host "Form shown, loading data..."
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
    
    [void]Show() { 
        [System.Windows.Forms.Application]::EnableVisualStyles()
        $this.MainForm.ShowDialog() | Out-Null 
    }
}

# Entry point
$app = [PSUtilApp]::new()
$app.Show()