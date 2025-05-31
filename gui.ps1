Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.MinimizeBox = $false
$form.MaximizeBox = $false
$form.FormBorderStyle = 'FixedDialog'

$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot\gandalf.ico")

$form.Text = "Gandalf - WinUtil"
$form.Size = New-Object System.Drawing.Size(300, 600)
$form.MinimumSize = New-Object System.Drawing.Size(300, 600)
$form.StartPosition = "CenterScreen"

# Create a split container
$splitContainer = New-Object System.Windows.Forms.SplitContainer
$splitContainer.Dock = 'Fill'
$splitContainer.Orientation = 'Horizontal'
$splitContainer.SplitterDistance = 60
$form.Controls.Add($splitContainer)

# Left Panel: Applications List
$appsPanel = New-Object System.Windows.Forms.Panel

$appsPanel.Dock = 'Fill'
$splitContainer.Panel1.Controls.Add($appsPanel)

$appOptions = New-Object System.Windows.Forms.ListView
$appOptions.Dock = 'Fill'
$appOptions.Location = New-Object System.Drawing.Point(10, 40)
$appOptions.View = [System.Windows.Forms.View]::Details
$appOptions.CheckBoxes = $true
$appOptions.FullRowSelect = $true
$appOptions.HideSelection = $false
$appOptions.Columns.Add("Applications", -2)
$appsPanel.Controls.Add($appOptions)

# Right Panel: Configuration Options
$configPanel = New-Object System.Windows.Forms.Panel
$configPanel.Dock = 'Fill'
# $configPanel.Padding = New-Object System.Windows.Forms.Padding(10)
$splitContainer.Panel2.Controls.Add($configPanel)

$configOptions = New-Object System.Windows.Forms.ListView
$configOptions.Dock = 'Fill'
$configOptions.Location = New-Object System.Drawing.Point(10, 40)
$configOptions.View = [System.Windows.Forms.View]::Details
$configOptions.CheckBoxes = $true
$configOptions.FullRowSelect = $true
$configOptions.HideSelection = $false
$configOptions.Columns.Add("Configuration Options", -2)
$configPanel.Controls.Add($configOptions)

# Add apps to list
$scriptFile = "$PSScriptRoot\script.ps1"
. $scriptFile
foreach ($app in $GlobalAppList) {
    $itemText = ""
    if ($app -is [string]) {
        $itemText = $app
    }
    elseif ($app.PSObject.Properties['Name']) {
        $itemText = $app.Name
    }
    else {
        $itemText = $app.ToString()
    }
    $item = New-Object System.Windows.Forms.ListViewItem($itemText)
    $appOptions.Items.Add($item)
}

# Add configuration options
$scriptFunctions = Get-ChildItem function: | Where-Object { $_.ScriptBlock.File -eq $scriptFile }
foreach ($func in $scriptFunctions) {
    $item = New-Object System.Windows.Forms.ListViewItem($func.Name)
    $configOptions.Items.Add($item)
}

# Action Button
$runButton = New-Object System.Windows.Forms.Button
$runButton.Dock = 'Bottom'
$runButton.Height = 30
$runButton.Text = "▶▶▶ Run Selected Actions"
$runButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
# Get Windows accent color from registry and set as button BackColor
$accentColorValue = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AccentColor" -ErrorAction SilentlyContinue
if ($accentColorValue) {
    # AccentColor is in ABGR format, need to convert to ARGB
    $a = ($accentColorValue -band 0xFF000000) -shr 24
    $b = ($accentColorValue -band 0x00FF0000) -shr 16
    $g = ($accentColorValue -band 0x0000FF00) -shr 8
    $r = ($accentColorValue -band 0x000000FF)
    $runButton.BackColor = [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}
else {
    $runButton.BackColor = [System.Drawing.Color]::FromArgb(44, 151, 222)
}
$runButton.ForeColor = [System.Drawing.Color]::White
$runButton.FlatStyle = 'Flat'
$runButton.FlatAppearance.BorderSize = 0

$runButton.Add_Click({
        $selectedApps = $appOptions.CheckedItems | ForEach-Object { $_.Text }
        $selectedConfigs = $configOptions.CheckedItems | ForEach-Object { $_.Text }
        $msg = "Selected Applications:`n" + ($selectedApps -join "`n") + "`n`nSelected Config Options:`n" + ($selectedConfigs -join "`n")
        [System.Windows.Forms.MessageBox]::Show($msg, "Selections")
    })

$form.Controls.Add($runButton)
# Show the form
[void]$form.ShowDialog()
