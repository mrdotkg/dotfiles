Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Enable high DPI awareness for better scaling on modern displays
if ([Environment]::OSVersion.Version.Major -ge 6) {
    try { 
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
        [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2)
    }
    catch {}
}
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($true)

# Set the accent color based on the current Windows theme
$accentColorValue = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AccentColor" -ErrorAction SilentlyContinue
if ($accentColorValue) {
    $a = ($accentColorValue -band 0xFF000000) -shr 24
    $b = ($accentColorValue -band 0x00FF0000) -shr 16
    $g = ($accentColorValue -band 0x0000FF00) -shr 8
    $r = ($accentColorValue -band 0x000000FF)
    $accentColor = [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}
else {
    $accentColor = [System.Drawing.Color]::FromArgb(44, 151, 222)
}

# Full layout
$form = New-Object System.Windows.Forms.Form
$form.MinimizeBox = $false
$form.MaximizeBox = $false
$form.FormBorderStyle = 'FixedDialog'
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot\gandalf.ico")
$form.Text = "Gandalf - WinUtil"
$form.Size = $form.MinimumSize = New-Object System.Drawing.Size(300, 650)
$form.StartPosition = "CenterScreen"

# Split the page horizontally into two panels
$splitContainer = New-Object System.Windows.Forms.SplitContainer
$splitContainer.SplitterWidth = 2
$splitContainer.BackColor = $accentColor
$splitContainer.BorderStyle = 'None'
$splitContainer.Dock = 'Fill'
$splitContainer.Orientation = 'Horizontal'
$splitContainer.SplitterDistance = 60
$form.Controls.Add($splitContainer)

# Top panel for Apps installation
$appsPanel = New-Object System.Windows.Forms.Panel
$appsPanel.Dock = 'Fill'
$splitContainer.Panel1.Controls.Add($appsPanel)
$splitContainer.Panel1MinSize = 100
$appOptions = New-Object System.Windows.Forms.ListView
$appOptions.Dock = 'Fill'
$appOptions.View = [System.Windows.Forms.View]::Details
$appOptions.CheckBoxes = $true
$appOptions.FullRowSelect = $true
$appOptions.BorderStyle = 'None'
$appOptions.Columns.Add("Apps", 260)
$appsPanel.Controls.Add($appOptions)

# Bottom panel for Config options
$configPanel = New-Object System.Windows.Forms.Panel
$configPanel.Dock = 'Fill'
$splitContainer.Panel2.Controls.Add($configPanel)
$configOptions = New-Object System.Windows.Forms.ListView
$configOptions.Dock = 'Fill'
$configOptions.View = [System.Windows.Forms.View]::Details
$configOptions.CheckBoxes = $true
$configOptions.FullRowSelect = $true
$configOptions.BorderStyle = 'None'
$configOptions.Columns.Add("Config", 260)
$configPanel.Controls.Add($configOptions)

# Load applications from the script file
$scriptFile = "$PSScriptRoot\script.ps1"
. $scriptFile
foreach ($app in $GlobalAppList) {
    $itemText = if ($app -is [string]) { $app } elseif ($app.PSObject.Properties['Name']) { $app.Name } else { $app.ToString() }
    $appOptions.Items.Add((New-Object System.Windows.Forms.ListViewItem($itemText)))
}
# Load configuration options from the script file
$scriptFunctions = Get-ChildItem function: | Where-Object { $_.ScriptBlock.File -eq $scriptFile }
foreach ($func in $scriptFunctions) {
    $configOptions.Items.Add((New-Object System.Windows.Forms.ListViewItem($func.Name)))
}

# Execute all selected actions when the button is clicked
$runButton = New-Object System.Windows.Forms.Button
$runButton.Dock = 'Bottom'
$runButton.Height = 30
$runButton.Text = "Run Selected Actions"
$runButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$runButton.BackColor = $accentColor
$runButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(44, 151, 222)
$runButton.FlatAppearance.BorderSize = 0
$runButton.ForeColor = [System.Drawing.Color]::White
$runButton.FlatStyle = 'Flat'
$runButton.Add_Click({
        $selectedApps = $appOptions.CheckedItems | ForEach-Object { $_.Text }
        $selectedConfigs = $configOptions.CheckedItems | ForEach-Object { $_.Text }
        $msg = "Selected Applications:`n" + ($selectedApps -join "`n") + "`n`nSelected Config Options:`n" + ($selectedConfigs -join "`n")
        [System.Windows.Forms.MessageBox]::Show($msg, "Selections")
    })
$form.Controls.Add($runButton)

[void]$form.ShowDialog()
