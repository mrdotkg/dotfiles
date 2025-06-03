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

# Add sorting function
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
    CheckBoxes    = $true
    Dock          = 'Fill'
    View          = 'Details'
    FullRowSelect = $true
    MultiSelect   = $true
}

$SplitProps = @{
    BackColor        = $AccentColor
    Dock             = 'Fill'
    Orientation      = 'Horizontal'
    SplitterDistance = 50
    SplitterWidth    = 3
    # BorderStyle      = 'None'
}

$Form = New-Object Windows.Forms.Form -Property $FormProps
$AppsLV = New-Object Windows.Forms.ListView -Property $ListViewProps
$TweaksLV = New-Object Windows.Forms.ListView -Property $ListViewProps

$AppsLV.Columns.Add("Applications", 150) | Out-Null
# $AppsLV.Columns.Add("Link", -2) | Out-Null
$AppsLV.Columns.Add("Description", -2) | Out-Null

$TweaksLV.Columns.Add("Tweaks", 150) | Out-Null
$TweaksLV.Columns.Add("Description", -2) | Out-Null

# Add column click handlers
$AppsLV.Add_ColumnClick({ 
        Format-ListView -ListView $AppsLV -ViewName 'Apps' -Column $_.Column 
    })

$TweaksLV.Add_ColumnClick({ 
        Format-ListView -ListView $TweaksLV -ViewName 'Tweaks' -Column $_.Column 
    })
# Add a "Select All" item to both ListViews
$selectAllApps = New-Object Windows.Forms.ListViewItem "Select All"
$selectAllTweaks = New-Object Windows.Forms.ListViewItem "Select All"
$AppsLV.Items.Insert(0, $selectAllApps)
$TweaksLV.Items.Insert(0, $selectAllTweaks)

# Handle checkbox events
$AppsLV.Add_ItemCheck({
        param($sender, $e)
        if ($e.Index -eq 0) {
            $isChecked = $e.NewValue -eq 'Checked'
            for ($i = 1; $i -lt $AppsLV.Items.Count; $i++) {
                $AppsLV.Items[$i].Checked = $isChecked
            }
        }
    })

$TweaksLV.Add_ItemCheck({
        param($sender, $e)
        if ($e.Index -eq 0) {
            $isChecked = $e.NewValue -eq 'Checked'
            for ($i = 1; $i -lt $TweaksLV.Items.Count; $i++) {
                $TweaksLV.Items[$i].Checked = $isChecked
            }
        }
    })
$Split = New-Object Windows.Forms.SplitContainer -Property $SplitProps
$Split.Panel1.Controls.Add($AppsLV)
$Split.Panel2.Controls.Add($TweaksLV)

# Add to variable example:
$ActionButtonProps = @{ 
    Height    = 30
    Text      = "Invoke Selected"
    Font      = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    BackColor = $AccentColor
    ForeColor = [System.Drawing.Color]::White
    FlatStyle = 'Flat'
}
$InvokeButton = [System.Windows.Forms.Button]::new()
$RevokeButton = [System.Windows.Forms.Button]::new()

# Place buttons side by side using a Panel
$ButtonPanel = New-Object Windows.Forms.Panel
$ButtonPanel.Dock = 'Bottom'
$ButtonPanel.Height = 40
$ButtonPanel.Padding = '5,5,5,5'
$ButtonPanel.BorderStyle = 'None'

# Set button widths and positions
$InvokeButton.Width = [math]::Floor(($Form.Width - 30) / 2)
$RevokeButton.Width = $InvokeButton.Width
$InvokeButton.Left = 5
$RevokeButton.Left = $InvokeButton.Right - 1
$InvokeButton.Top = 5
$RevokeButton.Top = 5

# Center the buttons in the ButtonPanel
$ButtonSpacing = 8
$TotalButtonWidth = $InvokeButton.Width + $RevokeButton.Width + $ButtonSpacing
$ButtonPanelWidth = $ButtonPanel.Width
$StartLeft = [math]::Max(5, [math]::Floor(($ButtonPanelWidth - $TotalButtonWidth) / 2))

$ButtonPanel.Controls.AddRange(@($InvokeButton, $RevokeButton))
$InvokeButton | ForEach-Object { foreach ($k in $ActionButtonProps.Keys) { $_.$k = $ActionButtonProps[$k] } }
$InvokeButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(44, 151, 222)
$InvokeButton.FlatAppearance.BorderSize = 0
$InvokeButton.Left = $StartLeft
$RevokeButton.Left = $InvokeButton.Left + $InvokeButton.Width + $ButtonSpacing
$InvokeButton.Top = 5
$RevokeButton.Top = 5

# Set RevokeButton properties (similar to InvokeButton)
$RevokeButtonOptions = $ActionButtonProps.Clone()
$RevokeButtonOptions.Text = "Revoke Selected"
$RevokeButtonOptions.BackColor = [System.Drawing.Color]::FromArgb(200, 60, 60) # Red-ish for revoke
$RevokeButtonOptions.ForeColor = [System.Drawing.Color]::White

$RevokeButton | ForEach-Object { foreach ($k in $RevokeButtonOptions.Keys) { $_.$k = $RevokeButtonOptions[$k] } }
$RevokeButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(200, 60, 60)
$RevokeButton.FlatAppearance.BorderSize = 0

# Adjust position on resize
$ButtonPanel.Add_Resize({
        $ButtonPanelWidth = $ButtonPanel.Width
        $StartLeft = [math]::Max(5, [math]::Floor(($ButtonPanelWidth - $TotalButtonWidth) / 2))
        $InvokeButton.Left = $StartLeft
        $RevokeButton.Left = $InvokeButton.Left + $InvokeButton.Width + $ButtonSpacing / 2
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

$Form.Controls.AddRange(@($ButtonPanel, $Split))
$Form.Add_Shown({ $Form.Activate() })
[void]$Form.ShowDialog()