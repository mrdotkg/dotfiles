# Install ripgrep on Windows 11

Write-Output "Installing ripgrep..."
choco install ripgrep -y --force || { Write-Output "Failed to install ripgrep"; exit 1 }

# Configure ripgrep
Write-Output "Configuring ripgrep..."
$ripgrepConfigPath = "$env:USERPROFILE\.config\ripgrep"
if (-Not (Test-Path -Path $ripgrepConfigPath)) {
    New-Item -ItemType Directory -Path $ripgrepConfigPath
}

$ripgrepConfigFile = "$ripgrepConfigPath\ripgrep.conf"
$ripgrepConfigContent = @"
# Ripgrep Configuration
--hidden
--glob '!.git/*'
"@

Set-Content -Path $ripgrepConfigFile -Value $ripgrepConfigContent

Write-Output "ripgrep installation and configuration completed successfully."
