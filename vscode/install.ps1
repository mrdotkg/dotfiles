# Install and configure VSCode on Windows 11

# Define the URL for the latest VSCode release
$vscodeUrl = "https://update.code.visualstudio.com/latest/win32-x64-user/stable"

# Download and install VSCode
Write-Output "Installing VSCode..."
$vscodeInstaller = "$env:TEMP\vscode_installer.exe"
Invoke-WebRequest -Uri $vscodeUrl -OutFile $vscodeInstaller
Start-Process -FilePath $vscodeInstaller -ArgumentList "/silent" -Wait
Remove-Item -Path $vscodeInstaller -Force

# Configure VSCode
Write-Output "Configuring VSCode..."
$vscodeConfigPath = "$env:APPDATA\Code\User"
if (-Not (Test-Path -Path $vscodeConfigPath)) {
    New-Item -ItemType Directory -Path $vscodeConfigPath
}

# Create a basic VSCode settings file
$settingsFile = "$vscodeConfigPath\settings.json"
$settingsContent = @"
{
    "editor.fontSize": 14,
    "editor.tabSize": 4,
    "files.autoSave": "onFocusChange"
}
"@

Set-Content -Path $settingsFile -Value $settingsContent

Write-Output "VSCode installation and configuration completed successfully."
