# Uninstall Git

Write-Output "Uninstalling Git..."
choco uninstall git -y || { Write-Output "Failed to uninstall Git"; exit 1 }

# Remove Git config files
Write-Output "Removing Git config files..."
$configPath = "$env:USERPROFILE\.gitconfig"
if (Test-Path $configPath) {
    Remove-Item -Force $configPath
    Write-Output "Git config files removed successfully."
}
else {
    Write-Output "No Git config files found."
}
