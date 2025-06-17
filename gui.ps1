<#
This script is a PowerShell GUI application for managing and executing scripts from a GitHub repository.
Features:
- TODO Submit new collections and scripts to repository
- BUG only the first group, its actual name is being overridden by default
- FIXME Write commands to PowerShell history
- FIXME Improve execution UI performance - sluttering
- FIXME Instead of showing status inside time, show it as a separate column
- FIXME Fix Move List item down.
- TODO Enable command scheduling
- TODO Add native system notifications
- TODO Show hotkey tooltips in help
- TODO Maintain script execution order
- TODO Use %Temp% directory by default
- TODO Allow custom storage location (Documents/Winutil/Owner/Repo/Profiles)
- TODO Create Start Menu and Desktop shortcuts
- TODO Add context menu - reload scripts, move items up and down, Copy col1, col2..to clipboard, export selected commands to Clipboard
- TODO Add cancel action item to the status actions
- TODO Add the column sort on click of a column, update column header with these alt code chars ⬇, ⬆,↑↓, ↑↑, ↓↓
- TODO Read SSh Config, list remote machines execute on them.
#>
$script:Config = @{
    ApiUrl       = $null  
    DatabaseFile = "db.json"           
    DatabaseUrl  = $null  
    GitHubBranch = "main"              
    GitHubOwner  = "mrdotkg"           
    GitHubRepo   = "dotfiles"          
    ScriptsPath  = "$HOME\Documents\WinUtil Local Data"  
}

Add-Type -AssemblyName System.Drawing, System.Windows.Forms

$script:Config.DatabaseUrl = "https://raw.githubusercontent.com/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/refs/heads/$($script:Config.GitHubBranch)/$($script:Config.DatabaseFile)"
$script:Config.ApiUrl = "https://api.github.com/repos/$($script:Config.GitHubOwner)/$($script:Config.GitHubRepo)/contents"

$script:DataDirectory = "$HOME\Documents\WinUtil Local Data"
$script:ProfilesDirectory = "$HOME\Documents\WinUtil Local Data\Profiles"
$script:LogsDirectory = "$HOME\Documents\WinUtil Local Data\Logs"
$script:ListViews = @{}
$script:CurrentProfileIndex = -1  

$script:HelpForm = $null
$script:UpdatesForm = $null

$script:UI = @{
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
        Content = "0,0,0,35"        
        Control = '2,2,2,2'         
        Footer  = '0,0,0,0'     
        Form    = '5,0,5,0'         
        Header  = '0,0,0,0'         
        Help    = '15,15,15,15'     
        Panel   = '0,0,0,0'         
        Status  = '0,5,0,5'       
        ToolBar = '5,5,0,5'       
        Updates = '15,15,15,15'     
    }
    Sizes   = @{
        Columns = @{
            Command = 200
            Name    = -2
        }
        Footer  = @{
            Height = 30
        }
        Header  = @{

        }
        Input   = @{
            FooterWidth = 150
            Height      = 25
            Width       = 80
        }
        Status  = @{
            Height = 30
        }
        ToolBar = @{
            Height = 35
        }
        Window  = @{
            Height = 550
            Width  = 850
        }
    }
}

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

$FormProps = @{
    Add_KeyDown = {
        if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::A) {

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

            if ($script:CreatedButtons['RunButton'].Enabled) {
                $script:CreatedButtons['RunButton'].PerformClick()
            }
            $_.Handled = $true
        }
        elseif ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::C) {

            Copy-SelectedCommandsToClipboard
            $_.Handled = $true
        }
        elseif ($_.Control -and ($_.KeyCode -eq [System.Windows.Forms.Keys]::Up -or $_.KeyCode -eq [System.Windows.Forms.Keys]::K)) {

            $listView = $script:ListViews["MainList"]
            if ($listView) {
                Move-SelectedItemUp -ListView $listView
            }
            $_.Handled = $true
        }
        elseif ($_.Control -and ($_.KeyCode -eq [System.Windows.Forms.Keys]::Down -or $_.KeyCode -eq [System.Windows.Forms.Keys]::J)) {

            $listView = $script:ListViews["MainList"]
            if ($listView) {
                Move-SelectedItemDown -ListView $listView
            }
            $_.Handled = $true
        }
        elseif ($_.KeyCode -eq [System.Windows.Forms.Keys]::H) {

            $listView = $script:ListViews["MainList"]
            if ($listView) {
                Move-SelectedItemUp -ListView $listView
            }
            $_.Handled = $true
        }
        elseif ($_.KeyCode -eq [System.Windows.Forms.Keys]::L) {

            $listView = $script:ListViews["MainList"]
            if ($listView) {
                Move-SelectedItemDown -ListView $listView
            }
            $_.Handled = $true
        }
    }
    Add_Shown   = { 
        $Form.Activate()

        Get-ChildItem -Path $script:ProfilesDirectory -Filter "*.txt" | ForEach-Object {
            $ProfileDropdown.Items.Add($_.BaseName) | Out-Null
        }

        if ($ProfileDropdown.Items.Count -gt 0) {
            $ProfileDropdown.SelectedIndex = 0
            $script:CurrentProfileIndex = 0  
        }
    }
    BackColor   = $script:UI.Colors.Background
    Font        = $script:UI.Fonts.Default
    Height      = $script:UI.Sizes.Window.Height
    KeyPreview  = $true
    Padding     = $script:UI.Padding.Form
    Text        = "WINUTIL-$($script:Config.GitHubOwner.toUpper()) / $($script:Config.GitHubRepo.toUpper())"
    Width       = $script:UI.Sizes.Window.Width
}

$HeaderPanelProps = @{
    BackColor = $script:UI.Colors.Background

    Dock      = 'Top'
    Height    = $script:UI.Sizes.Header.Height
    Padding   = $script:UI.Padding.Header
}

$ContentPanelProps = @{
    BackColor = $script:UI.Colors.Background

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

$ProgressBarPanelProps = @{
    BackColor = $script:UI.Colors.Background
    Dock      = 'Bottom'
    Height    = 5
    Padding   = '0,0,0,0'  
}

$ListViewProps = @{
    Add_DragDrop       = {
        param($sender, $e)
        $draggedItem = $e.Data.GetData([System.Windows.Forms.ListViewItem])
        if ($draggedItem) {
            $targetIndex = $sender.InsertionMark.Index
            if ($targetIndex -ge 0) {

                Write-Host "=== DRAG DROP DEBUG ===" -ForegroundColor Yellow
                Write-Host "Dragged Item: '$($draggedItem.Text)' (Index: $($draggedItem.Index))" -ForegroundColor Cyan
                Write-Host "Target Index: $targetIndex" -ForegroundColor Cyan
                Write-Host "Appears After: $($sender.InsertionMark.AppearsAfterItem)" -ForegroundColor Cyan
                Write-Host "ListView Groups Count: $($sender.Groups.Count)" -ForegroundColor Cyan
                Write-Host "========================" -ForegroundColor Yellow

                Move-ListViewItem -ListView $sender -Item $draggedItem -TargetIndex $targetIndex -AppearsAfter $sender.InsertionMark.AppearsAfterItem
            }
        }

        $sender.InsertionMark.Index = -1
    }
    Add_DragEnter      = {
        if ($_.Data.GetDataPresent([System.Windows.Forms.ListViewItem])) {
            $_.Effect = [System.Windows.Forms.DragDropEffects]::Move
        }
        else {
            $_.Effect = [System.Windows.Forms.DragDropEffects]::None
        }
    }
    Add_DragLeave      = {
        $this.InsertionMark.Index = -1
    }
    Add_DragOver       = {
        param($sender, $e)

        if ($e.Data.GetDataPresent([System.Windows.Forms.ListViewItem])) {
            $e.Effect = [System.Windows.Forms.DragDropEffects]::Move

            $pt = $sender.PointToClient([System.Windows.Forms.Cursor]::Position)
            $targetItem = $sender.GetItemAt($pt.X, $pt.Y)

            if ($targetItem) {
                $targetIndex = $targetItem.Index

                $itemBounds = $targetItem.Bounds
                $midPoint = $itemBounds.Top + ($itemBounds.Height / 2)
                if ($pt.Y -gt $midPoint) {

                    $sender.InsertionMark.Index = $targetIndex
                    $sender.InsertionMark.AppearsAfterItem = $true

                    Write-Host "DragOver: Target '$($targetItem.Text)' (Index: $targetIndex) - INSERT AFTER" -ForegroundColor Green
                }
                else {

                    $sender.InsertionMark.Index = $targetIndex
                    $sender.InsertionMark.AppearsAfterItem = $false

                    Write-Host "DragOver: Target '$($targetItem.Text)' (Index: $targetIndex) - INSERT BEFORE" -ForegroundColor Green
                }
            }
            else {

                if ($sender.Items.Count -eq 0) {

                    $sender.InsertionMark.Index = 0
                    $sender.InsertionMark.AppearsAfterItem = $false
                    Write-Host "DragOver: Empty list - INSERT AT INDEX 0" -ForegroundColor Magenta
                }
                else {

                    $lastItem = $sender.Items[$sender.Items.Count - 1]
                    if ($pt.Y -gt $lastItem.Bounds.Bottom) {

                        $sender.InsertionMark.Index = $sender.Items.Count - 1
                        $sender.InsertionMark.AppearsAfterItem = $true
                        Write-Host "DragOver: END OF LIST - INSERT AFTER LAST ITEM (Index: $($sender.Items.Count - 1))" -ForegroundColor Magenta
                    }
                    else {

                        $sender.InsertionMark.Index = 0
                        $sender.InsertionMark.AppearsAfterItem = $false
                        Write-Host "DragOver: BEGINNING OF LIST - INSERT BEFORE FIRST ITEM" -ForegroundColor Magenta
                    }
                }
            }
        }
        else {
            $e.Effect = [System.Windows.Forms.DragDropEffects]::None
            $sender.InsertionMark.Index = -1
        }
    }
    Add_ItemChecked    = {
        $totalItems = ($script:ListViews.Values | ForEach-Object { $_.Items.Count } | Measure-Object -Sum).Sum
        $anyChecked = ($script:ListViews.Values | ForEach-Object { $_.Items | Where-Object { $_.Checked } } | Measure-Object).Count
        $script:CreatedButtons['RunButton'].Enabled = $ConsentCheckbox.Checked -and ($anyChecked -gt 0)
        $script:CreatedButtons['RunButton'].Text = "▶ Run ($anyChecked)"
        $SelectAllSwitch.Checked = ($anyChecked -eq $totalItems)
        $SelectAllSwitch.ForeColor = if ($SelectAllSwitch.Checked) { [System.Drawing.Color]::FromArgb(0, 95, 184) } else { [System.Drawing.Color]::White }
        $SelectAllSwitch.Tag = ($anyChecked -eq $totalItems)
    }
    Add_ItemDrag       = {
        if ($this.SelectedItems.Count -gt 0) {
            $selectedItem = $this.SelectedItems[0]

            $this.DoDragDrop($selectedItem, [System.Windows.Forms.DragDropEffects]::Move)
        }
    }
    Add_MouseDown      = {

        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $hitTest = $this.HitTest($_.X, $_.Y)
            if ($hitTest.Item -ne $null) {
                $this.SelectedItems.Clear()
                $hitTest.Item.Selected = $true
                $this.Focus()
            }
        }
    }
    AllowColumnReorder = $true
    AllowDrop          = $true   
    CheckBoxes         = $true
    Dock               = 'Fill'
    Font               = $script:UI.Fonts.Default
    Forecolor          = $script:UI.Colors.Text
    FullRowSelect      = $true
    GridLines          = $true
    MultiSelect        = $false  
    ShowItemToolTips   = $true
    Sorting            = [System.Windows.Forms.SortOrder]::None
    View               = 'Details'
}

$SelectAllSwitchProps = @{
    Add_Click  = {
        $isChecked = -not $SelectAllSwitch.Tag
        $SelectAllSwitch.Tag = $isChecked
        $SelectAllSwitch.Forecolor = if ($isChecked) { [System.Drawing.Color]::FromArgb(0, 95, 184) } else { [System.Drawing.Color]::White }
        $listViews = @($script:ListViews.Values)
        foreach ($lv in $listViews) {
            foreach ($item in $lv.Items) {
                $item.Checked = $isChecked
            }
        }
    }
    Appearance = 'Button'
    Dock       = 'Left'

    Tag        = $false
    Text       = "⏹"
    AutoSize   = $false
    BackColor  = $script:UI.Colors.Accent
    Checked    = $false
    FlatStyle  = 'Flat'
    Font       = $script:UI.Fonts.Bold
    ForeColor  = [System.Drawing.Color]::White
    Height     = $script:UI.Sizes.Input.Height
    Width      = $script:UI.Sizes.Input.Width / 2 - 14
}

$SearchBoxContainerProps = @{
    # BackColor = $script:UI.Colors.Accent  # This becomes the "border" color
    Dock    = 'Fill'
    Padding = '5,3,5,5'  # This creates the border width
}

$SearchBoxProps = @{
    Add_Enter       = {
        if ($this.Text -eq "👓 Search ...") {
            $this.Text = ""
            $this.ForeColor = $script:UI.Colors.Text
        }
    }
    Add_Leave       = {
        if ($this.Text.Trim() -eq "") {
            $this.Text = "👓 Search ..."
            $this.ForeColor = $script:UI.Colors.Accent
        }
    }
    Add_TextChanged = {
        $searchText = $this.Text.Trim()
        if ($searchText -eq "👓 Search ...") { return }
        
        $listViews = @($script:ListViews.Values)
        foreach ($lv in $listViews) {
            $lv.BeginUpdate()
            try {
                $allItems = @($lv.Items)                
                foreach ($item in $allItems) {
                    if ($item.Text -like "*$searchText*") {
                        $item.ForeColor = $script:UI.Colors.Text
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
    BorderStyle     = 'None'  # Remove the default border
    Dock            = 'Fill'
    ForeColor       = $script:UI.Colors.Accent
    Height          = $script:UI.Sizes.Input.Height
    Multiline       = $false
    Text            = "👓 Search ..."
    TextAlign       = 'Left'
    Width           = $script:UI.Sizes.Input.FooterWidth
}

$script:ToolbarButtons = @(
    @{
        Name        = "ScheduleButton"
        Text        = "⏰"
        BorderStyle = 'FixedSingle'
        BorderColor = [System.Drawing.Color]::FromArgb(76, 175, 80)   
        BackColor   = [System.Drawing.Color]::FromArgb(76, 175, 80)   
        ForeColor   = [System.Drawing.Color]::White
        Font        = $script:UI.Fonts.Regular
        ToolTip     = "Schedule scripts to run later"
        Enabled     = $true
        Click       = { 

            [System.Windows.Forms.MessageBox]::Show("Scheduling functionality coming soon!", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
        Width       = $script:UI.Sizes.Input.Width / 2 - 8
    }, 

    @{
        Name      = "RunButton"
        Text      = "▶ Run (0)"
        BackColor = [System.Drawing.Color]::Green   
        ForeColor = [System.Drawing.Color]::White
        ToolTip   = "Run selected scripts"
        Enabled   = $false
        Font      = $Script:UI.Fonts.Regular
        Click     = { 
            if ($ConsentCheckbox.Checked) {
                RunSelectedItems -Action Invoke
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Please check the consent checkbox to proceed with execution.", "Consent Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            }
        }
    },
    @{
        Name      = "Reset List"
        Text      = "⸙ Reload"
        BackColor = [System.Drawing.Color]::FromArgb(0, 114, 220)
        ForeColor = [System.Drawing.Color]::White
        ToolTip   = "Toggle admin consent for execution"
        Font      = $Script:UI.Fonts.Regular
        Dock      = "Left"
        Enabled   = $true
        Click     = { 

            $SelectAllSwitch.Checked = -not $SelectAllSwitch.Checked
            $ProfileDropdown.SelectedIndex = $script:CurrentProfileIndex
        }
        Width     = $script:UI.Sizes.Input.Width
    }
)

$ConsentCheckboxProps = @{
    Add_CheckedChanged = {
        $anyChecked = ($script:ListViews.Values | ForEach-Object { $_.Items | Where-Object { $_.Checked } } | Measure-Object).Count
        $script:CreatedButtons['RunButton'].Enabled = $ConsentCheckbox.Checked -and ($anyChecked -gt 0)
    }
    Add_Click          = {
        $isChecked = $ConsentCheckbox.Checked
        $ConsentCheckbox.ForeColor = if ($isChecked) { [System.Drawing.Color]::Red } else { [System.Drawing.Color]::White }
    }
    Add_MouseEnter     = {
        if ($script:StatusLabel) {
            $script:StatusLabel.Text = "Check this box to enable script execution."
        }
    }
    Add_MouseLeave     = {
        if ($script:StatusLabel -and -not $script:ActionButton.Visible) {
            $script:StatusLabel.Text = "Gray Winutil is ready to run scripts."
        }
    }
    Appearance         = 'Button'
    AutoSize           = $false
    BackColor          = $script:UI.Colors.Accent
    Checked            = $false
    Dock               = 'Right'
    FlatStyle          = 'Flat'
    Font               = $script:UI.Fonts.Regular
    ForeColor          = [System.Drawing.Color]::White
    Height             = $script:UI.Sizes.Input.Height
    Padding            = $script:UI.Padding.Control
    Text               = "⛊"
    Width              = $script:UI.Sizes.Input.Width / 2 - 10
}
function Read-Profile {
    param([string]$Path)
    if (Test-Path $Path) {

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

            $groupedScripts = New-Object Collections.Specialized.OrderedDictionary
            $currentGroupName = "Group #1"  

            foreach ($line in $ProfileLines) {
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
        $script:CurrentProfileIndex = $ProfileDropdown.SelectedIndex
        $selectedProfile = $ProfileDropdown.SelectedItem
        $selectedProfilePath = Join-Path -Path $script:ProfilesDirectory -ChildPath "$selectedProfile.txt"
        $scriptsDict = Read-Profile -Path $selectedProfilePath
        if ($scriptsDict.Count -gt 0) {
            CreateGroupedListView -parentPanel $ScriptsPanel -groupedScripts $scriptsDict
        }
    }
    # BackColor                = $script:UI.Colors.Accent  # ✅ This works
    ForeColor                = $script:UI.Colors.Accent        # ✅ This works
    # FlatStyle                = 'Flat'                        # ✅ This works - makes it look more modern
    Dock                     = 'Left'
    DropDownStyle            = 'DropDownList'
    Font                     = $script:UI.Fonts.Default
    Height                   = $script:UI.Sizes.Input.Height
    Width                    = $script:UI.Sizes.Input.FooterWidth
}


function Copy-SelectedCommandsToClipboard {
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
        $command = $item.SubItems[1].Text
        
        $commandsText += "# $($item.Text)`n"
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

function Move-ListViewItem {
    param(
        [System.Windows.Forms.ListView]$ListView,
        [System.Windows.Forms.ListViewItem]$Item,
        [int]$TargetIndex,
        [bool]$AppearsAfter = $false
    )

    $currentIndex = $Item.Index

    $insertIndex = if ($AppearsAfter) { $TargetIndex + 1 } else { $TargetIndex }

    Write-Host "--- MOVE CALCULATION ---" -ForegroundColor Blue
    Write-Host "Current Index: $currentIndex" -ForegroundColor White
    Write-Host "Target Index: $TargetIndex" -ForegroundColor White
    Write-Host "Appears After: $AppearsAfter" -ForegroundColor White
    Write-Host "Calculated Insert Index (before adjustment): $insertIndex" -ForegroundColor White

    if ($currentIndex -eq $insertIndex) {
        Write-Host "MOVE CANCELLED - Same position" -ForegroundColor Red
        return
    }

    $itemData = @{
        Text        = $Item.Text
        SubItems    = @($Item.SubItems | ForEach-Object { $_.Text })
        Checked     = $Item.Checked
        BackColor   = $Item.BackColor
        ForeColor   = $Item.ForeColor
        Font        = $Item.Font
        Group       = $Item.Group
        Tag         = $Item.Tag
        ToolTipText = $Item.ToolTipText
    }

    $ListView.BeginUpdate()
    try {

        $ListView.Items.RemoveAt($currentIndex)
        Write-Host "Item removed from index: $currentIndex" -ForegroundColor White

        if ($insertIndex > $currentIndex) {
            $insertIndex--
            Write-Host "Insert index adjusted to: $insertIndex (removed item was before target)" -ForegroundColor White
        }

        if ($insertIndex > $ListView.Items.Count) {
            $insertIndex = $ListView.Items.Count
            Write-Host "Insert index clamped to list end: $insertIndex" -ForegroundColor White
        }

        Write-Host "Final insert index: $insertIndex" -ForegroundColor Yellow

        $newItem = New-Object System.Windows.Forms.ListViewItem($itemData.Text)
        for ($i = 1; $i -lt $itemData.SubItems.Count; $i++) {
            $newItem.SubItems.Add($itemData.SubItems[$i]) | Out-Null
        }
        $newItem.Checked = $itemData.Checked
        $newItem.BackColor = $itemData.BackColor
        $newItem.ForeColor = $itemData.ForeColor
        $newItem.Font = $itemData.Font
        $newItem.Tag = $itemData.Tag
        $newItem.ToolTipText = $itemData.ToolTipText

        if ($ListView.Groups.Count -gt 0) {
            if ($insertIndex -lt $ListView.Items.Count) {

                $targetItem = $ListView.Items[$insertIndex]
                $newItem.Group = $targetItem.Group
                Write-Host "Group assignment: Using group of item at insert position '$($targetItem.Group.Header)'" -ForegroundColor White
            }
            elseif ($ListView.Items.Count -gt 0) {

                $lastItem = $ListView.Items[$ListView.Items.Count - 1]
                $newItem.Group = $lastItem.Group
                Write-Host "Group assignment: Using group of last item '$($lastItem.Group.Header)'" -ForegroundColor White
            }
            else {

                $newItem.Group = $itemData.Group
                Write-Host "Group assignment: Keeping original group '$($itemData.Group.Header)'" -ForegroundColor White
            }
        }
        else {
            $newItem.Group = $null
            Write-Host "Group assignment: No groups" -ForegroundColor White
        }

        if ($insertIndex -ge $ListView.Items.Count) {
            $ListView.Items.Add($newItem) | Out-Null
            Write-Host "Item added at end of list" -ForegroundColor Green
        }
        else {
            $ListView.Items.Insert($insertIndex, $newItem) | Out-Null
            Write-Host "Item inserted at index: $insertIndex" -ForegroundColor Green
        }

        $ListView.SelectedItems.Clear()
        $newItem.Selected = $true
        $newItem.EnsureVisible()

        Write-Host "MOVE COMPLETED - Item '$($newItem.Text)' moved to index $($newItem.Index)" -ForegroundColor Green
        Write-Host "------------------------" -ForegroundColor Blue
    }
    finally {
        $ListView.EndUpdate()
    }
}

function Move-SelectedItemUp {
    param([System.Windows.Forms.ListView]$ListView)

    if ($ListView.SelectedItems.Count -eq 0) { return }

    $selectedItem = $ListView.SelectedItems[0]
    $currentIndex = $selectedItem.Index

    if ($currentIndex -gt 0) {
        Move-ListViewItem -ListView $ListView -Item $selectedItem -TargetIndex ($currentIndex - 1)
    }
}

function Move-SelectedItemDown {
    param([System.Windows.Forms.ListView]$ListView)

    if ($ListView.SelectedItems.Count -eq 0) { return }

    $selectedItem = $ListView.SelectedItems[0]
    $currentIndex = $selectedItem.Index

    if ($currentIndex -lt $ListView.Items.Count - 1) {
        Move-ListViewItem -ListView $ListView -Item $selectedItem -TargetIndex ($currentIndex + 1) -AppearsAfter $true
    }
}

function CreateGroupedListView {
    param (
        $parentPanel,
        [System.Collections.Specialized.OrderedDictionary]$groupedScripts
    )

    $parentPanel.Controls.Clear()

    $ContainerPanel = New-Object System.Windows.Forms.Panel -Property @{
        Dock = 'Fill'
    }

    $LV = New-Object System.Windows.Forms.ListView -Property $ListViewProps

    $LV.Columns.Add("SCRIPT", $script:UI.Sizes.Columns.Name) | Out-Null
    $LV.Columns.Add("COMMAND", $script:UI.Sizes.Columns.Command) | Out-Null

    foreach ($groupName in $groupedScripts.Keys) {

        if ($groupedScripts.Count -gt 1) {

            $group = New-Object System.Windows.Forms.ListViewGroup($groupName, $groupName)
            $LV.Groups.Add($group) | Out-Null
        }

        foreach ($script in $groupedScripts[$groupName]) {
            $listItem = New-Object System.Windows.Forms.ListViewItem($script.content)
            
            $listItem.SubItems.Add($script.command)
            
            if ($LV.Groups.Count -gt 1) {
                $listItem.Group = $group
            }
            else {
                $listItem.Group = $null
            }

            $LV.Items.Add($listItem) | Out-Null
        }
    }

    $script:ListViews.Clear()
    $script:ListViews["MainList"] = $LV

    $ContainerPanel.Controls.Add($LV)

    $parentPanel.Controls.Add($ContainerPanel)
}
$ProgressBarProps = @{
    Dock      = 'Fill'
    Style     = 'Continuous'
    Minimum   = 0
    Maximum   = 100
    Value     = 0
    ForeColor = $script:UI.Colors.Accent
}
function RunSelectedItems {
    param(
        [bool]$RetryMode = $false
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logFileName = "GrayWinUtil_Execution_$timestamp.log"
    $script:CurrentLogFile = Join-Path -Path $script:LogsDirectory -ChildPath $logFileName

    $startTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    Add-Content -Path $script:CurrentLogFile -Value "$startTime INFO Gray WinUtil execution started"

    $script:CreatedButtons['RunButton'].Enabled = $false
    $script:CreatedButtons['RunButton'].Text = "Running..."

    if ($script:StatusLabel) { $script:StatusLabel.Text = "Initializing execution..." }
    if ($script:ActionButton) { $script:ActionButton.Visible = $false }
    if ($script:RetryButton) { $script:RetryButton.Visible = $false }
    if ($script:CancelButton) { $script:CancelButton.Visible = $true }

    $ProgressBar = New-Object System.Windows.Forms.ProgressBar -Property $ProgressBarPanelProps
    $script:ProgressBarPanel.Controls.Add($ProgressBar)

    try {

        $selectedItems = @()
        if ($RetryMode -and $script:RetryItems) {
            $selectedItems = $script:RetryItems

            foreach ($item in $selectedItems) {
                $item.BackColor = [System.Drawing.Color]::FromArgb(220, 240, 255)  
                $item.ForeColor = [System.Drawing.Color]::FromArgb(0, 70, 130)     
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

        $ProgressBar.Maximum = $selectedItems.Count

        if ($script:StatusLabel) {
            $script:StatusLabel.Text = "Initializing execution..."
            $script:StatusLabel.Visible = $true
        }

        foreach ($listView in $script:ListViews.Values) {

            foreach ($item in $listView.Items) {
                if ($selectedItems -contains $item) {

                    $item.BackColor = [System.Drawing.Color]::FromArgb(220, 240, 255)  
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(0, 70, 130)     
                    $item.Font = $script:UI.Fonts.Bold                                 
                    $item.SubItems[1].Text = "Queued"                                  
                }
                else {

                    $item.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 250)  
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(160, 160, 160)  
                    $item.Font = $script:UI.Fonts.Default                              

                }
            }
        }

        $completedCount = 0
        $failedCount = 0
        $cancelledCount = 0

        for ($i = 0; $i -lt $selectedItems.Count; $i++) {
            $item = $selectedItems[$i]
            $command = $item.SubItems[1].Text
            $name = $item.Text

            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            Add-Content -Path $script:CurrentLogFile -Value "$timestamp INFO Starting execution of '$name' - Command: $command"

            $ProgressBar.Value = $i + 1

            if ($script:StatusLabel) {
                $progressText = "Executing ($($i + 1)/$($selectedItems.Count)): $name"
                $script:StatusLabel.Text = $progressText
            }

            [System.Windows.Forms.Application]::DoEvents()

            $item.BackColor = [System.Drawing.Color]::Yellow
            $item.ForeColor = [System.Drawing.Color]::Black
            $item.Font = $script:UI.Fonts.Bold
            [System.Windows.Forms.Application]::DoEvents()

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $executionFailed = $false
            $executionCancelled = $false
            $executionOutput = ""

            try {

                $output = $null
                $errorOutput = $null

                if ($command -match 'winget') {

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

                    $executionOutput = if ($output) { $output.Trim() } else { $errorOutput.Trim() }

                    if ($errorOutput -match "cancelled|canceled|aborted|user.*declined|operation.*cancelled" -or
                        $output -match "cancelled|canceled|aborted|user.*declined|operation.*cancelled") {
                        $executionCancelled = $true
                    }

                    elseif ($exitCode -ne 0 -or 
                        $errorOutput -match "access.*denied|permission.*denied|requires.*administrator|elevation.*required" -or
                        $output -match "failed|error|denied") {
                        $executionFailed = $true
                    }
                }
                else {

                    $ErrorActionPreference = 'Stop'
                    $output = Invoke-Expression $command 2>&1

                    $executionOutput = if ($output) { $output.ToString().Trim() } else { "No output" }

                    if ($output -match "cancelled|canceled|aborted|user.*declined|operation.*cancelled") {
                        $executionCancelled = $true
                    }

                    elseif ($output -match "access.*denied|permission.*denied|requires.*administrator|elevation.*required|failed|error") {
                        $executionFailed = $true
                    }
                }

                $stopwatch.Stop()
                $ms = $stopwatch.ElapsedMilliseconds
                $executionTime = if ($ms -gt 1000) { "{0:N2} s" -f ($ms / 1000) } else { "$($ms) ms" }

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

                if ($executionCancelled) {

                    $item.BackColor = [System.Drawing.Color]::FromArgb(255, 235, 200)
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(205, 133, 0)
                    $item.Font = $script:UI.Fonts.Default
                    $item.SubItems[1].Text = "$($executionTime) (Cancelled)"
                    $cancelledCount++

                    if ($script:StatusLabel) {
                        $script:StatusLabel.Text = "Cancelled ($($i + 1)/$($selectedItems.Count)): $name"
                    }
                }
                elseif ($executionFailed) {

                    $item.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 200)
                    $item.ForeColor = [System.Drawing.Color]::Red
                    $item.Font = $script:UI.Fonts.Default
                    $item.SubItems[1].Text = "$($executionTime) (Failed)"
                    $failedCount++

                    if ($script:StatusLabel) {
                        $script:StatusLabel.Text = "Failed ($($i + 1)/$($selectedItems.Count)): $name"
                    }
                }
                else {

                    $item.BackColor = [System.Drawing.Color]::FromArgb(200, 255, 200)
                    $item.ForeColor = [System.Drawing.Color]::DarkGreen
                    $item.Font = $script:UI.Fonts.Default
                    $item.SubItems[1].Text = "$($executionTime) (Completed)"
                    $completedCount++

                    if ($script:StatusLabel) {
                        $script:StatusLabel.Text = "Completed ($($i + 1)/$($selectedItems.Count)): $name"
                    }
                }
            }
            catch {

                $stopwatch.Stop()
                $ms = $stopwatch.ElapsedMilliseconds
                $executionTime = if ($ms -gt 1000) { "{0:N2} s" -f ($ms / 1000) } else { "$($ms) ms" }

                $executionOutput = $_.Exception.Message

                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                if ($_.Exception.Message -match "cancelled|canceled|aborted|user.*declined|operation.*cancelled") {
                    Add-Content -Path $script:CurrentLogFile -Value "$timestamp WARN Execution cancelled with exception for '$name' - Time: $executionTime - Error: $executionOutput"
                }
                else {
                    Add-Content -Path $script:CurrentLogFile -Value "$timestamp ERROR Execution failed with exception for '$name' - Time: $executionTime - Error: $executionOutput"
                }

                if ($_.Exception.Message -match "cancelled|canceled|aborted|user.*declined|operation.*cancelled") {

                    $item.BackColor = [System.Drawing.Color]::FromArgb(255, 235, 200)
                    $item.ForeColor = [System.Drawing.Color]::FromArgb(205, 133, 0)
                    $item.Font = $script:UI.Fonts.Default
                    $item.SubItems[1].Text = "$($executionTime) (Cancelled)"
                    $cancelledCount++

                    if ($script:StatusLabel) {
                        $script:StatusLabel.Text = "Cancelled ($($i + 1)/$($selectedItems.Count)): $name"
                    }
                }
                else {

                    $item.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 200)
                    $item.ForeColor = [System.Drawing.Color]::Red
                    $item.Font = $script:UI.Fonts.Default
                    $item.SubItems[1].Text = "$($executionTime) (Failed)"
                    $failedCount++

                    if ($script:StatusLabel) {
                        $script:StatusLabel.Text = "Failed ($($i + 1)/$($selectedItems.Count)): $name"
                    }
                }

            }

            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 1000  
        }

        $endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $totalItems = $selectedItems.Count
        Add-Content -Path $script:CurrentLogFile -Value "$endTime INFO Execution completed - Total: $totalItems, Completed: $completedCount, Failed: $failedCount, Cancelled: $cancelledCount"

        if ($script:StatusLabel -and $script:ActionButton) {
            $totalItems = $selectedItems.Count
            $statusText = "Execution completed: $completedCount succeeded"
            if ($failedCount -gt 0) { $statusText += ", $failedCount failed" }
            if ($cancelledCount -gt 0) { $statusText += ", $cancelledCount cancelled" }
            $statusText += " (Total: $totalItems)"

            $script:StatusLabel.Text = $statusText
            $script:StatusLabel.Visible = $true
            $script:ActionButton.Visible = $true

            if (($failedCount -gt 0 -or $cancelledCount -gt 0) -and $script:RetryButton) {
                $script:RetryButton.Visible = $true
            }
        }
    }
    finally {

        $script:CreatedButtons['RunButton'].Enabled = $ConsentCheckbox.Checked
        $script:CreatedButtons['RunButton'].Text = "▶ Run"
        $SelectAllSwitch.Checked = $false
        $SelectAllSwitch.Tag = $false

        if ($script:StatusLabel -and -not $script:ActionButton.Visible) {
            $script:StatusLabel.Text = "Gray Winutil is ready to run scripts."
        }
    }
}

if ([Environment]::OSVersion.Version.Major -ge 6) {
    try { [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2) } catch {}
}
[System.Windows.Forms.Application]::EnableVisualStyles()

$Form = New-Object Windows.Forms.Form -Property $FormProps
$HeaderPanel = New-Object System.Windows.Forms.Panel -Property $HeaderPanelProps

$ContentPanel = New-Object Windows.Forms.Panel -Property $ContentPanelProps
$FooterPanel = New-Object Windows.Forms.Panel -Property $FooterPanelProps

$SelectAllSwitch = New-Object System.Windows.Forms.CheckBox -Property $SelectAllSwitchProps
$SearchBoxContainer = New-Object System.Windows.Forms.Panel -Property $SearchBoxContainerProps
$SearchBox = New-Object System.Windows.Forms.TextBox -Property $SearchBoxProps
$ConsentCheckbox = New-Object System.Windows.Forms.CheckBox -Property $ConsentCheckboxProps

$ProfileDropDown = New-Object System.Windows.Forms.ComboBox -Property $ProfileDropdownProps

$HelpLabel = New-Object System.Windows.Forms.Button -Property @{
    Text      = "ℹ"
    Dock      = 'Left'
    FlatStyle = 'Flat'
    Height    = $script:UI.Sizes.Input.Height - 5
    Width     = $script:UI.Sizes.Input.Width / 2 - 10
    BackColor = $script:UI.Colors.Accent
    ForeColor = [System.Drawing.Color]::White
    Font      = $Script:UI.Fonts.Regular
    Enabled   = $true
    Add_Click = { 
        if ($script:HelpForm -and -not $script:HelpForm.IsDisposed) {

            $script:HelpForm.BringToFront()
            $script:HelpForm.Activate()
            return
        }

        $script:HelpForm = New-Object System.Windows.Forms.Form -Property @{
            Add_FormClosed = { $script:HelpForm = $null }  
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
        $script:HelpForm.Controls.Add($HelpPanel)
        $script:HelpForm.Show()  
    }
}

$script:StatusPanel = New-Object System.Windows.Forms.Panel -Property @{
    Dock   = 'Top'
    Font   = $script:UI.Fonts.Small
    Height = $script:UI.Sizes.Status.Height
}
$script:ToolBarPanel = New-Object System.Windows.Forms.Panel -Property @{

    Dock    = 'Top'
    Font    = $script:UI.Fonts.Default
    Height  = $script:UI.Sizes.ToolBar.Height
    Padding = $script:UI.Padding.ToolBar
}
$script:ScriptsPanel = New-Object System.Windows.Forms.Panel -Property @{
    Dock    = 'Fill'
    Padding = '0,0,0,0'  
}

$script:ProgressBarPanel = New-Object System.Windows.Forms.Panel -Property $ProgressBarPanelProps
$script:StatusPanel.Controls.Add($script:ProgressBarPanel)

$script:StatusContentPanel = New-Object System.Windows.Forms.Panel -Property @{
    Dock   = 'Fill'  
    Height = 25
}

$script:StatusLabel = New-Object System.Windows.Forms.Label -Property @{
    AutoSize = $true
    Dock     = 'Left'
    Padding  = $script:UI.Padding.Status
    Text     = "Gray Winutil is ready to run scripts."
    Visible  = $true
}

$script:ActionButton = New-Object System.Windows.Forms.Button -Property @{
    Add_Click = {

        if ($script:CurrentLogFile -and (Test-Path $script:CurrentLogFile)) {
            try {
                Start-Process -FilePath "notepad.exe" -ArgumentList $script:CurrentLogFile
            }
            catch {

                Start-Process -FilePath $script:CurrentLogFile
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("No log file found.", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    Dock      = 'Right'
    FlatStyle = 'Flat'
    ForeColor = $script:UI.Colors.Accent
    Font      = $script:UI.Fonts.Small 
    Height    = 22
    Text      = "≡ Logs"
    Visible   = $false
    Width     = 70
}

$script:RetryButton = New-Object System.Windows.Forms.Button -Property @{
    Add_Click = {
        $script:RetryItems = @()
        foreach ($listView in $script:ListViews.Values) {
            foreach ($item in $listView.Items) {
                if ($item.BackColor -eq [System.Drawing.Color]::FromArgb(255, 200, 200) -or 
                    $item.BackColor -eq [System.Drawing.Color]::FromArgb(255, 235, 200)) {
                    $script:RetryItems += $item
                }
            }
        }

        if ($script:RetryItems.Count -gt 0) {
            RunSelectedItems -RetryMode $true
        }
    }
    Dock      = 'Right'
    FlatStyle = 'Flat'
    ForeColor = $script:UI.Colors.Accent
    Font      = $script:UI.Fonts.Small
    Height    = 22
    Text      = "↻ Retry"
    Visible   = $false
    Width     = 70
}

$script:CancelButton = New-Object System.Windows.Forms.Button -Property @{
    Add_Click = {
        $script:RetryItems = @()
        foreach ($listView in $script:ListViews.Values) {
            foreach ($item in $listView.Items) {
                if ($item.BackColor -eq [System.Drawing.Color]::FromArgb(255, 200, 200) -or 
                    $item.BackColor -eq [System.Drawing.Color]::FromArgb(255, 235, 200)) {
                    $script:RetryItems += $item
                }
            }
        }

        if ($script:RetryItems.Count -gt 0) {
            RunSelectedItems -RetryMode $true
        }
    }
    Dock      = 'Right'
    FlatStyle = 'Flat'
    ForeColor = $script:UI.Colors.Accent
    Font      = $script:UI.Fonts.Small
    Height    = 22
    Text      = "✕ Cancel"
    Visible   = $false
    Width     = 70
}
$script:ActionButton.FlatAppearance.BorderSize = 0
$script:RetryButton.FlatAppearance.BorderSize = 0
$script:CancelButton.FlatAppearance.BorderSize = 0
$script:StatusContentPanel.Controls.AddRange(@($script:StatusLabel, $script:RetryButton, $script:ActionButton, $script:CancelButton))
$script:StatusPanel.Controls.AddRange(@($script:ProgressBarPanel, $script:StatusContentPanel))

$script:CreatedButtons = @{}

foreach ($buttonDef in $script:ToolbarButtons) {
    $button = New-Object System.Windows.Forms.Button -Property @{
        AutoSize  = $false
        BackColor = $script:UI.Colors.Accent
        Dock      = if ($buttonDef.ContainsKey('Dock')) { $buttonDef.Dock } else { 'Right' }

        FlatStyle = 'Flat'
        Font      = if ($buttonDef.ContainsKey('Font')) { $buttonDef.Font } else { $script:UI.Fonts.Bold }
        ForeColor = $buttonDef.ForeColor
        Height    = 16
        Padding   = $script:UI.Padding.Control
        Text      = $buttonDef.Text
        Width     = if ($buttonDef.ContainsKey('Width')) { $buttonDef.Width } else { $script:UI.Sizes.Input.Width }
    }

    $button.Add_Click($buttonDef.Click)

    $button.Add_MouseEnter({
            param($sender, $e)
            $buttonName = $sender.Name
            $buttonDef = $script:ToolbarButtons | Where-Object { $_.Name -eq $buttonName }
            if ($buttonDef -and $script:StatusLabel) {
                $script:StatusLabel.Text = $buttonDef.ToolTip
            }
        }.GetNewClosure())

    $button.Add_MouseLeave({
            if ($script:StatusLabel -and -not $script:ActionButton.Visible) {
                $script:StatusLabel.Text = "Gray Winutil is ready to run scripts."
            }
        })

    $button.FlatAppearance.BorderSize = 0

    $button.Name = $buttonDef.Name
    # for example $script:CreatedButtons['RunButton']
    $script:CreatedButtons[$buttonDef.Name] = $button
}
$SearchBoxContainer.Controls.Add($SearchBox)
$script:ToolBarPanel.Controls.AddRange(
    @($SearchBoxContainer) + 
    $script:CreatedButtons.Values + 
    @( $ProfileDropdown, $SelectAllSwitch, $ConsentCheckbox))

$ContentPanel.Controls.Add($script:ScriptsPanel)
$ContentPanel.Controls.Add($script:ToolBarPanel)
$FooterPanel.Controls.AddRange(@($script:StatusPanel, $HelpLabel))
$Form.Controls.AddRange(@($HeaderPanel, $FooterPanel, $ContentPanel))

@($script:DataDirectory, $script:ProfilesDirectory, $script:LogsDirectory) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

$defaultProfile = Join-Path -Path $script:ProfilesDirectory -ChildPath "Default Profile.txt"
if (-not (Test-Path $defaultProfile)) {

    try {
        $dbData = Invoke-WebRequest $script:Config.DatabaseUrl | ConvertFrom-Json
        $allIds = @()

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

        "# Default Profile" | Set-Content -Path $defaultProfile -Force
    }
}

[void]$Form.ShowDialog()