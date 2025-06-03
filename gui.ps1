Add-Type -AssemblyName System.Windows.Forms

# Add sorting variables
$script:LastColumnClicked = @{
    Apps   = 0
    Tweaks = 0
}
$script:LastColumnAscending = @{
    Apps   = $true
    Tweaks = $true
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

$Form = New-Object Windows.Forms.Form -Property @{ Text = "Dot's WinUtil"; Size = '300,600'; Topmost = $true; StartPosition = 'CenterScreen' }
$ListViewProps = @{ Dock = 'Fill'; View = 'Details'; CheckBoxes = $true; BorderStyle = 'None' }
$AppsLV = New-Object Windows.Forms.ListView -Property $ListViewProps
$TweaksLV = New-Object Windows.Forms.ListView -Property $ListViewProps

$AppsLV.Columns.Add("Applications") | Out-Null
$AppsLV.Columns.Add("Description") | Out-Null
$AppsLV.Columns.Add("Link") | Out-Null

$TweaksLV.Columns.Add("Tweaks") | Out-Null

# Add column click handlers
$AppsLV.Add_ColumnClick({ 
        Format-ListView -ListView $AppsLV -ViewName 'Apps' -Column $_.Column 
    })

$TweaksLV.Add_ColumnClick({ 
        Format-ListView -ListView $TweaksLV -ViewName 'Tweaks' -Column $_.Column 
    })

$Split = New-Object Windows.Forms.SplitContainer -Property @{ Orientation = 'Horizontal'; Dock = 'Fill'; SplitterDistance = 30; }
$Split.Panel1.Controls.Add($AppsLV)
$Split.Panel2.Controls.Add($TweaksLV)

$InvokeButton = New-Object Windows.Forms.Button -Property @{ Text = "INVOKE Selected Actions"; Dock = "Bottom"; BackColor = 'LightGreen' }
$UndoButton = New-Object Windows.Forms.Button -Property @{ Text = "REVOKE Selected Actions"; Dock = "Bottom"; BackColor = 'LightCoral' }

# Populate the ListViews with data from scripts.json
$Scripts = Get-Content "scripts.json" | ConvertFrom-Json
$Scripts.apps | ForEach-Object { $AppsLV.Items.Add($_.content) | Out-Null }
$Scripts.tweaks | ForEach-Object { $TweaksLV.Items.Add($_.content) | Out-Null }

# Attach actions to buttons
$InvokeButton.Add_Click({
        foreach ($i in $AppsLV.CheckedItems) { ($Scripts.apps | Where-Object { $_.content -eq $i.Text }).script | ForEach-Object { Invoke-Expression $_ } }
        foreach ($i in $TweaksLV.CheckedItems) { ($Scripts.tweaks | Where-Object { $_.content -eq $i.Text }).script | ForEach-Object { Invoke-Expression $_ } }
    })
$UndoButton.Add_Click({
        foreach ($i in $AppsLV.CheckedItems) { ($Scripts.apps | Where-Object { $_.content -eq $i.Text }).undo | ForEach-Object { Invoke-Expression $_ } }
        foreach ($i in $TweaksLV.CheckedItems) { ($Scripts.tweaks | Where-Object { $_.content -eq $i.Text }).undo | ForEach-Object { Invoke-Expression $_ } }
    })

$Form.Controls.AddRange(@($InvokeButton, $UndoButton, $Split))
$Form.Add_Shown({ $Form.Activate() })
[void]$Form.ShowDialog()