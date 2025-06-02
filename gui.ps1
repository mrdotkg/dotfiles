$jsonPath = "scripts.json"
$scripts = Get-Content $jsonPath | ConvertFrom-Json
Add-Type -AssemblyName System.Windows.Forms

#  Hardened Values
$formSize = New-Object System.Drawing.Size(300, 600)
$form = New-Object System.Windows.Forms.Form -Property @{
    Text          = "Select Applications to Install"
    Size          = $formSize
    StartPosition = "Manual"
}

# Apps ListView
$appsListView = New-Object System.Windows.Forms.ListView -Property @{
    Dock        = 'Fill'
    View        = 'Details'
    CheckBoxes  = $true
    BorderStyle = 'None'
}
$appsListView.Columns.Add("Applications", -2) | Out-Null

# Tweaks ListView
$tweaksListView = New-Object System.Windows.Forms.ListView -Property @{
    Dock        = 'Fill'
    View        = 'Details'
    CheckBoxes  = $true
    BorderStyle = 'None'
}
$tweaksListView.Columns.Add("Tweaks", -2) | Out-Null

# Create a SplitContainer for horizontal splitting
$splitContainer = New-Object System.Windows.Forms.SplitContainer -Property @{
    Orientation      = [System.Windows.Forms.Orientation]::Horizontal
    Dock             = 'Fill'
    SplitterDistance = 30
}
$splitContainer.Panel1.Controls.Add($appsListView)
$splitContainer.Panel2.Controls.Add($tweaksListView)

# Create "Invoke Script" button
$invokeButton = New-Object System.Windows.Forms.Button -Property @{
    Text      = "Invoke Script"
    Dock      = "Bottom"
    Size      = New-Object System.Drawing.Size(120, 30)
    BackColor = [System.Drawing.Color]::LightGreen
}

# Create "Undo Script" button
$undoButton = New-Object System.Windows.Forms.Button -Property @{
    Text      = "Undo Script"
    Size      = New-Object System.Drawing.Size(120, 30)
    Dock      = "Bottom"
    BackColor = [System.Drawing.Color]::LightCoral

}

# Add button click event handlers
$invokeButton.Add_Click({
        # Run scripts for selected apps
        foreach ($item in $appsListView.CheckedItems) {
            $app = $scripts.apps | Where-Object { $_.content -eq $item.Text }
            if ($app -and $app.script) {
                Invoke-Expression $app.script
            }
        }
        # Run scripts for selected tweaks
        foreach ($item in $tweaksListView.CheckedItems) {
            $tweak = $scripts.tweaks | Where-Object { $_.content -eq $item.Text }
            if ($tweak -and $tweak.script) {
                Invoke-Expression $tweak.script
            }
        }
    })

$undoButton.Add_Click({
        # Run undo scripts for selected apps
        foreach ($item in $appsListView.CheckedItems) {
            $app = $scripts.apps | Where-Object { $_.content -eq $item.Text }
            if ($app -and $app.undo) {
                Invoke-Expression $app.undo
            }
        }
        # Run undo scripts for selected tweaks
        foreach ($item in $tweaksListView.CheckedItems) {
            $tweak = $scripts.tweaks | Where-Object { $_.content -eq $item.Text }
            if ($tweak -and $tweak.undo) {
                Invoke-Expression $tweak.undo
            }
        }
    })

$form.Controls.Add($invokeButton)
$form.Controls.Add($undoButton)

$form.Controls.Add($splitContainer)
$form.Topmost = $true
$form.Add_Shown({ $form.Activate() })

foreach ($app in $scripts.apps) {
    $item = New-Object System.Windows.Forms.ListViewItem($app.content)
    $appsListView.Items.Add($item) | Out-Null
}

foreach ($tweak in $scripts.tweaks) {
    $item = New-Object System.Windows.Forms.ListViewItem($tweak.content)
    $tweaksListView.Items.Add($item) | Out-Null
}

[void]$form.ShowDialog()
