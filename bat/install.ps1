# Install bat on Windows 11

Write-Output "Installing bat..."
choco install bat -y --force || { Write-Output "Failed to install bat"; exit 1 }

# Configure bat
Write-Output "Configuring bat..."
$batConfigPath = "$env:USERPROFILE\.config\bat"
if (-Not (Test-Path -Path $batConfigPath)) {
    New-Item -ItemType Directory -Path $batConfigPath
}

$batConfigFile = "$batConfigPath\config"
$batConfigContent = @"
# Bat Configuration
--theme="TwoDark"
--style="numbers,changes"
"@

Set-Content -Path $batConfigFile -Value $batConfigContent

Write-Output "bat installation and configuration completed successfully."
