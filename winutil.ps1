<#
WinUtilApp.ps1 - Object-Oriented rewrite of gui.ps1
#>

Add-Type -AssemblyName System.Drawing, System.Windows.Forms

class WinUtilApp {
    [hashtable]$Config
    [hashtable]$UI
    [string]$DataDirectory
    [string]$ProfilesDirectory
    [string]$LogsDirectory
    [System.Windows.Forms.Form]$Form
    [System.Windows.Forms.Panel]$HeaderPanel
    [System.Windows.Forms.Panel]$ContentPanel
    [System.Windows.Forms.Panel]$FooterPanel
    [System.Windows.Forms.Panel]$ScriptsPanel
    [System.Windows.Forms.Panel]$ToolBarPanel
    [System.Windows.Forms.Panel]$StatusPanel
    [System.Windows.Forms.Panel]$ProgressBarPanel
    [System.Windows.Forms.Panel]$StatusContentPanel
    [System.Windows.Forms.Label]$StatusLabel
    [System.Windows.Forms.Button]$ActionButton
    [System.Windows.Forms.Button]$CancelButton
    [System.Windows.Forms.Button]$HelpLabel
    [System.Windows.Forms.Button]$SearchButton
    [System.Windows.Forms.CheckBox]$SelectAllSwitch
    [System.Windows.Forms.CheckBox]$ConsentCheckbox
    [System.Windows.Forms.ComboBox]$ProfileDropdown
    [System.Windows.Forms.ComboBox]$MachineDropdown
    [System.Windows.Forms.TextBox]$SearchBox
    [System.Windows.Forms.ProgressBar]$ProgressBar
    [int]$CurrentProfileIndex = -1
    [string]$CurrentMachine = $env:COMPUTERNAME
    [System.Collections.ArrayList]$AvailableMachines
    [System.Collections.Generic.Dictionary[string, System.Windows.Forms.ListView]]$ListViews
    [System.Collections.Generic.List[System.Windows.Forms.ListViewItem]]$RetryItems
    [string]$CurrentLogFile
    [hashtable]$CreatedButtons

    WinUtilApp() {
        # Config from original
        $this.Config = @{
            ApiUrl        = $null
            DatabaseFile  = 'db.json'
            DatabaseUrl   = $null
            GitHubBranch  = 'main'
            GitHubOwner   = 'mrdotkg'
            GitHubRepo    = 'dotfiles'
            ScriptsPath   = "$env:USERPROFILE\Documents\WinUtil Local Data"
            SshConfigPath = "$env:USERPROFILE\.ssh\config"
        }
        $this.Config.DatabaseUrl = "https://raw.githubusercontent.com/$($this.Config.GitHubOwner)/$($this.Config.GitHubRepo)/refs/heads/$($this.Config.GitHubBranch)/$($this.Config.DatabaseFile)"
        $this.Config.ApiUrl = "https://api.github.com/repos/$($this.Config.GitHubOwner)/$($this.Config.GitHubRepo)/contents"

        # init collections
        $this.UI = @{}
        $this.DataDirectory = "$env:USERPROFILE\Documents\WinUtil Local Data"
        $this.ProfilesDirectory = "$env:USERPROFILE\Documents\WinUtil Local Data\Profiles"
        $this.LogsDirectory = "$env:USERPROFILE\Documents\WinUtil Local Data\Logs"
        $this.ListViews = [ordered]@{}
        $this.AvailableMachines = [System.Collections.ArrayList]::new()
        $this.CreatedButtons = @{}
        $this.RetryItems = [System.Collections.Generic.List[System.Windows.Forms.ListViewItem]]::new()

        # build UI & logic
        $this.SetupUIProperties()
        $this.CreateControls()
        $this.WireEvents()
        $this.FinalizeLayout()
        $this.PopulateProfiles()
        $this.RefreshSshMachines()
    }

    [void]SetupUIProperties() {
        # Colors, Fonts, Padding, Sizes
        $this.UI = @{
            Colors  = @{
                Accent     = $null
                Background = [System.Drawing.Color]::FromArgb(241, 243, 249)
                Disabled   = [System.Drawing.Color]::LightGray
                Text       = [System.Drawing.Color]::Black
            }
            Fonts   = @{
                Big       = [System.Drawing.Font]::new("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
                Bold      = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
                Default   = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
                Small     = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
                SmallBold = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            }
            Padding = @{
                Button  = '0,0,0,0'
                Content = '0,0,0,35'
                Control = '2,2,2,2'
                Footer  = '0,0,0,0'
                Form    = '5,0,5,0'
                Header  = '0,0,0,0'
                Help    = '15,15,15,15'
                Panel   = '0,0,0,0'
                Status  = '0,5,0,5'
                ToolBar = '0,5,0,5'
                Updates = '15,15,15,15'
            }
            Sizes   = @{
                Columns = @{ Command = 200; Name = -2 }
                Input   = @{ Height = 25; Width = 120; FooterWidth = 120; Icon = @{ Height = 25; Width = 25 } }
                Header  = @{ Height = 0 }
                Footer  = @{ Height = 30 }
                Status  = @{ Height = 30 }
                ToolBar = @{ Height = 35 }
                Window  = @{ Height = 600; Width = 600 }
            }
        }

        # Detect accent color
        $val = Get-ItemPropertyValue HKCU:\Software\Microsoft\Windows\DWM -Name AccentColor -ErrorAction SilentlyContinue
        if ($val) {
            $this.UI.Colors.Accent = [System.Drawing.Color]::FromArgb(
                ($val -shr 0) -band 0xFF,
                ($val -shr 8) -band 0xFF,
                ($val -shr 16) -band 0xFF,
                ($val -shr 24) -band 0xFF
            )
        }
        else {
            $this.UI.Colors.Accent = [System.Drawing.Color]::FromArgb(44, 151, 222)
        }
    }

    [void]CreateControls() {
        # Form
        $formProps = @{
            Add_KeyDown    = $null
            Add_Shown      = $null
            Add_FormClosed = $null
            BackColor      = $this.UI.Colors.Background
            Font           = $this.UI.Fonts.Default
            Height         = $this.UI.Sizes.Window.Height
            KeyPreview     = $true
            Padding        = $this.UI.Padding.Form
            Text           = "WINUTIL-$($this.Config.GitHubOwner.ToUpper()) / $($this.Config.GitHubRepo.ToUpper())"
            Width          = $this.UI.Sizes.Window.Width
        }
        $this.Form = New-Object System.Windows.Forms.Form -Property $formProps

        # Header, Content, Footer, Progress panels
        $this.HeaderPanel = New-Object System.Windows.Forms.Panel -Property @{ BackColor = $this.UI.Colors.Background; Dock = 'Top'; Height = $this.UI.Sizes.Header.Height; Padding = $this.UI.Padding.Header }
        $this.ToolBarPanel = New-Object System.Windows.Forms.Panel -Property @{ Dock = 'Top'; Font = $this.UI.Fonts.Default; Height = $this.UI.Sizes.ToolBar.Height; Padding = $this.UI.Padding.ToolBar }
        $this.ScriptsPanel = New-Object System.Windows.Forms.Panel -Property @{ Dock = 'Fill'; Padding = '0,0,0,0' }
        $this.ProgressBarPanel = New-Object System.Windows.Forms.Panel -Property @{ BackColor = $this.UI.Colors.Background; Dock = 'Bottom'; Height = 5; Padding = '0,0,0,0' }
        $this.StatusPanel = New-Object System.Windows.Forms.Panel -Property @{ Dock = 'Top'; Font = $this.UI.Fonts.Small; Height = $this.UI.Sizes.Status.Height }
        $this.StatusContentPanel = New-Object System.Windows.Forms.Panel -Property @{ Dock = 'Fill'; Height = 25 }

        # Status label + buttons
        $this.StatusLabel = New-Object System.Windows.Forms.Label -Property @{
            AutoSize = $true; Dock = 'Left'; Padding = $this.UI.Padding.Status
            Text = "Gray Winutil is ready to run scripts."; Visible = $true
        }
        $this.ActionButton = New-Object System.Windows.Forms.Button -Property @{
            Dock = 'Right'; FlatStyle = 'Flat'; ForeColor = $this.UI.Colors.Accent
            Font = $this.UI.Fonts.Small; Height = 22; Text = '≡ Logs'; Visible = $false; Width = 70
        }
        $this.CancelButton = New-Object System.Windows.Forms.Button -Property @{
            Dock = 'Right'; FlatStyle = 'Flat'; ForeColor = $this.UI.Colors.Accent
            Font = $this.UI.Fonts.Small; Height = 22; Text = '✕ Cancel'; Visible = $false; Width = 70
        }
        $this.HelpLabel = New-Object System.Windows.Forms.Button -Property @{
            Dock = 'Left'; FlatStyle = 'Flat'; Font = $this.UI.Fonts.Bold
            ForeColor = $this.UI.Colors.Accent; Height = $this.UI.Sizes.Input.Icon.Height; Text = '?'; Width = $this.UI.Sizes.Input.Icon.Width
        }
        $this.ActionButton.FlatAppearance.BorderSize = 0
        $this.CancelButton.FlatAppearance.BorderSize = 0
        $this.HelpLabel.FlatAppearance.BorderSize = 0

        # Toolbar controls
        $this.SelectAllSwitch = New-Object System.Windows.Forms.CheckBox -Property @{
            Appearance = 'Button'; AutoSize = $false; BackColor = $this.UI.Colors.Accent; Dock = 'Left'
            FlatStyle = 'Flat'; Font = $this.UI.Fonts.Bold; ForeColor = [System.Drawing.Color]::White
            Height = $this.UI.Sizes.Input.Icon.Height; Width = $this.UI.Sizes.Input.Icon.Width; Tag = $false; Text = '◼'
        }
        $this.ProfileDropdown = New-Object System.Windows.Forms.ComboBox -Property @{
            Dock = 'Right'; DropDownStyle = 'DropDownList'; Font = $this.UI.Fonts.Default
            Height = $this.UI.Sizes.Input.Height; Width = $this.UI.Sizes.Input.Width
        }
        # Machine selection dropdown
        $this.MachineDropdown = New-Object System.Windows.Forms.ComboBox -Property @{
            Dock = 'Right'; DropDownStyle = 'DropDownList'; Font = $this.UI.Fonts.Default
            Height = $this.UI.Sizes.Input.Height; Width = $this.UI.Sizes.Input.Width
        }
        $this.SearchBox = New-Object System.Windows.Forms.TextBox -Property @{
            BackColor = $this.UI.Colors.Background; BorderStyle = 'FixedSingle'; Dock = 'Right'
            Height = $this.UI.Sizes.Input.Height; Width = ($this.UI.Sizes.Input.Width - 30); Text = 'Search ...'
        }
        $this.SearchButton = New-Object System.Windows.Forms.Button -Property @{
            BackColor = $this.UI.Colors.Accent; Dock = 'Right'; FlatStyle = 'Flat'
            Font = $this.UI.Fonts.Regular; ForeColor = [System.Drawing.Color]::White
            Width = $this.UI.Sizes.Input.Icon.Width; Text = 'X'
        }
        $this.ConsentCheckbox = New-Object System.Windows.Forms.CheckBox -Property @{
            Appearance = 'Button'; AutoSize = $false; BackColor = $this.UI.Colors.Accent; Dock = 'Left'
            FlatStyle = 'Flat'; Font = $this.UI.Fonts.Bold; ForeColor = [System.Drawing.Color]::White
            Height = $this.UI.Sizes.Input.Icon.Height; Width = $this.UI.Sizes.Input.Icon.Width; Text = '⛊'
        }
        # Run button
        $this.CreatedButtons['RunButton'] = New-Object System.Windows.Forms.Button -Property @{ 
            Text      = '▶ Run (0)';
            Dock      = 'Left';
            FlatStyle = 'Flat';
            BackColor = $this.UI.Colors.Accent;
            ForeColor = [System.Drawing.Color]::White;
            Font      = $this.UI.Fonts.Bold;
            Height    = $this.UI.Sizes.Input.Height;
            Width     = $this.UI.Sizes.Input.Width
        }
        $this.CreatedButtons['RunButton'].FlatAppearance.BorderSize = 0
    }

    [void]WireEvents() {
        # Keyboard shortcuts
        $this.Form.Add_KeyDown({
                param($s, $e)
                if ($e.Control -and $e.KeyCode -eq 'A') {
                    $this.SelectAllSwitch.Checked = $true
                    foreach ($lv in $this.ListViews.Values) { foreach ($i in $lv.Items) { $i.Checked = $true } }
                    $e.Handled = $true
                }
                elseif ($e.Control -and $e.KeyCode -eq 'R') {
                    if ($this.CreatedButtons['RunButton'].Enabled) { $this.CreatedButtons['RunButton'].PerformClick() }
                    $e.Handled = $true
                }
                elseif ($e.Control -and $e.KeyCode -eq 'C') {
                    $this.CopySelectedCommands(); $e.Handled = $true
                }
            })

        # Profile change
        $this.ProfileDropdown.Add_SelectedIndexChanged({ $this.OnProfileChanged() })

        # Toolbar buttons
        $this.CreatedButtons['RunButton'].Add_Click({ $this.OnRunButtonClick($false) })
        $this.SelectAllSwitch.Add_Click({
                $on = -not $this.SelectAllSwitch.Tag
                $this.SelectAllSwitch.Tag = $on
                $this.SelectAllSwitch.Checked = $on
                foreach ($lv in $this.ListViews.Values) { foreach ($i in $lv.Items) { $i.Checked = $on } }
            })
        $this.SearchButton.Add_Click({
                $this.SearchBox.Text = 'Search ...'
                foreach ($lv in $this.ListViews.Values) {
                    $lv.BeginUpdate()
                    foreach ($i in $lv.Items) { $i.ForeColor = $this.UI.Colors.Text }
                    $lv.EndUpdate()
                }
            })
        $this.ConsentCheckbox.Add_Click({
                $this.ConsentCheckbox.ForeColor = if ($this.ConsentCheckbox.Checked) { [System.Drawing.Color]::Red } else { [System.Drawing.Color]::White }
            })
        $this.HelpLabel.Add_Click({
                # original HELP form logic…
            })
        $this.ActionButton.Add_Click({
                if (Test-Path $this.CurrentLogFile) { Start-Process notepad.exe $this.CurrentLogFile }
                else { [System.Windows.Forms.MessageBox]::Show('No log file found.', 'Info') }
            })
        $this.CancelButton.Add_Click({
                $this.RetryItems.Clear()
                foreach ($lv in $this.ListViews.Values) {
                    foreach ($i in $lv.Items) {
                        if ($i.BackColor -eq [System.Drawing.Color]::FromArgb(255, 200, 200) -or
                            $i.BackColor -eq [System.Drawing.Color]::FromArgb(255, 235, 200)) {
                            $this.RetryItems.Add($i)
                        }
                    }
                }
                if ($this.RetryItems.Count) { $this.OnRunButtonClick($true) }
            })

        # Machine dropdown
        $this.MachineDropdown.Add_SelectedIndexChanged({
                $sel = $this.MachineDropdown.SelectedItem
                $m = $this.AvailableMachines | Where-Object DisplayName -EQ $sel
                if ($m) { $this.CurrentMachine = $m.Name; $this.StatusLabel.Text = "Target: $sel" }
            })
    }

    [void]FinalizeLayout() {
        # Assemble panels & controls
        $this.StatusContentPanel.Controls.AddRange(@($this.StatusLabel, $this.HelpLabel, $this.ActionButton, $this.CancelButton))
        $this.StatusPanel.Controls.AddRange(@($this.ProgressBarPanel, $this.StatusContentPanel))
        $this.ToolBarPanel.Controls.AddRange(@($this.SelectAllSwitch, $this.ConsentCheckbox, $this.MachineDropdown, $this.ProfileDropdown, $this.SearchBox, $this.SearchButton))
        $this.ContentPanel.Controls.AddRange(@($this.ScriptsPanel, $this.ToolBarPanel))
        $this.Form.Controls.AddRange(@($this.HeaderPanel, $this.ContentPanel, $this.FooterPanel))
    }

    [void]PopulateProfiles() {
        foreach ($d in @($this.DataDirectory, $this.ProfilesDirectory, $this.LogsDirectory)) {
            if (-not (Test-Path $d)) { New-Item -Path $d -ItemType Directory -Force | Out-Null }
        }
        $default = Join-Path $this.ProfilesDirectory 'Default Profile.txt'
        if (-not (Test-Path $default)) {
            try {
                $db = Invoke-WebRequest $this.Config.DatabaseUrl | ConvertFrom-Json
                $db.id | Set-Content $default
            }
            catch {
                '# Default Profile' | Set-Content $default
            }
        }
        $this.ProfileDropdown.Items.Clear()
        Get-ChildItem $this.ProfilesDirectory -Filter '*.txt' | ForEach-Object {
            $this.ProfileDropdown.Items.Add($_.BaseName) | Out-Null
        }
        $this.ProfileDropdown.SelectedIndex = 0
    }

    [void]RefreshSshMachines() {
        $this.AvailableMachines = $this.GetSshMachines()
        $this.MachineDropdown.Items.Clear()
        foreach ($m in $this.AvailableMachines) { $this.MachineDropdown.Items.Add($m.DisplayName) | Out-Null }
        $this.MachineDropdown.SelectedIndex = 0
    }

    [System.Collections.ArrayList]GetSshMachines() {
        $machines = [System.Collections.ArrayList]::new()
        # local
        $machines.Add(@{ Name = $env:COMPUTERNAME; DisplayName = "$env:COMPUTERNAME (Local)"; Type = 'Local'; Host = 'localhost' }) | Out-Null
        if (Test-Path $this.Config.SshConfigPath) {
            $curr = $null
            foreach ($l in Get-Content $this.Config.SshConfigPath) {
                $t = $l.Trim()
                if ($t -match '^Host\s+(.+)$') {
                    $h = $Matches[1]
                    if ($h -notmatch '[*?]' -and $h -ne 'localhost') {
                        $curr = @{Name = $h; DisplayName = $h; Type = 'SSH'; Host = $h; User = $null; Port = 22 }
                    }
                    else { $curr = $null }
                }
                elseif ($curr -and $t -match '^HostName\s+(.+)$') { $curr.Host = $Matches[1] }
                elseif ($curr -and $t -match '^User\s+(.+)$') { $curr.User = $Matches[1] }
                elseif ($curr -and $t -match '^Port\s+(.+)$') { $curr.Port = [int]$Matches[1] }
                elseif ($curr -and ($t -match '^Host\s+' -or $t -eq '')) {
                    $machines.Add($curr) | Out-Null; $curr = $null
                }
            }
            if ($curr) { $machines.Add($curr) | Out-Null }
        }
        return $machines
    }

    [void]OnProfileChanged() {
        $idx = $this.ProfileDropdown.SelectedIndex
        $name = $this.ProfileDropdown.SelectedItem
        $path = Join-Path $this.ProfilesDirectory "$name.txt"
        $groups = $this.ReadProfile($path)
        if ($groups.Count) { $this.CreateGroupedListView($this.ScriptsPanel, $groups) }
    }

    [System.Collections.Specialized.OrderedDictionary]ReadProfile([string]$p) {
        $gd = [System.Collections.Specialized.OrderedDictionary]::new()
        $grp = 'Group #1'
        if (-not (Test-Path $p)) { Write-Warning "Profile not found: $p"; return $gd }
        $lines = Get-Content $p
        foreach ($l in $lines) {
            if ($l -eq '') { $grp = "Group #$([int]($gd.Count+1))" }
            elseif ($l.TrimStart().StartsWith('#')) { $grp = $l.TrimStart('#').Trim() }
            else {
                if (-not $gd.Contains($grp)) { $gd[$grp] = @() }
                $gd[$grp] += @{ content = $l.Trim(); command = $l.Trim() }
            }
        }
        if (-not $gd.Count) { Write-Warning "No scripts in profile: $p" }
        return $gd
    }

    [void]CreateGroupedListView([System.Windows.Forms.Panel]$parent, [System.Collections.Specialized.OrderedDictionary]$groups) {
        $parent.Controls.Clear()
        $cont = New-Object System.Windows.Forms.Panel -Property @{ Dock = 'Fill' }
        $lv = New-Object System.Windows.Forms.ListView -Property @{
            AllowColumnReorder = $true; AllowDrop = $true; BorderStyle = 'None'; CheckBoxes = $true
            Dock = 'Fill'; Font = $this.UI.Fonts.Default; ForeColor = $this.UI.Colors.Text
            FullRowSelect = $true; GridLines = $true; MultiSelect = $false; ShowItemToolTips = $true
            Sorting = [System.Windows.Forms.SortOrder]::None; View = 'Details'
        }
        $lv.Columns.Add('SCRIPT', $this.UI.Sizes.Columns.Name) | Out-Null
        $lv.Columns.Add('COMMAND', $this.UI.Sizes.Columns.Command) | Out-Null
        $i = 0
        $grpObj = $null
        foreach ($g in $groups.Keys) {
            if ($groups.Count -gt 1) {
                $grpObj = New-Object System.Windows.Forms.ListViewGroup($g, $g)
                $lv.Groups.Add($grpObj) | Out-Null
            }
            foreach ($e in $groups[$g]) {
                $it = New-Object System.Windows.Forms.ListViewItem($e.content)
                $it.SubItems.Add($e.command) | Out-Null
                $it.BackColor = if ($i % 2 -eq 0) { [Drawing.Color]::FromArgb(240, 242, 245) } else { [Drawing.Color]::White }
                if ($lv.Groups.Count -gt 1) { $it.Group = $grpObj }
                $lv.Items.Add($it) | Out-Null
                $i++
            }
        }
        $this.ListViews.Clear()
        $this.ListViews['MainList'] = $lv
        $cont.Controls.Add($lv)
        $parent.Controls.Add($cont)
    }

    [void]OnRunButtonClick([bool]$retry = $false) {
        # replicate entire RunSelectedItems from gui.ps1
        $ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        $logFile = Join-Path $this.LogsDirectory "GrayWinUtil_Execution_$ts.log"
        $this.CurrentLogFile = $logFile
        $smode = if ($this.ConsentCheckbox.Checked) { 'administrator' } else { 'normal' }
        $mi = $this.AvailableMachines | Where-Object Name -EQ $this.CurrentMachine
        $remote = $mi.Type -eq 'SSH'
        # Replace ternary operator with if/else expression
        Add-Content $logFile "$(Get-Date -F 'yyyy-MM-dd HH:mm:ss.fff') INFO Starting execution in $smode mode on $(if ($remote) {'remote'} else {'local'})"
        # disable Run
        $this.CreatedButtons['RunButton'].Enabled = $false
        $this.CreatedButtons['RunButton'].Text = 'Running...'
        $this.StatusLabel.Text = 'Initializing execution...'
        $this.StatusLabel.Visible = $true
        $this.CancelButton.Visible = $true
        $this.ActionButton.Visible = $false
        # add progress bar
        $pb = New-Object System.Windows.Forms.ProgressBar -Property @{
            Dock = 'Fill'; Style = 'Continuous'
            Minimum = 0; Maximum = 100; Value = 0; ForeColor = $this.UI.Colors.Accent
        }
        $this.ProgressBarPanel.Controls.Add($pb)
        # gather items
        $sel = @()
        if ($retry -and $this.RetryItems.Count) { $sel = $this.RetryItems }
        else { foreach ($lv in $this.ListViews.Values) { $sel += $lv.Items | Where-Object Checked } }
        if (-not $sel.Count) {
            [Windows.Forms.MessageBox]::Show('No items selected.', 'Warning', [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        $pb.Maximum = $sel.Count
        # initial styling
        foreach ($lv in $this.ListViews.Values) {
            foreach ($it in $lv.Items) {
                if ($sel -contains $it) {
                    $it.BackColor = [Drawing.Color]::FromArgb(220, 240, 255)
                    $it.ForeColor = [Drawing.Color]::FromArgb(0, 70, 130)
                    $it.SubItems[1].Text = 'Queued'
                }
                else {
                    $it.BackColor = [Drawing.Color]::FromArgb(250, 250, 250)
                    $it.ForeColor = [Drawing.Color]::FromArgb(160, 160, 160)
                }
            }
        }
        # run loop
        $c = 0; $f = 0; $x = 0
        for ($i = 0; $i -lt $sel.Count; $i++) {
            $item = $sel[$i]; $cmd = $item.SubItems[1].Text; $nm = $item.Text
            $pb.Value = $i + 1
            $this.StatusLabel.Text = "Executing ($($i+1)/$($sel.Count)): $nm"
            [System.Windows.Forms.Application]::DoEvents()
            $item.BackColor = [Drawing.Color]::Yellow; $item.ForeColor = [Drawing.Color]::Black; $item.Font = $this.UI.Fonts.Bold
            [System.Windows.Forms.Application]::DoEvents()
            # stopwatch
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $fail = false; $cancel = false; $outp = ''
            try {
                if ($remote) {
                    # SSH branch
                    $ssh = "ssh " + (if ($mi.User) { "$($mi.User)@" } else { "" }) + $mi.Host + (if ($mi.Port -ne 22) { " -p $($mi.Port)" } else { "" })
                    $esc = $cmd -replace '"', '\"'
                    $ssh += " `"$esc`""
                    $p = New-Object Diagnostics.ProcessStartInfo
                    $p.FileName = "powershell.exe"; $p.Arguments = "-Command `"$ssh`""
                    $p.RedirectStandardOutput = $true; $p.RedirectStandardError = $true; $p.UseShellExecute = $false; $p.CreateNoWindow = $true
                    $proc = [Diagnostics.Process]::Start($p)
                    $out = $proc.StandardOutput.ReadToEnd(); $err = $proc.StandardError.ReadToEnd()
                    $proc.WaitForExit()
                    if ($err -match 'connection.*refused|permission.*denied' -or $proc.ExitCode -eq 255) {
                        $fail = $true; $outp = "SSH failed: " + (if ($out) { $out } else { $err })
                    }
                    elseif ($err -match 'cancelled|aborted' -or $out -match 'cancelled|aborted') {
                        $cancel = $true; $outp = "SSH canceled"
                    }
                    elseif ($proc.ExitCode -ne 0) {
                        $fail = $true; $outp = "SSH exit code $($proc.ExitCode)"
                    }
                    else {
                        $outp = $out.Trim()
                    }
                }
                elseif ($this.ConsentCheckbox.Checked) {
                    # run as admin
                    $pi = New-Object Diagnostics.ProcessStartInfo
                    $pi.FileName = "powershell.exe"; $pi.Arguments = "-Command `"$cmd`""; $pi.Verb = "runas"; $pi.CreateNoWindow = $true; $pi.UseShellExecute = $true
                    try { $pr = [Diagnostics.Process]::Start($pi); $pr.WaitForExit(); if ($pr.ExitCode -ne 0) { $fail = $true; $outp = "Admin failed: exit $($pr.ExitCode)" } }
                    catch [ComponentModel.Win32Exception] { $cancel = $true; $outp = "User declined UAC" }
                }
                elseif ($cmd -match 'winget') {
                    # winget
                    $pi = New-Object Diagnostics.ProcessStartInfo
                    $pi.FileName = "powershell.exe"; $pi.Arguments = "-Command `"$cmd`""; $pi.RedirectStandardOutput = $true; $pi.RedirectStandardError = $true; $pi.UseShellExecute = $false; $pi.CreateNoWindow = $true
                    $pr = [Diagnostics.Process]::Start($pi)
                    $o = $pr.StandardOutput.ReadToEnd(); $e = $pr.StandardError.ReadToEnd(); $pr.WaitForExit()
                    $outp = if ($o.Trim()) { $o.Trim() } else { $e.Trim() }
                    if ($e -match 'error|denied' -or $pr.ExitCode -ne 0) { $fail = $true }
                }
                else {
                    # local
                    $ea = $global:ErrorActionPreference; $global:ErrorActionPreference = 'Stop'
                    try { $res = Invoke-Expression $cmd 2>&1; $trim = $res.ToString().Trim(); $outp = if ($trim) { $trim } else { 'No output' }; if ($res -match 'error|denied') { $fail = $true } }
                    catch { $fail = $true; $outp = $_.Exception.Message }
                    finally { $global:ErrorActionPreference = $ea }
                }
            }
            catch {
                $fail = true; $outp = $_.Exception.Message
            }
            finally {
                $sw.Stop()
                $dur = if ($sw.ElapsedMilliseconds -gt 1000) { "{0:N2}s" -f ($sw.ElapsedMilliseconds / 1000) } else { "$($sw.ElapsedMilliseconds)ms" }
                Add-Content $this.CurrentLogFile "$(Get-Date -F 'yyyy-MM-dd HH:mm:ss.fff') $((if($fail){'ERROR'}elseif($cancel){'WARN'}else{'INFO'})) $nm ($dur): $outp"
                if ($cancel) {
                    $item.BackColor = [Drawing.Color]::FromArgb(255, 235, 200); $item.ForeColor = [Drawing.Color]::FromArgb(205, 133, 0)
                    $item.SubItems[1].Text = "$dur (Cancelled)"; $this.RetryItems.Add($item); $x++
                }
                elseif ($fail) {
                    $item.BackColor = [Drawing.Color]::FromArgb(255, 200, 200); $item.ForeColor = [Drawing.Color]::Red
                    $item.SubItems[1].Text = "$dur (Failed)"; $this.RetryItems.Add($item); $f++
                }
                else {
                    $item.BackColor = [Drawing.Color]::FromArgb(200, 255, 200); $item.ForeColor = [Drawing.Color]::DarkGreen
                    $item.SubItems[1].Text = "$dur (Completed)"; $c++
                }
            }
            Start-Sleep -Milliseconds 500
        }

        # finalize UI
        $summary = "Completed: $c, Failed: $f, Cancelled: $x"
        $this.StatusLabel.Text = "Execution finished — $summary"
        $this.CreatedButtons['RunButton'].Text = "▶ Run ($((if($f+$x){$f+$x}else{0})))"
        $this.CreatedButtons['RunButton'].Enabled = $true
        $this.CancelButton.Visible = $false
        $this.ActionButton.Visible = $true
    }

    [void]CopySelectedCommands() {
        $sel = @()
        foreach ($lv in $this.ListViews.Values) { $sel += $lv.Items | Where { $_.Checked } }
        if (-not $sel.Count) { [Windows.Forms.MessageBox]::Show('No items.', 'Warning'); return }
        $txt = "# Gray WinUtil - Selected Commands`n# Generated: $(Get-Date)`n# Total: $($sel.Count)`n`n"
        foreach ($i in $sel) { $txt += "# $($i.Text)`n$($i.SubItems[1].Text)`n`n" }
        [Windows.Forms.Clipboard]::SetText($txt)
    }

    [hashtable]GetScriptById([string]$id, $dbData) {
        $sd = $dbData | Where id -EQ $id
        if ($sd) { return @{ content = $sd.id; description = $sd.description; command = $sd.command } }
        return $null
    }

    [void]Show() {
        try { [Windows.Forms.Application]::SetHighDpiMode([Windows.Forms.HighDpiMode]::PerMonitorV2) } catch {}
        [Windows.Forms.Application]::EnableVisualStyles()
        $this.Form.ShowDialog() | Out-Null
    }
}

# Bootstrap
$app = [WinUtilApp]::new()
$app.Show()
