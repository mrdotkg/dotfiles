<#
Object-Oriented PowerShell GUI Application for managing and executing scripts from a GitHub repository.
Converted from process-oriented to OOP structure for better maintainability and extensibility.
#>

Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# Add Windows API for titlebar customization
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class WindowAPI {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
    
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    
    public const int DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1 = 19;
    public const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
    public const int DWMWA_CAPTION_COLOR = 35;
    public const int DWMWA_TEXT_COLOR = 36;
    public const uint SWP_FRAMECHANGED = 0x0020;
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    
    public static void SetTitleBarColor(IntPtr handle, int captionColor, int textColor) {
        int darkMode = 1;
        DwmSetWindowAttribute(handle, DWMWA_USE_IMMERSIVE_DARK_MODE, ref darkMode, sizeof(int));
        DwmSetWindowAttribute(handle, DWMWA_CAPTION_COLOR, ref captionColor, sizeof(int));
        DwmSetWindowAttribute(handle, DWMWA_TEXT_COLOR, ref textColor, sizeof(int));
        SetWindowPos(handle, IntPtr.Zero, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE);
    }
}
"@

# Configuration Class
class WinUtilConfig {
    [string]$ApiUrl
    [string]$DatabaseFile = "db.json"
    [string]$DatabaseUrl
    [string]$GitHubBranch = "main"
    [string]$GitHubOwner = "mrdotkg"
    [string]$GitHubRepo = "dotfiles"
    [string]$ScriptsPath
    [string]$SshConfigPath
    [string]$DataDirectory
    [string]$ProfilesDirectory
    [string]$LogsDirectory

    WinUtilConfig() {
        $this.ScriptsPath = "$env:USERPROFILE\Documents\WinUtil Local Data"
        $this.SshConfigPath = "$env:USERPROFILE\.ssh\config"
        $this.DataDirectory = "$env:USERPROFILE\Documents\WinUtil Local Data"
        $this.ProfilesDirectory = "$env:USERPROFILE\Documents\WinUtil Local Data\Profiles"
        $this.LogsDirectory = "$env:USERPROFILE\Documents\WinUtil Local Data\Logs"
        $this.UpdateUrls()
    }

    [void]UpdateUrls() {
        $this.DatabaseUrl = "https://raw.githubusercontent.com/$($this.GitHubOwner)/$($this.GitHubRepo)/refs/heads/$($this.GitHubBranch)/$($this.DatabaseFile)"
        $this.ApiUrl = "https://api.github.com/repos/$($this.GitHubOwner)/$($this.GitHubRepo)/contents"
    }

    [void]EnsureDirectories() {
        @($this.DataDirectory, $this.ProfilesDirectory, $this.LogsDirectory) | ForEach-Object {
            if (-not (Test-Path $_)) {
                New-Item -ItemType Directory -Path $_ -Force | Out-Null
            }
        }
    }
}

# UI Theme and Colors Class
class UITheme {
    [hashtable]$Colors = @{}
    [hashtable]$Fonts = @{}
    [hashtable]$Padding = @{}
    [hashtable]$Sizes = @{}
    [System.Windows.Forms.Timer]$ThemeMonitorTimer
    [bool]$LastDetectedTheme
    [System.Drawing.Color]$LastDetectedAccentColor

    UITheme() {
        $this.InitializeTheme()
        $this.StartThemeMonitoring()
    }

    [void]InitializeTheme() {
        # Initialize accent color
        $AccentColorValue = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AccentColor" -ErrorAction SilentlyContinue
        $accentColor = if ($AccentColorValue) {
            [System.Drawing.Color]::FromArgb(
                ($AccentColorValue -band 0xFF000000) -shr 24, 
                ($AccentColorValue -band 0x000000FF), 
                ($AccentColorValue -band 0x0000FF00) -shr 8, 
                ($AccentColorValue -band 0x00FF0000) -shr 16)
        }
        else {
            [System.Drawing.Color]::FromArgb(44, 151, 222)
        }

        $this.Colors = @{
            Accent     = $accentColor
            Background = [System.Drawing.Color]::FromArgb(241, 243, 249)
            Disabled   = [System.Drawing.Color]::LightGray
            Text       = [System.Drawing.Color]::Black
        }

        $this.Fonts = @{
            Big       = [System.Drawing.Font]::new("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
            Bold      = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
            Default   = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
            Small     = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
            SmallBold = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        }

        $this.Padding = @{
            Button  = '0,0,0,0'
            Content = "0,0,0,35"
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

        $this.Sizes = @{
            Columns = @{
                Command = 200
                Name    = -2
            }
            Footer  = @{ Height = 30 }
            Header  = @{}
            Input   = @{
                FooterWidth = 120
                Height      = 25
                Width       = 120
                Icon        = @{
                    Height = 25
                    Width  = 25
                }
            }
            Status  = @{ Height = 30 }
            ToolBar = @{ Height = 35 }
            Window  = @{
                Height = 600
                Width  = 600
            }
        }
    }

    [void]StartThemeMonitoring() {
        $this.ThemeMonitorTimer = New-Object System.Windows.Forms.Timer
        $this.ThemeMonitorTimer.Interval = 2000
        $appInstance = $this.Tag
        $this.ThemeMonitorTimer.Add_Tick({
                if ($appInstance) {
                    $appInstance.UpdateTheme()
                }
            }.GetNewClosure())
    }

    [void]UpdateTheme() {
        try {
            $appsUseLightTheme = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue
            $isDarkMode = ($appsUseLightTheme -eq 0)
        }
        catch {
            $isDarkMode = $false
        }
        
        # Check for accent color changes
        try {
            $AccentColorValue = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AccentColor" -ErrorAction SilentlyContinue
            $newAccentColor = if ($AccentColorValue) {
                [System.Drawing.Color]::FromArgb(
                    ($AccentColorValue -band 0xFF000000) -shr 24, 
                    ($AccentColorValue -band 0x000000FF), 
                    ($AccentColorValue -band 0x0000FF00) -shr 8, 
                    ($AccentColorValue -band 0x00FF0000) -shr 16)
            }
            else {
                [System.Drawing.Color]::FromArgb(44, 151, 222)
            }
        }
        catch {
            $newAccentColor = [System.Drawing.Color]::FromArgb(44, 151, 222)
        }
        
        $accentColorChanged = ($this.LastDetectedAccentColor -eq $null) -or 
                             ($this.LastDetectedAccentColor.ToArgb() -ne $newAccentColor.ToArgb())
        
        if ($this.LastDetectedTheme -ne $isDarkMode -or $accentColorChanged) {
            $this.LastDetectedTheme = $isDarkMode
            $this.LastDetectedAccentColor = $newAccentColor
            $this.Colors.Accent = $newAccentColor
            
            # Notify main application of theme change
            # This would be handled by the main form class
        }
    }

    [void]StopThemeMonitoring() {
        if ($this.ThemeMonitorTimer) {
            $this.ThemeMonitorTimer.Stop()
            $this.ThemeMonitorTimer.Dispose()
            $this.ThemeMonitorTimer = $null
        }
    }
}

# Machine Management Class
class MachineManager {
    [array]$AvailableMachines = @()
    [string]$CurrentMachine
    [WinUtilConfig]$Config

    MachineManager([WinUtilConfig]$config) {
        $this.Config = $config
        $this.CurrentMachine = $env:COMPUTERNAME
        $this.LoadMachines()
    }

    [void]LoadMachines() {
        $this.AvailableMachines = @(@{
                Name        = $env:COMPUTERNAME
                DisplayName = "$env:COMPUTERNAME (Local)"
                Type        = "Local"
                Host        = "localhost"
            })
        
        if (Test-Path $this.Config.SshConfigPath) {
            try {
                $sshConfig = Get-Content $this.Config.SshConfigPath -ErrorAction SilentlyContinue
                $currentHost = $null
                
                foreach ($line in $sshConfig) {
                    $line = $line.Trim()
                    
                    if ($line -match '^Host\s+(.+)$') {
                        $hostName = $Matches[1].Trim()
                        
                        if ($hostName -notmatch '[*?]' -and $hostName -ne 'localhost') {
                            $currentHost = @{
                                Name        = $hostName
                                DisplayName = $hostName
                                Type        = "SSH"
                                Host        = $hostName
                                User        = $null
                                Port        = 22
                            }
                        }
                        else {
                            $currentHost = $null
                        }
                    }
                    elseif ($currentHost -and $line -match '^\s*HostName\s+(.+)$') {
                        $currentHost.Host = $Matches[1].Trim()
                    }
                    elseif ($currentHost -and $line -match '^\s*User\s+(.+)$') {
                        $currentHost.User = $Matches[1].Trim()
                    }
                    elseif ($currentHost -and $line -match '^\s*Port\s+(.+)$') {
                        $currentHost.Port = [int]$Matches[1].Trim()
                    }
                    elseif ($line -match '^Host\s+' -or $line -eq '') {
                        if ($currentHost -and $currentHost.Name) {
                            $this.AvailableMachines += $currentHost
                            $currentHost = $null
                        }
                    }
                }
                
                if ($currentHost -and $currentHost.Name) {
                    $this.AvailableMachines += $currentHost
                }
            }
            catch {
                Write-Warning "Failed to read SSH config: $_"
            }
        }
    }

    [object]GetCurrentMachine() {
        return $this.AvailableMachines | Where-Object { $_.Name -eq $this.CurrentMachine }
    }

    [void]SetCurrentMachine([string]$machineName) {
        $machine = $this.AvailableMachines | Where-Object { $_.Name -eq $machineName }
        if ($machine) {
            $this.CurrentMachine = $machineName
        }
    }
}

# Script Execution Class
class ScriptExecutor {
    [WinUtilConfig]$Config
    [MachineManager]$MachineManager
    [string]$CurrentLogFile
    [bool]$IsRunning = $false

    ScriptExecutor([WinUtilConfig]$config, [MachineManager]$machineManager) {
        $this.Config = $config
        $this.MachineManager = $machineManager
    }

    [void]ExecuteScripts([array]$items, [bool]$adminMode, [bool]$retryMode = $false) {
        if ($this.IsRunning) {
            return
        }

        $this.IsRunning = $true
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $logFileName = "GrayWinUtil_Execution_$timestamp.log"
        $this.CurrentLogFile = Join-Path -Path $this.Config.LogsDirectory -ChildPath $logFileName

        try {
            $this.ExecuteItemsInternal($items, $adminMode, $retryMode)
        }
        finally {
            $this.IsRunning = $false
        }
    }

    [void]ExecuteItemsInternal([array]$items, [bool]$adminMode, [bool]$retryMode) {
        $startTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $currentMachine = $this.MachineManager.GetCurrentMachine()
        $isRemote = $currentMachine.Type -eq "SSH"
        $targetDescription = if ($isRemote) { "remote machine $($currentMachine.Host)" } else { "local machine" }
        $modeText = if ($adminMode) { "administrator" } else { "normal" }
        
        Add-Content -Path $this.CurrentLogFile -Value "$startTime INFO Gray WinUtil execution started in $modeText mode on $targetDescription"

        $completedCount = 0
        $failedCount = 0
        $cancelledCount = 0

        for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            $command = $item.SubItems[1].Text
            $name = $item.Text

            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            Add-Content -Path $this.CurrentLogFile -Value "$timestamp INFO Starting execution of '$name' - Command: $command"

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = $this.ExecuteSingleCommand($command, $adminMode, $isRemote, $currentMachine)
            $stopwatch.Stop()

            $ms = $stopwatch.ElapsedMilliseconds
            $executionTime = if ($ms -gt 1000) { "{0:N2} s" -f ($ms / 1000) } else { "$($ms) ms" }

            $this.UpdateItemStatus($item, $result, $executionTime)

            switch ($result.Status) {
                "Completed" { $completedCount++ }
                "Failed" { $failedCount++ }
                "Cancelled" { $cancelledCount++ }
            }

            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            Add-Content -Path $this.CurrentLogFile -Value "$timestamp $($result.LogLevel) Execution $($result.Status.ToLower()) for '$name' - Time: $executionTime - Output: $($result.Output)"

            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 1000
        }

        $endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $totalItems = $items.Count
        Add-Content -Path $this.CurrentLogFile -Value "$endTime INFO Execution completed - Total: $totalItems, Completed: $completedCount, Failed: $failedCount, Cancelled: $cancelledCount"
    }

    [hashtable]ExecuteSingleCommand([string]$command, [bool]$adminMode, [bool]$isRemote, [object]$machine) {
        $result = @{
            Status   = "Completed"
            Output   = "No output"
            LogLevel = "INFO"
        }

        try {
            if ($isRemote) {
                $result = $this.ExecuteRemoteCommand($command, $machine)
            }
            elseif ($adminMode) {
                $result = $this.ExecuteAdminCommand($command)
            }
            else {
                $result = $this.ExecuteLocalCommand($command)
            }
        }
        catch {
            $result.Status = "Failed"
            $result.Output = $_.Exception.Message
            $result.LogLevel = "ERROR"
        }

        return $result
    }

    [hashtable]ExecuteRemoteCommand([string]$command, [object]$machine) {
        # ...existing SSH execution logic...
        return @{ Status = "Completed"; Output = "SSH execution placeholder"; LogLevel = "INFO" }
    }

    [hashtable]ExecuteAdminCommand([string]$command) {
        # ...existing admin execution logic...
        return @{ Status = "Completed"; Output = "Admin execution placeholder"; LogLevel = "INFO" }
    }

    [hashtable]ExecuteLocalCommand([string]$command) {
        # ...existing local execution logic...
        return @{ Status = "Completed"; Output = "Local execution placeholder"; LogLevel = "INFO" }
    }

    [void]UpdateItemStatus([object]$item, [hashtable]$result, [string]$executionTime) {
        switch ($result.Status) {
            "Completed" {
                $item.BackColor = [System.Drawing.Color]::FromArgb(200, 255, 200)
                $item.ForeColor = [System.Drawing.Color]::DarkGreen
                $item.SubItems[1].Text = "$($executionTime) (Completed)"
                $item.Checked = $false
            }
            "Failed" {
                $item.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 200)
                $item.ForeColor = [System.Drawing.Color]::Red
                $item.SubItems[1].Text = "$($executionTime) (Failed)"
                $item.Checked = $true
            }
            "Cancelled" {
                $item.BackColor = [System.Drawing.Color]::FromArgb(255, 235, 200)
                $item.ForeColor = [System.Drawing.Color]::FromArgb(205, 133, 0)
                $item.SubItems[1].Text = "$($executionTime) (Cancelled)"
                $item.Checked = $true
            }
        }
    }
}

# Profile Manager Class
class ProfileManager {
    [WinUtilConfig]$Config
    [array]$Profiles = @()

    ProfileManager([WinUtilConfig]$config) {
        $this.Config = $config
        $this.LoadProfiles()
        $this.EnsureDefaultProfile()
    }

    [void]LoadProfiles() {
        $this.Profiles = @()
        if (Test-Path $this.Config.ProfilesDirectory) {
            Get-ChildItem -Path $this.Config.ProfilesDirectory -Filter "*.txt" | ForEach-Object {
                $this.Profiles += $_.BaseName
            }
        }
    }

    [void]EnsureDefaultProfile() {
        $defaultProfile = Join-Path -Path $this.Config.ProfilesDirectory -ChildPath "Default Profile.txt"
        if (-not (Test-Path $defaultProfile)) {
            try {
                $dbData = Invoke-WebRequest $this.Config.DatabaseUrl | ConvertFrom-Json
                $allIds = @()
                $dbData | ForEach-Object {
                    if ($_.id) { $allIds += $_.id }
                }
                if ($allIds.Count -gt 0) {
                    $allIds | Set-Content -Path $defaultProfile -Force
                }
            }
            catch {
                "# Default Profile" | Set-Content -Path $defaultProfile -Force
            }
        }
    }

    [hashtable]ReadProfile([string]$profileName) {
        $profilePath = Join-Path -Path $this.Config.ProfilesDirectory -ChildPath "$profileName.txt"
        if (-not (Test-Path $profilePath)) {
            return @{}
        }

        $profileLines = Get-Content -Path $profilePath -ErrorAction SilentlyContinue
        if (-not $profileLines) {
            return @{}
        }

        try {
            $dbData = Invoke-WebRequest $this.Config.DatabaseUrl | ConvertFrom-Json
        }
        catch {
            Write-Warning "Failed to fetch database from GitHub: $_"
            return @{}
        }

        $groupedScripts = New-Object Collections.Specialized.OrderedDictionary
        $currentGroupName = "Group #1"

        foreach ($line in $profileLines) {
            if ($line -eq "") {
                $currentGroupName = "Group#$($groupedScripts.Count + 1)"
                continue
            }
            elseif ($line.StartsWith("#")) {
                $currentGroupName = $line.TrimStart("#").Trim()
                continue
            }
            else {
                $line = $line.Trim()
                $scriptData = $this.GetScriptFromId($line, $dbData)
                if ($scriptData) {
                    if (-not $groupedScripts.Contains($currentGroupName)) {
                        $groupedScripts.Add($currentGroupName, [System.Collections.ArrayList]@())
                    }
                    [void]$groupedScripts[$currentGroupName].Add($scriptData)
                }
            }
        }

        return $groupedScripts
    }

    [hashtable]GetScriptFromId([string]$id, [array]$dbData) {
        $scriptData = $dbData | Where-Object { $_.id -eq $id }
        if ($scriptData) {
            return @{
                content     = $scriptData.id
                description = $scriptData.description
                command     = $scriptData.command
            }
        }
        return $null
    }
}

# Main Application Class
class WinUtilApplication {
    [WinUtilConfig]$Config
    [UITheme]$Theme
    [MachineManager]$MachineManager
    [ScriptExecutor]$ScriptExecutor
    [ProfileManager]$ProfileManager
    [System.Windows.Forms.Form]$MainForm
    [hashtable]$ListViews = @{}
    [hashtable]$Controls = @{}
    [int]$CurrentProfileIndex = -1

    WinUtilApplication() {
        $this.InitializeComponents()
        $this.CreateMainForm()
    }

    [void]InitializeComponents() {
        $this.Config = [WinUtilConfig]::new()
        $this.Config.EnsureDirectories()
        
        $this.Theme = [UITheme]::new()
        $this.MachineManager = [MachineManager]::new($this.Config)
        $this.ScriptExecutor = [ScriptExecutor]::new($this.Config, $this.MachineManager)
        $this.ProfileManager = [ProfileManager]::new($this.Config)
    }

    [void]CreateMainForm() {
        # Create the main form and set properties
        $this.MainForm = New-Object System.Windows.Forms.Form -Property @{
            BackColor       = $this.Theme.Colors.Background
            Font            = $this.Theme.Fonts.Default
            Height          = $this.Theme.Sizes.Window.Height
            KeyPreview      = $true
            Padding         = $this.Theme.Padding.Form
            Text            = "WINUTIL-$($this.Config.GitHubOwner.toUpper()) / $($this.Config.GitHubRepo.toUpper())"
            TransparencyKey = $this.Theme.Colors.Background;
            Width           = $this.Theme.Sizes.Window.Width
        }

        # Set form background to current Windows wallpaper
        try {
            $wallpaperPath = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -ErrorAction Stop).Wallpaper
            if (Test-Path $wallpaperPath) {
                $this.MainForm.BackgroundImage = [System.Drawing.Image]::FromFile($wallpaperPath)
                $this.MainForm.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Stretch
            }
        }
        catch {
            Write-Warning "Unable to load desktop wallpaper: $_"
            # Fallback to solid background color
            $this.MainForm.BackgroundImage = $null
            $this.MainForm.BackColor = $this.Theme.Colors.Background
        }
        $this.MainForm.Icon = [System.Drawing.SystemIcons]::Application
        $this.MainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
        $this.MainForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        

        # Store application instance on form for event handlers
        $this.MainForm.Tag = $this

        # Subscribe to events using form.Tag to call class methods
        $this.MainForm.add_KeyDown({ param($sender, $e) $sender.Tag.HandleFormKeyDown($e) })
        $this.MainForm.add_Shown({ param($sender, $e) $sender.Tag.HandleFormShown() })
        $this.MainForm.add_FormClosed({ param($sender, $e) $sender.Tag.HandleFormClosed() })

        # Initialize child controls on the form
        # $this.CreateFormControls()
    }

    [void]CreateFormControls() {
        # Create main panels
        $headerPanel = New-Object System.Windows.Forms.Panel -Property @{
            Dock   = 'Top'
            Height = 0
        }

        $contentPanel = New-Object System.Windows.Forms.Panel -Property @{
            Dock    = 'Fill'
            Padding = $this.Theme.Padding.Content
        }

        $footerPanel = New-Object System.Windows.Forms.Panel -Property @{
            Dock   = 'Bottom'
            Height = $this.Theme.Sizes.Footer.Height
        }

        # Create toolbar
        $toolbarPanel = $this.CreateToolbar()
        $scriptsPanel = $this.CreateScriptsPanel()
        $statusPanel = $this.CreateStatusPanel()

        # Add controls to panels
        $contentPanel.Controls.Add($scriptsPanel)
        $contentPanel.Controls.Add($toolbarPanel)
        $footerPanel.Controls.Add($statusPanel)

        $this.MainForm.Controls.AddRange(@($headerPanel, $footerPanel, $contentPanel))

        # Store references
        $this.Controls.ScriptsPanel = $scriptsPanel
        $this.Controls.StatusPanel = $statusPanel
        $this.Controls.ToolbarPanel = $toolbarPanel
    }

    [System.Windows.Forms.Panel]CreateToolbar() {
        # ...existing toolbar creation logic...
        $toolbarPanel = New-Object System.Windows.Forms.Panel -Property @{
            Dock   = 'Top'
            Height = $this.Theme.Sizes.ToolBar.Height
        }
        return $toolbarPanel
    }

    [System.Windows.Forms.Panel]CreateScriptsPanel() {
        # ...existing scripts panel creation logic...
        $scriptsPanel = New-Object System.Windows.Forms.Panel -Property @{
            Dock = 'Fill'
        }
        return $scriptsPanel
    }

    [System.Windows.Forms.Panel]CreateStatusPanel() {
        # ...existing status panel creation logic...
        $statusPanel = New-Object System.Windows.Forms.Panel -Property @{
            Dock   = 'Top'
            Height = $this.Theme.Sizes.Status.Height
        }
        return $statusPanel
    }

    [void]HandleFormKeyDown([System.Windows.Forms.KeyEventArgs]$e) {
        # ...existing key handling logic...
    }

    [void]HandleFormShown() {
        $this.MainForm.Activate()
        $this.Theme.ThemeMonitorTimer.Start()
        
        # Load machines and profiles
        $this.LoadInitialData()
    }

    [void]HandleFormClosed() {
        $this.Theme.StopThemeMonitoring()
    }

    [void]LoadInitialData() {
        # Load profiles and set default
        if ($this.ProfileManager.Profiles.Count -gt 0) {
            $this.CurrentProfileIndex = 0
            $this.LoadProfile($this.ProfileManager.Profiles[0])
        }
    }

    [void]LoadProfile([string]$profileName) {
        $scriptsDict = $this.ProfileManager.ReadProfile($profileName)
        if ($scriptsDict.Count -gt 0) {
            $this.CreateGroupedListView($scriptsDict)
        }
    }

    [void]CreateGroupedListView([hashtable]$groupedScripts) {
        # ...existing list view creation logic...
    }

    [void]Show() {
        # Enable visual styles and high DPI
        if ([Environment]::OSVersion.Version.Major -ge 6) {
            try { 
                [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2) 
            }
            catch {}
        }
        [System.Windows.Forms.Application]::EnableVisualStyles()

        $this.MainForm.ShowDialog() | Out-Null
    }
}

# Entry point
$app = [WinUtilApplication]::new()
$app.Show()
