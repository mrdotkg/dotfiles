Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$formProperties = @{
    Text          = "Setup Wizard"
    Size          = New-Object System.Drawing.Size(600, 400)
    StartPosition = "CenterScreen"
}
$form = New-Object System.Windows.Forms.Form -Property $formProperties

# Title Panel
$titlePanel = New-Object System.Windows.Forms.Panel -Property @{
    Dock      = 'Top'
    Height    = 100
    BackColor = [System.Drawing.Color]::LightSteelBlue
}
$titleLabel = New-Object System.Windows.Forms.Label -Property @{
    Text     = "Dotfiles Setup"
    Font     = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    AutoSize = $true
    Location = New-Object System.Drawing.Point(20, 20)
}
$descLabel = New-Object System.Windows.Forms.Label -Property @{
    Text     = "Select the dotfiles you want to install/uninstall"
    Font     = New-Object System.Drawing.Font("Segoe UI", 10)
    AutoSize = $true
    Location = New-Object System.Drawing.Point(20, 60)
}
$titlePanel.Controls.AddRange(@($titleLabel, $descLabel))

# Checkbox Panel
$checkboxPanel = [System.Windows.Forms.Panel]@{
    Dock       = 'Fill'
    Height     = 350
    BackColor  = [System.Drawing.Color]::LightSteelBlue
    AutoScroll = $true
}
# Get the directory where the script is located
$currentDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Find all directories in the root of the current directory
$emptyDirs = Get-ChildItem -Path $currentDir -Directory

# Starting coordinates for checkboxes within the panel
$startX = 20
$startY = 5
$verticalSpacing = 30
$horizontalSpacing = 120
$index = 0
$columns = 4

foreach ($dir in $emptyDirs) {
    $column = $index % $columns
    $row = [math]::Floor($index / $columns)
    $xPos = $startX + ($column * $horizontalSpacing)
    $yPos = $startY + ($row * $verticalSpacing)
    $checkbox = New-Object System.Windows.Forms.CheckBox -Property @{
        Text     = $dir.Name
        AutoSize = $true
        Location = New-Object System.Drawing.Point($xPos, $yPos)
    }
    
    $checkboxPanel.Controls.Add($checkbox)
    $index++
}
$buttonPanel = New-Object System.Windows.Forms.Panel -Property @{
    Dock   = 'Bottom'
    Height = 50
}
$selectAll = New-Object System.Windows.Forms.Button -Property @{
    Text     = "Select All"
    Size     = New-Object System.Drawing.Size(80, 30)
    Location = New-Object System.Drawing.Point(20, 10)
}
$selectAll.Add_Click({
        foreach ($control in $checkboxPanel.Controls) {
            if ($control -is [System.Windows.Forms.CheckBox]) {
                $control.Checked = $true
            }
        }
    })
$unselectAll = New-Object System.Windows.Forms.Button -Property @{
    Text     = "Unselect All"
    Size     = New-Object System.Drawing.Size(80, 30)
    Location = New-Object System.Drawing.Point(120, 10)
}
$unselectAll.Add_Click({
        foreach ($control in $checkboxPanel.Controls) {
            if ($control -is [System.Windows.Forms.CheckBox]) {
                $control.Checked = $false
            }
        }
    })
function Get-SelectedItems {
    return $checkboxPanel.Controls | Where-Object {
        $_ -is [System.Windows.Forms.CheckBox] -and $_.Checked
    } | ForEach-Object { $_.Text }
}
function Install-SelectedItems {
    $selectedItems = Get-SelectedItems
    if ($selectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No dotfiles selected.", "Install", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
    else {
        $msg = "Installing selected dotfiles:`n" + ($selectedItems -join "`n")
        [System.Windows.Forms.MessageBox]::Show($msg, "Install", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    
        foreach ($item in $selectedItems) {
            $installScript = Join-Path -Path $currentDir -ChildPath "$item/install.ps1"
            if (Test-Path $installScript) {
                # Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File $installScript" -Wait
            }
            else {
                Write-Host "No installation script found for $item"
            }
        }
    }
    
}
function Uninstall-SelectedItems {
    $selectedItems = Get-SelectedItems
    if ($selectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No dotfiles selected.", "Uninstall", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
    else {
        $msg = "Uninstalling selected dotfiles:`n" + ($selectedItems -join "`n")
        [System.Windows.Forms.MessageBox]::Show($msg, "Uninstall", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        
        foreach ($item in $selectedItems) {
            $uninstallScript = Join-Path -Path $currentDir -ChildPath "$item/uninstall.ps1"
            if (Test-Path $uninstallScript) {
                # Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File $uninstallScript" -Wait
            }
            else {
                Write-Host "No uninstallation script found for $item"
            }
        }
    }
}
function GitBackup {
    param (
        [string]$itemDir
    )
    Set-Location -Path $itemDir
    git add .
    git commit -m "Backup of $itemDir"
    git push
}
$installButton = New-Object System.Windows.Forms.Button -Property @{
    Text     = "Install"
    Size     = New-Object System.Drawing.Size(80, 30)
    Location = New-Object System.Drawing.Point(300, 10)
}
$installButton.Add_Click({ Install-SelectedItems })

$uninstallButton = New-Object System.Windows.Forms.Button -Property @{
    Text     = "Uninstall"
    Size     = New-Object System.Drawing.Size(80, 30)
    Location = New-Object System.Drawing.Point(400, 10)
}
$uninstallButton.Add_Click({ Uninstall-SelectedItems })
$backupButton = New-Object System.Windows.Forms.Button -Property @{
    Text     = "Backup"
    Size     = New-Object System.Drawing.Size(80, 30)
    Location = New-Object System.Drawing.Point(500, 10)
}
$backupButton.Add_Click({
        $selectedItems = Get-SelectedItems
        if ($selectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No dotfiles selected.", "Backup", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
        else {
            $msg = "Backing up selected dotfiles:`n" + ($selectedItems -join "`n")
            [System.Windows.Forms.MessageBox]::Show($msg, "Backup", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        
            foreach ($item in $selectedItems) {
                $itemDir = Join-Path -Path $currentDir -ChildPath "$item"
                GitBackup -itemDir $itemDir
            }
        }
    })
$buttonPanel.Controls.Add($backupButton)

$buttonPanel.Controls.AddRange(@($selectAll, $unselectAll, $installButton, $backupButton , $uninstallButton))

$form.Controls.AddRange(@($titlePanel, $checkboxPanel, $buttonPanel))

$form.Add_Shown({ $form.Activate() })
[System.Windows.Forms.Application]::Run($form)