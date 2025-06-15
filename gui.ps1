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

### TODO **Help**
# - Help Shows relevant info and action buttons on the footer panel aligned to right side.

### TODO **Local Data Storage**
# - Store local data in the %Temp% directory by default.
# - Provide an option for users to store data locally.
# - Create a PowerShell script file executing this script from github url
# - Create a startmenu and desktop shortcut for the script
#>

# ------------------------------
# Configuration
# ------------------------------
# Repository configuration - Update these variables for your own repository
$script:Config = @{
    AdminRequiredPatterns = @(
        'Add-WindowsCapability',
        'bcdedit',
        'Clear-Disk',
        'dism',
        'Disable-Service',
        'diskpart',
        'Enable-Service',
        'Format-Volume',
        'netsh',
        'New-ItemProperty.*HKLM',
        'New-NetFirewallRule',
        'reg add.*HKLM',
        'reg delete.*HKLM',
        'Remove-NetFirewallRule',
        'Remove-WindowsCapability',
        'sc.exe',
        'Set-ItemProperty.*HKLM',
        'Set-NetFirewallRule',
        'Set-Service',
        'sfc',
        'Start-Service',
        'Stop-Service',
        'winget'
    )
    ApiUrl                = $null  # Will be generated below
    DatabaseFile          = "db.json"           # Database file name
    DatabaseUrl           = $null  # Will be generated below
    GitHubBranch          = "main"              # Default branch
    GitHubOwner           = "mrdotkg"           # GitHub username
    GitHubRepo            = "dotfiles"          # Repository name
    HighRiskPatterns      = @(
        'bcdedit',
        'Clear-Disk',
        'diskpart',
        'Format-Volume',
        'reg delete.*HKLM',
        'Remove-Computer',
        'Remove-Item.*-Recurse',
        'Restart-Computer',
        'rm.*-rf',
        'Set-ExecutionPolicy.*Unrestricted',
        'shutdown',
        'Stop-Computer'
    )
    MediumRiskPatterns    = @(
        'Disable-Service',
        'New-ItemProperty.*HKLM',
        'New-NetFirewallRule',
        'Set-ItemProperty.*HKLM',
        'Set-NetFirewallRule',
        'Set-Service',
        'Stop-Service',
        'winget uninstall'
    )
    ScriptsPath           = "$HOME\Documents\WinUtil Local Data"  # Local data directory
}

# ------------------------------
# Initialize Dependencies
# ------------------------------
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# Generate URLs from configuration
$script:Config.DatabaseUrl = "https://raw.githubusercontent.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/refs/heads/$($script:Config.GitHubBranch)/$($script:Config.DatabaseFile)"
$script:Config.ApiUrl = "https://api.github.com/repos/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/contents"

# ------------------------------
# State Management
# ------------------------------
# Script-scoped variables
$script:DataDirectory = "$HOME\Documents\WinUtil Local Data"
$script:ProfilesDirectory = "$HOME\Documents\WinUtil Local Data\Profiles"
$script:LogsDirectory = "$HOME\Documents\WinUtil Local Data\Logs"
$script:ListViews = @{}
$script:CurrentProfileIndex = -1  # Track currently selected profile index
# Window management for singleton pattern
$script:HelpForm = $null
$script:UpdatesForm = $null

# UI Theme and Constants
$script:UI = @{
    Colors  = @{
        Accent     = $null  # Will be set from Windows theme
        Background = [System.Drawing.Color]::FromArgb(241, 243, 249)
        Disabled   = [System.Drawing.Color]::LightGray
        Text       = [System.Drawing.Color]::Black
    }
    Fonts   = @{
        Bold    = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        Default = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
        Small   = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
    }
    Padding = @{
        Button  = '0,0,0,0'         # Button padding - no padding for precise alignment
        Content = "0,0,0,0"        # Content panel padding - enough top margin to clear 40px header + 10px buffer
        Control = '0,0,0,0'         # Standard control margins - centered vertically
        Footer  = '0,0,0,0'     # Footer panel padding - consistent padding all around
        Form    = '0,0,0,0'         # Main form padding - no padding for full control
        Header  = '0,0,0,0'         # Header panel padding - no padding for precise control
        Help    = '15,15,15,15'     # Help window padding - generous padding for readability
        Panel   = '0,0,0,0'         # Standard panel padding - no padding for alignment
        Status  = '0,5,0,5'       # Status panel padding - left/right margin with minimal vertical
        ToolBar = '5,8,0,8'       # ToolBar panel padding - consistent with control margins
        Updates = '15,15,15,15'     # Updates panel padding - generous padding for readability
    }
    Sizes   = @{
        Columns = @{
            Command    = 100
            Name       = 250
            Permission = 100
            Time       = 100
        }
        Footer  = @{
            Height = 30
        }
        Header  = @{
            # Height = 30
        }
        Input   = @{
            FooterWidth = 150
            Height      = 25
            Width       = 100
        }
        Status  = @{
            Height = 30
        }
        ToolBar = @{
            Height = 40
        }
        Window  = @{
            Height = 700
            Width  = 600
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
        elseif ($_.Control -and ($_.KeyCode -eq [System.Windows.Forms.Keys]::Up -or $_.KeyCode -eq [System.Windows.Forms.Keys]::K)) {
            # Ctrl+Up or Ctrl+K: Move selected item up
            $listView = $script:ListViews["MainList"]
            if ($listView) {
                Move-SelectedItemUp -ListView $listView
            }
            $_.Handled = $true
        }
        elseif ($_.Control -and ($_.KeyCode -eq [System.Windows.Forms.Keys]::Down -or $_.KeyCode -eq [System.Windows.Forms.Keys]::J)) {
            # Ctrl+Down or Ctrl+J: Move selected item down
            $listView = $script:ListViews["MainList"]
            if ($listView) {
                Move-SelectedItemDown -ListView $listView
            }
            $_.Handled = $true
        }
        elseif ($_.KeyCode -eq [System.Windows.Forms.Keys]::H) {
            # H: Move selected item up (Vim-style)
            $listView = $script:ListViews["MainList"]
            if ($listView) {
                Move-SelectedItemUp -ListView $listView
            }
            $_.Handled = $true
        }
        elseif ($_.KeyCode -eq [System.Windows.Forms.Keys]::L) {
            # L: Move selected item down (Vim-style)
            $listView = $script:ListViews["MainList"]
            if ($listView) {
                Move-SelectedItemDown -ListView $listView
            }
            $_.Handled = $true
        }
    }
    Add_Shown   = { 
        $Form.Activate()
        # Load user provided profiles
        Get-ChildItem -Path $script:ProfilesDirectory -Filter "*.txt" | ForEach-Object {
            $ProfileDropdown.Items.Add($_.BaseName) | Out-Null
        }

        if ($ProfileDropdown.Items.Count -gt 0) {
            $ProfileDropdown.SelectedIndex = 0
            $script:CurrentProfileIndex = 0  # Initialize the script variable
        }
    }
    BackColor   = $script:UI.Colors.Background
    Font        = $script:UI.Fonts.Default
    Height      = $script:UI.Sizes.Window.Height
    KeyPreview  = $true
    Padding     = $script:UI.Padding.Form
    Text        = "GRAY WINUTIL"
    Width       = $script:UI.Sizes.Window.Width
}

# Panels
$HeaderPanelProps = @{
    BackColor = $script:UI.Colors.Background
    # BorderStyle = 'FixedSingle'
    Dock      = 'Top'
    Height    = $script:UI.Sizes.Header.Height
    Padding   = $script:UI.Padding.Header
}

$ContentPanelProps = @{
    BackColor = $script:UI.Colors.Background
    # BorderStyle = 'FixedSingle'
    Dock      = 'Fill'
    Padding   = $script:UI.Padding.Content
}

$FooterPanelProps = @{
    BackColor   = $script:UI.Colors.Background
    BorderStyle = 'None'
    Dock        = 'Bottom'
    Font        = $script:UI.Fonts.Default
    Height      = $script:UI.Sizes.Footer.Height
    Padding     = $script:UI.Padding.Footer
}

# Spacer Panel between Header and Content
$SpacerPanelProps = @{
    BackColor = $script:UI.Colors.Background
    Dock      = 'Bottom'
    Height    = 5
    Padding   = '0,0,0,0'  # Remove padding so progress bar fills entire panel
}

# List View and Split Container
$ListViewProps = @{
    Add_DragDrop       = {
        param($sender, $e)
        $draggedItem = $e.Data.GetData([System.Windows.Forms.ListViewItem])
        if ($draggedItem) {
            $targetIndex = $sender.InsertionMark.Index
            if ($targetIndex -ge 0) {
                # Adjust target index based on AppearsAfterItem
                if ($sender.InsertionMark.AppearsAfterItem) {
                    $targetIndex++
                }
                Move-ListViewItem -ListView $sender -Item $draggedItem -TargetIndex $targetIndex
            }
        }
        # Clear the insertion mark
        $sender.InsertionMark.Index = -1
    }
    Add_DragEnter      = {
        if ($_.Data.GetDataPresent([System.Windows.Forms.ListViewItem])) {
            $_.Effect = [System.Windows.Forms.DragDropEffects]::Move
        }
    }
    Add_DragLeave      = {
        # Clear insertion mark when drag leaves the control
        $this.InsertionMark.Index = -1
    }
    Add_DragOver       = {
        param($sender, $e)
        $_.Effect = [System.Windows.Forms.DragDropEffects]::Move
        
        # Calculate the target index based on mouse position
        $pt = $sender.PointToClient([System.Windows.Forms.Cursor]::Position)
        $targetItem = $sender.GetItemAt($pt.X, $pt.Y)
        
        if ($targetItem) {
            $targetIndex = $targetItem.Index
            # Determine if we should insert before or after the target item
            $itemBounds = $targetItem.Bounds
            $midPoint = $itemBounds.Top + ($itemBounds.Height / 2)
            if ($pt.Y -gt $midPoint) {
                $targetIndex++
                $sender.InsertionMark.AppearsAfterItem = $true
            }
            else {
                $sender.InsertionMark.AppearsAfterItem = $false
            }
            $sender.InsertionMark.Index = $targetIndex
        }
        else {
            # If no item at cursor, insert at end
            $sender.InsertionMark.Index = $sender.Items.Count
            $sender.InsertionMark.AppearsAfterItem = $false
        }
    }
    Add_ItemChecked    = {
        $totalItems = ($script:ListViews.Values | ForEach-Object { $_.Items.Count } | Measure-Object -Sum).Sum
        $anyChecked = ($script:ListViews.Values | ForEach-Object { $_.Items | Where-Object { $_.Checked } } | Measure-Object).Count
        $InvokeButton.Enabled = $ConsentCheckbox.Checked -and ($anyChecked -gt 0)
        $InvokeButton.Text = "▶ Run ($anyChecked)"
        $SelectAllSwitch.Checked = ($anyChecked -eq $totalItems)
        $SelectAllSwitch.Tag = ($anyChecked -eq $totalItems)
    }
    Add_ItemDrag       = {
        if ($this.SelectedItems.Count -gt 0) {
            $this.DoDragDrop($this.SelectedItems[0], [System.Windows.Forms.DragDropEffects]::Move)
        }
    }
    AllowColumnReorder = $true
    AllowDrop          = $true   # Enable drag-drop
    # BorderStyle        = 'FixedSingle'
    CheckBoxes         = $true
    Dock               = 'Fill'
    Font               = $script:UI.Fonts.Default
    Forecolor          = $script:UI.Colors.Text
    FullRowSelect      = $true
    GridLines          = $true
    # Margin             = $script:UI.Padding.Button
    MultiSelect        = $false  # Changed to false for better reordering experience
    ShowItemToolTips   = $true
    Sorting            = [System.Windows.Forms.SortOrder]::None
    View               = 'Details'
}

# Control Properties
$SelectAllSwitchProps = @{
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
    AutoSize  = $true
    Dock      = 'Left'
    # Font      = $Script:UI.Fonts.Default
    Height    = 16
    Margin    = $script:UI.Padding.Control
    Tag       = $false
    Text      = "All"
    Width     = $script:UI.Sizes.Input.Width
}

$SearchBoxProps = @{
    # Add_Enter       = { 
    #     if ($this.Text -eq " Type to filter scripts...") { 
    #         $this.Text = ""
    #     } 
    # }
    # Add_Leave       = { 
    #     if ($this.Text -eq "") { 
    #         $this.Text = " Type to filter scripts..."
    #     } 
    # }
    Add_TextChanged = {
        $searchText = $this.Text.Trim()
        # if ($searchText -eq "Type to filter scripts...") { return }
        $listViews = @($script:ListViews.Values)
        foreach ($lv in $listViews) {
            $lv.BeginUpdate()
            try {
                # Collect all items and separate matched from non-matched
                $allItems = @($lv.Items)                
                foreach ($item in $allItems) {
                    if ($item.Text -like "*$searchText*") {
                        # instead of setting this Forecolor use the existing ForeColor
                        $command = $item.SubItems[2].Text
                        $Color = if (Test-RequiresAdminPrivileges -command $command) { "Red" } else { $script:UI.Colors.Text }
                        $item.ForeColor = $Color
                    }
                    else {
                        $item.ForeColor = $script:UI.Colors.Disabled
                    }
                }
            }
            finally {
                $lv.EndUpdate()
            }
        }
    }
    BackColor       = $script:UI.Colors.Background
    # BorderStyle     = 'FixedSingle'
    Dock            = 'Left'
    # Font            = $script:UI.Fonts.Default
    Height          = $script:UI.Sizes.Input.Height
    Margin          = '10,7,10,7'  # Consistent margin for alignment with other controls
    Multiline       = $false
    PlaceholderText = "Search"
    TextAlign       = 'Left'
    Width           = $script:UI.Sizes.Input.FooterWidth
}

$InvokeButtonProps = @{
    Add_Click = { 
        if ($ConsentCheckbox.Checked) {
            RunSelectedItems -Action Invoke
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Please check the consent checkbox to proceed with execution.", "Consent Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    }
    AutoSize  = $false
    BackColor = [System.Drawing.Color]::FromArgb(76, 175, 80)
    Dock      = 'Right'
    Enabled   = $false
    FlatStyle = 'Flat'
    # Font      = $script:UI.Fonts.Default
    ForeColor = [System.Drawing.Color]::White
    Height    = 16
    Margin    = $script:UI.Padding.Control
    Text      = "▶ Run"
    Width     = $script:UI.Sizes.Input.Width
}

$ConsentCheckboxProps = @{
    Add_CheckedChanged = {
        # Enable/disable buttons based on consent and selection
        $anyChecked = ($script:ListViews.Values | ForEach-Object { $_.Items | Where-Object { $_.Checked } } | Measure-Object).Count
        $InvokeButton.Enabled = $ConsentCheckbox.Checked -and ($anyChecked -gt 0)
    }
    Appearance         = 'Button'
    AutoSize           = $true
    Checked            = $false
    Dock               = 'Right'
    # Font               = $script:UI.Fonts.Default
    Height             = 16
    Margin             = $script:UI.Padding.Control
    Text               = "As Admin"
    Width              = $script:UI.Sizes.Input.Width
}
function Read-Profile {
    param([string]$Path)
    if (Test-Path $Path) {
        # Load the selected profile
        $ProfileLines = Get-Content -Path $Path -ErrorAction SilentlyContinue
        if (-not $ProfileLines) {
            Write-Warning "Selected profile '$Path' is empty or does not exist."
            return
        }
        else {
            try {
                $dbData = Invoke-WebRequest $script:Config.DatabaseUrl | ConvertFrom-Json
            }
            catch {
                Write-Warning "Failed to fetch database from GitHub: $_"
                return @{
                }
            }
            
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
            if ($groupedScripts.Count -gt 0) {
                return $groupedScripts
            }
            else {
                Write-Warning "No valid scripts found in profile at '$Path'."
                return @{
                }
            }
        }
    }
    else {
        Write-Warning "Selected file '$Path' does not exist."
        return @{
        }
    }
}

$ProfileDropdownProps = @{
    Add_SelectedIndexChanged = {
        # Update the script-scoped variable with current selection
        $script:CurrentProfileIndex = $ProfileDropdown.SelectedIndex
        
        $selectedProfile = $ProfileDropdown.SelectedItem
        $selectedProfilePath = Join-Path -Path $script:ProfilesDirectory -ChildPath "$selectedProfile.txt"
        $scriptsDict = Read-Profile -Path $selectedProfilePath
        if ($scriptsDict.Count -gt 0) {
            # Create or update the ListView with grouped scripts
            CreateGroupedListView -parentPanel $ScriptsPanel -groupedScripts $scriptsDict
        }
    }
    Dock                     = 'Left'
    DropDownStyle            = 'DropDownList'
    Font                     = $script:UI.Fonts.Default
    ForeColor                = $script:UI.Colors.Text
    Height                   = $script:UI.Sizes.Input.Height
    Margin                   = '10,10,10,10'  # Consistent margin all around for footer items
    # Width                    = $script:UI.Sizes.Input.FooterWidth
}

# ------------------------------
# Enhanced RUN Button Functions
# ------------------------------
function Get-CommandRiskLevel {
    param([string]$command)
    
    foreach ($pattern in $script:Config.HighRiskPatterns) {
        if ($command -match $pattern) { return "HIGH" }
    }
    
    foreach ($pattern in $script:Config.MediumRiskPatterns) {
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
function Test-RequiresAdminPrivileges {
    param([string]$command)
    
    foreach ($pattern in $script:Config.AdminRequiredPatterns) {
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
        $requiresAdmin = Test-RequiresAdminPrivileges -command $command
        
        $commandsText += "# $($item.Text)`n"
        $commandsText += "# Risk: $risk | Time: $timeEst | Admin Required: $requiresAdmin`n"
        $commandsText += "$command`n`n"
    }

    [System.Windows.Forms.Clipboard]::SetText($commandsText)
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
# Functions
# ------------------------------
# Function to move ListView items
function Move-ListViewItem {
    param(
        [System.Windows.Forms.ListView]$ListView,
        [System.Windows.Forms.ListViewItem]$Item,
        [int]$TargetIndex
    )
    
    # Get the current index before removing
    $currentIndex = $Item.Index
    
    # Don't move if dropping on the same position
    if ($currentIndex -eq $TargetIndex -or ($currentIndex + 1) -eq $TargetIndex) {
        return
    }
    
    # Adjust target index if moving item down
    if ($TargetIndex > $currentIndex) {
        $TargetIndex--
    }
    
    # Store item properties
    $itemText = $Item.Text
    $subItems = @()
    foreach ($subItem in $Item.SubItems) {
        $subItems += $subItem.Text
    }
    $itemChecked = $Item.Checked
    $itemBackColor = $Item.BackColor
    $itemForeColor = $Item.ForeColor
    $itemFont = $Item.Font
    $itemGroup = $Item.Group
    
    # Remove item from current position
    $ListView.Items.Remove($Item)
    
    # Create new item with same properties
    $newItem = New-Object System.Windows.Forms.ListViewItem($itemText)
    for ($i = 1; $i -lt $subItems.Count; $i++) {
        $newItem.SubItems.Add($subItems[$i]) | Out-Null
    }
    $newItem.Checked = $itemChecked
    $newItem.BackColor = $itemBackColor
    $newItem.ForeColor = $itemForeColor
    $newItem.Font = $itemFont
    $newItem.Group = $itemGroup
    
    # Insert at new position
    if ($TargetIndex -ge $ListView.Items.Count) {
        $ListView.Items.Add($newItem) | Out-Null
    }
    else {
        $ListView.Items.Insert($TargetIndex, $newItem) | Out-Null
    }
    
    # Select the moved item
    $newItem.Selected = $true
    $ListView.Focus()
}

# Function to move selected item up
function Move-SelectedItemUp {
    param([System.Windows.Forms.ListView]$ListView)
    
    if ($ListView.SelectedItems.Count -eq 0) { return }
    
    $selectedItem = $ListView.SelectedItems[0]
    $currentIndex = $selectedItem.Index
    
    if ($currentIndex -gt 0) {
        Move-ListViewItem -ListView $ListView -Item $selectedItem -TargetIndex ($currentIndex - 1)
    }
}

# Function to move selected item down
function Move-SelectedItemDown {
    param([System.Windows.Forms.ListView]$ListView)
    
    if ($ListView.SelectedItems.Count -eq 0) { return }
    
    $selectedItem = $ListView.SelectedItems[0]
    $currentIndex = $selectedItem.Index
    
    if ($currentIndex -lt $ListView.Items.Count - 1) {
        Move-ListViewItem -ListView $ListView -Item $selectedItem -TargetIndex ($currentIndex + 2)
    }
}

# Function to create a single ListView with groups
function CreateGroupedListView {
    param (
        $parentPanel,
        [System.Collections.Specialized.OrderedDictionary]$groupedScripts
    )
    
    # Clear existing controls
    $parentPanel.Controls.Clear()
    
    # Create container panel for ListView and buttons
    $ContainerPanel = New-Object System.Windows.Forms.Panel -Property @{
        Dock = 'Fill'
    }
    
    # Create the main ListView with basic properties
    $LV = New-Object System.Windows.Forms.ListView -Property $ListViewProps
    # Add columns
    $LV.Columns.Add("SCRIPT", $script:UI.Sizes.Columns.Name) | Out-Null
    $LV.Columns.Add("TIME", $script:UI.Sizes.Columns.Time) | Out-Null
    $LV.Columns.Add("COMMAND", $script:UI.Sizes.Columns.Command) | Out-Null
    $LV.Columns.Add("PERMISSION", $script:UI.Sizes.Columns.Permission) | Out-Null

    # Create and add groups, then add items to each group
    foreach ($groupName in $groupedScripts.Keys) {
        # do not create groups is there is just one group
        if ($groupedScripts.Count -gt 1) {
            # Create ListView group
            $group = New-Object System.Windows.Forms.ListViewGroup($groupName, $groupName)
            $LV.Groups.Add($group) | Out-Null
        }
        # Add items to this group
        foreach ($script in $groupedScripts[$groupName]) {
            $listItem = New-Object System.Windows.Forms.ListViewItem($script.content)

            # Get time estimate and risk assessment
            $timeEst = Get-EstimatedExecutionTime -command $script.command
            $risk = Get-CommandRiskLevel -command $script.command
            $requiresAdmin = Test-RequiresAdminPrivileges -command $script.command
            
            $listItem.SubItems.Add($timeEst)
            $listItem.SubItems.Add($script.command)
            $privilege = if ($requiresAdmin) { "Admin" } else { "User" }
            $listItem.SubItems.Add($privilege)
            
            # Color code by risk level
            switch ($risk) {
                "HIGH" { $listItem.BackColor = [System.Drawing.Color]::FromArgb(255, 230, 230) }
                "MEDIUM" { $listItem.BackColor = [System.Drawing.Color]::FromArgb(255, 245, 230) }
                "LOW" { $listItem.BackColor = [System.Drawing.Color]::FromArgb(230, 255, 230) }
            }
            
            # Bold font for admin-required commands
            if ($requiresAdmin) {
                $listItem.ForeColor = [System.Drawing.Color]::Red
            }
            
            # Assign item to the group only if there are more than 1 groups
            if ($LV.Groups.Count -gt 1) {
                $listItem.Group = $group
            }
            else {
                # If there's only one group, we don't need to set the group
                $listItem.Group = $null
            }
            # Add item to ListView
            $LV.Items.Add($listItem) | Out-Null
        }
    }
    
    # Store the ListView in script scope
    $script:ListViews.Clear()
    $script:ListViews["MainList"] = $LV
    
    # Add ListView and button panel to container
    $ContainerPanel.Controls.Add($LV)

    # Add container to the parent panel
    $parentPanel.Controls.Add($ContainerPanel)
}

function RunSelectedItems {
    param(
        [bool]$RetryMode = $false
    )
    
    # Always create a new log file for each execution
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logFileName = "GrayWinUtil_Execution_$timestamp.log"
    $script:CurrentLogFile = Join-Path -Path $script:LogsDirectory -ChildPath $logFileName
    
    # Initialize log file with standard format
    $startTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    Add-Content -Path $script:CurrentLogFile -Value "$startTime INFO Gray WinUtil execution started"
    
    # Disable the invoke button while running
    $InvokeButton.Enabled = $false
    $InvokeButton.Text = "Running..."

    # Hide buttons and update status during execution
    if ($script:StatusLabel) { $script:StatusLabel.Text = "Initializing execution..." }
    if ($script:ActionButton) { $script:ActionButton.Visible = $false }
    if ($script:RetryButton) { $script:RetryButton.Visible = $false }

    # Create and add progress bar to spacer panel (now inside button panel)
    $ProgressBar = New-Object System.Windows.Forms.ProgressBar -Property @{
        Dock      = 'Fill'
        Style     = 'Continuous'
        Minimum   = 0
        Maximum   = 100
        Value     = 0
        ForeColor = $script:UI.Colors.Accent
    }
    $script:SpacerPanel.Controls.Add($ProgressBar)

    try {
        # Get selected items
        $selectedItems = @()
        if ($RetryMode -and $script:RetryItems) {
            $selectedItems = $script:RetryItems
            # Reset the items for execution
            foreach ($item in $selectedItems) {
                $item.BackColor = [System.Drawing.Color]::FromArgb(220, 240, 255)  # Light blue for queued
                $item.ForeColor = [System.Drawing.Color]::FromArgb(0, 70, 130)     # Dark blue text
                $item.SubItems[1].Text = "Queued"
            }
        }
        else {
            foreach ($listView in $script:ListViews.Values) {
                $selectedItems += $listView.Items | Where-Object { $_.Checked }
            }
        }

        if ($selectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No items selected.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        # Set progress bar maximum to number of selected items
        $ProgressBar.Maximum = $selectedItems.Count

        # Show initial progress in button panel
        if ($script:StatusLabel) {
            $script:StatusLabel.Text = "Initializing execution..."
            $script:StatusLabel.Visible = $true
        }

        # Prepare ListView for execution mode - keep checkboxes and all items visible
        foreach ($listView in $script:ListViews.Values) {
            # Keep checkboxes enabled during execution
            # $listView.CheckBoxes = $true  # Keep checkboxes visible
            
            # Style all items based on selection status
            foreach ($item in $listView.Items) {
                if ($selectedItems -contains $item) {
                    # Selected items - bright and ready for execution
                    $item.BackColor = [System.Drawing.Color]::FromArgb(220, 240, 255)  # Light blue background
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(0, 70, 130)     # Dark blue text
                    $item.Font = $script:UI.Fonts.Bold                                 # Bold font
                    $item.SubItems[1].Text = "Queued"                                  # Show as queued
                }
                else {
                    # Non-selected items - muted but visible
                    $item.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 250)  # Very light gray
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)  # Muted gray text
                    $item.Font = $script:UI.Fonts.Default                              # Normal font
                    # Keep original time text for non-selected items
                }
            }
        }
        
        # Track execution statistics
        $completedCount = 0
        $failedCount = 0
        $cancelledCount = 0
        
        # Process each selected item
        for ($i = 0; $i -lt $selectedItems.Count; $i++) {
            $item = $selectedItems[$i]
            $command = $item.SubItems[2].Text
            $name = $item.Text

            # Log the current item being executed in standard format
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            Add-Content -Path $script:CurrentLogFile -Value "$timestamp INFO Starting execution of '$name' - Command: $command"

            # Update progress bar
            $ProgressBar.Value = $i + 1
            
            # Update progress message in button panel
            if ($script:StatusLabel) {
                $progressText = "Executing ($($i + 1)/$($selectedItems.Count)): $name"
                $script:StatusLabel.Text = $progressText
            }
            
            [System.Windows.Forms.Application]::DoEvents()

            # Highlight currently executing item
            $item.BackColor = [System.Drawing.Color]::Yellow
            $item.ForeColor = [System.Drawing.Color]::Black
            $item.Font = $script:UI.Fonts.Bold
            $item.SubItems[1].Text = "Running..."  # Update TIME column during execution
            [System.Windows.Forms.Application]::DoEvents()
            
            # Start timing the execution
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $executionFailed = $false
            $executionCancelled = $false
            $executionOutput = ""
            
            try {
                # Capture output and errors for better detection
                $output = $null
                $errorOutput = $null
                
                # Execute the command and capture output
                if ($command -match 'winget') {
                    # For winget commands, capture both output and check exit code
                    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                    $processInfo.FileName = "powershell.exe"
                    $processInfo.Arguments = "-Command `"$command`"" 
                    $processInfo.RedirectStandardOutput = $true
                    $processInfo.RedirectStandardError = $true
                    $processInfo.UseShellExecute = $false
                    $processInfo.CreateNoWindow = $true
                    
                    $process = [System.Diagnostics.Process]::Start($processInfo)
                    $output = $process.StandardOutput.ReadToEnd()
                    $errorOutput = $process.StandardError.ReadToEnd()
                    $process.WaitForExit()
                    $exitCode = $process.ExitCode
                    
                    # Store execution output for display
                    $executionOutput = if ($output) { $output.Trim() } else { $errorOutput.Trim() }
                    
                    # Check for cancellation indicators first
                    if ($errorOutput -match "cancelled|canceled|aborted|user.*declined|operation.*cancelled" -or
                        $output -match "cancelled|canceled|aborted|user.*declined|operation.*cancelled") {
                        $executionCancelled = $true
                    }
                    # Then check for other failure indicators
                    elseif ($exitCode -ne 0 -or 
                        $errorOutput -match "access.*denied|permission.*denied|requires.*administrator|elevation.*required" -or
                        $output -match "failed|error|denied") {
                        $executionFailed = $true
                    }
                }
                else {
                    # For other commands, use regular execution but with error stream capture
                    $ErrorActionPreference = 'Stop'
                    $output = Invoke-Expression $command 2>&1
                    
                    # Store execution output for display
                    $executionOutput = if ($output) { $output.ToString().Trim() } else { "No output" }
                    
                    # Check for cancellation indicators first
                    if ($output -match "cancelled|canceled|aborted|user.*declined|operation.*cancelled") {
                        $executionCancelled = $true
                    }
                    # Then check for other error indicators
                    elseif ($output -match "access.*denied|permission.*denied|requires.*administrator|elevation.*required|failed|error") {
                        $executionFailed = $true
                    }
                }
                
                # Stop timing and calculate execution time
                $stopwatch.Stop()
                $ms = $stopwatch.ElapsedMilliseconds
                $executionTime = if ($ms -gt 1000) { "{0:N2} s" -f ($ms / 1000) } else { "$($ms) ms" }
                
                # Log execution result in standard format
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                if ($executionCancelled) {
                    Add-Content -Path $script:CurrentLogFile -Value "$timestamp WARN Execution cancelled for '$name' - Time: $executionTime - Output: $executionOutput"
                }
                elseif ($executionFailed) {
                    Add-Content -Path $script:CurrentLogFile -Value "$timestamp ERROR Execution failed for '$name' - Time: $executionTime - Output: $executionOutput"
                }
                else {
                    Add-Content -Path $script:CurrentLogFile -Value "$timestamp INFO Execution completed for '$name' - Time: $executionTime - Output: $executionOutput"
                }
                
                # Update button panel with execution result
                if ($executionCancelled) {
                    # Mark as cancelled (orange/amber)
                    $item.BackColor = [System.Drawing.Color]::FromArgb(255, 235, 200)
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(205, 133, 0)
                    $item.Font = $script:UI.Fonts.Default
                    $item.SubItems[1].Text = "$($executionTime) (Cancelled)"
                    $cancelledCount++
                    
                    # Update status in button panel
                    if ($script:StatusLabel) {
                        $script:StatusLabel.Text = "Cancelled ($($i + 1)/$($selectedItems.Count)): $name"
                    }
                }
                elseif ($executionFailed) {
                    # Mark as failed even if no exception was thrown
                    $item.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 200)
                    $item.ForeColor = [System.Drawing.Color]::Red
                    $item.Font = $script:UI.Fonts.Default
                    $item.SubItems[1].Text = "$($executionTime) (Failed)"
                    $failedCount++
                    
                    # Update status in button panel
                    if ($script:StatusLabel) {
                        $script:StatusLabel.Text = "Failed ($($i + 1)/$($selectedItems.Count)): $name"
                    }
                }
                else {
                    # Mark as completed (green) and show actual execution time
                    $item.BackColor = [System.Drawing.Color]::FromArgb(200, 255, 200)
                    $item.ForeColor = [System.Drawing.Color]::DarkGreen
                    $item.Font = $script:UI.Fonts.Default
                    $item.SubItems[1].Text = "$($executionTime) (Completed)"
                    $completedCount++
                    
                    # Update status in button panel
                    if ($script:StatusLabel) {
                        $script:StatusLabel.Text = "Completed ($($i + 1)/$($selectedItems.Count)): $name"
                    }
                }
            }
            catch {
                # Stop timing even on error
                $stopwatch.Stop()
                $ms = $stopwatch.ElapsedMilliseconds
                $executionTime = if ($ms -gt 1000) { "{0:N2} s" -f ($ms / 1000) } else { "$($ms) ms" }

                # Store exception message
                $executionOutput = $_.Exception.Message
                
                # Log exception in standard format
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                if ($_.Exception.Message -match "cancelled|canceled|aborted|user.*declined|operation.*cancelled") {
                    Add-Content -Path $script:CurrentLogFile -Value "$timestamp WARN Execution cancelled with exception for '$name' - Time: $executionTime - Error: $executionOutput"
                }
                else {
                    Add-Content -Path $script:CurrentLogFile -Value "$timestamp ERROR Execution failed with exception for '$name' - Time: $executionTime - Error: $executionOutput"
                }
                
                # Check if exception message indicates cancellation
                if ($_.Exception.Message -match "cancelled|canceled|aborted|user.*declined|operation.*cancelled") {
                    # Mark as cancelled (orange/amber)
                    $item.BackColor = [System.Drawing.Color]::FromArgb(255, 235, 200)
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(205, 133, 0)
                    $item.Font = $script:UI.Fonts.Default
                    $item.SubItems[1].Text = "$($executionTime) (Cancelled)"
                    $cancelledCount++
                    
                    # Update status in button panel
                    if ($script:StatusLabel) {
                        $script:StatusLabel.Text = "Cancelled ($($i + 1)/$($selectedItems.Count)): $name"
                    }
                }
                else {
                    # Mark as failed (red) and show execution time up to failure
                    $item.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 200)
                    $item.ForeColor = [System.Drawing.Color]::Red
                    $item.Font = $script:UI.Fonts.Default
                    $item.SubItems[1].Text = "$($executionTime) (Failed)"
                    $failedCount++
                    
                    # Update status in button panel
                    if ($script:StatusLabel) {
                        $script:StatusLabel.Text = "Failed ($($i + 1)/$($selectedItems.Count)): $name"
                    }
                }
                
                # Continue with next command without asking user
            }
            
            # Brief pause between commands for UI updates
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 1000  # Increased to 1 second to better see the status updates
        }
        
        # Write execution summary to log in standard format
        $endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $totalItems = $selectedItems.Count
        Add-Content -Path $script:CurrentLogFile -Value "$endTime INFO Execution completed - Total: $totalItems, Completed: $completedCount, Failed: $failedCount, Cancelled: $cancelledCount"
        
        # Show final completion message in button panel
        if ($script:StatusLabel -and $script:ActionButton) {
            $totalItems = $selectedItems.Count
            $statusText = "Execution completed: $completedCount succeeded"
            if ($failedCount -gt 0) { $statusText += ", $failedCount failed" }
            if ($cancelledCount -gt 0) { $statusText += ", $cancelledCount cancelled" }
            $statusText += " (Total: $totalItems)"
            
            $script:StatusLabel.Text = $statusText
            $script:StatusLabel.Visible = $true
            $script:ActionButton.Visible = $true

            # Show retry button only if there were failures or cancellations
            if (($failedCount -gt 0 -or $cancelledCount -gt 0) -and $script:RetryButton) {
                $script:RetryButton.Visible = $true
            }
        }
    }
    finally {
        # Do NOT remove progress bar - keep it visible
        # $script:SpacerPanel.Controls.Remove($ProgressBar)
        # $ProgressBar.Dispose()
        
        # Re-enable the invoke button and reset controls
        $InvokeButton.Enabled = $ConsentCheckbox.Checked
        $InvokeButton.Text = "▶ Run"
        $SelectAllSwitch.Checked = $false
        $SelectAllSwitch.Tag = $false
        
        # Reset status label to default message if execution finished
        if ($script:StatusLabel -and -not $script:ActionButton.Visible) {
            $script:StatusLabel.Text = "Ready! Welcome to Gray WInUtil App. Select and run scripts from below."
        }
    }
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
# Remove SpacerPanel from main form - it's now created inside CreateGroupedListView

$ContentPanel = New-Object Windows.Forms.Panel -Property $ContentPanelProps
$FooterPanel = New-Object Windows.Forms.Panel -Property $FooterPanelProps

$SelectAllSwitch = New-Object System.Windows.Forms.CheckBox -Property $SelectAllSwitchProps
$SearchBox = New-Object System.Windows.Forms.TextBox -Property $SearchBoxProps
$ConsentCheckbox = New-Object System.Windows.Forms.CheckBox -Property $ConsentCheckboxProps
$InvokeButton = New-Object System.Windows.Forms.Button -Property $InvokeButtonProps

$ProfileDropDown = New-Object System.Windows.Forms.ComboBox -Property $ProfileDropdownProps

# Create padding spacer between search area and consent checkbox
$PaddingSpacerPanel = New-Object System.Windows.Forms.Panel -Property @{
    Dock  = 'Right'
    Width = 10  # Reduced from 15 to 10 for better alignment
}

$HelpLabel = New-Object System.Windows.Forms.Label -Property @{
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
            Add_FormClosed = { $script:HelpForm = $null }  # Clear reference when closed
            Add_Shown      = { $script:HelpForm.Activate() }
            BackColor      = $script:UI.Colors.Background
            Font           = $script:UI.Fonts.Default
            MaximizeBox    = $false
            MinimizeBox    = $false
            Padding        = $script:UI.Padding.Help
            Size           = New-Object System.Drawing.Size(350, 350)
            StartPosition  = "CenterParent"
            Text           = "HELP - Gray WinUtil"
        }         
        $HelpPanel = New-Object System.Windows.Forms.Panel -Property @{
            Dock       = 'Fill'
            AutoScroll = $true
        }
        
        $yPosition = 10
        
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
            Add_FormClosed = { $script:UpdatesForm = $null }  # Clear reference when closed
            Add_Shown      = { $script:UpdatesForm.Activate() }
            BackColor      = $script:UI.Colors.Background
            Font           = $script:UI.Fonts.Default
            MaximizeBox    = $false
            MinimizeBox    = $false
            Padding        = $script:UI.Padding.Help
            Size           = New-Object System.Drawing.Size(350, 350)
            StartPosition  = "CenterParent"
            Text           = "Updates - Gray WinUtil"
        }        

        # Main panel to hold ListView
        $UpdatesPanel = New-Object System.Windows.Forms.Panel -Property @{
            Dock    = 'Fill'
            Padding = $script:UI.Padding.Updates
        }        
        # Updates ListView with Details view (no checkboxes)
        $UpdatesListView = New-Object System.Windows.Forms.ListView -Property @{
            BackColor        = $script:UI.Colors.Background
            BorderStyle      = 'None'
            CheckBoxes       = $false
            Dock             = 'Fill'
            Font             = $script:UI.Fonts.Default
            ForeColor        = $script:UI.Colors.Text
            FullRowSelect    = $true
            MultiSelect      = $false
            ShowItemToolTips = $true
            View             = 'Details'
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
                    $listItem.ForeColor = [System.Drawing.Color]::FromArgb(230, 126, 34) # Orange
                    $listItem.ToolTipText = "To be updated"                
                }
                else {
                    # Download candidate - not locally available
                    $listItem.SubItems.Add("⏬")
                    $listItem.SubItems.Add($sizeText)
                    $listItem.ForeColor = [System.Drawing.Color]::FromArgb(76, 175, 80) # Green
                    $listItem.ToolTipText = "To be downloaded"
                }
                
                $UpdatesListView.Items.Add($listItem) | Out-Null
            }
        }        # Add a button to download selected files into the user's personal scripts folder
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
                [System.Windows.Forms.MessageBox]::Show("Download functionality coming soon!", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
        }
        $UpdatesPanel.Controls.Add($UpdatesListView)
        $UpdatesPanel.Controls.Add($DownloadButton)
        $script:UpdatesForm.Controls.Add($UpdatesPanel)
        
        $script:UpdatesForm.Show()  # Use Show() instead of ShowDialog() for non-blocking
    }
}

# Create button panel for reorder controls and completion messages
$script:StatusPanel = New-Object System.Windows.Forms.Panel -Property @{
    Dock   = 'Top'
    Font   = $script:UI.Fonts.Small
    Height = $script:UI.Sizes.Status.Height
}
$script:ToolBarPanel = New-Object System.Windows.Forms.Panel -Property @{
    # BorderStyle = 'FixedSingle'
    Dock    = 'Top'
    Font    = $script:UI.Fonts.Default
    Height  = $script:UI.Sizes.ToolBar.Height
    Padding = $script:UI.Padding.ToolBar
}
$script:ScriptsPanel = New-Object System.Windows.Forms.Panel -Property @{
    Dock    = 'Fill'
    Padding = '0,0,0,0'  # Consistent padding all around for scripts area
}
    
# Create spacer panel and dock to top of button panel
$script:SpacerPanel = New-Object System.Windows.Forms.Panel -Property $SpacerPanelProps
$script:StatusPanel.Controls.Add($script:SpacerPanel)

# Create status panel to hold the status label and buttons
$script:StatusContentPanel = New-Object System.Windows.Forms.Panel -Property @{
    Dock   = 'Fill'  # Fill remaining space in button panel
    Height = 25
}

# Create single status label for all messages
$script:StatusLabel = New-Object System.Windows.Forms.Label -Property @{
    AutoSize = $true
    Dock     = 'Left'
    Padding  = $script:UI.Padding.Status
    Text     = "Ready! Welcome to Gray WinUtil App. Select and run  scripts from below."
    Visible  = $true
}

# Create action button (hidden by default)
$script:ActionButton = New-Object System.Windows.Forms.Button -Property @{
    Add_Click = {
        # Open the most recent log file
        if ($script:CurrentLogFile -and (Test-Path $script:CurrentLogFile)) {
            try {
                Start-Process -FilePath "notepad.exe" -ArgumentList $script:CurrentLogFile
            }
            catch {
                # Fallback to default text editor
                Start-Process -FilePath $script:CurrentLogFile
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("No log file found.", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    Dock      = 'Right'
    FlatStyle = 'Flat'
    Font      = $script:UI.Fonts.Small
    Height    = 22
    Text      = "≡ Logs"
    Visible   = $false
    Width     = 70
}

# Create retry button (hidden by default)
$script:RetryButton = New-Object System.Windows.Forms.Button -Property @{
    Add_Click = {
        # Store the failed/cancelled items to retry
        $script:RetryItems = @()
        foreach ($listView in $script:ListViews.Values) {
            foreach ($item in $listView.Items) {
                if ($item.SubItems[1].Text -match "(Failed|Cancelled)") {
                    $script:RetryItems += $item
                }
            }
        }
            
        # If we have items to retry, run them
        if ($script:RetryItems.Count -gt 0) {
            RunSelectedItems -RetryMode $true
        }
    }
    Dock      = 'Right'
    FlatStyle = 'Flat'
    Font      = $script:UI.Fonts.Small
    Height    = 22
    Text      = "↻ Retry"
    Visible   = $false
    Width     = 70
}
    
# Remove button border
$script:ActionButton.FlatAppearance.BorderSize = 0
    
# Remove retry button border
$script:RetryButton.FlatAppearance.BorderSize = 0

# Add controls to status panel first
$script:StatusContentPanel.Controls.AddRange(@($script:StatusLabel, $script:RetryButton, $script:ActionButton))
    
# Add spacer panel first (top), then status panel (fill) to button panel
$script:StatusPanel.Controls.AddRange(@($script:SpacerPanel, $script:StatusContentPanel))
$p10left = New-Object System.Windows.Forms.Panel -Property @{
    Dock  = 'Left'
    Width = 2  # Reduced from 15 to 10 for better alignment
}
$script:ToolBarPanel.Controls.AddRange(@($SearchBox, $p10left, $ProfileDropdown, $SelectAllSwitch, $PaddingSpacerPanel, $InvokeButton, $ConsentCheckbox))

# $HeaderPanel.Controls.AddRange(@($script:StatusPanel))
$ContentPanel.Controls.Add($script:ScriptsPanel)
$ContentPanel.Controls.Add($script:ToolBarPanel)

$FooterPanel.Controls.AddRange(@($script:StatusPanel))
# Remove SpacerPanel from main form controls
$Form.Controls.AddRange(@($HeaderPanel, $FooterPanel, $ContentPanel))

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

    # Fetch from GitHub instead of looking for local db.json
    try {
        $dbData = Invoke-WebRequest $script:Config.DatabaseUrl | ConvertFrom-Json
        $allIds = @()
        
        # Extract all IDs from the database
        $dbData | ForEach-Object {
            if ($_.id) {
                $allIds += $_.id
            }
        }
        
        if ($allIds.Count -gt 0) {
            $allIds | Set-Content -Path $defaultProfile -Force
            Write-Host "Created default profile with $($allIds.Count) scripts from GitHub database"
        }
    }
    catch {
        Write-Warning "Failed to create default profile from GitHub database: $_"
        # Create an empty default profile as fallback
        "# Default Profile" | Set-Content -Path $defaultProfile -Force
    }
}

# Start application
[void]$Form.ShowDialog()