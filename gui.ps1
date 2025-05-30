Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Responsive WinForm Layout"
$form.Size = New-Object System.Drawing.Size(900, 600)
$form.MinimumSize = New-Object System.Drawing.Size(600, 400)
$form.StartPosition = "CenterScreen"

# Header
$header = New-Object System.Windows.Forms.Panel
$header.Height = 60
$header.Dock = 'Top'
$header.BackColor = [System.Drawing.Color]::SteelBlue

$headerLabel = New-Object System.Windows.Forms.Label
$headerLabel.Text = "Header"
$headerLabel.ForeColor = [System.Drawing.Color]::White
$headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$headerLabel.AutoSize = $true
$headerLabel.Location = New-Object System.Drawing.Point(20, 15)
$header.Controls.Add($headerLabel)

# Footer
$footer = New-Object System.Windows.Forms.Panel
$footer.Height = 40
$footer.Dock = 'Bottom'
$footer.BackColor = [System.Drawing.Color]::LightSteelBlue

$footerLabel = New-Object System.Windows.Forms.Label
$footerLabel.Text = "Footer"
$footerLabel.ForeColor = [System.Drawing.Color]::Black
$footerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$footerLabel.AutoSize = $true
$footerLabel.Location = New-Object System.Drawing.Point(20, 10)
$footer.Controls.Add($footerLabel)

# Left Sidebar (Scrollable)
$leftSidebar = New-Object System.Windows.Forms.Panel
$leftSidebar.Width = 275
$leftSidebar.Dock = 'Left'


$leftSidebar.BackColor = [System.Drawing.Color]::LightGray
$leftSidebar.AutoScroll = $true

$leftLabel = New-Object System.Windows.Forms.Label
$leftLabel.Text = "Select Apps"
$leftLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$leftLabel.AutoSize = $true
$leftLabel.Location = New-Object System.Drawing.Point(20, 20)
$leftSidebar.Controls.Add($leftLabel)

. "$PSScriptRoot\setup.ps1"
$appList = $GlobalAppList
$y = 60
foreach ($app in $appList) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $app
    $cb.Location = New-Object System.Drawing.Point(20, $y)
    $cb.AutoSize = $true
    $y += 25
    $leftSidebar.Controls.Add($cb)
}


# Right Sidebar
$rightSidebar = New-Object System.Windows.Forms.Panel
$rightSidebar.Width = 150
$rightSidebar.Dock = 'Right'
$rightSidebar.BackColor = [System.Drawing.Color]::Gainsboro

$rightLabel = New-Object System.Windows.Forms.Label
$rightLabel.Text = "Right Sidebar"
$rightLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$rightLabel.AutoSize = $true
$rightLabel.Location = New-Object System.Drawing.Point(20, 20)
$rightSidebar.Controls.Add($rightLabel)

# Main Content
$mainContent = New-Object System.Windows.Forms.Panel
$mainContent.Dock = 'Fill'
$mainContent.BackColor = [System.Drawing.Color]::White

$mainLabel = New-Object System.Windows.Forms.Label
$mainLabel.Text = "Select Configuration Options"
$mainLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$mainLabel.AutoSize = $true
$mainLabel.Location = New-Object System.Drawing.Point(30, 20)
$mainContent.Controls.Add($mainLabel)

# List functions defined in setup.ps1
$scriptFunctions = Get-ChildItem function: | Where-Object { $_.ScriptBlock.File -eq "$PSScriptRoot\setup.ps1" }
$funcY = 30
foreach ($func in $scriptFunctions) {
    $funcCheckbox = New-Object System.Windows.Forms.CheckBox
    $funcCheckbox.Text = $func.Name
    $funcCheckbox.Location = New-Object System.Drawing.Point(30, $funcY)
    $funcCheckbox.AutoSize = $true
    $mainContent.Controls.Add($funcCheckbox)
    $funcY += 25
}

# Add controls to form
$form.Controls.Add($mainContent)
$form.Controls.Add($rightSidebar)
$form.Controls.Add($leftSidebar)
$form.Controls.Add($footer)
$form.Controls.Add($header)

# Show the form
[void]$form.ShowDialog()