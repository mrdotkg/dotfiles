Add-Type -AssemblyName System.Drawing, System.Windows.Forms
if ([Environment]::OSVersion.Version.Major -ge 6) {
    try { [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2) } catch {}
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

$appsScript = "$PSScriptRoot\apps.ps1"
$configScript = "$PSScriptRoot\config.ps1"

# Form options
$formOptions = @{
    MinimizeBox     = $false
    MaximizeBox     = $false
    FormBorderStyle = 'FixedDialog'
    Icon            = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot\gandalf.ico")
    Text            = "Gandalf - WinUtil"
    Size            = [System.Drawing.Size]::new(300, 650)
    MinimumSize     = [System.Drawing.Size]::new(300, 650)
    StartPosition   = "CenterScreen"
}
$form = [System.Windows.Forms.Form]::new()
$form | ForEach-Object { foreach ($k in $formOptions.Keys) { $_.$k = $formOptions[$k] } }

# SplitContainer options
$splitOptions = @{
    SplitterWidth    = 2
    BackColor        = $accentColor
    BorderStyle      = 'None'
    Dock             = 'Fill'
    Orientation      = 'Horizontal'
    SplitterDistance = 60
}
$splitContainer = [System.Windows.Forms.SplitContainer]::new()
$splitContainer | ForEach-Object { foreach ($k in $splitOptions.Keys) { $_.$k = $splitOptions[$k] } }
$form.Controls.Add($splitContainer)

# Apps Panel
$appsPanel = [System.Windows.Forms.Panel]::new()
$appsPanel.Dock = 'Fill'
$splitContainer.Panel1.Controls.Add($appsPanel)
$splitContainer.Panel1MinSize = 100

# Apps ListView
$appOptions = [System.Windows.Forms.ListView]::new()
$appListViewOptions = @{
    Dock          = 'Fill'
    View          = [System.Windows.Forms.View]::Details
    CheckBoxes    = $true
    FullRowSelect = $true
    BorderStyle   = 'None'
}
$appOptions | ForEach-Object { foreach ($k in $appListViewOptions.Keys) { $_.$k = $appListViewOptions[$k] } }
$appOptions.Columns.Add("Apps", 260)
$appsPanel.Controls.Add($appOptions)

# Config Panel
$configPanel = [System.Windows.Forms.Panel]::new()
$configPanel.Dock = 'Fill'
$splitContainer.Panel2.Controls.Add($configPanel)

# Config ListView
$configOptions = [System.Windows.Forms.ListView]::new()
$configListViewOptions = @{
    Dock          = 'Fill'
    View          = [System.Windows.Forms.View]::Details
    CheckBoxes    = $true
    FullRowSelect = $true
    BorderStyle   = 'None'
}
$configOptions | ForEach-Object { foreach ($k in $configListViewOptions.Keys) { $_.$k = $configListViewOptions[$k] } }
$configOptions.Columns.Add("Config", 260)
$configPanel.Controls.Add($configOptions)

# Populate Apps checkboxes as the list of applications mentioned in the script file
. $appsScript
$appList = $AppList
foreach ($app in $appList) {
    $itemText = if ($app -is [string]) { $app } elseif ($app.PSObject.Properties['Name']) { $app.Name } else { $app.ToString() }
    $appOptions.Items.Add([System.Windows.Forms.ListViewItem]::new($itemText))
}
# Load configuration options from the script file
. $configScript
$scriptFunctions = Get-ChildItem function: | Where-Object { $_.ScriptBlock.File -eq $configScript }
foreach ($config in $scriptFunctions) {
    $configOptions.Items.Add([System.Windows.Forms.ListViewItem]::new($config.Name))
}

# Run Button
$runButtonOptions = @{
    Dock      = 'Bottom'
    Height    = 30
    Text      = "Run Selected Actions"
    Font      = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    BackColor = $accentColor
    ForeColor = [System.Drawing.Color]::White
    FlatStyle = 'Flat'
}
$runButton = [System.Windows.Forms.Button]::new()
$runButton | ForEach-Object { foreach ($k in $runButtonOptions.Keys) { $_.$k = $runButtonOptions[$k] } }
$runButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(44, 151, 222)
$runButton.FlatAppearance.BorderSize = 0
$runButton.Add_Click({
        $selectedApps = $appOptions.CheckedItems | ForEach-Object { $_.Text }
        Install-Apps -Apps $selectedApps

        $selectedConfigs = $configOptions.CheckedItems | ForEach-Object { $_.Text }
        foreach ($config in $selectedConfigs) {
            if (Get-Command -Name $config -ErrorAction SilentlyContinue) {
                & $config
            }
            else {
                Write-Warning "Configuration function '$($config)' not found."
            }
        }
    })
$form.Controls.Add($runButton)
$form.Controls.Add($runButton)

[void]$form.ShowDialog()
