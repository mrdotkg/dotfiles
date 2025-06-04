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
    Size          = '400,600'
    StartPosition = "CenterParent"
    Text          = "Gandalf's WinUtil"
    Topmost       = $true
    Padding       = '10,0,10,0'
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
    Padding       = '20,20,20,20'
}

$SplitProps = @{
    BackColor        = $AccentColor
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

$ContentPanelProps = @{
    Dock      = 'Fill'
    Padding   = '0,0,0,0'
    BackColor = [System.Drawing.Color]::White
}

$FooterPanelProps = @{
    Dock        = 'Bottom'
    Height      = 50
    BackColor   = [System.Drawing.Color]::FromArgb(245, 245, 245)
    Padding     = '5,5,5,10'
    BorderStyle = 'None'
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

########################
## GUI Initialization ##
########################

$Form = New-Object Windows.Forms.Form -Property $FormProps

# Create a responsive layout: main content area and footer
$ContentPanel = New-Object Windows.Forms.Panel -Property $ContentPanelProps
$FooterPanel = New-Object Windows.Forms.Panel -Property $FooterPanelProps

# Separate the Content Panel horizontally with a Splitter bar
$Split = New-Object Windows.Forms.SplitContainer -Property $SplitProps

# Append ListViews to both sides of the Splitter bar
$AppsLV = New-Object Windows.Forms.ListView -Property $ListViewProps
$TweaksLV = New-Object Windows.Forms.ListView -Property $ListViewProps
$Split.Panel1.Controls.Add($AppsLV)
$Split.Panel2.Controls.Add($TweaksLV)

# Add Split (with ListViews) to content area, and ButtonPanel to footer
$ContentPanel.Controls.Add($Split)

$InvokeButton = New-ActionButton -Text "Invoke Selected" -BackColor $AccentColor -BorderColor ([System.Drawing.Color]::FromArgb(44, 151, 222))
$RevokeButton = New-ActionButton -Text "Revoke Selected" -BackColor ([System.Drawing.Color]::FromArgb(200, 60, 60)) -BorderColor ([System.Drawing.Color]::FromArgb(200, 60, 60))
foreach ($k in $InvokeButtonProps.Keys) { $InvokeButton.$k = $InvokeButtonProps[$k] }
foreach ($k in $RevokeButtonProps.Keys) { $RevokeButton.$k = $RevokeButtonProps[$k] }
# Attach actions to buttons
$InvokeButton.Add_Click({
        # Skip "Select All" item and process only actual apps
        $selectedApps = $AppsLV.CheckedItems | Where-Object { $_.Text -ne "Select All" }
        $selectedTweaks = $TweaksLV.CheckedItems | Where-Object { $_.Text -ne "Select All" }

        foreach ($i in $selectedApps) { 
            ($Scripts.apps | Where-Object { $_.content -eq $i.Text }).script | 
            ForEach-Object { Write-Host "Executing App:" $i } 
        }
        foreach ($i in $selectedTweaks) { 
            ($Scripts.tweaks | Where-Object { $_.content -eq $i.Text }).script | 
            ForEach-Object { Write-Host "Executing Tweak:" $i } 
        }
    })

$RevokeButton.Add_Click({
        # Skip "Select All" item and process only actual items
        $selectedApps = $AppsLV.CheckedItems | Where-Object { $_.Text -ne "Select All" }
        $selectedTweaks = $TweaksLV.CheckedItems | Where-Object { $_.Text -ne "Select All" }

        foreach ($i in $selectedApps) { 
            ($Scripts.apps | Where-Object { $_.content -eq $i.Text }).Revoke | 
            ForEach-Object { Write-Host "Revoking App:" $i } 
        }
        foreach ($i in $selectedTweaks) { 
            ($Scripts.tweaks | Where-Object { $_.content -eq $i.Text }).Revoke | 
            ForEach-Object { Write-Host "Revoking Tweak:" $i } 
        }
    })

# Adjust position on resize
$FooterPanel.Add_Resize({
        $FooterPanelWidth = $FooterPanel.Width
        $ButtonSpacing = 8
        $TotalButtonWidth = $InvokeButton.Width + $RevokeButton.Width + $ButtonSpacing
        Write-Host "FooterPanel resized: Width=$FooterPanelWidth, TotalButtonWidth=$TotalButtonWidth"
        $StartLeft = [math]::Max(5, [math]::Floor(($FooterPanelWidth - $TotalButtonWidth) / 2))
        $InvokeButton.Left = $StartLeft
        $RevokeButton.Left = $InvokeButton.Left + $InvokeButton.Width + $ButtonSpacing / 2
    })
$FooterPanel.Controls.AddRange(@($InvokeButton, $RevokeButton))

$AppsLV.Columns.Add("Applications", 150) | Out-Null
# $AppsLV.Columns.Add("Link", -2) | Out-Null
$AppsLV.Columns.Add("Description", -2) | Out-Null

$TweaksLV.Columns.Add("Tweaks", 150) | Out-Null
$TweaksLV.Columns.Add("Description", -2) | Out-Null


# Add a "Select All" item to both ListViews
$AppsLV.Items.Add("Select All") | Out-Null
$TweaksLV.Items.Add("Select All") | Out-Null

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

$Form.Controls.AddRange(@($ContentPanel, $FooterPanel))
$Form.Add_Shown({ $Form.Activate() })
[void]$Form.ShowDialog()