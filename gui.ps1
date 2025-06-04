Add-Type -AssemblyName System.Drawing, System.Windows.Forms
if ([Environment]::OSVersion.Version.Major -ge 6) {
    try { [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2) } catch {}
}
[System.Windows.Forms.Application]::EnableVisualStyles()

# Add sorting variables
$script:LastColumnClicked = @{
    Apps   = 0
    Tweaks = 0
}
$script:LastColumnAscending = @{
    Apps   = $true
    Tweaks = $true
}

# Set the accent color based on the current Windows theme
$AccentColorValue = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AccentColor" -ErrorAction SilentlyContinue
if ($AccentColorValue) {
    $a = ($AccentColorValue -band 0xFF000000) -shr 24
    $b = ($AccentColorValue -band 0x00FF0000) -shr 16
    $g = ($AccentColorValue -band 0x0000FF00) -shr 8
    $r = ($AccentColorValue -band 0x000000FF)
    $AccentColor = [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}
else {
    $AccentColor = [System.Drawing.Color]::FromArgb(44, 151, 222)
}

# Define properties for the main form and controls
$FormProps = @{
    # FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    Icon          = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot\gandalf.ico")
    # MinimizeBox     = $false
    # MaximizeBox     = $false
    Size          = '400,700'
    StartPosition = "CenterParent"
    Text          = "Gandalf's WinUtil"
    # Topmost       = $true
    # Padding       = '10,10,10,10'
    BackColor     = [System.Drawing.Color]::white
    Font          = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
}

$ListViewProps = @{
    BorderStyle   = 'None'
    # height        = $FormProps.Size.Height - 100
    # width         = $Form.Rectangle.Width
    # anchor        = 'Top, Left, Right, Bottom'
    CheckBoxes    = $true
    Dock          = 'Fill'
    View          = 'Details'
    FullRowSelect = $true
    MultiSelect   = $true
    # Padding       = '20,20,20,20'
    BackColor     = [System.Drawing.Color]::FromArgb(241, 243, 249)
}

$SplitProps = @{
    BackColor        = [System.Drawing.Color]::White
    Dock             = 'Fill'
    Orientation      = 'Horizontal'
    SplitterDistance = 50
    SplitterWidth    = 3
    # BorderStyle      = 'None'
}

$ActionButtonProps = @{ 
    Height    = 30
    Text      = "Invoke Selected"
    Font      = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    BackColor = $AccentColor
    ForeColor = [System.Drawing.Color]::White
    FlatStyle = 'Flat'
}

$HeaderHeight = 40
$HeaderPanelProps = @{
    Height    = $HeaderHeight
    Dock      = 'Top'
    BackColor = [System.Drawing.Color]::FromArgb(241, 243, 249)
    Padding   = '10,10,10,0'
}

$ContentPanelProps = @{
    Dock      = 'Fill'
    Padding   = '0,40,10,10'
    BackColor = [System.Drawing.Color]::FromArgb(241, 243, 249)
}

$FooterPanelProps = @{
    Dock        = 'Bottom'
    Height      = 50
    BackColor   = [System.Drawing.Color]::FromArgb(241, 243, 249)
    Padding     = '10,5,10,10'
    BorderStyle = 'None'
}

$SearchBoxProps = @{
    Location        = New-Object System.Drawing.Point(0, 0)
    Size            = New-Object System.Drawing.Size(308, 40)
    Font            = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    # BackColor       = [System.Drawing.Color]::FromArgb(241, 243, 249)
    # ForeColor       = [System.Drawing.Color]::FromArgb(100, 100, 100)
    BorderStyle     = 'FixedSingle'
    PlaceholderText = "Search..."
    TextAlign       = 'Left'
    # Add a search icon to the left of the TextBox
    Padding         = '10,0,0,0'  # Add padding to the left for the icon
    Add_Enter       = ({
            if ($SearchBox.Text -eq "Search...") {
                $SearchBox.Text = ""
                $SearchBox.ForeColor = [System.Drawing.Color]::Black
            }
        })
    Add_Leave       = ({
            if ($SearchBox.Text -eq "") {
                $SearchBox.Text = "Search..."
                $SearchBox.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
            }
        })
    Add_TextChanged = ({
            $searchText = $SearchBox.Text.Trim()
            if ($searchText -eq "Search...") { return }
        
            # Filter ListViews based on search text
            $listViews = @($AppsLV, $TweaksLV, $TasksLV)
            foreach ($lv in $listViews) {
                foreach ($item in $lv.Items) {
                    if ($item.Text -like "*$searchText*") {
                        $item.ForeColor = [System.Drawing.Color]::Black
                    }
                    else {
                        $item.ForeColor = [System.Drawing.Color]::LightGray
                    }
                }
            }
        })
}

$InvokeButtonProps = @{
    Width     = 150
    Left      = 5
    Top       = 5
    Text      = "Invoke Selected"
    BackColor = $AccentColor
    ForeColor = [System.Drawing.Color]::White
    Font      = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    FlatStyle = 'Flat'
}

$RevokeButtonProps = @{
    Width     = $InvokeButtonProps.Width
    Left      = $InvokeButtonProps.Left + $InvokeButtonProps.Width - 1
    Top       = 5
    Text      = "Revoke Selected"
    BackColor = [System.Drawing.Color]::FromArgb(200, 60, 60)
    ForeColor = [System.Drawing.Color]::White
    Font      = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    FlatStyle = 'Flat'
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

    # Exclude the first row ("Select All") from sorting
    $header = $ListView.Items[0]
    # $itemsToSort = @($ListView.Items) | Select-Object -Skip 1
    $items = @($ListView.Items) | Select-Object -Skip 1
    $ListView.BeginUpdate()
    try {
        # Sort items
        $items = $items | Sort-Object -Property {
            $_.SubItems[$Column].Text
        } -Descending:(-not $script:LastColumnAscending[$ViewName])

        # Rebuild ListView
        $ListView.Items.Clear()
        $ListView.Items.Add($header)
        $ListView.Items.AddRange([System.Windows.Forms.ListViewItem[]]$items)
    }
    finally {
        $ListView.EndUpdate()
    }
}

# Helper function to create styled buttons
function New-ActionButton {
    param(
        [string]$Text,
        [System.Drawing.Color]$BackColor,
        [System.Drawing.Color]$BorderColor
    )
    $btn = [System.Windows.Forms.Button]::new()
    foreach ($k in $ActionButtonProps.Keys) { $btn.$k = $ActionButtonProps[$k] }
    $btn.Text = $Text
    $btn.BackColor = $BackColor
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.FlatAppearance.BorderColor = $BorderColor
    $btn.FlatAppearance.BorderSize = 0
    return $btn
}

function Set-FooterButtonPositions {
    $FooterPanelWidth = $FooterPanel.Width
    $ButtonSpacing = 8
    $TotalButtonWidth = $InvokeButton.Width + $RevokeButton.Width + $ButtonSpacing
    $StartLeft = [math]::Max(5, [math]::Floor(($FooterPanelWidth - $TotalButtonWidth) / 2))
    $InvokeButton.Left = $StartLeft
    $RevokeButton.Left = $InvokeButton.Left + $InvokeButton.Width + $ButtonSpacing / 2
    $SearchBox.Left = $StartLeft
}
function Run-SelectedItems {
    param(
        [ValidateSet("Invoke", "Revoke")]
        [string]$Action
    )
    $listViews = @(
        @{ LV = $AppsLV; Data = $Scripts.apps },
        @{ LV = $TweaksLV; Data = $Scripts.tweaks }
    )
    foreach ($entry in $listViews) {
        $selected = $entry.LV.CheckedItems | Where-Object { $_.Text -ne "Select All" }
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

########################
## GUI Initialization ##
########################

$Form = New-Object Windows.Forms.Form -Property $FormProps

# Create a responsive layout: header, main content area and footer
$HeaderPanel = New-Object System.Windows.Forms.Panel -Property $HeaderPanelProps
$ContentPanel = New-Object Windows.Forms.Panel -Property $ContentPanelProps
$FooterPanel = New-Object Windows.Forms.Panel -Property $FooterPanelProps

# Create Search Bar
$SearchBox = New-Object System.Windows.Forms.TextBox -Property $SearchBoxProps
$HeaderPanel.Controls.Add($SearchBox)

# Separate the Content Panel horizontally with a Splitter bar
$Split = New-Object Windows.Forms.SplitContainer -Property $SplitProps
$Split2 = New-Object Windows.Forms.SplitContainer -Property $SplitProps

# Append ListViews to both sides of the Splitter bar
$AppsLV = New-Object Windows.Forms.ListView -Property $ListViewProps
$TweaksLV = New-Object Windows.Forms.ListView -Property $ListViewProps
$TasksLV = New-Object Windows.Forms.ListView -Property $ListViewProps

# Enable tooltips for both ListViews
$AppsLV.ShowItemToolTips = $true
$TweaksLV.ShowItemToolTips = $true
$TasksLV.ShowItemToolTips = $true

$Split.Panel1.Controls.Add($AppsLV)
$Split.Panel2.Controls.Add($Split2)
$Split2.Panel1.Controls.Add($TweaksLV)
$Split2.Panel2.Controls.Add($TasksLV)

# Add Split (with ListViews) to content area, and ButtonPanel to footer
$ContentPanel.Controls.Add($Split)

$InvokeButton = New-ActionButton -Text "Invoke Selected" -BackColor $AccentColor -BorderColor ([System.Drawing.Color]::FromArgb(44, 151, 222))
$RevokeButton = New-ActionButton -Text "Revoke Selected" -BackColor ([System.Drawing.Color]::FromArgb(200, 60, 60)) -BorderColor ([System.Drawing.Color]::FromArgb(200, 60, 60))
foreach ($k in $InvokeButtonProps.Keys) { $InvokeButton.$k = $InvokeButtonProps[$k] }
foreach ($k in $RevokeButtonProps.Keys) { $RevokeButton.$k = $RevokeButtonProps[$k] }

# Attach actions to buttons
$InvokeButton.Add_Click({ Run-SelectedItems -Action Invoke })
$RevokeButton.Add_Click({ Run-SelectedItems -Action Revoke })

# Adjust position on resize
$FooterPanel.Add_Resize({ Set-FooterButtonPositions })
$FooterPanel.Controls.AddRange(@($InvokeButton, $RevokeButton))

$AppsLV.Columns.Add("Applications", 150) | Out-Null
$AppsLV.Columns.Add("Description", 200) | Out-Null
$TweaksLV.Columns.Add("Tweaks", 150) | Out-Null
$TasksLV.Columns.Add("Tasks( can't be revoked )", 150) | Out-Null
$TweaksLV.Columns.Add("Description", 200) | Out-Null

# Add a "Select All" item to both ListViews
$AppsLV.Items.Add("Select All") | Out-Null
$TweaksLV.Items.Add("Select All") | Out-Null
$TasksLV.Items.Add("Select All") | Out-Null

# Create a handler for "Select All" checkbox
$SelectAllHandler = {
    param($sender, $e)
    if ($e.Index -eq 0) {
        $isChecked = $e.NewValue -eq 'Checked'
        for ($i = 1; $i -lt $sender.Items.Count; $i++) {
            $sender.Items[$i].Checked = $isChecked
        }
    }
}

# Attach the Select All handler to both ListViews
$AppsLV.Add_ItemCheck($SelectAllHandler)
$TweaksLV.Add_ItemCheck($SelectAllHandler)

# Add column click handlers
$AppsLV.Add_ColumnClick({ 
        Format-ListView -ListView $AppsLV -ViewName 'Apps' -Column $_.Column 
    })

$TweaksLV.Add_ColumnClick({ 
        Format-ListView -ListView $TweaksLV -ViewName 'Tweaks' -Column $_.Column 
    })

# Populate the ListViews with data from scripts.json
$Scripts = Get-Content "scripts.json" | ConvertFrom-Json
$Scripts.apps | ForEach-Object { 
    $AppsLV.Items.Add($_.content) | Out-Null
    # $AppsLV.Items[$AppsLV.Items.Count - 1].SubItems.Add($_.link) | Out-Null
    $AppsLV.Items[$AppsLV.Items.Count - 1].SubItems.Add($_.description) | Out-Null
}
$Scripts.tweaks | ForEach-Object { 
    $TweaksLV.Items.Add($_.content) | Out-Null 
    $TweaksLV.Items[$TweaksLV.Items.Count - 1].SubItems.Add($_.description) | Out-Null
}

$Form.Controls.AddRange(@($HeaderPanel, $ContentPanel, $FooterPanel))
$Form.Add_Shown({ $Form.Activate() })
[void]$Form.ShowDialog()