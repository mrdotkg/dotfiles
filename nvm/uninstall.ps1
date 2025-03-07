# Uninstall nvm

Write-Output "Uninstalling nvm..."
choco uninstall nvm -y || { Write-Output "Failed to uninstall nvm"; exit 1 }

# Remove nvm config files
Write-Output "Removing nvm config files..."
$configPath = "$env:USERPROFILE\.nvm"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "nvm config files removed successfully."
}
else {
    Write-Output "No nvm config files found."
}
