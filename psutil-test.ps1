<#
PowerShell GUI utility for executing scripts from GitHub repository
Features:
- PS1 script files with embedded metadata 
- Multiple execution modes (Admin, Current User, Other Users)
- Multi-script collections support
#>

Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# Helper function to show messages that works with IEX
function Show-PSUtilMessage {
    param(
        [string]$Message,
        [string]$Title = "PSUtil",
        [string]$Buttons = "OK",
        [string]$Icon = "Information"
    )
    
    try {
        # Ensure assemblies are loaded
        if (-not ([System.Management.Automation.PSTypeName]'System.Windows.Forms.MessageBox').Type) {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        }
        
        # Use reflection to call MessageBox.Show
        $messageBoxType = [System.Type]::GetType("System.Windows.Forms.MessageBox")
        if ($messageBoxType) {
            $showMethod = $messageBoxType.GetMethod("Show", [System.Type[]]@([string], [string]))
            $result = $showMethod.Invoke($null, @($Message, $Title))
            return $result
        }
        else {
            throw "MessageBox type not available"
        }
    }
    catch {
        # Fallback to console output
        Write-Host "[$Title] $Message" -ForegroundColor Yellow
        # Also try simple Read-Host for user acknowledgment
        try {
            Read-Host "Press Enter to continue"
        }
        catch {
            # If Read-Host fails, just continue
        }
        return "OK"
    }
}

class PSUtilApp {
    # Config
    $Owner = "mrdotkg"; $Repo = "dotfiles"; $Branch = "main"; $DbFile = "db.ps1"
    $DataDir = "$env:USERPROFILE\Documents\PSUtil Local Data"
    $DatabaseUrl; $Controls = @{}; $Theme = @{}
    $Machines = @(); $Collections = @(); $ScriptFiles = @(); $SelectedScriptFiles = @(); $CurrentMachine; $CurrentCollection; $IsExecuting
    $ExecutionMode = "CurrentUser" # CurrentUser, Admin, OtherUser
    $MainForm

    PSUtilApp() {
        try {
            $this.Initialize()
            $this.CreateInterface()
        }
        catch {
            Write-Error "Error during PSUtilApp initialization: $_"
            Write-Error "Stack trace: $($_.ScriptStackTrace)"
            Show-PSUtilMessage -Message "Error during initialization: $_`n`nStack trace: $($_.ScriptStackTrace)" -Title "Initialization Error"
            throw
        }
    }

    Initialize() {
        # Setup
        @("$($this.DataDir)", "$($this.DataDir)\Collections", "$($this.DataDir)\Logs", "$($this.DataDir)\Scripts") | ForEach-Object { if (!(Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null } }
        $this.DatabaseUrl = "https://raw.githubusercontent.com/$($this.Owner)/$($this.Repo)/refs/heads/$($this.Branch)/$($this.DbFile)"
        
        # Theme
        $accent = try { 
            $accentValue = Get-ItemPropertyValue "HKCU:\Software\Microsoft\Windows\DWM" "AccentColor"
            [System.Drawing.Color]::FromArgb($accentValue)
        }
        catch { 
            [System.Drawing.Color]::FromArgb(44, 151, 222) 
        }
        $this.Theme = @{
            Colors = @{ 
                Accent     = $accent
                Background = [System.Drawing.Color]::FromArgb(241, 243, 249)
                Surface    = [System.Drawing.Color]::White
                Text       = [System.Drawing.Color]::Black 
            }
            Fonts  = @{ 
                Default = New-Object System.Drawing.Font("Segoe UI", 10)
                Bold    = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
            }
            Layout = @{ 
                Window  = @{ Width = 800; Height = 600; Padding = New-Object System.Windows.Forms.Padding(5, 5, 5, 5) }
                Control = @{ Height = 30; Width = 120; Padding = New-Object System.Windows.Forms.Padding(1, 1, 1, 1) }
                ToolBar = @{ Height = 30; Padding = New-Object System.Windows.Forms.Padding(2, 2, 2, 2) }
                Status  = @{ Height = 30; Padding = New-Object System.Windows.Forms.Padding(2, 2, 2, 2) } 
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

    LoadScriptFiles() {
        $this.ScriptFiles = @()
        
        try {
            $sourceInfo = $this.GetSourceInfo()
            
            # Check source type and load accordingly - Fix conditional logic
            if ($sourceInfo -and (($sourceInfo.Contains("(GitHub)")) -or ($sourceInfo.Contains("(Remote)")))) {
                $this.LoadRemoteScriptFiles()
            }
            elseif ($sourceInfo -and $sourceInfo.Contains("(Local)")) {
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
    
    LoadRemoteScriptFiles() {
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
    
    GetRemoteScriptFilesRecursive($path) {
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
        
        $files
    }
    
    LoadLocalScriptFiles($directory) {
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

    LoadCollections() {
        $collectionsDir = "$($this.DataDir)\Collections"
        $this.Collections = if (Test-Path $collectionsDir) { (Get-ChildItem $collectionsDir -Filter "*.txt").BaseName } else { @() }
        $defaultCollection = "$collectionsDir\All Commands.txt"
        if (!(Test-Path $defaultCollection)) { 
            "# All Commands - Multiple Script Files`ndb.ps1`n# Add more script files below" | Set-Content $defaultCollection -Force
            $this.Collections += "All Commands" 
        }
        $this.CurrentCollection = if ($this.Collections.Count -gt 0) { $this.Collections[0] } else { $null }
    }

    CreateInterface() {
        try {
            # Determine source for title
            $sourceInfo = $this.GetSourceInfo()
            
            # Main Form
            $this.MainForm = New-Object System.Windows.Forms.Form
            $this.MainForm.Text = "PSUTIL - $sourceInfo"
            $this.MainForm.Size = New-Object System.Drawing.Size(900, 650)
            $this.MainForm.StartPosition = "CenterScreen"
            $this.MainForm.BackColor = $this.Theme.Colors.Background
            $this.MainForm.Font = $this.Theme.Fonts.Default
            
            # Create panels first
            $toolbar = New-Object System.Windows.Forms.Panel
            $toolbar.Dock = "Top"
            $toolbar.Height = $this.Theme.Layout.ToolBar.Height
            $toolbar.BackColor = $this.Theme.Colors.Background
            $toolbar.Padding = $this.Theme.Layout.ToolBar.Padding
            
            $content = New-Object System.Windows.Forms.Panel
            $content.Dock = "Fill"
            $content.BackColor = $this.Theme.Colors.Background
            
            $status = New-Object System.Windows.Forms.Panel
            $status.Dock = "Bottom"
            $status.Height = $this.Theme.Layout.Status.Height
            $status.BackColor = $this.Theme.Colors.Background
            $status.Padding = $this.Theme.Layout.Status.Padding
            
            # Create controls
            $scriptsListView = New-Object System.Windows.Forms.ListView
            $scriptsListView.Dock = "Fill"
            $scriptsListView.View = "Details"
            $scriptsListView.GridLines = $true
            $scriptsListView.CheckBoxes = $true
            $scriptsListView.FullRowSelect = $true
            $scriptsListView.BackColor = $this.Theme.Colors.Surface
            $scriptsListView.Font = $this.Theme.Fonts.Default
            
            $executeBtn = New-Object System.Windows.Forms.Button
            $executeBtn.Text = "▶ Run Commands"
            $executeBtn.Dock = "Left"
            $executeBtn.Width = $this.Theme.Layout.Control.Width * 2
            $executeBtn.Height = $this.Theme.Layout.Control.Height
            $executeBtn.BackColor = $this.Theme.Colors.Accent
            $executeBtn.ForeColor = $this.Theme.Colors.Surface
            $executeBtn.FlatStyle = "Flat"
            $executeBtn.Font = $this.Theme.Fonts.Bold
            
            $executeModeCombo = New-Object System.Windows.Forms.ComboBox
            $executeModeCombo.Dock = "Left"
            $executeModeCombo.Width = $this.Theme.Layout.Control.Width
            $executeModeCombo.Height = $this.Theme.Layout.Control.Height
            $executeModeCombo.DropDownStyle = "DropDownList"
            $executeModeCombo.Font = $this.Theme.Fonts.Default
            
            $machineCombo = New-Object System.Windows.Forms.ComboBox
            $machineCombo.Dock = "Left"
            $machineCombo.Width = $this.Theme.Layout.Control.Width
            $machineCombo.Height = $this.Theme.Layout.Control.Height
            $machineCombo.DropDownStyle = "DropDownList"
            $machineCombo.Font = $this.Theme.Fonts.Default
            
            $selectAllCheckBox = New-Object System.Windows.Forms.CheckBox
            $selectAllCheckBox.Text = "Select All"
            $selectAllCheckBox.Dock = "Left"
            $selectAllCheckBox.Width = $this.Theme.Layout.Control.Width
            $selectAllCheckBox.Height = $this.Theme.Layout.Control.Height
            $selectAllCheckBox.Font = $this.Theme.Fonts.Default
            $selectAllCheckBox.BackColor = $this.Theme.Colors.Background
            $selectAllCheckBox.ForeColor = $this.Theme.Colors.Text
            
            $filesCombo = New-Object System.Windows.Forms.ComboBox
            $filesCombo.Dock = "Right"
            $filesCombo.Width = $this.Theme.Layout.Control.Width
            $filesCombo.Height = $this.Theme.Layout.Control.Height
            $filesCombo.DropDownStyle = "DropDownList"
            $filesCombo.Font = $this.Theme.Fonts.Default
            
            $collectionCombo = New-Object System.Windows.Forms.ComboBox
            $collectionCombo.Dock = "Right"
            $collectionCombo.Width = $this.Theme.Layout.Control.Width
            $collectionCombo.Height = $this.Theme.Layout.Control.Height
            $collectionCombo.DropDownStyle = "DropDownList"
            $collectionCombo.Font = $this.Theme.Fonts.Default
            
            $filterText = New-Object System.Windows.Forms.TextBox
            $filterText.Dock = "Right"
            $filterText.Width = $this.Theme.Layout.Control.Width
            $filterText.Height = $this.Theme.Layout.Control.Height
            $filterText.Font = $this.Theme.Fonts.Default
            $filterText.BackColor = $this.Theme.Colors.Surface
            $filterText.ForeColor = $this.Theme.Colors.Text
            
            # Store controls
            $this.Controls = @{
                ScriptsListView   = $scriptsListView
                ExecuteBtn        = $executeBtn
                ExecuteModeCombo  = $executeModeCombo
                MachineCombo      = $machineCombo
                SelectAllCheckBox = $selectAllCheckBox
                FilesCombo        = $filesCombo
                CollectionCombo   = $collectionCombo
                FilterText        = $filterText
                Toolbar           = $toolbar
                Content           = $content
                Status            = $status
            }
            
            # Add columns to ListView
            $scriptsListView.Columns.Add("Script", 250) | Out-Null
            $scriptsListView.Columns.Add("Command", 350) | Out-Null
            $scriptsListView.Columns.Add("File", 100) | Out-Null
            $scriptsListView.Columns.Add("Status", 100) | Out-Null
            
            # Setup execution mode combo items
            $executeModeCombo.Items.Add("As $env:USERNAME (Current User)") | Out-Null
            $executeModeCombo.Items.Add("As Admin") | Out-Null
            
            # Add other users safely - Enhanced user detection
            try {
                $otherUsers = @()
                
                # Try modern PowerShell cmdlet first
                try {
                    $otherUsers = Get-LocalUser -ErrorAction Stop | Where-Object { 
                        $_.Name -ne $env:USERNAME -and 
                        $_.Enabled -eq $true -and 
                        $_.Name -notlike "*$*" -and
                        $_.Name -ne "DefaultAccount" -and
                        $_.Name -ne "WDAGUtilityAccount"
                    } | Select-Object -ExpandProperty Name
                    Write-Host "Found users via Get-LocalUser: $($otherUsers -join ', ')"
                }
                catch {
                    # Fallback to WMI for older systems
                    try {
                        $otherUsers = Get-WmiObject Win32_UserAccount -Filter "LocalAccount=True AND Disabled=False" -ErrorAction Stop | Where-Object { 
                            $_.Name -ne $env:USERNAME -and
                            $_.Name -notlike "*$*" -and
                            $_.Name -ne "DefaultAccount" -and
                            $_.Name -ne "WDAGUtilityAccount"
                        } | Select-Object -ExpandProperty Name
                        Write-Host "Found users via WMI: $($otherUsers -join ', ')"
                    }
                    catch {
                        # Final fallback to net user command
                        try {
                            $netUsers = net user 2>$null | Where-Object { $_ -match "^[a-zA-Z]" -and $_ -notlike "*command completed*" }
                            if ($netUsers) {
                                $otherUsers = $netUsers | ForEach-Object { $_.Trim() } | Where-Object { 
                                    $_ -ne $env:USERNAME -and 
                                    $_ -notlike "*$*" -and
                                    $_ -ne "DefaultAccount" -and
                                    $_ -ne "WDAGUtilityAccount" -and
                                    $_ -ne ""
                                }
                                Write-Host "Found users via net user: $($otherUsers -join ', ')"
                            }
                        }
                        catch {
                            Write-Warning "Could not enumerate users via any method"
                        }
                    }
                }
                
                # Add found users to combo
                if ($otherUsers -and $otherUsers.Count -gt 0) {
                    foreach ($user in $otherUsers) {
                        if ($user -and $user.Trim() -ne "") {
                            $executeModeCombo.Items.Add("As $($user.Trim())") | Out-Null
                        }
                    }
                    Write-Host "Added $($otherUsers.Count) other users to execution mode combo"
                }
                else {
                    $executeModeCombo.Items.Add("Other User...") | Out-Null
                    Write-Host "No other users found, added 'Other User...' option"
                }
            }
            catch {
                Write-Warning "Error adding users to execution mode combo: $_"
                $executeModeCombo.Items.Add("Other User...") | Out-Null
            }

            # Add event handlers
            $app = $this
            $executeBtn.Add_Click({ $app.ExecuteSelectedScripts() })
            $executeModeCombo.Add_SelectedIndexChanged({ $app.OnExecutionModeChanged() })
            $machineCombo.Add_SelectedIndexChanged({ $app.SwitchMachine() })
            $selectAllCheckBox.Add_CheckedChanged({ $app.OnSelectAllChanged() })
            $filesCombo.Add_SelectedIndexChanged({ $app.OnFilesComboChanged() })
            $collectionCombo.Add_SelectedIndexChanged({ $app.OnCollectionChanged() })
            $filterText.Add_TextChanged({ $app.FilterScripts() })
            
            # Add event handler for list view item checked changes to update button text
            $scriptsListView.Add_ItemChecked({ $app.UpdateExecuteButtonText() })

            # Add controls to panels
            $toolbar.Controls.Add($executeBtn)
            $toolbar.Controls.Add($executeModeCombo)
            $toolbar.Controls.Add($machineCombo)
            $toolbar.Controls.Add($selectAllCheckBox)
            $toolbar.Controls.Add($filesCombo)
            $toolbar.Controls.Add($collectionCombo)
            $toolbar.Controls.Add($filterText)
            
            $content.Controls.Add($scriptsListView)
            
            # Add panels to form
            $this.MainForm.Controls.Add($content)
            $this.MainForm.Controls.Add($toolbar)
            $this.MainForm.Controls.Add($status)
            
            # Set form shown event
            $this.MainForm.Add_Shown({ 
                    try {
                        $app.OnFormShown() 
                        if ($app.Controls.ExecuteModeCombo.Items.Count -gt 0) {
                            $app.Controls.ExecuteModeCombo.SelectedIndex = 0
                        }
                    }
                    catch {
                        Write-Warning "Error in Form_Shown event: $_"
                    }
                })
        }
        catch {
            Write-Error "Error in CreateInterface: $_"
            throw
        }
    }

    LoadData() {
        try {
            if ($this.Controls.MachineCombo) {
                $this.Controls.MachineCombo.Items.Clear()
                $this.Machines | ForEach-Object { 
                    $this.Controls.MachineCombo.Items.Add($_.DisplayName) | Out-Null 
                }
                if ($this.Machines.Count -gt 0) {
                    $this.Controls.MachineCombo.SelectedIndex = 0
                    $this.CurrentMachine = $this.Machines[0].Name
                }
            }
        }
        catch {
            Write-Warning "Error loading machine data: $_"
        }
    
        try {
            if ($this.Controls.CollectionCombo) {
                $this.Controls.CollectionCombo.Items.Clear()
                $this.Collections | ForEach-Object { 
                    $this.Controls.CollectionCombo.Items.Add($_) | Out-Null 
                }
                if ($this.Collections.Count -gt 0) {
                    $this.Controls.CollectionCombo.SelectedIndex = 0
                    $this.CurrentCollection = $this.Collections[0]
                }
            }
        }
        catch {
            Write-Warning "Error loading collection data: $_"
        }

        try {
            if ($this.Controls.FilesCombo) {
                $this.Controls.FilesCombo.Items.Clear()
                $this.Controls.FilesCombo.Items.Add("From All Files") | Out-Null
                
                $sortedFiles = $this.ScriptFiles | Sort-Object
                $sortedFiles | ForEach-Object { 
                    $this.Controls.FilesCombo.Items.Add("From $_") | Out-Null 
                }
                
                if ($this.Controls.FilesCombo.Items.Count -gt 0) {
                    $this.Controls.FilesCombo.SelectedIndex = 0
                    $this.SelectedScriptFiles = $this.ScriptFiles
                }
            }
        }
        catch {
            Write-Warning "Error loading files data: $_"
        }
    }

    LoadCollectionScripts() {
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
        catch {
            Show-PSUtilMessage -Message "Failed to load collection scripts: $_" -Title "Error"
        }
    }

    ParsePS1ScriptFile($content, $fileName) {
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
        $scripts
    }

    ExecuteSelectedScripts() {
        if ($this.IsExecuting) { return }
        $checkedItems = $this.Controls.ScriptsListView.Items | Where-Object { $_.Checked }
        if (!$checkedItems) { 
            Show-PSUtilMessage -Message "No scripts selected."
            return 
        }
    
        $this.IsExecuting = $true; $this.Controls.ExecuteBtn.Enabled = $false
        $checkedItems | ForEach-Object {
            $_.SubItems[3].Text = "Running..."
            $_.BackColor = [System.Drawing.Color]::LightYellow
            try {
                $script = $_.Tag
                $result = $this.ExecuteScript($script)
            
                $_.SubItems[3].Text = if ($result.Success) { "Completed" } else { "Failed" }
                $_.BackColor = if ($result.Success) { [System.Drawing.Color]::LightGreen } else { [System.Drawing.Color]::LightCoral }
                $_.Checked = !$result.Success
            }
            catch { 
                $_.SubItems[3].Text = "Failed"
                $_.BackColor = [System.Drawing.Color]::LightCoral
                Write-host "Execution error: $_" -ForegroundColor Red
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
        $this.IsExecuting = $false; $this.Controls.ExecuteBtn.Enabled = $true
    }

    ExecuteScript($script) {
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
        
            @{ Success = $true; Output = $result }
        }
        catch {
            @{ Success = $false; Output = $_.Exception.Message }
        }
    }

    OnExecutionModeChanged() {
        try {
            $selectedIndex = $this.Controls.ExecuteModeCombo.SelectedIndex
            if ($selectedIndex -ge 0) {
                $selectedText = $this.Controls.ExecuteModeCombo.Items[$selectedIndex].ToString()
            
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
        catch {
            Write-Warning "Error in OnExecutionModeChanged: $_"
        }
    }

    SwitchMachine() {
        try {
            $idx = $this.Controls.MachineCombo.SelectedIndex
            if ($idx -ge 0 -and $idx -lt $this.Machines.Count) { 
                $this.CurrentMachine = $this.Machines[$idx].Name 
            }
        }
        catch {
            Write-Warning "Error in SwitchMachine: $_"
        }
    }

    FilterScripts() {
        try {
            if ($this.Controls.FilterText -and $this.Controls.ScriptsListView) {
                $filter = $this.Controls.FilterText.Text.ToLower()
                $this.Controls.ScriptsListView.Items | ForEach-Object {
                    $visible = !$filter -or $_.Text.ToLower().Contains($filter) -or $_.SubItems[1].Text.ToLower().Contains($filter)
                    $_.ForeColor = if ($visible) { $this.Theme.Colors.Text } else { [System.Drawing.Color]::LightGray }
                }
            }
        }
        catch {
            Write-Warning "Error in FilterScripts: $_"
        }
    }

    OnFormShown() { 
        $this.MainForm.Activate()
        $this.LoadData()
        
        # Initialize button text with current count
        $this.UpdateExecuteButtonText()
        
        if ($this.CurrentCollection) { 
            $this.LoadCollectionScripts() 
        }
        else {
            $this.OnFileSelectionChanged()
        }
    }
    
    OnCollectionChanged() { 
        try {
            $idx = $this.Controls.CollectionCombo.SelectedIndex
            if ($idx -ge 0 -and $idx -lt $this.Collections.Count) { 
                $this.CurrentCollection = $this.Collections[$idx]
                $this.LoadCollectionScripts() 
            } 
        }
        catch {
            Write-Warning "Error in OnCollectionChanged: $_"
        }
    }
    
    OnFileSelectionChanged() {
        if ($this.SelectedScriptFiles -and $this.SelectedScriptFiles.Count -gt 0) {
            $this.LoadScriptsFromFiles($this.SelectedScriptFiles)
        }
        else {
            $this.Controls.ScriptsListView.Items.Clear()
        }
    }

    OnFilesComboChanged() {
        try {
            if ($this.Controls.FilesCombo -and $this.Controls.FilesCombo.SelectedIndex -ge 0) {
                $selectedText = $this.Controls.FilesCombo.Items[$this.Controls.FilesCombo.SelectedIndex].ToString()
                
                if ($selectedText -eq "From All Files") {
                    $this.SelectedScriptFiles = $this.ScriptFiles
                }
                else {
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

    LoadScriptsFromFiles($scriptFiles) {
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
        
        # Update button text after loading scripts
        $this.UpdateExecuteButtonText()
    }

    ParseScriptFile($content, $fileName) {
        $extension = [System.IO.Path]::GetExtension($fileName).ToLower()
        
        switch ($extension) {
            '.ps1' { $this.ParsePS1ScriptFile($content, $fileName) }
            '.sh' { $this.ParseShellScriptFile($content, $fileName) }
            '.bash' { $this.ParseShellScriptFile($content, $fileName) }
            '.py' { $this.ParsePythonScriptFile($content, $fileName) }
            default { $this.ParseGenericScriptFile($content, $fileName) }
        }
    }

    ParseShellScriptFile($content, $fileName) {
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
        $scripts
    }

    ParsePythonScriptFile($content, $fileName) {
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
        $scripts
    }

    ParseGenericScriptFile($content, $fileName) {
        @(@{
                Description = "Execute $fileName"
                Command     = $content.Trim()
                File        = $fileName
                LineNumber  = 1
            })
    }

    OnSelectAllChanged() {
        try {
            if ($this.Controls.SelectAllCheckBox -and $this.Controls.ScriptsListView) {
                $checked = $this.Controls.SelectAllCheckBox.Checked
                $this.Controls.ScriptsListView.Items | ForEach-Object {
                    $_.Checked = $checked
                }
                $this.UpdateExecuteButtonText()
            }
        }
        catch {
            Write-Warning "Error in OnSelectAllChanged: $_"
        }
    }

    UpdateExecuteButtonText() {
        try {
            if ($this.Controls.ScriptsListView -and $this.Controls.ExecuteBtn) {
                $checkedCount = ($this.Controls.ScriptsListView.Items | Where-Object { $_.Checked }).Count
                $this.Controls.ExecuteBtn.Text = "▶ Run $checkedCount Commands"
            }
        }
        catch {
            Write-Warning "Error updating execute button text: $_"
        }
    }

    Show() { 
        try {
            [System.Windows.Forms.Application]::EnableVisualStyles()
            $null = $this.MainForm.ShowDialog()
        }
        catch {
            Write-Error "Error in Show method: $_"
            Show-PSUtilMessage -Message "Error starting application: $_`n`nStack trace: $($_.ScriptStackTrace)" -Title "Application Error"
        }
    }

    GetSourceInfo() {
        try {
            # Get the script path - check multiple sources
            $currentScript = $PSCommandPath
            if (!$currentScript) {
                $currentScript = $MyInvocation.ScriptName
            }
            if (!$currentScript) {
                $currentScript = $script:MyInvocation.MyCommand.Path
            }
            
            Write-Host "Current script path: $currentScript"
            
            # Check if running from URL (IEX scenario)
            if ($currentScript -and $currentScript -match "^https?://") {
                "$($this.Owner.ToUpper())/$($this.Repo.ToUpper()) (GitHub)"
            }
            # Check if running from local file
            elseif ($currentScript -and (Test-Path $currentScript)) {
                $scriptDir = Split-Path $currentScript -Parent
                "$scriptDir (Local)"
            }
            # Check if we're in a known local development path
            elseif ($PWD.Path -and $PWD.Path.Contains("dotfiles")) {
                "$($PWD.Path) (Local)"
            }
            # Default to remote
            else {
                "$($this.Owner.ToUpper())/$($this.Repo.ToUpper()) (Remote)"
            }
        }
        catch {
            Write-Warning "Error in GetSourceInfo: $_"
            "$($this.Owner.ToUpper())/$($this.Repo.ToUpper())"
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
    Show-PSUtilMessage -Message "Fatal error: $_" -Title "Fatal Error"
}