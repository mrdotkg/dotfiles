# Install nvm on Windows 11

Write-Output "Installing nvm..."
choco install nvm -y --force || { Write-Output "Failed to install nvm"; exit 1 }

# Configure nvm
Write-Output "Configuring nvm..."
$nvmConfigPath = "$env:USERPROFILE\.nvm"
if (-Not (Test-Path -Path $nvmConfigPath)) {
    New-Item -ItemType Directory -Path $nvmConfigPath
}

$nvmConfigFile = "$nvmConfigPath\settings.txt"
$nvmConfigContent = @"
root: $env:USERPROFILE\.nvm
path: $env:USERPROFILE\AppData\Roaming\npm
"@

Set-Content -Path $nvmConfigFile -Value $nvmConfigContent

Write-Output "nvm installation and configuration completed successfully."
