# Multiline doc comment
<#
This script is a PowerShell GUI application for managing and executing scripts from a GitHub repository.
### TODO **Command History & Last Selected Profile System**
# - Implement a system to track frequently used commands.
# - Add a "Favorites" tab to quickly access most-used scripts.
# - Store usage statistics in a JSON file for persistence.

### TODO **Command Scheduling**
# - Enable scheduling of commands to run at specific times.
# - Implement background task execution for scheduled commands.
# - Add a notification system to inform users when scheduled tasks are completed.

### TODO **Downloads Feature**
# - Complete the functionality to download profiles from GitHub.
# - Ensure downloaded profiles are stored in the appropriate directory.

### TODO **ListView Sorting**
# - Sort ListView items by name in ascending order for better organization.

### TODO **Local Data Storage**
# - Store local data in the %Temp% directory by default.
# - Provide an option for users to store data locally.
# - Create a PowerShell script file executing this script from github url
# - Create a startmenu and desktop shortcut for the script

# - Command - irm "<URL>" | iwr

#>

# ------------------------------
# Configuration
# ------------------------------
# Repository configuration - Update these variables for your own repository
$script:Config = @{
    GitHubOwner  = "mrdotkg"           # GitHub username
    GitHubRepo   = "dotfiles"          # Repository name
    GitHubBranch = "main"              # Default branch
    DatabaseFile = "db.json"           # Database file name
    ScriptsPath  = "$HOME\Documents\WinUtil Local Data"  # Local data directory (Profiles stored in subdirectory)
}

# ------------------------------
# Initialize Dependencies
# ------------------------------
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# Generate URLs from configuration
$script:Config.DatabaseUrl = "https://raw.githubusercontent.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/refs/heads/$($script:Config.GitHubBranch)/$($script:Config.DatabaseFile)"
$script:Config.ApiUrl = "https://api.github.com/repos/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/contents"
$script:Config.RawBaseUrl = "https://raw.githubusercontent.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/$($script:Config.GitHubBranch)"

# ------------------------------
# State Management
# ------------------------------
# Script-scoped variables
$script:PersonalScriptsPath = $script:Config.ScriptsPath
$script:DataDirectory = "$HOME\Documents\WinUtil Local Data"
$script:ProfilesDirectory = "$HOME\Documents\WinUtil Local Data\Profiles"
$script:LogsDirectory = "$HOME\Documents\WinUtil Local Data\Logs"
$script:LastColumnClicked = @{}
$script:LastColumnAscending = @{}
$script:ListViews = @{}
$script:SplitContainers = @()
# Window management for singleton pattern
$script:HelpForm = $null
$script:UpdatesForm = $null

# UI Theme and Constants
$script:UI = @{
    Colors = @{
        Background = [System.Drawing.Color]::FromArgb(241, 243, 249)
        Text       = [System.Drawing.Color]::Black
        Disabled   = [System.Drawing.Color]::LightGray
        Accent     = $null  # Will be set from Windows theme
    }
    Fonts  = @{
        Default = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
        Bold    = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    }
    Sizes  = @{
        Window  = @{
            Width  = 600
            Height = 700
        }
        Header  = @{
            Height = 40
        }
        Footer  = @{
            Height = 50
        }
        Input   = @{
            Width       = 100
            Height      = 30
            FooterWidth = 150
        }
        Columns = @{
            Name        = 250
            Description = 100
            Command     = 100
        }
    }
}

# Initialize accent color from Windows theme
$AccentColorValue = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AccentColor" -ErrorAction SilentlyContinue
$script:UI.Colors.Accent = if ($AccentColorValue) {
    [System.Drawing.Color]::FromArgb(
        ($AccentColorValue -band 0xFF000000) -shr 24, 
        ($AccentColorValue -band 0x000000FF), 
        ($AccentColorValue -band 0x0000FF00) -shr 8, 
        ($AccentColorValue -band 0x00FF0000) -shr 16)
}
else {
    [System.Drawing.Color]::FromArgb(44, 151, 222)
}

# ------------------------------
# Component Properties
# ------------------------------
# Main Form
$FormProps = @{
    Width       = $script:UI.Sizes.Window.Width
    Height      = $script:UI.Sizes.Window.Height
    Text        = "GRAY WINUTIL"
    BackColor   = $script:UI.Colors.Background
    Font        = $script:UI.Fonts.Default
    KeyPreview  = $true
    Add_Shown   = { $Form.Activate() }
    Add_KeyDown = {
        if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::A) {
            # Ctrl+A: Select All
            $SelectAllSwitch.Checked = $true
            $SelectAllSwitch.Tag = $true
            $listViews = @($script:ListViews.Values)
            foreach ($lv in $listViews) {
                foreach ($item in $lv.Items) {
                    $item.Checked = $true
                }
            }
            $_.Handled = $true
        }
        elseif ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::R) {
            # Ctrl+R: Run
            if ($InvokeButton.Enabled) {
                $InvokeButton.PerformClick()
            }
            $_.Handled = $true
        }
        elseif ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::C) {
            # Ctrl+C: Copy Selected Commands to Clipboard
            Copy-SelectedCommandsToClipboard
            $_.Handled = $true
        }
    }
}

# Panels
$HeaderPanelProps = @{
    Height    = $script:UI.Sizes.Header.Height
    Dock      = 'Top'
    Padding   = '20,8,20,8'  # More balanced padding for better alignment
    BackColor = $script:UI.Colors.Background
}

$ContentPanelProps = @{
    Dock      = 'Fill'
    Padding   = '15,40,15,15'  # Increased padding for better spacing
    BackColor = $script:UI.Colors.Background
}

$FooterPanelProps = @{
    Dock        = 'Bottom'
    Height      = $script:UI.Sizes.Footer.Height
    BackColor   = $script:UI.Colors.Background
    Padding     = '15,0,15,0'
    BorderStyle = 'None'
    Font        = $script:UI.Fonts.Default
}

# List View and Split Container
$ListViewProps = @{
    CheckBoxes       = $true
    Font             = $script:UI.Fonts.Default
    Dock             = 'Fill'
    View             = 'Details'
    GridLines        = $true
    FullRowSelect    = $true
    MultiSelect      = $true
    ShowItemToolTips = $true
    BorderStyle      = 'None'
    Margin           = '5,5,5,5'  # Add padding around ListView
    Add_ItemChecked  = {
        $totalItems = ($script:ListViews.Values | ForEach-Object { $_.Items.Count } | Measure-Object -Sum).Sum
        $anyChecked = ($script:ListViews.Values | ForEach-Object { $_.Items | Where-Object { $_.Checked } } | Measure-Object).Count
        $InvokeButton.Enabled = $ConsentCheckbox.Checked -and ($anyChecked -gt 0)
        $InvokeButton.Text = "RUN ($anyChecked)"
        $SelectAllSwitch.Checked = ($anyChecked -eq $totalItems)
        $SelectAllSwitch.Tag = ($anyChecked -eq $totalItems)
    }
}

$SplitProps = @{
    Dock             = 'Fill'
    Orientation      = 'Horizontal'
    SplitterWidth    = 10
    SplitterDistance = 30
    BorderStyle      = 'None'
    Padding          = '0,0,0,20'
}

# Control Properties
$SelectAllSwitchProps = @{
    Text      = "SELECT ALL"
    Width     = $script:UI.Sizes.Input.Width
    Height    = $script:UI.Sizes.Input.Height
    AutoSize  = $true
    Dock      = 'Left'
    Font      = $script:UI.Fonts.Default
    Tag       = $false
    Add_Click = {
        $isChecked = -not $SelectAllSwitch.Tag
        $SelectAllSwitch.Tag = $isChecked
        $listViews = @($script:ListViews.Values)
        foreach ($lv in $listViews) {
            foreach ($item in $lv.Items) {
                $item.Checked = $isChecked
            }
        }
    }
}

$SearchBoxProps = @{
    Height          = $script:UI.Sizes.Input.Height
    Dock            = 'Fill'
    Font            = $script:UI.Fonts.Default
    ForeColor       = $script:UI.Colors.Disabled  # Set initial placeholder color to be visible
    Text            = " Type to filter scripts..."
    TextAlign       = 'Left'
    Multiline       = $false
    BorderStyle     = 'FixedSingle'  # Add border for better visual definition
    BackColor       = [System.Drawing.Color]::White  # Use white background for better contrast
    Margin          = '3,3,3,3'  # Add margin for better spacing
    Add_Enter       = { if ($this.Text -eq " Type to filter scripts...") { $this.Text = ""; $this.ForeColor = $script:UI.Colors.Text } }
    Add_Leave       = { if ($this.Text -eq "") { $this.Text = " Type to filter scripts..."; $this.ForeColor = $script:UI.Colors.Disabled } }
    Add_TextChanged = {
        $searchText = $this.Text.Trim()
        if ($searchText -eq "Type to filter scripts...") { return }
        $listViews = @($script:ListViews.Values)
        foreach ($lv in $listViews) {
            foreach ($item in $lv.Items) {
                $item.ForeColor = if ($item.Text -like "*$searchText*") { $script:UI.Colors.Text } else { $script:UI.Colors.Disabled }
            }
        }
    }
}

$InvokeButtonProps = @{
    Width     = $script:UI.Sizes.Input.Width
    Text      = "RUN"
    Dock      = 'Right'
    Enabled   = $false  # Initially disabled
    Font      = $script:UI.Fonts.Bold
    FlatStyle = 'Flat'
    BackColor = [System.Drawing.Color]::FromArgb(76, 175, 80)
    ForeColor = [System.Drawing.Color]::White
        
    AutoSize  = $true
    Add_Click = { 
        if ($ConsentCheckbox.Checked) {
            RunSelectedItems -Action Invoke
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Please check the consent checkbox to proceed with execution.", "Consent Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    }
}

$ConsentCheckboxProps = @{
    Text               = "ALLOW"
    Width              = $script:UI.Sizes.Input.Width
    Height             = $script:UI.Sizes.Input.Height
    AutoSize           = $true
    Dock               = 'Right'
    Font               = $script:UI.Fonts.Default
    Checked            = $false
    Add_CheckedChanged = {
        # Enable/disable buttons based on consent and selection
        $anyChecked = ($script:ListViews.Values | ForEach-Object { $_.Items | Where-Object { $_.Checked } } | Measure-Object).Count
        $InvokeButton.Enabled = $ConsentCheckbox.Checked -and ($anyChecked -gt 0)
    }
}


$ProfileDropdownProps = @{
    Width                    = $script:UI.Sizes.Input.FooterWidth
    Height                   = $script:UI.Sizes.Input.Height
    Dock                     = 'Left'
    Font                     = $script:UI.Fonts.Default
    ForeColor                = $script:UI.Colors.Text
    DropDownStyle            = 'DropDownList'
    Add_SelectedIndexChanged = {
        $selectedProfile = $ProfileDropdown.SelectedItem
        if ($selectedProfile) {
            $selectedProfilePath = Join-Path -Path $script:ProfilesDirectory -ChildPath "$selectedProfile.txt"
            if (Test-Path $selectedProfilePath) {
                # Load the selected profile
                $ProfileLines = Get-Content -Path $selectedProfilePath -ErrorAction SilentlyContinue
                if (-not $ProfileLines) {
                    Write-Warning "Selected profile '$selectedProfilePath' is empty or does not exist."
                    return
                }
                else {
                    # Clear existing ListViews
                    $script:ListViews.Clear()                    # get from github
                    $dbData = Invoke-WebRequest $script:Config.DatabaseUrl | ConvertFrom-Json
                    # Create an ordered dictionary to maintain group order
                    $groupedScripts = New-Object Collections.Specialized.OrderedDictionary
                    $currentGroupName = "Group #1"  # Default group name
                    
                    foreach ($line in $ProfileLines) {
                        if ($line -eq "") {
                            # If we hit an empty line, start a new group
                            $currentGroupName = "Group#$($groupedScripts.Count + 1)"
                            continue
                        }
                        elseif ($line.StartsWith("#")) {
                            $currentGroupName = $line.TrimStart("#").Trim()
                            continue
                        }
                        else {
                            $line = $line.Trim()
                            $scriptData = Get-ScriptFromId -Id $line -DbData $dbData
                            if ($scriptData) {
                                if (-not $groupedScripts.Contains($currentGroupName)) {
                                    $groupedScripts.Add($currentGroupName, [System.Collections.ArrayList]@())
                                }
                                [void]$groupedScripts[$currentGroupName].Add($scriptData)
                            }
                            else {
                                Write-Warning "No script found for ID: $line"
                            }
                        }
                    }

                    # Create split containers for grouped scripts
                    if ($groupedScripts.Count -gt 0) {
                        # Suspend layout while we make changes
                        $ContentPanel.SuspendLayout()
                        CreateSplitContainer -parentPanel $ContentPanel -keys $groupedScripts.Keys -index 0 -groupedScripts $groupedScripts
                        
                        # Calculate equal heights
                        $totalHeight = $ContentPanel.ClientSize.Height
                        $heightPerContainer = [Math]::Floor($totalHeight / $groupedScripts.Count)
                        
                        # Force layout update on all split containers
                        foreach ($splitContainer in $script:SplitContainers) {
                            $splitContainer.SuspendLayout()
                            $splitContainer.Height = $heightPerContainer
                            $splitContainer.SplitterDistance = [Math]::Floor($heightPerContainer * 0.3) # 30% split

                            $splitContainer.ResumeLayout($true)
                            $splitContainer.PerformLayout()
                            $splitContainer.Refresh()
                        }
                        
                        $ContentPanel.ResumeLayout($true)
                        $ContentPanel.PerformLayout()
                        $Form.PerformLayout()
                        
                        # Final refresh
                        $ContentPanel.Refresh()
                        $Form.Refresh()
                    }
                    else {
                        Write-Warning "No valid scripts found in profile."
                    }
                }
            }
            else {
                Write-Warning "Selected file '$selectedProfilePath' does not exist."
            }
        }
    }
}

# ------------------------------
# Enhanced RUN Button Functions
# ------------------------------

function Get-CommandRiskLevel {
    param([string]$command)
    
    $highRiskPatterns = @(
        'Remove-Item.*-Recurse',
        'rm.*-rf',
        'Format-Volume',
        'Clear-Disk',
        'Remove-Computer',
        'Restart-Computer',
        'Stop-Computer',
        'shutdown',
        'bcdedit',
        'diskpart',
        'reg delete.*HKLM',
        'Set-ExecutionPolicy.*Unrestricted'
    )
    
    $mediumRiskPatterns = @(
        'Set-ItemProperty.*HKLM',
        'New-ItemProperty.*HKLM',
        'Set-Service',
        'Stop-Service',
        'Disable-Service',
        'Set-NetFirewallRule',
        'New-NetFirewallRule',
        'winget uninstall'
    )
    
    foreach ($pattern in $highRiskPatterns) {
        if ($command -match $pattern) { return "HIGH" }
    }
    
    foreach ($pattern in $mediumRiskPatterns) {
        if ($command -match $pattern) { return "MEDIUM" }
    }
    
    return "LOW"
}

function Get-EstimatedExecutionTime {
    param([string]$command)
    
    if ($command -match 'winget install') { return "2-5 minutes" }
    if ($command -match 'winget uninstall') { return "1-3 minutes" }
    if ($command -match 'Add-WindowsCapability') { return "3-10 minutes" }
    if ($command -match 'Set-ItemProperty|New-ItemProperty') { return "< 10 seconds" }
    if ($command -match 'Set-Service|Start-Service|Stop-Service') { return "10-30 seconds" }
    if ($command -match 'New-NetFirewallRule') { return "10-30 seconds" }
    if ($command -match 'Restart-Computer|Stop-Computer') { return "1-2 minutes" }
    
    return "< 30 seconds"
}

function Get-CommandCategory {
    param([string]$command)
    
    if ($command -match 'winget') { return "SOFTWARE" }
    if ($command -match 'Set-ItemProperty|New-ItemProperty|reg ') { return "REGISTRY" }
    if ($command -match 'Set-Service|Start-Service|Stop-Service') { return "SERVICES" }
    if ($command -match 'NetFirewall|firewall') { return "FIREWALL" }
    if ($command -match 'Add-WindowsCapability') { return "FEATURES" }
    if ($command -match 'Remove-Item|Clear-') { return "CLEANUP" }
    
    return "SYSTEM"
}

function Test-RequiresAdminPrivileges {
    param([string]$command)
    
    $adminRequiredPatterns = @(
        'Set-ItemProperty.*HKLM',
        'New-ItemProperty.*HKLM',
        'reg add.*HKLM',
        'reg delete.*HKLM',
        'Set-Service',
        'Start-Service',
        'Stop-Service',
        'Enable-Service',
        'Disable-Service',
        'Add-WindowsCapability',
        'Remove-WindowsCapability',
        'Set-NetFirewallRule',
        'New-NetFirewallRule',
        'Remove-NetFirewallRule',
        'bcdedit',
        'diskpart',
        'Format-Volume',
        'Clear-Disk',
        'netsh',
        'sc.exe',
        'dism',
        'sfc'
    )
    
    foreach ($pattern in $adminRequiredPatterns) {
        if ($command -match $pattern) { return $true }
    }
    
    return $false
}

function Copy-SelectedCommandsToClipboard {
    # Get all selected items from all ListViews
    $selectedItems = @()
    foreach ($listView in $script:ListViews.Values) {
        $selectedItems += $listView.Items | Where-Object { $_.Checked }
    }

    if ($selectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No items selected to copy.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $commandsText = "# Gray WinUtil - Selected Commands`n"
    $commandsText += "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $commandsText += "# Total Commands: $($selectedItems.Count)`n`n"
    
    foreach ($item in $selectedItems) {

        $command = $item.SubItems[2].Text

        $risk = Get-CommandRiskLevel -command $command
        $timeEst = Get-EstimatedExecutionTime -command $command
        $category = Get-CommandCategory -command $command
        $requiresAdmin = Test-RequiresAdminPrivileges -command $command
        
        $commandsText += "# $($item.Text)`n"
        $commandsText += "# Risk: $risk | Time: $timeEst | Category: $category | Admin Required: $requiresAdmin`n"
        $commandsText += "$command`n`n"
    }

    [System.Windows.Forms.Clipboard]::SetText($commandsText)
}

# Enhanced Error Handling and Recovery Functions
function Get-ErrorCategory {
    param([string]$errorMessage)
    
    if ($errorMessage -match 'Access.*denied|Permission.*denied|Unauthorized') {
        return "PERMISSION"
    }
    if ($errorMessage -match 'Not found|Cannot find|does not exist') {
        return "MISSING_DEPENDENCY"
    }
    if ($errorMessage -match 'Network|timeout|connection|download') {
        return "NETWORK"
    }
    if ($errorMessage -match 'Syntax error|Invalid command|Parse error') {
        return "SYNTAX"
    }
    if ($errorMessage -match 'Already exists|Already installed') {
        return "ALREADY_EXISTS"
    }
    
    return "UNKNOWN"
}

function Get-ErrorSuggestion {
    param([string]$errorMessage, [string]$command)
    
    $category = Get-ErrorCategory -errorMessage $errorMessage
    
    switch ($category) {
        "PERMISSION" {
            return "Try running as Administrator or check user permissions for this operation."
        }
        "MISSING_DEPENDENCY" {
            if ($command -match 'winget') {
                return "Ensure Windows Package Manager (winget) is installed and updated."
            }
            return "Check if required dependencies or services are installed and running."
        }
        "NETWORK" {
            return "Check internet connection and try again. Some packages may require network access."
        }
        "SYNTAX" {
            return "Command syntax may be incorrect. Review the command parameters."
        }
        "ALREADY_EXISTS" {
            return "Item already exists or is installed. This may not be an error."
        }
        default {
            return "Review the error details and command syntax. Consider retrying the operation."
        }
    }
}

function Show-ErrorRecoveryDialog {
    param(
        [string]$commandName,
        [string]$errorMessage,
        [string]$command,
        [string]$suggestion
    )
    
    $recoveryForm = New-Object System.Windows.Forms.Form -Property @{
        Text          = "Error Recovery - $commandName"
        Size          = New-Object System.Drawing.Size(600, 400)
        StartPosition = "CenterParent"
        Font          = $script:UI.Fonts.Default
        BackColor     = $script:UI.Colors.Background
        MaximizeBox   = $false
        MinimizeBox   = $false
        ShowIcon      = $false
    }

    $mainPanel = New-Object System.Windows.Forms.Panel -Property @{
        Dock    = 'Fill'
        Padding = '15,15,15,15'
    }

    $titleLabel = New-Object System.Windows.Forms.Label -Property @{
        Text      = "Command failed: $commandName"
        Dock      = 'Top'
        Height    = 30
        Font      = [System.Drawing.Font]::new("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        ForeColor = [System.Drawing.Color]::FromArgb(244, 67, 54)
    }

    $errorLabel = New-Object System.Windows.Forms.Label -Property @{
        Text      = "Error Details:"
        Dock      = 'Top'
        Height    = 20
        Font      = $script:UI.Fonts.Bold
        ForeColor = $script:UI.Colors.Text
    }

    $errorTextBox = New-Object System.Windows.Forms.TextBox -Property @{
        Text       = $errorMessage
        Dock       = 'Top'
        Height     = 60
        Multiline  = $true
        ReadOnly   = $true
        ScrollBars = 'Vertical'
        Font       = $script:UI.Fonts.Default
        BackColor  = [System.Drawing.Color]::FromArgb(245, 245, 245)
    }

    $suggestionLabel = New-Object System.Windows.Forms.Label -Property @{
        Text      = "Suggested Solution:"
        Dock      = 'Top'
        Height    = 20
        Font      = $script:UI.Fonts.Bold
        ForeColor = $script:UI.Colors.Text
    }

    $suggestionTextBox = New-Object System.Windows.Forms.TextBox -Property @{
        Text       = $suggestion
        Dock       = 'Top'
        Height     = 60
        Multiline  = $true
        ReadOnly   = $true
        ScrollBars = 'Vertical'
        Font       = $script:UI.Fonts.Default
        BackColor  = [System.Drawing.Color]::FromArgb(230, 255, 230)
    }

    $buttonPanel = New-Object System.Windows.Forms.Panel -Property @{
        Dock   = 'Bottom'
        Height = 50
    }

    $retryButton = New-Object System.Windows.Forms.Button -Property @{
        Text      = "RETRY"
        Size      = New-Object System.Drawing.Size(100, 35)
        Location  = New-Object System.Drawing.Point(10, 7)
        Font      = $script:UI.Fonts.Bold
        BackColor = [System.Drawing.Color]::FromArgb(76, 175, 80)
        ForeColor = [System.Drawing.Color]::White
        FlatStyle = 'Flat'
        Add_Click = {
            $recoveryForm.DialogResult = [System.Windows.Forms.DialogResult]::Retry
            $recoveryForm.Close()
        }
    }

    $skipButton = New-Object System.Windows.Forms.Button -Property @{
        Text      = "SKIP"
        Size      = New-Object System.Drawing.Size(100, 35)
        Location  = New-Object System.Drawing.Point(120, 7)
        Font      = $script:UI.Fonts.Bold
        BackColor = [System.Drawing.Color]::FromArgb(255, 152, 0)
        ForeColor = [System.Drawing.Color]::White
        FlatStyle = 'Flat'
        Add_Click = {
            $recoveryForm.DialogResult = [System.Windows.Forms.DialogResult]::Ignore
            $recoveryForm.Close()
        }
    }

    $cancelButton = New-Object System.Windows.Forms.Button -Property @{
        Text      = "CANCEL ALL"
        Size      = New-Object System.Drawing.Size(100, 35)
        Location  = New-Object System.Drawing.Point(230, 7)
        Font      = $script:UI.Fonts.Bold
        BackColor = [System.Drawing.Color]::FromArgb(244, 67, 54)
        ForeColor = [System.Drawing.Color]::White
        FlatStyle = 'Flat'
        Add_Click = {
            $recoveryForm.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $recoveryForm.Close()
        }
    }

    $buttonPanel.Controls.AddRange(@($retryButton, $skipButton, $cancelButton))
    $mainPanel.Controls.AddRange(@($titleLabel, $errorLabel, $errorTextBox, $suggestionLabel, $suggestionTextBox, $buttonPanel))
    $recoveryForm.Controls.Add($mainPanel)

    return $recoveryForm.ShowDialog()
}

# ------------------------------
# Functions
# ------------------------------
function Add-ListView {
    param ($panel, $key, $data)

    $LV = New-Object System.Windows.Forms.ListView -Property $ListViewProps
    # Add columns: NAME, TIME, COMMAND (removed Description)
    $LV.Columns.Add($key.ToUpper(), $script:UI.Sizes.Columns.Name) | Out-Null
    $LV.Columns.Add("TIME", $script:UI.Sizes.Columns.Description) | Out-Null
    $LV.Columns.Add("COMMAND", $script:UI.Sizes.Columns.Command) | Out-Null

    # Capture the current $key value in a local variable
    $currentKey = $key
    $LV.Add_ColumnClick({
            Format-ListView -ListView $LV -ViewName $currentKey -Column $_.Column
        }.GetNewClosure())

    # Add items from grouped scripts data with risk assessment and styling
    foreach ($script in $data) {
        $listItem = New-Object System.Windows.Forms.ListViewItem($script.content)
        
        # Get time estimate and risk assessment
        $timeEst = Get-EstimatedExecutionTime -command $script.command
        $risk = Get-CommandRiskLevel -command $script.command
        $requiresAdmin = Test-RequiresAdminPrivileges -command $script.command
        
        $listItem.SubItems.Add($timeEst)
        $listItem.SubItems.Add($script.command)
        
        # Color code by risk level
        switch ($risk) {
            "HIGH" { $listItem.BackColor = [System.Drawing.Color]::FromArgb(255, 230, 230) }
            "MEDIUM" { $listItem.BackColor = [System.Drawing.Color]::FromArgb(255, 245, 230) }
            "LOW" { $listItem.BackColor = [System.Drawing.Color]::FromArgb(230, 255, 230) }
        }
        
        # Bold font for admin-required commands
        if ($requiresAdmin) {
            $listItem.Font = $script:UI.Fonts.Bold
        }
        
        $LV.Items.Add($listItem)
    }

    $script:LastColumnClicked[$key] = 0
    $script:LastColumnAscending[$key] = $true
    $script:ListViews[$key] = $LV

    # Add ListView to the specified panel
    $panel.Controls.Add($LV)
}

# Function to create nested SplitContainer
function CreateSplitContainer {
    param (
        $parentPanel, 
        [string[]]$keys,
        [int]$index,
        [System.Collections.Specialized.OrderedDictionary]$groupedScripts
    )

    if ($index -ge $keys.Count) { return }

    # Clear existing controls first
    if ($index -eq 0) {
        $parentPanel.Controls.Clear()
        $script:SplitContainers = @()  # Reset split containers array
        
        # If only one group, add it directly without split container
        if ($keys.Count -eq 1) {
            Add-ListView -panel $parentPanel -key $keys[0] -data $groupedScripts[$keys[0]]
            return
        }
    }

    # Create split container for two or more groups
    $splitContainer = New-Object System.Windows.Forms.SplitContainer -Property $SplitProps
    $script:SplitContainers += $splitContainer
    
    # Calculate the position for this splitter based on remaining groups
    $remainingGroups = $keys.Count - $index
    if ($remainingGroups -gt 1) {
        $splitDistance = [Math]::Floor($parentPanel.ClientSize.Height / $remainingGroups)
        try {
            $splitContainer.SplitterDistance = $splitDistance
        }
        catch {
            Write-Warning "Error setting SplitterDistance: $_"
        }
    }

    $parentPanel.Controls.Add($splitContainer)

    # Add ListView to first panel with current group
    $currentKey = $keys[$index]
    Add-ListView -panel $splitContainer.Panel1 -key $currentKey -data $groupedScripts[$currentKey]

    # If there's another group, add it to Panel2
    if ($index + 1 -lt $keys.Count) {
        # If this is the last pair of groups, add ListView directly to Panel2
        if ($index + 2 -ge $keys.Count) {
            Add-ListView -panel $splitContainer.Panel2 -key $keys[$index + 1] -data $groupedScripts[$keys[$index + 1]]
        }
        # Otherwise, continue creating nested split containers
        else {
            CreateSplitContainer -parentPanel $splitContainer.Panel2 -keys $keys -index ($index + 1) -groupedScripts $groupedScripts
        }
    }
}

function Format-ListView {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.ListView]$ListView,
        [Parameter(Mandatory)][string]$ViewName,
        [Parameter(Mandatory)][int]$Column
    )
    
    # Toggle sort direction if same column clicked
    if ($script:LastColumnClicked[$ViewName] -eq $Column) {
        $script:LastColumnAscending[$ViewName] = -not $script:LastColumnAscending[$ViewName]
    }
    else {
        $script:LastColumnAscending[$ViewName] = $true
    }
    $script:LastColumnClicked[$ViewName] = $Column

    $items = @($ListView.Items)
    $ListView.BeginUpdate()
    try {
        # Sort items
        $items = $items | Sort-Object -Property {
            $_.SubItems[$Column].Text
        } -Descending:(-not $script:LastColumnAscending[$ViewName])

        # Rebuild ListView
        $ListView.Items.Clear()
        $ListView.Items.AddRange([System.Windows.Forms.ListViewItem[]]$items)
    }
    finally {
        $ListView.EndUpdate()
    }
}

function RunSelectedItems {
    param(
        [ValidateSet("Invoke", "Revoke")]
        [string]$Action,
        [array]$SelectedItems = $null
    )
    
    # Disable the invoke button while running
    $InvokeButton.Enabled = $false
    $InvokeButton.Text = "Running..."

    try {
        # Get selected items - either from parameter or from ListViews
        $selectedItems = if ($SelectedItems) { 
            $SelectedItems 
        }
        else {
            $items = @()
            foreach ($listView in $script:ListViews.Values) {
                $items += $listView.Items | Where-Object { $_.Checked }
            }
            $items
        }

        if ($selectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No items selected.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        # Create log file with timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $logFileName = "WinUtil_Run_$timestamp.log"
        $logFilePath = Join-Path -Path $script:LogsDirectory -ChildPath $logFileName
        
        # Initialize log file with simple header
        $logHeader = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [INFO] Gray WinUtil execution started - Action: $Action, Items: $($selectedItems.Count)"
        Set-Content -Path $logFilePath -Value $logHeader -Encoding UTF8

        # Create progress form
        $progressForm = New-Object System.Windows.Forms.Form -Property @{
            Text            = "Running Commands"
            Size            = New-Object System.Drawing.Size(500, 200)
            StartPosition   = "CenterParent"
            FormBorderStyle = "FixedDialog"
            ControlBox      = $false
            Font            = $script:UI.Fonts.Default
        }

        $progressLabel = New-Object System.Windows.Forms.Label -Property @{
            Location = New-Object System.Drawing.Point(10, 20)
            Size     = New-Object System.Drawing.Size(460, 60)
            Font     = $script:UI.Fonts.Default
            Text     = "Initializing..."
        }

        $progressBar = New-Object System.Windows.Forms.ProgressBar -Property @{
            Location = New-Object System.Drawing.Point(10, 90)
            Size     = New-Object System.Drawing.Size(460, 20)
            Minimum  = 0
            Maximum  = $selectedItems.Count
            Value    = 0
        }

        $statusLabel = New-Object System.Windows.Forms.Label -Property @{
            Location = New-Object System.Drawing.Point(10, 120)
            Size     = New-Object System.Drawing.Size(460, 40)
            Font     = $script:UI.Fonts.Default
            Text     = "Ready to start..."
        }

        $progressForm.Controls.AddRange(@($progressLabel, $progressBar, $statusLabel))
        $progressForm.Show()
        $Form.Enabled = $false

        # Track overall success
        $successCount = 0
        $failureCount = 0
        $skippedCount = 0
        $errorLog = @()
        $userCancelled = $false

        # Process each selected item with enhanced error handling
        for ($i = 0; $i -lt $selectedItems.Count; $i++) {
            if ($userCancelled) { break }
            
            $item = $selectedItems[$i]
            $command = $item.SubItems[2].Text
            $name = $item.Text

            $progressBar.Value = $i
            $progressLabel.Text = "Running: $name ($($i + 1) of $($selectedItems.Count))"
            $statusLabel.Text = "Executing command..."
            [System.Windows.Forms.Application]::DoEvents()

            # Log command execution start
            $startLogEntry = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [INFO] Starting [$($i + 1)/$($selectedItems.Count)] $name - Command: $command"
            Add-Content -Path $logFilePath -Value $startLogEntry -Encoding UTF8

            $retryCount = 0
            $maxRetries = 2
            $commandCompleted = $false
            
            while ($retryCount -le $maxRetries -and -not $commandCompleted -and -not $userCancelled) {
                try {
                    $startTime = Get-Date
                    
                    if ($retryCount -gt 0) {
                        $statusLabel.Text = "Retrying... (Attempt $($retryCount + 1) of $($maxRetries + 1))"
                        [System.Windows.Forms.Application]::DoEvents()
                        Start-Sleep -Seconds 2  # Brief delay before retry
                    }
                    
                    # Execute command and capture output
                    $psi = New-Object System.Diagnostics.ProcessStartInfo
                    $psi.FileName = "powershell.exe"
                    $psi.Arguments = "-NoProfile -Command `"$command`""
                    $psi.UseShellExecute = $false
                    $psi.RedirectStandardOutput = $true
                    $psi.RedirectStandardError = $true
                    $psi.CreateNoWindow = $true
                    
                    $process = New-Object System.Diagnostics.Process
                    $process.StartInfo = $psi
                    
                    # Start the process
                    $process.Start() | Out-Null
                    
                    # Read output streams
                    $output = $process.StandardOutput.ReadToEnd()
                    $errorOutput = $process.StandardError.ReadToEnd()
                    
                    # Wait for process to complete
                    $process.WaitForExit()
                    $exitCode = $process.ExitCode
                    $endTime = Get-Date
                    $duration = $endTime - $startTime
                    
                    if ($exitCode -eq 0) {
                        # Command succeeded
                        $commandCompleted = $true
                        # Filter out verbose progress information for winget commands
                        $filteredOutput = $output
                        if ($command -like "*winget*") {
                            $outputLines = $output -split "`n"
                            $filteredLines = $outputLines | Where-Object {
                                $line = $_.Trim()
                                -not ($line -match "^\s*[\[\]]+$") -and
                                -not ($line -match "^\s*\d+%\s*$") -and
                                -not ($line -match "^\s*[#+=\-_]{5,}") -and
                                -not ($line -match "^\s*\.\.\.\s*$") -and
                                -not ($line -match "^Downloading.*MB/.*MB") -and
                                -not ($line -match "^\s*$")
                            }
                            $relevantLines = $filteredLines | Where-Object {
                                $line = $_.Trim()
                                $line -match "(Successfully|Found|Installing|Installed|Failed|Error|Warning|Agreement|License)" -or
                                $line.Length -lt 100
                            }
                            
                            $filteredOutput = if ($relevantLines.Count -gt 0) {
                                ($relevantLines | Select-Object -First 10) -join "`n"
                            }
                            else {
                                "Command completed (verbose output filtered)"
                            }
                        }
                        
                        # Log success
                        $successLogEntry = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [SUCCESS] $name - ExitCode: $exitCode, Duration: $([Math]::Round($duration.TotalSeconds, 2))s, Attempts: $($retryCount + 1)"
                        Add-Content -Path $logFilePath -Value $successLogEntry -Encoding UTF8
                        
                        if ($filteredOutput.Trim()) {
                            $outputLogEntry = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [OUTPUT] $($filteredOutput.Trim())"
                            Add-Content -Path $logFilePath -Value $outputLogEntry -Encoding UTF8
                        }
                        $successCount++
                        $item.Checked = $false
                        $statusLabel.Text = "Completed successfully"
                    }
                    else {
                        # Command failed, prepare error message
                        $fullErrorMessage = if ($errorOutput.Trim()) { $errorOutput.Trim() } else { "Command exited with code $exitCode" }
                        throw [System.Exception]::new($fullErrorMessage)
                    }
                }
                catch {
                    $endTime = Get-Date
                    $duration = $endTime - $startTime
                    $errorMessage = $_.Exception.Message
                    
                    # Log the attempt
                    $attemptLogEntry = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [ATTEMPT] $name - Attempt $($retryCount + 1) failed - Duration: $([Math]::Round($duration.TotalSeconds, 2))s - Error: $errorMessage"
                    Add-Content -Path $logFilePath -Value $attemptLogEntry -Encoding UTF8
                    $retryCount++
                    if ($retryCount -le $maxRetries) {
                        # Show error recovery dialog
                        $suggestion = Get-ErrorSuggestion -errorMessage $errorMessage -command $command
                        
                        $statusLabel.Text = "Error occurred - showing recovery options..."
                        [System.Windows.Forms.Application]::DoEvents()
                        
                        # Temporarily hide progress form to show recovery dialog
                        $progressForm.Hide()
                        $Form.Enabled = $true
                        
                        $recoveryChoice = Show-ErrorRecoveryDialog -commandName $name -errorMessage $errorMessage -command $command -suggestion $suggestion
                        
                        # Restore progress form
                        $Form.Enabled = $false
                        $progressForm.Show()
                        
                        switch ($recoveryChoice) {
                            'Retry' {
                                # Continue the retry loop
                                continue
                            }                            'Ignore' {
                                # Skip this command
                                $skippedCount++
                                $commandCompleted = $true
                                $skipLogEntry = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [SKIPPED] $name - User chose to skip after $($retryCount) attempts"
                                Add-Content -Path $logFilePath -Value $skipLogEntry -Encoding UTF8
                                $statusLabel.Text = "Skipped by user"
                                break
                            }
                            'Cancel' {
                                # Cancel all remaining commands
                                $userCancelled = $true
                                $cancelLogEntry = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [CANCELLED] Execution cancelled by user at command: $name"
                                Add-Content -Path $logFilePath -Value $cancelLogEntry -Encoding UTF8
                                break
                            }
                        }
                    }
                    else {
                        # Max retries reached
                        $failureCount++
                        $commandCompleted = $true
                        $errorLog += "Error running '$name' (after $($maxRetries + 1) attempts): $errorMessage"
                        $failureLogEntry = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [FAILED] $name - Max retries reached - Total Duration: $([Math]::Round($duration.TotalSeconds, 2))s - Final Error: $errorMessage"
                        Add-Content -Path $logFilePath -Value $failureLogEntry -Encoding UTF8
                        $statusLabel.Text = "Failed after $($maxRetries + 1) attempts"
                    }
                }
                
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 500
            }
        }

        # Log session summary
        $summaryLogEntry = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [INFO] Execution completed - Total: $($selectedItems.Count), Success: $successCount, Failed: $failureCount, Skipped: $skippedCount, Cancelled: $userCancelled"
        Add-Content -Path $logFilePath -Value $summaryLogEntry -Encoding UTF8        # Show final results
        $progressForm.Close()
        $Form.Enabled = $true

        $resultMessage = "Execution complete.`n`n"
        $resultMessage += "SUCCESS: $successCount`n"
        if ($failureCount -gt 0) {
            $resultMessage += "FAILED: $failureCount`n"
        }
        if ($skippedCount -gt 0) {
            $resultMessage += "SKIPPED: $skippedCount`n"
        }
        if ($userCancelled) {
            $resultMessage += "CANCELLED by user`n"
        }
        
        if ($failureCount -gt 0) {
            $resultMessage += "`nError Details:`n" + ($errorLog -join "`n")
            $icon = [System.Windows.Forms.MessageBoxIcon]::Warning
        }
        elseif ($skippedCount -gt 0) {
            $resultMessage += "`nSome commands were skipped."
            $icon = [System.Windows.Forms.MessageBoxIcon]::Information
        }
        else {
            $resultMessage += "`nAll commands completed successfully!"
            $icon = [System.Windows.Forms.MessageBoxIcon]::Information
        }
        
        $resultMessage += "`n`nDetailed log saved to:`n$logFilePath"

        [System.Windows.Forms.MessageBox]::Show($resultMessage, "Execution Results", [System.Windows.Forms.MessageBoxButtons]::OK, $icon)
    }
    finally {
        # Re-enable the invoke button
        $InvokeButton.Enabled = $true
        $InvokeButton.Text = "Run"
    }
}

function Get-ScriptFromId {
    param (
        [Parameter(Mandatory)]
        [string]$Id,
        [Parameter(Mandatory)]
        $DbData
    )
    
    $scriptData = $DbData | Where-Object { $_.id -eq $Id }
    if ($scriptData) {
        return @{
            content     = $scriptData.id
            description = $scriptData.description
            command     = $scriptData.command
        }
    }
    return $null
}

# ------------------------------
# Application Initialization
# ------------------------------
if ([Environment]::OSVersion.Version.Major -ge 6) {
    try { [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2) } catch {}
}
[System.Windows.Forms.Application]::EnableVisualStyles()

# ------------------------------
# GUI Initialization
# ------------------------------
$Form = New-Object Windows.Forms.Form -Property $FormProps
$HeaderPanel = New-Object System.Windows.Forms.Panel -Property $HeaderPanelProps
$ContentPanel = New-Object Windows.Forms.Panel -Property $ContentPanelProps
$FooterPanel = New-Object System.Windows.Forms.Panel -Property $FooterPanelProps

$SelectAllSwitch = New-Object System.Windows.Forms.CheckBox -Property $SelectAllSwitchProps
$SearchBox = New-Object System.Windows.Forms.TextBox -Property $SearchBoxProps
$ConsentCheckbox = New-Object System.Windows.Forms.CheckBox -Property $ConsentCheckboxProps
$InvokeButton = New-Object System.Windows.Forms.Button -Property $InvokeButtonProps

$ProfileDropDown = New-Object System.Windows.Forms.ComboBox -Property $ProfileDropdownProps

# Create padding spacer between search area and consent checkbox
$PaddingSpacerPanel = New-Object System.Windows.Forms.Panel -Property @{
    Width = 15
    Dock  = 'Right'
}

$HelpLabel = New-Object System.Windows.Forms.Label -Property @{
    Text      = "HELP?"
    Width     = $script:UI.Sizes.Input.FooterWidth
    Height    = $script:UI.Sizes.Input.Height
    Dock      = 'Right'
    Font      = $script:UI.Fonts.Default
    ForeColor = $script:UI.Colors.Text
    TextAlign = 'MiddleCenter'
    AutoSize  = $true
    Add_Click = {
        # Singleton pattern: Check if Help window already exists
        if ($script:HelpForm -and -not $script:HelpForm.IsDisposed) {
            # Window exists, bring it to front
            $script:HelpForm.BringToFront()
            $script:HelpForm.Activate()
            return
        }        
        # Create Help Window
        $script:HelpForm = New-Object System.Windows.Forms.Form -Property @{
            Text           = "HELP - Gray WinUtil"
            Size           = New-Object System.Drawing.Size(350, 350)
            Font           = $script:UI.Fonts.Default
            BackColor      = $script:UI.Colors.Background
            StartPosition  = "CenterParent"
            MaximizeBox    = $false
            MinimizeBox    = $false
            Padding        = '10,10,10,10'
            Add_Shown      = { $script:HelpForm.Activate() }
            Add_FormClosed = { $script:HelpForm = $null }  # Clear reference when closed
        }       
        $HelpPanel = New-Object System.Windows.Forms.Panel -Property @{
            Dock       = 'Fill'
            AutoScroll = $true
        }
        $KeyboardShortcutsLabel = New-Object System.Windows.Forms.Label -Property @{
            Text      = "Hotkeys:`n• Ctrl+A - Select All Scripts`n• Ctrl+R - Run Selected Scripts`n• Ctrl+C - Copy Selected Scripts"
            Location  = New-Object System.Drawing.Point(10, $yPosition)
            Size      = New-Object System.Drawing.Size(300, 70)
            ForeColor = $script:UI.Colors.Text
            Font      = $script:UI.Fonts.Default
            TextAlign = 'TopLeft'
            AutoSize  = $false
        }
        $yPosition += 80

        $LowRiskLabel = New-Object System.Windows.Forms.Label -Property @{
            Text      = "Color Codes:`n• This action is marked as a low risk item"
            Location  = New-Object System.Drawing.Point(10, $yPosition)
            Size      = New-Object System.Drawing.Size(300, 40)
            Font      = $script:UI.Fonts.Default
            BackColor = [System.Drawing.Color]::FromArgb(230, 255, 230)
            ForeColor = $script:UI.Colors.Text
            TextAlign = 'MiddleLeft'
            AutoSize  = $true
        }
        $yPosition += 40

        $MediumRiskLabel = New-Object System.Windows.Forms.Label -Property @{
            Text      = "• This action is marked as a medium risk item"
            Location  = New-Object System.Drawing.Point(10, $yPosition)
            Size      = New-Object System.Drawing.Size(300, 20)
            Font      = $script:UI.Fonts.Default
            BackColor = [System.Drawing.Color]::FromArgb(255, 245, 230)
            ForeColor = $script:UI.Colors.Text
            TextAlign = 'MiddleLeft'
            AutoSize  = $true
        }
        $yPosition += 20

        $AdminLabel = New-Object System.Windows.Forms.Label -Property @{
            Text      = "• This action requires admin privileges"
            Location  = New-Object System.Drawing.Point(10, $yPosition)
            Size      = New-Object System.Drawing.Size(300, 20)
            Font      = $script:UI.Fonts.Bold
            BackColor = $script:UI.Colors.Background
            ForeColor = $script:UI.Colors.Text
            TextAlign = 'MiddleLeft'
            AutoSize  = $true
        }
        $yPosition += 20

        $HighRiskLabel = New-Object System.Windows.Forms.Label -Property @{
            Text      = "• This action is marked as a high risk item"
            Location  = New-Object System.Drawing.Point(10, $yPosition)
            Size      = New-Object System.Drawing.Size(300, 20)
            Font      = $script:UI.Fonts.Default
            BackColor = [System.Drawing.Color]::FromArgb(255, 230, 230)
            ForeColor = $script:UI.Colors.Text
            TextAlign = 'MiddleLeft'
            AutoSize  = $true
        }

        $yPosition += 30
        
        $DiscordHelpLabel = New-Object System.Windows.Forms.Label -Property @{
            Text      = "Links:`n• Ask for help on Discord: discord.gg/GT4fac2u"
            Location  = New-Object System.Drawing.Point(10, $yPosition)
            Size      = New-Object System.Drawing.Size(300, 40)
            Font      = $script:UI.Fonts.Default
            BackColor = [System.Drawing.Color]::FromArgb(240, 242, 245)
            ForeColor = [System.Drawing.Color]::FromArgb(88, 101, 242)
            AutoSize  = $false
            Cursor    = [System.Windows.Forms.Cursors]::Hand
            Add_Click = {
                Start-Process -FilePath "https://discord.gg/GT4fac2u"
            }
        }
        $yPosition += 35

        $RepoHelpLabel = New-Object System.Windows.Forms.Label -Property @{
            Text      = "• View Source code: github.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)"
            Location  = New-Object System.Drawing.Point(10, $yPosition)
            Font      = $script:UI.Fonts.Default
            Size      = New-Object System.Drawing.Size(300, 20)
            BackColor = [System.Drawing.Color]::FromArgb(240, 242, 245)
            ForeColor = [System.Drawing.Color]::FromArgb(88, 101, 242)
            AutoSize  = $false
            Cursor    = [System.Windows.Forms.Cursors]::Hand
            Add_Click = {
                $url = "https://github.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)"
                Start-Process -FilePath $url
            }
        }

        $HelpPanel.Controls.AddRange(@( $KeyboardShortcutsLabel, $LowRiskLabel, $MediumRiskLabel, $HighRiskLabel, $AdminLabel, $DiscordHelpLabel, $RepoHelpLabel))
        $script:HelpForm.Controls.Add($HelpPanel)
        $script:HelpForm.Show()  # Use Show() instead of ShowDialog() for non-blocking
    }
}

$UpdatesLabel = New-Object System.Windows.Forms.Label -Property @{
    Text      = "UPDATES"
    Width     = $script:UI.Sizes.InputFooterWidth
    Height    = $script:UI.Sizes.Input.Height
    Dock      = 'Right'
    Font      = $script:UI.Fonts.Default
    ForeColor = $script:UI.Colors.Text
    TextAlign = 'MiddleCenter'
    AutoSize  = $true
    Add_Click = {
        # Singleton pattern: Check if Updates window already exists
        if ($script:UpdatesForm -and -not $script:UpdatesForm.IsDisposed) {
            # Window exists, bring it to front
            $script:UpdatesForm.BringToFront()
            $script:UpdatesForm.Activate()
            return
        }

        # Fetch repository profiles
        $repoUrl = "$($script:Config.ApiUrl)/Profiles"
        try {
            $response = Invoke-WebRequest -Uri $repoUrl -UseBasicParsing
            $content = ConvertFrom-Json $response.Content
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error accessing repository: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        # Create UpdatesForm matching HelpForm design
        $script:UpdatesForm = New-Object System.Windows.Forms.Form -Property @{
            Text           = "Updates - Gray WinUtil"
            Size           = New-Object System.Drawing.Size(350, 350)
            Font           = $script:UI.Fonts.Default
            BackColor      = $script:UI.Colors.Background
            StartPosition  = "CenterParent"
            MaximizeBox    = $false
            MinimizeBox    = $false
            Padding        = '10,10,10,10'
            Add_Shown      = { $script:UpdatesForm.Activate() }
            Add_FormClosed = { $script:UpdatesForm = $null }  # Clear reference when closed
        }        

        # Main panel to hold ListView
        $UpdatesPanel = New-Object System.Windows.Forms.Panel -Property @{
            Dock    = 'Fill'
            Padding = '15,15,15,15'  # Add padding around the Updates panel
        }        
        # Updates ListView with Details view (no checkboxes)
        $UpdatesListView = New-Object System.Windows.Forms.ListView -Property @{
            Dock             = 'Fill'
            View             = 'Details'
            CheckBoxes       = $false
            Font             = $script:UI.Fonts.Default
            BackColor        = $script:UI.Colors.Background
            ForeColor        = $script:UI.Colors.Text
            BorderStyle      = 'None'
            FullRowSelect    = $true
            MultiSelect      = $false
            ShowItemToolTips = $true
        }

        # Add columns: Updates, Status, Size
        $UpdatesListView.Columns.Add("Updates", 160) | Out-Null
        $UpdatesListView.Columns.Add("Status", 50) | Out-Null
        $UpdatesListView.Columns.Add("Size", 70) | Out-Null

        # Get local profiles for comparison
        $localProfiles = @()
        if (Test-Path $script:ProfilesDirectory) {
            $localProfiles = Get-ChildItem -Path $script:ProfilesDirectory -Filter "*.txt" | ForEach-Object { $_.Name }
        }

        # Populate ListView with repository profiles
        foreach ($repoItem in $content) {
            if ($repoItem.type -eq "file" -and $repoItem.name -like "*.txt") {
                $listItem = New-Object System.Windows.Forms.ListViewItem($repoItem.name)
                
                # Format file size
                $fileSizeKB = [Math]::Round($repoItem.size / 1024, 1)
                $sizeText = if ($fileSizeKB -lt 1) { "$($repoItem.size) B" } else { "$fileSizeKB KB" }
                
                if ($localProfiles -contains $repoItem.name) {
                    # Update candidate - locally available
                    $listItem.SubItems.Add("🔃")
                    $listItem.SubItems.Add($sizeText)
                    # $listItem.BackColor = [System.Drawing.Color]::FromArgb(255, 248, 225) # Light orange
                    $listItem.ForeColor = [System.Drawing.Color]::FromArgb(230, 126, 34) # Orange
                    $listItem.ToolTipText = "To be updated"                
                }
                else {
                    # Download candidate - not locally available
                    $listItem.SubItems.Add("⏬")
                    $listItem.SubItems.Add($sizeText)
                    # $listItem.BackColor = [System.Drawing.Color]::FromArgb(232, 245, 233) # Light green
                    $listItem.ForeColor = [System.Drawing.Color]::FromArgb(76, 175, 80) # Green
                    $listItem.ToolTipText = "To be downloaded"
                }
                
                $UpdatesListView.Items.Add($listItem) | Out-Null
            }
        }
        # Add a button to download selected files into the user's personal scripts folder
        $DownloadButton = New-Object System.Windows.Forms.Button -Property @{
            Text      = "DOWNLOAD"
            Height    = 25
            Width     = $script:UI.Sizes.Input.FooterWidth
            Font      = $script:UI.Fonts.Bold
            FlatStyle = 'Flat'
            BackColor = [System.Drawing.Color]::FromArgb(76, 175, 80)
            ForeColor = [System.Drawing.Color]::White
            Dock      = 'Bottom'
            Add_Click = {
                # Dowload all the profiles from github raw urls
                 

            }
        }
        $UpdatesPanel.Controls.Add($UpdatesListView)
        $UpdatesPanel.Controls.Add($DownloadButton)
        $script:UpdatesForm.Controls.Add($UpdatesPanel)
        
        $script:UpdatesForm.Show()  # Use Show() instead of ShowDialog() for non-blocking
    }
}

$HeaderPanel.Controls.AddRange(@($SearchBox, $SelectAllSwitch, $PaddingSpacerPanel, $ConsentCheckbox, $InvokeButton))
$FooterPanel.Controls.AddRange(@($ProfileDropdown, $HelpLabel, $UpdatesLabel))
$Form.Controls.AddRange(@($HeaderPanel, $ContentPanel, $FooterPanel))

# Initialize file system
if (-not (Test-Path $script:DataDirectory)) {
    New-Item -ItemType Directory -Path $script:DataDirectory | Out-Null
}

if (-not (Test-Path $script:ProfilesDirectory)) {
    New-Item -ItemType Directory -Path $script:ProfilesDirectory | Out-Null
}

if (-not (Test-Path $script:LogsDirectory)) {
    New-Item -ItemType Directory -Path $script:LogsDirectory | Out-Null
}

$defaultProfile = Join-Path -Path $script:ProfilesDirectory -ChildPath "Default Profile.txt"
if (-not (Test-Path $defaultProfile)) {
    New-Item -ItemType File -Path $defaultProfile | Out-Null

    # scan db.json, for each entry add the id and a new line to the default profile
    $dbJsonPath = Join-Path -Path $PSScriptRoot -ChildPath "db.json"
    if (Test-Path $dbJsonPath) {
        $scriptsData = Get-Content -Path $dbJsonPath -Raw | ConvertFrom-Json
        $allIds = @()
        $scriptsData.PSObject.Properties | ForEach-Object {
            $_.Value | ForEach-Object {
                if ($_.id) {
                    $allIds += $_.id
                }
            }
        }
        if ($allIds.Count -gt 0) {
            $allIds | Set-Content -Path $defaultProfile -Force
        }
    }
}

# Load user provided profiles
Get-ChildItem -Path $script:ProfilesDirectory -Filter "*.txt" | ForEach-Object {
    $ProfileDropdown.Items.Add($_.BaseName) | Out-Null
}

if ($ProfileDropdown.Items.Count -gt 0) {
    $ProfileDropdown.SelectedIndex = 0
}

# Start application
[void]$Form.ShowDialog()