<#
.SYNOPSIS
Windows Utility GUI Application

.DESCRIPTION
This script creates a Windows Forms GUI application for managing and executing scripts from a user-defined profile. It allows users to select scripts, view descriptions, and execute them within the application.

.NOTES
This script is designed to be a starting point for building a more complex GUI application. It may require additional features and error handling for production use.
#>

# ------------------------------
# Initialize Dependencies
# ------------------------------
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# ------------------------------
# State Management
# ------------------------------
# Script-scoped variables
$script:PersonalScriptsPath = "$HOME\Documents\Gandalf-WinUtil-Scripts"
$script:DataDirectory = "$HOME\Documents\Gandalf-WinUtil-Scripts"
$script:LastColumnClicked = @{}
$script:LastColumnAscending = @{}
$script:ListViews = @{}
$script:SplitContainers = @()

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
    Size      = '500,600'
    Text      = "Gray WinUtil"
    BackColor = $script:UI.Colors.Background
    Font      = $script:UI.Fonts.Default
    Add_Shown = { $Form.Activate() }
}

# Panels
$HeaderPanelProps = @{
    Height    = 40
    Dock      = 'Top'
    Padding   = '15,10,15,5'
    BackColor = $script:UI.Colors.Background
    Font      = $script:UI.Fonts.Default
}

$ContentPanelProps = @{
    Dock      = 'Fill'
    Padding   = '10,40,10,10'
    BackColor = $script:UI.Colors.Background
}

$FooterPanelProps = @{
    Dock        = 'Bottom'
    Height      = 50
    BackColor   = $script:UI.Colors.Background
    Padding     = '15,10,15,10'
    BorderStyle = 'None'
}

# List View and Split Container
$ListViewProps = @{
    BorderStyle      = 'None'
    CheckBoxes       = $true
    Font             = $script:UI.Fonts.Default
    Dock             = 'Fill'
    View             = 'Details'
    FullRowSelect    = $true
    MultiSelect      = $true
    BackColor        = $script:UI.Colors.Background
    ShowItemToolTips = $true

    # Enable the Invoke button only if at least one item is checked
    Add_ItemChecked  = {
        $anyChecked = $script:ListViews.Values | ForEach-Object { $_.Items | Where-Object { $_.Checked } } | Measure-Object | Select-Object -ExpandProperty Count
        $InvokeButton.Enabled = $anyChecked -gt 0
    }
}

$SplitProps = @{
    Dock             = 'Fill'
    Orientation      = 'Horizontal'
    SplitterWidth    = 3
    SplitterDistance = 30
    BorderStyle      = 'None'
    Padding          = '0,0,0,20'
}

# Control Properties
$SelectAllSwitchProps = @{
    Text      = "ALL"
    Width     = 100
    Height    = $script:UI.Sizes.Input.Height
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
    Dock            = 'Right'
    Width           = $script:UI.Sizes.Input.Width
    Font            = $script:UI.Fonts.Default
    ForeColor       = $script:UI.Colors.Text
    PlaceholderText = " SEARCH..."
    TextAlign       = 'Left'
    Multiline       = $false
    BorderStyle     = 'FixedSingle'
    # Left            = 150 + 20
    # Top             = 5
    Add_Enter       = { if ($SearchBox.Text -eq "SEARCH...") { $SearchBox.Text = ""; $SearchBox.ForeColor = $script:UI.Colors.Text } }
    Add_Leave       = { if ($SearchBox.Text -eq "") { $SearchBox.Text = "SEARCH..."; $SearchBox.ForeColor = $script:UI.Colors.Disabled } }
    Add_TextChanged = {
        $searchText = $SearchBox.Text.Trim()
        if ($searchText -eq "SEARCH...") { return }
        $listViews = @($script:ListViews.Values)
        foreach ($lv in $listViews) {
            foreach ($item in $lv.Items) {
                $item.ForeColor = if ($item.Text -like "*$searchText*") { $script:UI.Colors.Text } else { $script:UI.Colors.Disabled }
            }
        }
    }
}

$ProfileDropdownProps = @{
    Width                    = $script:UI.Sizes.Input.FooterWidth
    Height                   = $script:UI.Sizes.Input.Height
    Dock                     = 'Left'
    Text                     = "SELECT PROFILE"
    Font                     = $script:UI.Fonts.Default
    ForeColor                = $script:UI.Colors.Text
    DropDownStyle            = 'DropDownList'
    Padding                  = New-Object System.Windows.Forms.Padding(0)
    Add_SelectedIndexChanged = {
        $selectedProfile = $ProfileDropdown.SelectedItem
        if ($selectedProfile) {
            $selectedProfilePath = Join-Path -Path $script:PersonalScriptsPath -ChildPath "$selectedProfile.txt"
            
            if (Test-Path $selectedProfilePath) {
                # Load the selected profile
                $ProfileLines = Get-Content -Path $selectedProfilePath -ErrorAction SilentlyContinue
                if (-not $ProfileLines) {
                    Write-Warning "Selected profile '$selectedProfilePath' is empty or does not exist."
                    return
                }
                else {
                    # Clear existing ListViews
                    $script:ListViews.Clear()

                    # get from github
                    $dbData = iwr "https://raw.githubusercontent.com/mrdotkg/dotfiles/refs/heads/main/db.json" | ConvertFrom-Json
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

$InvokeButtonProps = @{
    Width     = $script:UI.Sizes.Input.Width
    Text      = "RUN"
    Dock      = 'Right'
    # BackColor = $script:UI.Colors.Accent
    # ForeColor = [System.Drawing.Color]::White
    Font      = $script:UI.Fonts.Bold
    FlatStyle = 'Flat'
    Add_Click = { RunSelectedItems -Action Invoke }
}

# ------------------------------
# Functions
# ------------------------------
function Add-ListView {
    param ($panel, $key, $data)

    $LV = New-Object System.Windows.Forms.ListView -Property $ListViewProps
    # Add columns first
    $LV.Columns.Add($key.ToUpper(), $script:UI.Sizes.Columns.Name) | Out-Null
    $LV.Columns.Add("Description".ToUpper(), $script:UI.Sizes.Columns.Description) | Out-Null
    $LV.Columns.Add("Command".ToUpper(), $script:UI.Sizes.Columns.Command) | Out-Null

    #TODO Show context menu or right click with copy command option

    # Capture the current $key value in a local variable
    $currentKey = $key
    $LV.Add_ColumnClick({
            Format-ListView -ListView $LV -ViewName $currentKey -Column $_.Column
        }.GetNewClosure())

    # Add items from grouped scripts data
    foreach ($script in $data) {
        $listItem = New-Object System.Windows.Forms.ListViewItem($script.content)
        $listItem.SubItems.Add($script.description)
        $listItem.SubItems.Add($script.command)
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
        
        # Calculate the height for each section based on total groups
        $totalHeight = $parentPanel.ClientSize.Height
        $heightPerSection = [Math]::Floor($totalHeight / $keys.Count)
        
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
        [string]$Action
    )
    
    # Disable the invoke button while running
    $InvokeButton.Enabled = $false
    $InvokeButton.Text = "Running..."

    try {
        # Get all selected items from all ListViews
        $selectedItems = @()
        foreach ($listView in $script:ListViews.Values) {
            $selectedItems += $listView.Items | Where-Object { $_.Checked }
        }

        if ($selectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No items selected.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }

        # Create progress form
        $progressForm = New-Object System.Windows.Forms.Form -Property @{
            Text            = "Running Commands"
            Size            = New-Object System.Drawing.Size(400, 150)
            StartPosition   = "CenterParent"
            FormBorderStyle = "FixedDialog"
            ControlBox      = $false
            Font            = $script:UI.Fonts.Default
        }

        $progressLabel = New-Object System.Windows.Forms.Label -Property @{
            Location = New-Object System.Drawing.Point(10, 20)
            Size     = New-Object System.Drawing.Size(360, 40)
            Font     = $script:UI.Fonts.Default
            Text     = "Initializing..."
        }

        $progressBar = New-Object System.Windows.Forms.ProgressBar -Property @{
            Location = New-Object System.Drawing.Point(10, 70)
            Size     = New-Object System.Drawing.Size(360, 20)
            Minimum  = 0
            Maximum  = $selectedItems.Count
            Value    = 0
        }

        $progressForm.Controls.AddRange(@($progressLabel, $progressBar))
        $progressForm.Show()
        $Form.Enabled = $false

        # Track overall success
        $successCount = 0
        $failureCount = 0
        $errorLog = @()

        # Process each selected item
        for ($i = 0; $i -lt $selectedItems.Count; $i++) {
            $item = $selectedItems[$i]
            $command = $item.SubItems[2].Text
            $name = $item.Text

            $progressBar.Value = $i
            $progressLabel.Text = "Running: $name"
            [System.Windows.Forms.Application]::DoEvents()

            try {
                $result = Invoke-Expression -Command $command
                if ($result -ne $null) {
                    $progressLabel.Text += "`nOutput: $result"
                }

                $successCount++
                $item.Checked = $false  # Uncheck successful items
            }
            catch {
                $failureCount++
                $errorLog += "Error running '$name': $_"
            }
        }

        # Show final results
        $progressForm.Close()
        $Form.Enabled = $true

        $resultMessage = "Execution complete.`n`n"
        $resultMessage += "Successful: $successCount`n"
        if ($failureCount -gt 0) {
            $resultMessage += "Failed: $failureCount`n`n"
            $resultMessage += "Error Details:`n" + ($errorLog -join "`n")
            $icon = [System.Windows.Forms.MessageBoxIcon]::Warning
        }
        else {
            $resultMessage += "`nAll commands completed successfully!"
            $icon = [System.Windows.Forms.MessageBoxIcon]::Information
        }

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
$InvokeButton = New-Object System.Windows.Forms.Button -Property $InvokeButtonProps

$ProfileDropDown = New-Object System.Windows.Forms.ComboBox -Property $ProfileDropdownProps
$BrowseLibrary = New-Object System.Windows.Forms.Label -Property @{
    Text      = "MORE PROFILES"
    Width     = $script:UI.Sizes.Input.FooterWidth
    Height    = $script:UI.Sizes.Input.Height
    Dock      = 'Right'
    Font      = $script:UI.Fonts.Default
    ForeColor = $script:UI.Colors.Text
    TextAlign = 'MiddleCenter'
    AutoSize  = $false
    Add_Click = {
        # Open Another window and load a checkbox list view with all the json files in the repository mrdotkg/dotfiles/
        $repoUrl = "https://api.github.com/repos/mrdotkg/dotfiles/contents"
        $response = Invoke-WebRequest -Uri $repoUrl -UseBasicParsing
        $content = ConvertFrom-Json $response.Content

        $ProfileForm = New-Object System.Windows.Forms.Form -Property @{
            Text          = "Select profiles to download"
            Size          = New-Object System.Drawing.Size(300, 360)
            Font          = $script:UI.Fonts.Default
            BackColor     = $script:UI.Colors.Background
            StartPosition = "CenterParent"
            MaximizeBox   = $false
            MinimizeBox   = $false
            Padding       = '10,10,10,10'

            Add_Shown     = {
                # $DownloadButton.Enabled = $false  # Initially disable the download button
                $ProfileForm.Activate()
                $ProfileLV.Focus()
            }
            
        }

        $ProfileLV = New-Object System.Windows.Forms.CheckedListBox -Property @{
            Dock        = 'Fill'
            Font        = $script:UI.Fonts.Default
            ForeColor   = $script:UI.Colors.Text
            BackColor   = $script:UI.Colors.Background
            BorderStyle = 'None'

            # Add_SelectedIndexChanged = {
            #     # Enable the download button if at least one item is checked
            #     $DownloadButton.Enabled = $ProfileLV.CheckedItems.Count -gt 0
            # }
        }

        foreach ($item in $content) {
            if ($item.type -eq "file" -and $item.name -like "*.json") {
                $ProfileLV.Items.Add($item.name)
            }
        }

        # Add a button to download selected files into the user's personal scripts folder
        $DownloadButton = New-Object System.Windows.Forms.Button -Property @{
            Text      = "DOWNLOAD"
            Height    = 25
            Width     = $script:UI.Sizes.Input.FooterWidth
            Font      = $script:UI.Fonts.Bold
            FlatStyle = 'Flat'
            Dock      = 'Bottom'
            Add_Click = {
                $selectedItems = $ProfileLV.CheckedItems
                foreach ($selectedItem in $selectedItems) {
                    $fileName = $selectedItem.ToString()
                    $fileUrl = "https://raw.githubusercontent.com/mrdotkg/dotfiles/main/$fileName"
                    $destinationPath = Join-Path -Path $HOME\Documents\Gandalf-WinUtil-Scripts -ChildPath $fileName
                    write-host "Downloading $fileName to $destinationPath"
                    # Ensure the destination directory exists
                    if (-not (Test-Path -Path (Split-Path -Path $destinationPath -Parent))) {
                        New-Item -ItemType Directory -Path (Split-Path -Path $destinationPath -Parent) | Out-Null
                    }
                    Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath
                }
                if ($selectedItems.Count -eq 0) {
                    [System.Windows.Forms.MessageBox]::Show("No files selected for download.")
                    return
                }
                [System.Windows.Forms.MessageBox]::Show("Selected files downloaded successfully to $HOME\Documents\Gandalf-WinUtil-Scripts!")                
                $ProfileForm.Close()
            }
        }

        $ProfileForm.Controls.Add($ProfileLV)
        $ProfileForm.Controls.Add($DownloadButton)
        $ProfileForm.ShowDialog()
    }

}

# Create a spacer panel
$SpacerPanel = New-Object System.Windows.Forms.Panel -Property @{
    Width = 20
    Dock  = 'Right'
}

$HeaderPanel.Controls.AddRange(@($SelectAllSwitch, $SearchBox, $SpacerPanel, $InvokeButton))
$FooterPanel.Controls.AddRange(@($ProfileDropdown, $BrowseLibrary))
$Form.Controls.AddRange(@($HeaderPanel, $ContentPanel, $FooterPanel))

# Initialize file system
if (-not (Test-Path $script:DataDirectory)) {
    New-Item -ItemType Directory -Path $script:DataDirectory | Out-Null
}

$defaultProfile = Join-Path -Path $script:DataDirectory -ChildPath "Default-Profile.txt"
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
Get-ChildItem -Path $script:DataDirectory | ForEach-Object {
    $ProfileDropdown.Items.Add($_.BaseName) | Out-Null
}

if ($ProfileDropdown.Items.Count -gt 0) {
    $ProfileDropdown.SelectedIndex = 0
}

# Start application
[void]$Form.ShowDialog()