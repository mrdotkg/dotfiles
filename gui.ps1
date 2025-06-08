# ------------------------------
# Initialize Dependencies
# ------------------------------
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

# ------------------------------
# State Management
# ------------------------------
# Script-scoped variables
$script:PersonalScriptsPath = "$HOME\Documents\Gandalf-WinUtil-Scripts"
$script:LastColumnClicked = @{}
$script:LastColumnAscending = @{}
$script:ListViews = @{}

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
            Width  = 150
            Height = 30
        }
        Columns = @{
            Name        = 150
            Description = 300
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
    Icon      = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot\gandalf.ico")
    Size      = '600,700'
    Text      = "Gandalf's WinUtil"
    BackColor = $script:UI.Colors.Background
    Font      = $script:UI.Fonts.Default
    Add_Shown = { $Form.Activate() }
}

# Panels
$HeaderPanelProps = @{
    Height    = 40
    Dock      = 'Top'
    Padding   = '15,7,15,7'
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
    Padding     = '15,5,10,10'
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
}

$SplitProps = @{
    Dock             = 'Fill'
    Orientation      = 'Horizontal'
    SplitterDistance = 50
    SplitterWidth    = 3
    BorderStyle      = 'None'
    Padding          = '0,0,0,20'
    Panel1MinSize    = 50
    Panel2MinSize    = 30
}

# Control Properties
$SelectAllSwitchProps = @{
    Text               = "Select All"
    Width              = 100
    Height             = $script:UI.Sizes.Input.Height
    Dock               = 'Left'
    Font               = $script:UI.Fonts.Default
    BackColor          = $script:UI.Colors.Background
    ForeColor          = $script:UI.Colors.Text
    Add_CheckedChanged = {
        $isChecked = $SelectAllSwitch.Checked
        $listViews = @($script:ListViews.Values)
        $listViews | ForEach-Object { $_.Items | ForEach-Object { $_.Checked = $isChecked } }
    }
}

$SearchBoxProps = @{
    Height          = $script:UI.Sizes.Input.Height
    Width           = $script:UI.Sizes.Input.Width
    Font            = $script:UI.Fonts.Default
    ForeColor       = $script:UI.Colors.Text
    PlaceholderText = " Search..."
    TextAlign       = 'Left'
    Multiline       = $false
    Left            = 150 + 20
    Top             = 7
    Add_Enter       = { if ($SearchBox.Text -eq "Search...") { $SearchBox.Text = ""; $SearchBox.ForeColor = $script:UI.Colors.Text } }
    Add_Leave       = { if ($SearchBox.Text -eq "") { $SearchBox.Text = "Search..."; $SearchBox.ForeColor = $script:UI.Colors.Disabled } }
    Add_TextChanged = {
        $searchText = $SearchBox.Text.Trim()
        if ($searchText -eq "Search...") { return }
        $listViews = @($script:ListViews.Values)
        foreach ($lv in $listViews) {
            foreach ($item in $lv.Items) {
                $item.ForeColor = if ($item.Text -like "*$searchText*") { $script:UI.Colors.Text } else { $script:UI.Colors.Disabled }
            }
        }
    }
}

$ProfileDropdownProps = @{
    Width                    = $script:UI.Sizes.Input.Width
    Height                   = $script:UI.Sizes.Input.Height
    Left                     = 15
    Font                     = $script:UI.Fonts.Default
    ForeColor                = $script:UI.Colors.Text
    DropDownStyle            = 'DropDownList'
    Add_SelectedIndexChanged = {
        $selectedFile = $ProfileDropdown.SelectedItem
        if ($selectedFile) {
            $SelectedFilePath = Join-Path -Path $script:PersonalScriptsPath -ChildPath "$selectedFile.json"
            if (Test-Path $SelectedFilePath) {
                $Scripts = Get-Content $SelectedFilePath | ConvertFrom-Json
                $ContentPanel.Controls.Clear()
                $keys = $Scripts.PSObject.Properties.Name
                CreateSplitContainer -parentPanel $ContentPanel -keys $keys -index 0
                $ContentPanel.Refresh()
            }
            else {
                Write-Warning "Selected file '$SelectedFilePath' does not exist."
            }
        }
    }
}

$InvokeButtonProps = @{
    Width     = $script:UI.Sizes.Input.Width
    Text      = "Run Selected Actions"
    Dock      = 'Right'
    BackColor = $script:UI.Colors.Accent
    ForeColor = [System.Drawing.Color]::White
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

    # Capture the current $key value in a local variable
    $currentKey = $key
    $LV.Add_ColumnClick({
            Format-ListView -ListView $LV -ViewName $currentKey -Column $_.Column
        }.GetNewClosure())

    # Add items from JSON data
    foreach ($item in $data) {
        $listItem = New-Object System.Windows.Forms.ListViewItem($item.content)
        $listItem.SubItems.Add($item.description)
        $LV.Items.Add($listItem)
    }

    $script:LastColumnClicked[$key] = 0
    $script:LastColumnAscending[$key] = $true
    $script:ListViews[$key] = $LV

    # Add ListView to the specified panel
    $panel.Controls.Add($LV)
}

# Function to recursively create nested SplitContainer
function CreateSplitContainer {
    param ($parentPanel, $keys, $index)

    if ($index -ge $keys.Count) { return }

    $splitContainer = New-Object System.Windows.Forms.SplitContainer -Property $SplitProps
    
    # Add ListView to first panel
    Add-ListView -panel $splitContainer.Panel1 -key $keys[$index] -data $Scripts.$($keys[$index])

    # If more keys remain, nest another SplitContainer in Panel2
    if ($index + 1 -lt $keys.Count) {
        CreateSplitContainer -parentPanel $splitContainer.Panel2 -keys $keys -index ($index + 1)
    }

    # Add SplitContainer to the parent panel
    $parentPanel.Controls.Add($splitContainer)
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
    
    # Get list of active views
    $listViews = $script:ListViews.GetEnumerator() | ForEach-Object {
        @{
            LV   = $_.Value
            Key  = $_.Key
            Data = $Scripts.$($_.Key)
        }
    }
    foreach ($entry in $listViews) {
        # differentiate between Apps, Tweaks and Tasks
        
        $selected = $entry.LV.CheckedItems
        foreach ($item in $selected) {
            $scriptObj = $entry.Data | Where-Object { $_.content -eq $item.Text }
            if ($Action -eq "Invoke") {
                $scriptObj.script | ForEach-Object { Write-Host "Executing $($item.Text): $_" }
            }
            elseif ($Action -eq "Revoke") {
                $scriptObj.Revoke | ForEach-Object { Write-Host "Revoking $($item.Text): $_" }
            }
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
$ContentPanel = New-Object Windows.Forms.Panel -Property $ContentPanelProps
$FooterPanel = New-Object System.Windows.Forms.Panel -Property $FooterPanelProps

$SelectAllSwitch = New-Object System.Windows.Forms.CheckBox -Property $SelectAllSwitchProps
$SearchBox = New-Object System.Windows.Forms.TextBox -Property $SearchBoxProps
$InvokeButton = New-Object System.Windows.Forms.Button -Property $InvokeButtonProps

$ProfileDropDown = New-Object System.Windows.Forms.ComboBox -Property $ProfileDropdownProps
$BrowseLibrary = New-Object System.Windows.Forms.Label -Property @{
    Text      = "Download Profiles"
    Width     = $script:UI.Sizes.Input.Width
    Height    = $script:UI.Sizes.Input.Height
    Dock      = 'Right'
    Font      = $script:UI.Fonts.Default
    ForeColor = $script:UI.Colors.Text
    Add_Click = {
        # Open Another window and load a checkbox list view with all the json files in the repository mrdotkg/dotfiles/
        $repoUrl = "https://api.github.com/repos/mrdotkg/dotfiles/contents"
        $response = Invoke-WebRequest -Uri $repoUrl -UseBasicParsing
        $content = ConvertFrom-Json $response.Content

        $ProfileForm = New-Object System.Windows.Forms.Form -Property @{
            Text          = "Select profiles to download"
            Size          = New-Object System.Drawing.Size(400, 300)
            Font          = $script:UI.Fonts.Default
            StartPosition = "CenterParent"
            MaximizeBox   = $false
            MinimizeBox   = $false
            Padding       = '10,10,10,10'
            
        }

        $ProfileLV = New-Object System.Windows.Forms.CheckedListBox -Property @{
            Dock        = 'Fill'
            Font        = $script:UI.Fonts.Default
            ForeColor   = $script:UI.Colors.Text
            BackColor   = $script:UI.Colors.Background
            BorderStyle = 'None'
        }

        foreach ($item in $content) {
            if ($item.type -eq "file" -and $item.name -like "*.json") {
                $ProfileLV.Items.Add($item.name)
            }
        }

        # Add a button to download selected files into the user's personal scripts folder
        $DownloadButton = New-Object System.Windows.Forms.Button -Property @{
            Text      = "Download Selected"
            BackColor = $script:UI.Colors.Accent
            ForeColor = [System.Drawing.Color]::White
            Font      = $script:UI.Fonts.Bold
            FlatStyle = 'Flat'
            Dock      = 'Bottom'
            Height    = 30
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

$HeaderPanel.Controls.AddRange(@($SelectAllSwitch, $SearchBox, $InvokeButton))
$FooterPanel.Controls.AddRange(@($ProfileDropdown, $BrowseLibrary))
$Form.Controls.AddRange(@($HeaderPanel, $ContentPanel, $FooterPanel))

# Initialize file system
if (-not (Test-Path $script:PersonalScriptsPath)) {
    New-Item -ItemType Directory -Path $script:PersonalScriptsPath | Out-Null
}

# Load profiles
Get-ChildItem -Path $script:PersonalScriptsPath -Filter *.json | ForEach-Object {
    $ProfileDropdown.Items.Add($_.BaseName) | Out-Null
}

if ($ProfileDropdown.Items.Count -gt 0) {
    $ProfileDropdown.SelectedIndex = 0
}

# Start application
[void]$Form.ShowDialog()