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
    $AccentColor = [System.Drawing.Color]::FromArgb(
        ($AccentColorValue -band 0xFF000000) -shr 24, 
        ($AccentColorValue -band 0x000000FF), 
        ($AccentColorValue -band 0x0000FF00) -shr 8, 
        ($AccentColorValue -band 0x00FF0000) -shr 16)
}
else {
    $AccentColor = [System.Drawing.Color]::FromArgb(44, 151, 222)
}

# Define properties for the main form and controls
$FormProps = @{
    Icon          = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot\gandalf.ico")
    Size          = '600,700'
    StartPosition = "CenterParent"
    Text          = "Gandalf's WinUtil"
    BackColor     = [System.Drawing.Color]::white
    Font          = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)

    Add_Shown     = {
        $Form.Activate()
    }
}

$ListViewProps = @{
    BorderStyle      = 'None'
    CheckBoxes       = $true
    Font             = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    Dock             = 'Fill'
    View             = 'Details'
    FullRowSelect    = $true
    MultiSelect      = $true
    BackColor        = [System.Drawing.Color]::FromArgb(241, 243, 249)
    ShowItemToolTips = $true

    # Add column click event to sort items
    Add_ColumnClick  = {
        param($sender, $e)
        $ListView = $sender
        $columnIndex = $e.Column
        $viewName = switch ($ListView) {
            $AppsLV { 'Apps' }
            $TweaksLV { 'Tweaks' }
            $TasksLV { 'Tasks' }
        }
        Format-ListView -ListView $ListView -ViewName $viewName -Column $columnIndex
    }
}

$SplitProps = @{
    BackColor        = [System.Drawing.Color]::White
    Dock             = 'Fill'
    Orientation      = 'Horizontal'
    SplitterDistance = 50
    SplitterWidth    = 3
    BorderStyle      = 'None'
    Padding          = '0,0,0,20'
    Panel1MinSize    = 50
    Panel2MinSize    = 30
}

$HeaderPanelProps = @{
    Height    = 40
    Dock      = 'Top'
    Padding   = '15,7,15,7'
    BackColor = [System.Drawing.Color]::FromArgb(241, 243, 249)
    Font      = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
}

$ContentPanelProps = @{
    Dock      = 'Fill'
    Padding   = '10,40,10,10'
    BackColor = [System.Drawing.Color]::FromArgb(241, 243, 249)
}

$FooterPanelProps = @{
    Dock        = 'Bottom'
    Height      = 50
    BackColor   = [System.Drawing.Color]::FromArgb(241, 243, 249)
    Padding     = '15,5,10,10'
    BorderStyle = 'None'
}

$InputWidth = 150
$InputHeight = 30
$SelectAllSwitchProps = @{
    Text               = "Select All"
    Width              = 100
    Height             = 30
    Dock               = 'Left'
    Font               = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    BackColor          = [System.Drawing.Color]::FromArgb(241, 243, 249)
    ForeColor          = [System.Drawing.Color]::Black
    
    Add_CheckedChanged = {
        $isChecked = $SelectAllSwitch.Checked
        $AppsLV.Items | ForEach-Object { $_.Checked = $isChecked }
        $TweaksLV.Items | ForEach-Object { $_.Checked = $isChecked }
        $TasksLV.Items | ForEach-Object { $_.Checked = $isChecked }

    }
}

$ProfileDropdownProps = @{
    Width                    = $InputWidth
    Height                   = $InputHeight
    Left                     = 15
    Font                     = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    ForeColor                = [System.Drawing.Color]::FromArgb(100, 100, 100)
    DropDownStyle            = 'DropDownList'
    Add_SelectedIndexChanged = ({
            $selectedFile = $ProfileDropdown.SelectedItem
            if ($selectedFile) {
                # Load the selected script JSON file
                $SelectedFilePath = "$HOME\Documents\Gandalf-WinUtil-Scripts\$selectedFile.json"
                if (Test-Path $SelectedFilePath) {
                    $Scripts = Get-Content $SelectedFilePath | ConvertFrom-Json

                    # Clear existing items in ListViews
                    $AppsLV.Items.Clear()
                    $TweaksLV.Items.Clear()
                    $TasksLV.Items.Clear()

                    # Populate ListViews with new data
                    $Scripts.apps | ForEach-Object { 
                        $AppsLV.Items.Add($_.content) | Out-Null
                        $AppsLV.Items[$AppsLV.Items.Count - 1].SubItems.Add($_.description) | Out-Null
                    }
                    $Scripts.tweaks | ForEach-Object { 
                        $TweaksLV.Items.Add($_.content) | Out-Null 
                        $TweaksLV.Items[$TweaksLV.Items.Count - 1].SubItems.Add($_.description) | Out-Null
                    }
                    $Scripts.tasks | ForEach-Object { 
                        $TasksLV.Items.Add($_.content) | Out-Null 
                        $TasksLV.Items[$TasksLV.Items.Count - 1].SubItems.Add($_.description) | Out-Null
                    }
                }
                else {
                    Write-Warning "Selected file '$SelectedFilePath' does not exist."
                }
            }
        })

}

$SearchBoxProps = @{
    Height          = $InputHeight
    Width           = $InputWidth
    Font            = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    ForeColor       = [System.Drawing.Color]::FromArgb(100, 100, 100)
    PlaceholderText = " Search..."
    TextAlign       = 'Left'
    Multiline       = $false
    Left            = 150 + 20
    Top             = 7
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
    Width     = $InputWidth
    Text      = "Run Selected Actions"
    Dock      = 'Right'
    BackColor = $AccentColor
    ForeColor = [System.Drawing.Color]::White
    Font      = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    FlatStyle = 'Flat'

    Add_Click = {
        RunSelectedItems -Action Invoke
    }
}

$BrowseLibraryProps = @{
    Text      = "Browse Plugins Online"
    Width     = $InputWidth
    Height    = $InputHeight
    Dock      = 'Right'
    Font      = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    Add_Click = {
        # Open Another window and load a checkbox list view with all the json files in the repository mrdotkg/dotfiles/
        $repoUrl = "https://api.github.com/repos/mrdotkg/dotfiles/contents"
        $response = Invoke-WebRequest -Uri $repoUrl -UseBasicParsing
        $content = ConvertFrom-Json $response.Content

        $CheckboxForm = New-Object System.Windows.Forms.Form
        $CheckboxForm.Text = "Select plugins to download"
        $CheckboxForm.Size = New-Object System.Drawing.Size(400, 300)
        $CheckboxForm.StartPosition = "CenterParent"
        $CheckboxForm.MaximizeBox = $false
        $CheckboxForm.MinimizeBox = $false

        $CheckboxList = New-Object System.Windows.Forms.CheckedListBox
        $CheckboxList.Dock = 'Fill'

        foreach ($item in $content) {
            if ($item.type -eq "file" -and $item.name -like "*.json") {
                $CheckboxList.Items.Add($item.name)
            }
        }

        # Add a button to download selected files into the user's personal scripts folder
        $DownloadButton = New-Object System.Windows.Forms.Button -Property @{
            Text      = "Download Selected"
            Dock      = 'Bottom'
            Height    = 30
            Add_Click = {
                $selectedItems = $CheckboxList.CheckedItems
                foreach ($selectedItem in $selectedItems) {
                    $fileName = $selectedItem.ToString()
                    $fileUrl = "https://raw.githubusercontent.com/mrdotkg/dotfiles/main/$fileName"
                    $destinationPath = Join-Path -Path $HOME\Documents\Gandalf-WinUtil-Scripts -ChildPath $fileName
                    write-host "Downloading $fileName to $destinationPath"
                    # Ensure the destination directory exists
                    if (-not (Test-Path -Path (Split-Path -Path $destinationPath -Parent))) {
                        New-Item -ItemType Directory -Path (Split-Path -Path $destinationPath -Parent) | Out-Null
                    }
                    Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath
                }
                [System.Windows.Forms.MessageBox]::Show("Selected files downloaded successfully!")
                # Close the checkbox form after download, re populate the select dropdown and select the first item
                $SelectDropdown.Items.Clear()
                Get-ChildItem -Path $PersonalScriptsPath -Filter *.json | ForEach-Object {
                    $SelectDropdown.Items.Add($_.BaseName) | Out-Null
                }
                if ($SelectDropdown.Items.Count -gt 0) {
                    $SelectDropdown.SelectedIndex = 0
                }

                $CheckboxForm.Close()
            }
        }

        $CheckboxForm.Controls.Add($CheckboxList)
        $CheckboxForm.Controls.Add($DownloadButton)
        $CheckboxForm.ShowDialog()
    }
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
function RunSelectedItems {
    param(
        [ValidateSet("Invoke", "Revoke")]
        [string]$Action
    )
    $listViews = @(
        @{ LV = $AppsLV; Data = $Scripts.apps },
        @{ LV = $TweaksLV; Data = $Scripts.tweaks },
        @{ LV = $TasksLV; Data = $Scripts.tasks }
    )
    foreach ($entry in $listViews) {
        # differentiate between Apps, Tweaks and Tasks
        
        $selected = $entry.LV.CheckedItems
        foreach ($item in $selected) {
            $scriptObj = $entry.Data | Where-Object { $_.content -eq $item.Text }
            if ($Action -eq "Invoke") {
                # TODO - Create a universal invoke action
                $scriptObj.script | ForEach-Object { Write-Host "Executing $($item.Text): $_" }
            }
            elseif ($Action -eq "Revoke") {
                # TODO - Create a universal revoke action
                $scriptObj.Revoke | ForEach-Object { Write-Host "Revoking $($item.Text): $_" }
            }
        }
    }
}

## GUI Initialization ##
$Form = New-Object Windows.Forms.Form -Property $FormProps

$HeaderPanel = New-Object System.Windows.Forms.Panel -Property $HeaderPanelProps
$ContentPanel = New-Object Windows.Forms.Panel -Property $ContentPanelProps
$FooterPanel = New-Object Windows.Forms.Panel -Property $FooterPanelProps

$SearchBox = New-Object System.Windows.Forms.TextBox -Property $SearchBoxProps
$ProfileDropDown = New-Object System.Windows.Forms.ComboBox -Property $ProfileDropdownProps
$BrowseLibrary = New-Object System.Windows.Forms.Label -Property $BrowseLibraryProps

# Separate the Content Panel horizontally with a Splitter bar
$SplitContainer1 = New-Object Windows.Forms.SplitContainer -Property $SplitProps
$SplitContainer2 = New-Object Windows.Forms.SplitContainer -Property $SplitProps

# Append ListViews to both sides of the Splitter bar
$AppsLV = New-Object Windows.Forms.ListView -Property $ListViewProps
$TweaksLV = New-Object Windows.Forms.ListView -Property $ListViewProps
$TasksLV = New-Object Windows.Forms.ListView -Property $ListViewProps

$SplitContainer1.Panel1.Controls.Add($AppsLV)
$SplitContainer1.Panel2.Controls.Add($SplitContainer2)
$SplitContainer2.Panel1.Controls.Add($TweaksLV)
$SplitContainer2.Panel2.Controls.Add($TasksLV)

$AppsLV.Columns.Add("Install Apps & Tools", 150)
$AppsLV.Columns.Add("Description", 300)

$TweaksLV.Columns.Add("Edit System Settings", 150)
$TweaksLV.Columns.Add("Description", 300)

$TasksLV.Columns.Add("Run Helper Tasks", 150)
$TasksLV.Columns.Add("Description", 300)
$InvokeButton = New-Object System.Windows.Forms.Button -Property $InvokeButtonProps
$SelectAllSwitch = New-Object System.Windows.Forms.CheckBox -Property $SelectAllSwitchProps

$HeaderPanel.Controls.AddRange(@($SelectAllSwitch, $SearchBox, $InvokeButton))
$ContentPanel.Controls.Add($SplitContainer1)
$FooterPanel.Controls.AddRange(@($ProfileDropdown, $BrowseLibrary))

$Form.Controls.AddRange(@($HeaderPanel, $ContentPanel, $FooterPanel))

$PersonalScriptsPath = "$HOME\Documents\Gandalf-WinUtil-Scripts"
Get-ChildItem -Path $PersonalScriptsPath -Filter *.json | ForEach-Object {
    $ProfileDropdown.Items.Add($_.BaseName) | Out-Null
}
if ($ProfileDropdown.Items.Count -gt 0) {
    $ProfileDropdown.SelectedIndex = 0
}

[void]$Form.ShowDialog()